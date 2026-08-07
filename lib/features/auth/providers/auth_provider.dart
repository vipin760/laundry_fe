import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/api/api_client.dart';
import '../../../core/services/notification_service.dart';
import '../models/auth_user.dart';
import '../../services/providers/cart_provider.dart' show clearCartLocalCache;

class AuthState {
  AuthState({
    this.isLoading = false,
    this.isInitialized = false,
    this.error,
    this.isAuthenticated = false,
    this.token,
    this.user,
    this.isOtpSent = false,
    this.pendingMobileNumber,
    this.isNewUser = false,
    this.serverName,
    this.verificationId,
  });

  final bool isLoading;
  final bool isInitialized;
  final String? error;
  final bool isAuthenticated;
  final String? token;
  final AuthUser? user;
  final bool isOtpSent;
  final String? pendingMobileNumber;
  /// True when send-otp confirms this mobile number has no existing account.
  final bool isNewUser;
  /// Name returned by send-otp for existing users (used for "Welcome back" UI).
  final String? serverName;
  /// Firebase verification ID for OTP verification
  final String? verificationId;

  AuthState copyWith({
    bool? isLoading,
    bool? isInitialized,
    String? error,
    bool? isAuthenticated,
    String? token,
    AuthUser? user,
    bool? isOtpSent,
    String? pendingMobileNumber,
    bool? isNewUser,
    String? serverName,
    String? verificationId,
    bool clearError = false,
    bool clearServerName = false,
    bool clearVerificationId = false,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isInitialized: isInitialized ?? this.isInitialized,
      error: clearError ? null : (error ?? this.error),
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      token: token ?? this.token,
      user: user ?? this.user,
      isOtpSent: isOtpSent ?? this.isOtpSent,
      pendingMobileNumber: pendingMobileNumber ?? this.pendingMobileNumber,
      isNewUser: isNewUser ?? this.isNewUser,
      serverName: clearServerName ? null : (serverName ?? this.serverName),
      verificationId: clearVerificationId ? null : (verificationId ?? this.verificationId),
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  bool _isCheckingAuthStatus = false;

  @override
  AuthState build() {
    Future.microtask(() => _checkAuthStatus());
    return AuthState();
  }

  /// Normalize phone number to E.164 format for India
  /// Converts: 9876543210 -> +919876543210
  /// Converts: 919876543210 -> +919876543210
  /// Converts: +919876543210 -> +919876543210
  /// Converts: 98765 43210 -> +919876543210
  /// Throws if invalid format
  String _normalizePhoneNumber(String phoneNumber) {
    final digits = phoneNumber.replaceAll(RegExp(r'\D'), '');

    if (digits.length == 10) {
      return '+91$digits';
    }

    if (digits.length == 12 && digits.startsWith('91')) {
      return '+$digits';
    }

    throw FormatException(
      'Please enter a valid Indian mobile number.',
    );
  }

  Future<void> _checkAuthStatus() async {
    if (_isCheckingAuthStatus) return;
    _isCheckingAuthStatus = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      final encodedUser = prefs.getString('auth_user');

      if (token != null && token.isNotEmpty) {
        ApiClient.setToken(token);
        state = state.copyWith(
          isAuthenticated: true,
          isInitialized: true,
          token: token,
          user: _decodeUser(encodedUser),
          isNewUser: false,
        );
        // cartProvider/addressesProvider/walletProvider watch this state
        // directly, so they auto-rebuild (and fetch) now that isAuthenticated
        // flipped true — no manual invalidation needed.
      } else {
        state = state.copyWith(isInitialized: true);
      }
    } finally {
      _isCheckingAuthStatus = false;
    }
  }

  /// Sends OTP to [mobileNumber]. On success, the backend returns whether
  /// this is a new user and (for existing users) their saved name.
  /// Then triggers Firebase Phone Authentication to send the actual OTP.
  Future<bool> sendMobileOtp(String mobileNumber) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      // Normalize phone number to E.164 format
      final normalizedMobile = _normalizePhoneNumber(mobileNumber);

      // Step 1: Call backend to check user existence
      final response = await ApiClient.instance.post(
        '/auth/mobile/send-otp',
        data: {'mobileNumber': normalizedMobile},
      );

      // Backend returns { isNewUser: bool, name: String? }
      final data = response.data;
      final isNewUser =
          (data is Map<String, dynamic>) ? data['isNewUser'] == true : false;
      final serverName = (data is Map<String, dynamic>)
          ? data['name']?.toString()
          : null;

      // Step 2: Trigger Firebase Phone Auth
      final firebaseAuth = FirebaseAuth.instance;
      
      await firebaseAuth.verifyPhoneNumber(
        phoneNumber: normalizedMobile,
        verificationCompleted: (PhoneAuthCredential credential) async {
          debugPrint(
            'Firebase automatic verification received but intentionally ignored.',
          );
          return;
        },
        verificationFailed: (FirebaseAuthException e) {
          state = state.copyWith(
            isLoading: false,
            error: _extractFirebaseErrorMessage(e),
          );
        },
        codeSent: (String verificationId, int? resendToken) {
          // OTP sent successfully, store verificationId for manual verification
          state = state.copyWith(
            isLoading: false,
            isOtpSent: true,
            pendingMobileNumber: normalizedMobile,
            isNewUser: isNewUser,
            serverName: serverName,
            verificationId: verificationId,
            clearError: true,
          );
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          // Auto-retrieval timeout, user must enter OTP manually
          // verificationId is still valid for manual entry
        },
        timeout: const Duration(seconds: 60),
      );

      return true;
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: _extractErrorMessage(
          e,
          fallback: 'Failed to send OTP. Please try again.',
        ),
      );
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Verifies OTP. For new users, pass [name] so the backend can create the
  /// account in a single step. On success, always navigates to HomeScreen.
  Future<void> verifyMobileOtp(
    String mobileNumber,
    String otp, {
    String? name,
  }) async {
    debugPrint('[AUTH] verifyMobileOtp() started');
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      // Normalize phone number to E.164 format
      final normalizedMobile = _normalizePhoneNumber(mobileNumber);

      // Verify OTP through Firebase
      final firebaseAuth = FirebaseAuth.instance;
      final verificationId = state.verificationId;

      if (verificationId == null) {
        state = state.copyWith(
          isLoading: false,
          error: 'OTP session expired. Please request a new OTP.',
        );
        return;
      }

      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: otp.trim(),
      );

