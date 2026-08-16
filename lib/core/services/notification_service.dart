import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';

import 'notification_sound.dart';

/// Permission status enum
enum PermissionStatus {
  notRequested,
  granted,
  denied,
  provisional,
}

/// Background message handler.
/// Must be a top-level function for Firebase Messaging.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[NotificationService] Background message: ${message.messageId}');
  // Background messages are handled automatically by Firebase
  // No additional processing needed for basic notification display
}

/// NotificationService
/// -------------------
/// Production-ready Firebase Cloud Messaging implementation.
///
/// Features:
/// - Permission request with state persistence
/// - Token generation, rotation, and registration
/// - Foreground, background, and terminated message handling
/// - Local notification display for foreground messages
/// - Notification tap handling with deep linking
/// - Android notification channels
/// - Multi-device support
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  bool _initialized = false;
  bool _localNotificationsInitialized = false;
  static const String _permissionRequestedKey = 'notification_permission_requested';
  static const String _permissionStatusKey = 'notification_permission_status';
  static const String _fcmTokenKey = 'fcm_token';
  static const String _fcmTokenRegisteredKey = 'fcm_token_registered';
  static const String _pendingTokenRefreshKey = 'pending_token_refresh';
  static const int _maxRetries = 3;

  bool get initialized => _initialized;
  Dio? _dioInstance;
  GoRouter? _router;

  final AndroidNotificationChannel _androidChannel = const AndroidNotificationChannel(
    'laundry_brew_high_importance',
    'High Importance Notifications',
    description: 'This channel is used for important notifications.',
    importance: Importance.high,
    playSound: true,
  );

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  /// Set router for deep linking from notification taps
  void setRouter(GoRouter router) {
    _router = router;
  }

  /// Initialize Firebase Messaging and Local Notifications.
  /// Call once from main() after Firebase.initializeApp().
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final messaging = FirebaseMessaging.instance;

      // Every platform-channel call below is timeout-guarded. On iOS,
      // FirebaseMessaging calls can hang indefinitely (never resolve, never
      // throw) when APNs registration never completes — e.g. the app is
      // missing the aps-environment entitlement (Push Notifications
      // capability). Since this runs on the critical path before runApp()
      // in main.dart, an unbounded hang here means an indefinite blank
      // screen with zero crash report. A timeout guarantees this method
      // always completes so startup can never be blocked by it.
      const platformCallTimeout = Duration(seconds: 5);

      // Configure foreground message presentation
      await messaging
          .setForegroundNotificationPresentationOptions(
            alert: true,
            badge: true,
            sound: true,
          )
          .timeout(platformCallTimeout);

      // Initialize local notifications. flutter_local_notifications has no
      // web plugin implementation (it only ships Android/iOS/macOS/Linux
      // platform channels) — calling it on web throws and would otherwise
      // abort this whole try block before the message listeners below are
      // registered. Web foreground messages get their sound played directly
      // via playWebNotificationSound() instead (see _handleForegroundMessage).
      if (!kIsWeb) {
        await _initializeLocalNotifications().timeout(platformCallTimeout);
      }

      // Set up message handlers
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      // Check for initial message (app opened from terminated state)
      final initialMessage =
          await messaging.getInitialMessage().timeout(platformCallTimeout);
      if (initialMessage != null) {
        _handleNotificationTap(initialMessage);
      }

      // Set up token refresh listener
      messaging.onTokenRefresh.listen((newToken) {
        debugPrint('[NotificationService] FCM token refreshed: ${newToken.substring(0, 10)}...');
        _handleTokenRefresh(newToken);
      }).onError((err) {
        debugPrint('[NotificationService] Token refresh error: $err');
      });

      debugPrint('[NotificationService] Firebase Messaging initialized successfully.');
    } catch (e) {
      debugPrint('[NotificationService] Firebase initialization error: $e');
    }
  }

  /// Initialize Flutter Local Notifications plugin.
  Future<void> _initializeLocalNotifications() async {
    if (_localNotificationsInitialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/launcher_icon');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        _handleLocalNotificationTap(response);
      },
    );

    // Create Android notification channel
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_androidChannel);

    _localNotificationsInitialized = true;
    debugPrint('[NotificationService] Local notifications initialized.');
  }

  /// Handle foreground messages (app is open).
  /// Display local notification to ensure user sees it.
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('[NotificationService] Foreground message received: ${message.messageId}');
    
    final notification = message.notification;
    final data = message.data;

    if (notification != null) {
      if (kIsWeb) {
        // No flutter_local_notifications support on web — the browser tab
        // already shows Firebase's own foreground handling (if any); we just
        // add the audio cue here.
        playWebNotificationSound();
      } else {
        _showLocalNotification(
          title: notification.title ?? 'Laundry Brew',
          body: notification.body ?? '',
          payload: jsonEncode(data),
        );
      }
    }
  }

  /// Handle notification tap when app is in background.
  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('[NotificationService] Notification tapped: ${message.messageId}');
    final data = message.data;
    _navigateFromNotification(data);
  }

  /// Handle local notification tap (foreground messages).
  void _handleLocalNotificationTap(NotificationResponse response) {
    debugPrint('[NotificationService] Local notification tapped');
    final payload = response.payload;
    if (payload != null) {
      try {
        final data = jsonDecode(payload) as Map<String, dynamic>;
        _navigateFromNotification(data);
      } catch (e) {
        debugPrint('[NotificationService] Error parsing notification payload: $e');
      }
    }
  }

  /// Navigate to appropriate screen based on notification payload.
  void _navigateFromNotification(Map<String, dynamic> data) {
    if (_router == null) {
      debugPrint('[NotificationService] Router not set, cannot navigate');
      return;
    }

    final type = data['type'] as String?;
    final orderId = data['orderId'] as String?;

    debugPrint('[NotificationService] Navigating - type: $type, orderId: $orderId');

    switch (type) {
      case 'order_created':
      case 'pickup_assigned':
      case 'clothes_received':
      case 'washing_started':
      case 'ready_for_delivery':
      case 'out_for_delivery':
      case 'ready_for_pickup':
      case 'delivered':
        // Validate orderId and include as query parameter for order selection
        if (orderId != null && _isValidOrderId(orderId)) {
          _router!.go('/orders?orderId=$orderId');
        } else {
          // Fallback to orders list if orderId is invalid or missing
          _router!.go('/orders');
        }
        break;
      case 'promotion':
        _router!.go('/home');
        break;
      case 'support_message':
        _router!.go('/support');
        break;
      default:
        _router!.go('/home');
    }
  }

  /// Validate orderId format.
  /// Returns true if orderId is non-empty and contains only alphanumeric characters.
  bool _isValidOrderId(String orderId) {
    if (orderId.isEmpty) return false;
    // Allow alphanumeric, hyphens, underscores (common order ID formats)
    final validPattern = RegExp(r'^[a-zA-Z0-9_-]+$');
    return validPattern.hasMatch(orderId);
  }

  /// Show local notification using Flutter Local Notifications.
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'laundry_brew_high_importance',
      'High Importance Notifications',
      channelDescription: 'This channel is used for important notifications.',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/launcher_icon',
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'default',
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  /// Request notification permission and register FCM token with backend.
  /// 
  /// Permission flow:
  /// 1. Check if permission was already requested
  /// 2. If not requested, ask user for permission
  /// 3. Store permission state to avoid repeated prompts
  /// 4. If granted, get FCM token and register with backend
  /// 
  /// Returns true if permission was granted and token registered successfully.
  /// Returns false if permission denied, not configured, or registration failed.
  Future<bool> requestPermissionAndRegister(Dio dio) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final permissionRequested = prefs.getBool(_permissionRequestedKey) ?? false;
      final storedStatus = prefs.getString(_permissionStatusKey);

      // If permission was already denied, don't prompt again
      if (permissionRequested && storedStatus == PermissionStatus.denied.name) {
        debugPrint('[NotificationService] Permission previously denied, skipping request.');
        return false;
      }

      // If permission was already granted, just register token
      if (permissionRequested && storedStatus == PermissionStatus.granted.name) {
        debugPrint('[NotificationService] Permission already granted, registering token.');
        return await _registerFcmToken(dio);
      }

      // Request permission from user
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: true,
        sound: true,
      );

      // Store that we've now requested permission
      await prefs.setBool(_permissionRequestedKey, true);

      // Determine and store permission status
      PermissionStatus status;
      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        status = PermissionStatus.granted;
      } else if (settings.authorizationStatus == AuthorizationStatus.denied) {
        status = PermissionStatus.denied;
      } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
        status = PermissionStatus.provisional;
      } else {
        status = PermissionStatus.denied;
      }

      await prefs.setString(_permissionStatusKey, status.name);

      debugPrint('[NotificationService] Permission status: ${status.name}');

      // Register token if permission granted or provisional
      if (status == PermissionStatus.granted || status == PermissionStatus.provisional) {
        // Store Dio instance for token refresh callbacks
        _dioInstance = dio;
        return await _registerFcmToken(dio);
      }

      return false;
    } catch (e) {
      debugPrint('[NotificationService] Permission request error: $e');
      return false;
    }
  }

  /// Get FCM token and register with backend.
  /// Handles token change detection and re-registration.
  Future<bool> _registerFcmToken(Dio dio) async {
    try {
      final messaging = FirebaseMessaging.instance;
      final prefs = await SharedPreferences.getInstance();
      
      // Get the FCM token
      final token = await messaging.getToken();
      
      if (token == null || token.isEmpty) {
        debugPrint('[NotificationService] Failed to get FCM token.');
        return false;
      }

      // Get stored token and registration status
      final storedToken = prefs.getString(_fcmTokenKey);
      final tokenRegistered = prefs.getBool(_fcmTokenRegisteredKey) ?? false;

      // Check if token has changed or not yet registered
      if (token == storedToken && tokenRegistered) {
        debugPrint('[NotificationService] FCM token unchanged and already registered.');
        return true;
      }

      debugPrint('[NotificationService] FCM token obtained: ${token.substring(0, 10)}...');

      // Register token with backend
      await dio.post('/notifications/register-fcm-token', data: {
        'fcmToken': token,
      });

      // Store token and mark as registered
      await prefs.setString(_fcmTokenKey, token);
      await prefs.setBool(_fcmTokenRegisteredKey, true);

      debugPrint('[NotificationService] FCM token registered with backend successfully.');
      return true;
    } catch (e) {
      debugPrint('[NotificationService] FCM token registration error: $e');
      return false;
    }
  }

  /// Handle FCM token refresh from Firebase.
  /// Called automatically when Firebase rotates the token.
  void _handleTokenRefresh(String newToken) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedToken = prefs.getString(_fcmTokenKey);

      // Only register if token has changed
      if (newToken == storedToken) {
        debugPrint('[NotificationService] Token unchanged, skipping registration.');
        return;
      }

      debugPrint('[NotificationService] New FCM token detected, registering with backend...');

      // Store pending token for retry if Dio is not available
      await prefs.setString(_pendingTokenRefreshKey, newToken);

      // Use stored Dio instance or get from ApiClient
      final dio = _dioInstance;
      if (dio == null) {
        debugPrint('[NotificationService] Dio instance not available for token refresh. Token stored for retry.');
        return;
      }

      // Register new token with backend with retry logic
      await _registerTokenWithRetry(dio, newToken, 0);

      // Clear pending token on success
      await prefs.remove(_pendingTokenRefreshKey);

      debugPrint('[NotificationService] New FCM token registered successfully.');
    } catch (e) {
      debugPrint('[NotificationService] Token refresh registration error: $e');
    }
  }

  /// Register token with retry logic.
  /// Implements exponential backoff for failed registrations.
  Future<bool> _registerTokenWithRetry(Dio dio, String token, int retryCount) async {
    try {
      await dio.post('/notifications/register-fcm-token', data: {
        'fcmToken': token,
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_fcmTokenKey, token);
      await prefs.setBool(_fcmTokenRegisteredKey, true);

      return true;
    } catch (e) {
      if (retryCount >= _maxRetries) {
        debugPrint('[NotificationService] Token registration failed after $_maxRetries retries: $e');
        return false;
      }

      final delay = Duration(seconds: 2 << retryCount); // Exponential backoff: 2, 4, 8 seconds
      debugPrint('[NotificationService] Token registration failed, retrying in ${delay.inSeconds}s (attempt ${retryCount + 1}/$_maxRetries)');
      
      await Future.delayed(delay);
      return _registerTokenWithRetry(dio, token, retryCount + 1);
    }
  }

  /// Check for pending token refresh and retry registration.
  /// Call this after login to ensure any pending token refreshes are processed.
  Future<void> processPendingTokenRefresh(Dio dio) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingToken = prefs.getString(_pendingTokenRefreshKey);

      if (pendingToken == null || pendingToken.isEmpty) {
        return;
      }

      debugPrint('[NotificationService] Processing pending token refresh...');

      final success = await _registerTokenWithRetry(dio, pendingToken, 0);

      if (success) {
        await prefs.remove(_pendingTokenRefreshKey);
        debugPrint('[NotificationService] Pending token refresh processed successfully.');
      }
    } catch (e) {
      debugPrint('[NotificationService] Error processing pending token refresh: $e');
    }
  }

  /// Get current permission status from storage.
  Future<PermissionStatus> getPermissionStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final statusString = prefs.getString(_permissionStatusKey);
      
      if (statusString == null) {
        return PermissionStatus.notRequested;
      }

      return PermissionStatus.values.firstWhere(
        (status) => status.name == statusString,
        orElse: () => PermissionStatus.notRequested,
      );
    } catch (e) {
      debugPrint('[NotificationService] Error getting permission status: $e');
      return PermissionStatus.notRequested;
    }
  }

  /// Clear stored permission state (for testing or re-prompting).
  Future<void> clearPermissionState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_permissionRequestedKey);
      await prefs.remove(_permissionStatusKey);
      debugPrint('[NotificationService] Permission state cleared.');
    } catch (e) {
      debugPrint('[NotificationService] Error clearing permission state: $e');
    }
  }

  /// Clear stored FCM token state.
  /// Call this on logout to clean up token registration.
  Future<void> clearTokenState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_fcmTokenKey);
      await prefs.remove(_fcmTokenRegisteredKey);
      await prefs.remove(_pendingTokenRefreshKey);
      _dioInstance = null;
      debugPrint('[NotificationService] Token state cleared.');
    } catch (e) {
      debugPrint('[NotificationService] Error clearing token state: $e');
    }
  }

  /// Get current FCM token from storage.
  Future<String?> getStoredToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_fcmTokenKey);
    } catch (e) {
      debugPrint('[NotificationService] Error getting stored token: $e');
      return null;
    }
  }

  /// Check if token is registered with backend.
  Future<bool> isTokenRegistered() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_fcmTokenRegisteredKey) ?? false;
    } catch (e) {
      debugPrint('[NotificationService] Error checking token registration: $e');
      return false;
    }
  }

  /// Force re-registration of FCM token with backend.
  /// Useful after app reinstall or when token registration failed.
  Future<bool> forceReregisterToken(Dio dio) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Clear registration flag to force re-registration
      await prefs.setBool(_fcmTokenRegisteredKey, false);
      
      // Store Dio instance for token refresh callbacks
      _dioInstance = dio;
      
      // Re-register token
      return await _registerFcmToken(dio);
    } catch (e) {
      debugPrint('[NotificationService] Force re-registration error: $e');
      return false;
    }
  }
}
