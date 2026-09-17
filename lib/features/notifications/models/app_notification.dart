class AppNotification {
  final String id;
  final String recipientId;
  final String? actorId;
  final String type;
  final String? entityId;
  final DateTime? readAt;
  final DateTime createdAt;
  final String actorDisplayName;

  const AppNotification({
    required this.id,
    required this.recipientId,
    required this.actorId,
    required this.type,
    required this.entityId,
    required this.readAt,
    required this.createdAt,
    required this.actorDisplayName,
  });

  bool get isRead => readAt != null;

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final actor = json['actor'] as Map<String, dynamic>?;
    return AppNotification(
      id: json['id'] as String,
      recipientId: json['recipient_id'] as String,
      actorId: json['actor_id'] as String?,
      type: json['type'] as String,
      entityId: json['entity_id'] as String?,
      readAt: json['read_at'] != null
          ? DateTime.parse(json['read_at'] as String).toLocal()
          : null,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      actorDisplayName: actor?['display_name'] as String? ?? 'Someone',
    );
  }
}
