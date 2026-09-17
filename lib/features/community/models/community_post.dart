class CommunityPost {
  final String id;
  final String userId;
  final String body;
  final String displayName;
  final DateTime createdAt;
  final int likeCount;
  final int commentCount;
  final bool isLikedByCurrentUser;
  final String? situationTag;

  const CommunityPost({
    required this.id,
    required this.userId,
    required this.body,
    required this.displayName,
    required this.createdAt,
    this.likeCount = 0,
    this.commentCount = 0,
    this.isLikedByCurrentUser = false,
    this.situationTag,
  });

  factory CommunityPost.fromJson(
    Map<String, dynamic> json, {
    String? currentUserId,
  }) {
    final profile = json['profiles'] as Map<String, dynamic>?;
    final likes = json['post_likes'] as List? ?? [];
    final replies = json['community_replies'] as List? ?? [];
    return CommunityPost(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      body: json['body'] as String,
      displayName: profile?['display_name'] as String? ?? 'Anonymous',
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      likeCount: likes.length,
      commentCount: replies.length,
      isLikedByCurrentUser: currentUserId != null &&
          likes.any((l) => (l as Map)['user_id'] == currentUserId),
      situationTag: json['situation_tag'] as String?,
    );
  }
}
