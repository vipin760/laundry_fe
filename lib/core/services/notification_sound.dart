import 'notification_sound_stub.dart'
    if (dart.library.js_interop) 'notification_sound_web.dart' as platform;

/// Plays the bundled notification chime.
///
/// Used only on Flutter Web: `flutter_local_notifications` ships no web
/// plugin implementation, so foreground FCM messages there can't play a
/// system notification sound the way Android/iOS do (see
/// [NotificationService._showLocalNotification]). This is the web-only
/// substitute — a plain HTML `<audio>` cue.
void playWebNotificationSound() => platform.playNotificationSound();
