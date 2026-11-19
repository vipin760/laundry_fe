import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:laudry_app/core/api/api_client.dart';
import 'package:laudry_app/core/realtime/order_realtime.dart';
import 'package:laudry_app/features/auth/models/auth_user.dart';
import 'package:laudry_app/features/auth/providers/auth_provider.dart';
import 'package:laudry_app/features/auth/screens/auth_screen.dart';
import 'package:laudry_app/features/delivery/screens/delivery_partner_home_screen.dart';
import 'package:laudry_app/features/home/screens/home_screen.dart';
import 'package:laudry_app/main.dart';

/// Real AuthNotifier minus Firebase/backend: send-otp and verify-otp are
/// faked, but the resulting state transitions mirror sendMobileOtp() and
/// verifyMobileOtp() -> _saveSession(), including the trailing await
/// (notification permission + FCM registration) after isAuthenticated flips.
class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier({
    this.isNewUser = false,
    this.role = 'user',
    this.otpIsValid = true,
  });

  final bool isNewUser;
  final String role;
  final bool otpIsValid;

  @override
  AuthState build() => AuthState(isInitialized: true);

  @override
  Future<bool> sendMobileOtp(String mobileNumber) async {
    state = state.copyWith(
      isOtpSent: true,
      pendingMobileNumber: '+91$mobileNumber',
      isNewUser: isNewUser,
      verificationId: 'test-verification-id',
      clearError: true,
    );
    return true;
  }

  @override
  Future<bool> verifyMobileOtp(
    String mobileNumber,
    String otp, {
    String? name,
  }) async {
    if (!otpIsValid) {
      state = state.copyWith(error: 'Invalid OTP. Please try again.');
      return false;
    }
    ApiClient.setToken('test-token');
    state = state.copyWith(
      isAuthenticated: true,
      token: 'test-token',
      user: AuthUser(mobileNumber: '+91$mobileNumber', name: name, role: role),
      isOtpSent: false,
      isNewUser: false,
      clearVerificationId: true,
      clearError: true,
    );
    // _saveSession keeps awaiting after the state flip; the router navigates
    // (and disposes the auth screen) before this returns.
    await Future<void>.delayed(const Duration(seconds: 1));
    return state.isAuthenticated;
  }
}

Future<void> _pumpAppToGuestHome(
  WidgetTester tester,
  _FakeAuthNotifier auth,
) async {
  SharedPreferences.setMockInitialValues({});
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authProvider.overrideWith(() => auth),
        // The live order socket can't connect under flutter_test.
        orderRealtimeProvider.overrideWith((ref) {}),
      ],
      // Same theme override as widget_test.dart (google_fonts can't fetch
      // in tests).
      child: LaundryApp(theme: ThemeData.light()),
    ),
  );
  // Splash decodes its logo with a real image codec — see widget_test.dart.
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
  });
  await tester.pump();
  for (var i = 0; i < 100; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (find.byType(HomeScreen).evaluate().isNotEmpty) break;
  }
  await tester.pumpAndSettle();
  expect(find.byType(HomeScreen), findsOneWidget);
}

/// Guest taps the Profile tab -> HomeScreen does context.push(login).
Future<void> _openLoginFromProfileTab(WidgetTester tester) async {
  await tester.tap(find.text('Profile').last);
  await tester.pumpAndSettle();
  expect(find.byType(AuthScreen), findsOneWidget);
  expect(find.text('Send OTP'), findsOneWidget);
}

Future<void> _sendOtp(WidgetTester tester) async {
  await tester.enterText(find.byType(TextFormField).first, '9876543210');
  await tester.tap(find.byType(Checkbox));
  await tester.pump();
  await tester.tap(find.text('Send OTP'));
  await tester.pumpAndSettle();
}