      debugPrint('[AUTH] Firebase signInWithCredential() started');
      final userCredential = await firebaseAuth.signInWithCredential(credential);
      final idToken = await userCredential.user?.getIdToken();
      debugPrint('[AUTH] Firebase idToken received: ${idToken != null ? "${idToken.substring(0, 10)}..." : "null"}');

      if (idToken == null) {
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to get authentication token.',
        );
        return;
      }

      // Complete login with backend
      debugPrint('[AUTH] Calling _completeFirebaseLogin()');
      await _completeFirebaseLogin(idToken, normalizedMobile, name);
    } on FirebaseAuthException catch (e) {
      debugPrint('[AUTH] FirebaseAuthException: ${e.code} - ${e.message}');
      state = state.copyWith(
        isLoading: false,
        error: _extractFirebaseErrorMessage(e),
      );
    } catch (e) {
      debugPrint('[AUTH] Exception in verifyMobileOtp: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void resetOtpFlow() {
    state = state.copyWith(
      isOtpSent: false,
      pendingMobileNumber: '',
      isNewUser: false,
      clearServerName: true,
      clearVerificationId: true,
      clearError: true,
    );
  }

  Future<bool> forgotPassword(String email) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await ApiClient.instance.post(
        '/auth/forgot-password',
        data: {'email': email},
      );

      state = state.copyWith(isLoading: false);
      return true;
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: _extractErrorMessage(
          e,
          fallback: 'Failed to send reset token. Please try again.',
        ),
      );
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Updates the user's name and/or photoUrl.
  /// Both fields are optional — pass null to leave unchanged.
  Future<void> updateProfile({String? name, String? photoUrl}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final body = <String, dynamic>{};
      if (name != null && name.trim().isNotEmpty) body['name'] = name.trim();
      if (photoUrl != null && photoUrl.trim().isNotEmpty) body['photoUrl'] = photoUrl.trim();

      final response = await ApiClient.instance.patch('/users/profile', data: body);
      final data = response.data;

      if (data is Map<String, dynamic>) {
        final updatedUser = state.user?.copyWith(
          name: data['name']?.toString() ?? state.user?.name,
          photoUrl: data['photoUrl']?.toString() ?? state.user?.photoUrl,
        );
        if (updatedUser != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('auth_user', jsonEncode(updatedUser.toJson()));
          state = state.copyWith(isLoading: false, user: updatedUser, clearError: true);
          return;
        }
      }
      state = state.copyWith(isLoading: false, clearError: true);
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: _extractErrorMessage(e, fallback: 'Failed to update profile. Please try again.'),
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> _completeFirebaseLogin(
    String idToken,
    String mobileNumber,
    String? name,
  ) async {
    debugPrint('[AUTH] _completeFirebaseLogin() started');
    try {
      final response = await ApiClient.instance.post(
        '/auth/firebase-login',
        data: {
          'firebaseIdToken': idToken,
          'mobileNumber': mobileNumber,
          if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
        },
      );
      debugPrint('[AUTH] Backend /auth/firebase-login response received');

      final data = response.data;
      if (data is! Map<String, dynamic>) {
        state = state.copyWith(
          isLoading: false,
          error: 'Invalid response from server.',
        );
        return;
      }

      final token = data['access_token'] ?? data['token'];
      final userData = data['user'];
      debugPrint('[AUTH] Backend JWT received: ${token != null ? "${token.toString().substring(0, 10)}..." : "null"}');

      if (token != null && userData is Map<String, dynamic>) {
        debugPrint('[AUTH] Calling _saveSession()');
        await _saveSession(
          token.toString(),
          AuthUser.fromJson(userData),
          isNewUser: false,
        );
        return;
      }

      state = state.copyWith(
        isLoading: false,
        error: 'Invalid response from server.',
      );
    } on DioException catch (e) {
      debugPrint('[AUTH] DioException in _completeFirebaseLogin: ${e.response?.statusCode} - ${e.message}');
      state = state.copyWith(
        isLoading: false,
        error: _extractErrorMessage(
          e,
          fallback: 'Login failed. Please try again.',
        ),
      );
    } catch (e) {
      debugPrint('[AUTH] Exception in _completeFirebaseLogin: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> _saveSession(
    String token,
    AuthUser user, {
    bool isNewUser = false,
  }) async {
    debugPrint('[AUTH] _saveSession() started with token: ${token.substring(0, 10)}...');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', token);
    await prefs.setString('auth_user', jsonEncode(user.toJson()));
    debugPrint('[AUTH] JWT Saved: ${token.substring(0, 10)}...');
    ApiClient.setToken(token);

    // Set authenticated state FIRST so GoRouter redirect fires with the
    // correct isAuthenticated = true before any provider rebuilds.
    state = state.copyWith(
      isLoading: false,
      isAuthenticated: true,
      token: token,
      user: user,
      isOtpSent: false,
      pendingMobileNumber: '',
      isNewUser: false,
      clearServerName: true,
      clearVerificationId: true,
      clearError: true,
    );
    debugPrint('[AUTH] State Updated after save: isAuthenticated=${state.isAuthenticated}, isInitialized=${state.isInitialized}');

    // Register FCM token so this device receives push notifications.
    // No-op until Firebase is configured (see NotificationService).
    await NotificationService.instance.requestPermissionAndRegister(ApiClient.instance);

    // Process any pending token refreshes that occurred during logout/auth transitions
    await NotificationService.instance.processPendingTokenRefresh(ApiClient.instance);
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('auth_user');

    // Tell the server to revoke the token (best-effort).
    try {
      await ApiClient.instance.post('/auth/logout');
    } catch (_) {}

    await ApiClient.clearToken();

    // Remove FCM token from backend before clearing local state
    // This prevents dead token accumulation in the database
    try {
      final currentToken = await NotificationService.instance.getStoredToken();
      if (currentToken != null && currentToken.isNotEmpty) {
        await ApiClient.instance.delete(
          '/notifications/fcm-token',
          data: {'fcmToken': currentToken},
        );
      }
    } catch (e) {
      // Never block logout if token removal fails
      debugPrint('[AuthProvider] Failed to remove FCM token from backend: $e');
    }

    // Clear FCM token state to clean up push notification registration
    await NotificationService.instance.clearTokenState();

    // Wipe the legacy local cart cache. Deliberately NOT
    // `ref.read(cartProvider.notifier).clearCart()` — cartProvider watches
    // this very provider (see CartNotifier.build()), so reading its notifier
    // from inside AuthNotifier's own method closes a cycle and trips
    // Riverpod's circular-dependency guard. clearCartLocalCache() is a plain
    // function, not a provider read, so it can't create that cycle.
    await clearCartLocalCache(prefs);

    // cartProvider/addressesProvider/walletProvider watch this state
    // directly, so they auto-rebuild to their logged-out (empty) shape now
    // that isAuthenticated flipped false — no manual invalidation needed.
    // (This covers cartProvider's in-memory reset too — see the comment on
    // clearCartLocalCache() above.)
    // servicesProvider is public and doesn't depend on auth at all.
    // isInitialized must stay true here (matching forceLogout() below) —
    // _checkAuthStatus() only ever runs once at provider creation, so a bare
    // AuthState() would leave isInitialized stuck false for the rest of the
    // session, and the router's redirect refuses to navigate at all while
    // isInitialized is false — stranding the very next successful login on
    // the auth screen.
    state = AuthState(isInitialized: true);
  }

  /// Called by the 401 interceptor when an authenticated request is
  /// rejected (token expired/revoked). Skips the /auth/logout API call
  /// (token is already invalid) and resets all local state immediately.
  Future<void> forceLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('auth_user');
    await ApiClient.clearToken();

    // Clear FCM token state to clean up push notification registration
    await NotificationService.instance.clearTokenState();

    // cartProvider/addressesProvider/walletProvider watch this state
    // directly, so they auto-rebuild to their logged-out (empty) shape now
    // that isAuthenticated flipped false — no manual invalidation needed.
    state = AuthState(isInitialized: true);
  }

  AuthUser? _decodeUser(String? encodedUser) {
    if (encodedUser == null || encodedUser.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(encodedUser);
      if (decoded is Map<String, dynamic>) {
        return AuthUser.fromJson(decoded);
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  String _extractErrorMessage(DioException error, {required String fallback}) {
    final data = error.response?.data;
    if (data is Map<String, dynamic>) {
      final message = data['message'];
      if (message is List) {
        return message.join(', ');
      }
      if (message is String && message.isNotEmpty) {
        return message;
      }
    }

    if (data is String && data.isNotEmpty) {
      return data;
    }

    return fallback;
  }

  String _extractFirebaseErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-phone-number':
        return 'Invalid phone number format';
      case 'invalid-verification-code':
        return 'Invalid OTP. Please try again.';
      case 'code-expired':
        return 'OTP has expired. Please request a new one.';
      case 'quota-exceeded':
        return 'Too many attempts. Please try again later.';
      case 'user-disabled':
        return 'This account has been disabled';
      case 'too-many-requests':
        return 'Too many requests. Please try again later.';
      default:
        return e.message ?? 'Authentication failed. Please try again.';
    }
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
