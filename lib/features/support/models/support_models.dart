class SupportConversation {
  const SupportConversation({
    required this.id,
    required this.userId,
    required this.status,
    this.lastMessagePreview,
    this.lastMessageAt,
    this.unreadForUser = 0,
    this.unreadForAdmin = 0,
  });

  final String id;
  final String userId;
  final String status;
  final String? lastMessagePreview;
  final DateTime? lastMessageAt;
  final int unreadForUser;
  final int unreadForAdmin;

  factory SupportConversation.fromJson(Map<String, dynamic> json) {
    return SupportConversation(
      id: json['_id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      status: json['status']?.toString() ?? 'open',
      lastMessagePreview: json['lastMessagePreview']?.toString(),
      lastMessageAt: json['lastMessageAt'] != null
          ? DateTime.tryParse(json['lastMessageAt'].toString())
          : null,
      unreadForUser: (json['unreadForUser'] as num?)?.toInt() ?? 0,
      unreadForAdmin: (json['unreadForAdmin'] as num?)?.toInt() ?? 0,
    );
  }
}

class SupportMessage {
  const SupportMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderRole,
    required this.body,
    this.readAt,
    this.createdAt,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String senderRole;
  final String body;
  final DateTime? readAt;
  final DateTime? createdAt;

  bool get isAdmin => senderRole == 'admin';

  factory SupportMessage.fromJson(Map<String, dynamic> json) {
    return SupportMessage(
      id: json['_id']?.toString() ?? '',
      conversationId: json['conversationId']?.toString() ?? '',
      senderId: json['senderId']?.toString() ?? '',
      senderRole: json['senderRole']?.toString() ?? 'user',
      body: json['body']?.toString() ?? '',
      readAt: json['readAt'] != null
          ? DateTime.tryParse(json['readAt'].toString())
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
    );
  }
}
