class AppNotificationModel {
  final String id;
  final String title;
  final String body;
  final String type;
  final String? orderId;
  final bool isRead;
  final DateTime createdAt;

  AppNotificationModel({
    required this.id,
    required this.title,
    required this.body,
    this.type = 'general',
    this.orderId,
    this.isRead = false,
    required this.createdAt,
  });

  factory AppNotificationModel.fromJson(Map<String, dynamic> json) {
    return AppNotificationModel(
      // Coerced, not cast: every other field here tolerates a missing value,
      // and a hard cast on this one would fail the entire list load over a
      // single bad row.
      id: json['_id']?.toString() ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      type: json['type'] as String? ?? 'general',
      orderId: json['orderId'] as String?,
      isRead: json['isRead'] as bool? ?? false,
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
