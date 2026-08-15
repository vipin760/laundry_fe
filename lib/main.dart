import 'dart:async';

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

void main() {
  // Startup init (below) must never be able to leave runApp() uncalled.
  // An uncaught exception thrown from an async main() before runApp() does
  // NOT produce a native iOS crash — the process stays alive with nothing
  // ever drawn, i.e. an indefinite blank screen with zero crash report.
  // runZonedGuarded + the try/catch below guarantee runApp() always runs.
  runZonedGuarded(() async {
    // debugPrint() is not stripped in release builds by default — it's a
    // throttled print wrapper, not a debug-only stub. Silence it here so
    // internal diagnostics (including things like auth token fragments)
    // never reach a production console.
    if (kReleaseMode) {
      debugPrint = (String? message, {int? wrapWidth}) {};
    }

    WidgetsFlutterBinding.ensureInitialized();

    try {
      await ApiClient.init();
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // Register background message handler for Firebase Messaging
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // Initialize notification service
      await NotificationService.instance.initialize();
    } catch (e, stack) {
      // Startup init failed (e.g. Firebase/network/platform-channel issue).
      // Report it instead of letting it block runApp() below — the app
      // still needs to render so the failure is visible and recoverable
      // rather than an indefinite blank screen.
      FlutterError.reportError(FlutterErrorDetails(exception: e, stack: stack));
    }

    // Single top-level container so the 401 interceptor can call forceLogout()
    // without needing a BuildContext.
    final container = ProviderContainer();

    ApiClient.onUnauthorized = () {
      container.read(authProvider.notifier).forceLogout();
    };

    runApp(
      UncontrolledProviderScope(
        container: container,
        child: const LaundryApp(),
      ),
    );
  }, (error, stack) {
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
    final router = ref.watch(appRouterProvider);

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
