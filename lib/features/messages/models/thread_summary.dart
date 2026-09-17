class ThreadSummary {
  final String threadId;
  final String otherUserId;
  final String otherDisplayName;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final int unreadCount;

  const ThreadSummary({
    required this.threadId,
    required this.otherUserId,
    required this.otherDisplayName,
    this.lastMessage,
    this.lastMessageAt,
    this.unreadCount = 0,
  });

  bool get hasUnread => unreadCount > 0;

  factory ThreadSummary.fromJson(Map<String, dynamic> json) {
    return ThreadSummary(
      threadId: json['thread_id'] as String,
      otherUserId: json['other_user_id'] as String,
      otherDisplayName: json['other_display_name'] as String? ?? 'Anonymous',
      lastMessage: json['last_message'] as String?,
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.parse(json['last_message_at'] as String).toLocal()
          : null,
      unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
    );
  }
}
