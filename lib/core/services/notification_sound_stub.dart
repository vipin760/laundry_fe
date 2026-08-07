/// Non-web platforms (Android/iOS) play sound through the OS notification
/// channel / APNs payload instead — see [NotificationService] — so this is
/// intentionally a no-op.
void playNotificationSound() {}
