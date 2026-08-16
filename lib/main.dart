import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'core/api/api_client.dart';
import 'firebase_options.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/providers/auth_provider.dart';
import 'core/services/notification_service.dart';

// TEMP DEBUG — white-screen investigation only. Remove once resolved.
// Fires a fire-and-forget ping to a webhook.site bin so we can see how far
// startup gets on a device with no Mac/Xcode console access. Never awaited
// by callers and always swallows its own errors so it can't itself become
// a new hang/crash point.
const _debugPingUrl = 'https://webhook.site/6ec5750b-8dc0-4535-a0e9-133358549dcd';

void _ping(String stage, {String? detail}) {
  unawaited(() async {
    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 5);
      final request = await client.postUrl(Uri.parse(_debugPingUrl));
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({
        'stage': stage,
        'detail': detail,
        'ts': DateTime.now().toIso8601String(),
        'platform': Platform.operatingSystem,
        'buildMode': kReleaseMode ? 'release' : (kProfileMode ? 'profile' : 'debug'),
      }));
      await request.close().timeout(const Duration(seconds: 5));
      client.close();
    } catch (_) {
      // Best-effort debug ping; must never affect real startup.
    }
  }());
}

void main() {
  _ping('main_entered');

  // Startup init (below) must never be able to leave runApp() uncalled.
  // An uncaught exception thrown from an async main() before runApp() does
  // NOT produce a native iOS crash — the process stays alive with nothing
  // ever drawn, i.e. an indefinite blank screen with zero crash report.
  // runZonedGuarded + the try/catch below guarantee runApp() always runs.
  runZonedGuarded(() async {
    _ping('zone_entered');

    // debugPrint() is not stripped in release builds by default — it's a
    // throttled print wrapper, not a debug-only stub. Silence it here so
    // internal diagnostics (including things like auth token fragments)
    // never reach a production console.
    if (kReleaseMode) {
      debugPrint = (String? message, {int? wrapWidth}) {};
    }

    WidgetsFlutterBinding.ensureInitialized();
    _ping('widgets_binding_ready');

    try {
      _ping('before_api_client_init');
      await ApiClient.init();
      _ping('after_api_client_init');

      _ping('before_firebase_init');
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      _ping('after_firebase_init');

      // Register background message handler for Firebase Messaging
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // Initialize notification service
      _ping('before_notification_init');
      await NotificationService.instance.initialize();
      _ping('after_notification_init');
    } catch (e, stack) {
      // Startup init failed (e.g. Firebase/network/platform-channel issue).
      // Report it instead of letting it block runApp() below — the app
      // still needs to render so the failure is visible and recoverable
      // rather than an indefinite blank screen.
      _ping('startup_catch_error', detail: e.toString());
      FlutterError.reportError(FlutterErrorDetails(exception: e, stack: stack));
    }

    // Single top-level container so the 401 interceptor can call forceLogout()
    // without needing a BuildContext.
    final container = ProviderContainer();

    ApiClient.onUnauthorized = () {
      container.read(authProvider.notifier).forceLogout();
    };

    _ping('before_run_app');
    runApp(
      UncontrolledProviderScope(
        container: container,
        child: const LaundryApp(),
      ),
    );
    _ping('after_run_app');
  }, (error, stack) {
    _ping('zone_uncaught_error', detail: error.toString());
    FlutterError.reportError(FlutterErrorDetails(exception: error, stack: stack));
  });
}

class LaundryApp extends ConsumerWidget {
  const LaundryApp({super.key, this.theme});

  /// Overrides the app's real theme (which pulls Manrope from
  /// `package:google_fonts`). Only ever supplied by widget tests, which run
  /// offline and can't fetch fonts — the real app always uses the default,
  /// i.e. [AppTheme.lightTheme].
  final ThemeData? theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    _ping('laundry_app_build_started');
    final router = ref.watch(appRouterProvider);
    _ping('app_router_provider_read');

    // Set router for notification deep linking
    NotificationService.instance.setRouter(router);

    return MaterialApp.router(
      title: 'LaundryBrew',
      debugShowCheckedModeBanner: false,
      theme: theme ?? AppTheme.lightTheme,
      routerConfig: router,
    );
  }
}