/// Types the code into the first OTP box (as iOS SMS autofill does); the
/// screen spreads it across the six boxes and auto-submits.
Future<void> _enterOtp(WidgetTester tester, {required int firstOtpBox}) async {
  await tester.enterText(find.byType(TextFormField).at(firstOtpBox), '123456');
  // Advance in frame-sized steps, like a device: the login screen's exit
  // transition completes (disposing it) *during* the post-login await, so code
  // after `await verifyMobileOtp()` really does run on a disposed screen.
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pumpAndSettle();
}

void main() {
  // Regression: iOS customers who opened login from guest Home were left on
  // the login screen, reset to "Send OTP", after entering a valid OTP.
  testWidgets('existing user: OTP login from guest Home lands on Home',
      (tester) async {
    await _pumpAppToGuestHome(tester, _FakeAuthNotifier());
    await _openLoginFromProfileTab(tester);
    await _sendOtp(tester);
    await _enterOtp(tester, firstOtpBox: 1);

    expect(find.byType(AuthScreen), findsNothing);
    expect(find.text('Send OTP'), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets(
      'new user: lands on Home and the referral code is still submitted',
      (tester) async {
    final requests = _recordRequests();
    await _pumpAppToGuestHome(tester, _FakeAuthNotifier(isNewUser: true));
    await _openLoginFromProfileTab(tester);
    await _sendOtp(tester);
    // New-user form: mobile(0), name(1), referral code(2), OTP boxes(3..8).
    await tester.enterText(find.byType(TextFormField).at(1), 'Test User');
    await tester.enterText(find.byType(TextFormField).at(2), 'FRIEND123');
    await _enterOtp(tester, firstOtpBox: 3);

    expect(find.byType(AuthScreen), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
    // The login screen was already gone when verifyMobileOtp() returned, yet
    // the referral code was still sent, with the new session's token.
    final apply = requests.where((r) => r.path == '/referral/apply').toList();
    expect(apply, hasLength(1));
    expect(apply.single.data, {'code': 'FRIEND123'});
    expect(apply.single.headers['Authorization'], 'Bearer test-token');

    // Its result is still reported to the user, on Home. flutter_test answers
    // every HTTP call with 400, so it's the failure message; it is queued
    // behind the "OTP sent" snackbar from the send step (4s default).
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Referral code could not be applied'),
      findsOneWidget,
    );
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('delivery partner: OTP login from guest Home lands on partner home',
      (tester) async {
    await _pumpAppToGuestHome(
      tester,
      _FakeAuthNotifier(role: 'delivery_partner'),
    );
    await _openLoginFromProfileTab(tester);
    await _sendOtp(tester);
    await _enterOtp(tester, firstOtpBox: 1);

    expect(find.byType(AuthScreen), findsNothing);
    expect(find.byType(DeliveryPartnerHomeScreen), findsOneWidget);
  });

  testWidgets('wrong OTP: stays on the OTP step, no referral call',
      (tester) async {
    final requests = _recordRequests();
    await _pumpAppToGuestHome(
      tester,
      _FakeAuthNotifier(isNewUser: true, otpIsValid: false),
    );
    await _openLoginFromProfileTab(tester);
    await _sendOtp(tester);
    await tester.enterText(find.byType(TextFormField).at(1), 'Test User');
    await tester.enterText(find.byType(TextFormField).at(2), 'FRIEND123');
    await _enterOtp(tester, firstOtpBox: 3);

    expect(find.byType(AuthScreen), findsOneWidget);
    expect(find.text('Invalid OTP. Please try again.'), findsOneWidget);
    expect(find.text('Create Account & Log in'), findsOneWidget);
    expect(requests.where((r) => r.path == '/referral/apply'), isEmpty);
  });
}

/// Records every request the app sends through the shared ApiClient (Dio is
/// a static singleton, so the interceptor is removed after each test).
List<RequestOptions> _recordRequests() {
  final requests = <RequestOptions>[];
  final recorder = InterceptorsWrapper(
    onRequest: (options, handler) {
      requests.add(options);
      handler.next(options);
    },
  );
  ApiClient.instance.interceptors.add(recorder);
  addTearDown(() => ApiClient.instance.interceptors.remove(recorder));
  return requests;
}
