class MessageRequest {
  final String id;
  final String senderId;
  final String receiverId;
  final String body;
  final String status;
  final DateTime createdAt;
  final String senderDisplayName;

  const MessageRequest({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.body,
    required this.status,
    required this.createdAt,
    required this.senderDisplayName,
  });

  factory MessageRequest.fromJson(Map<String, dynamic> json) {
    final profile = json['sender'] as Map<String, dynamic>?;
    return MessageRequest(
      id: json['id'] as String,
      senderId: json['sender_id'] as String,
      receiverId: json['receiver_id'] as String,
      body: json['body'] as String,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      senderDisplayName: profile?['display_name'] as String? ?? 'Anonymous',
    );
  }
}
