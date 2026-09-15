class CommunityReply {
  final String id;
  final String postId;
  final String userId;
  final String body;
  final String displayName;
  final DateTime createdAt;

  const CommunityReply({
    required this.id,
    required this.postId,
    required this.userId,
    required this.body,
    required this.displayName,
    required this.createdAt,
  });

  factory CommunityReply.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'] as Map<String, dynamic>?;
    return CommunityReply(
      id: json['id'] as String,
      postId: json['post_id'] as String,
      userId: json['user_id'] as String,
      body: json['body'] as String,
      displayName: profile?['display_name'] as String? ?? 'Anonymous',
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }
}
