class Message {
  final String id;
  final String conversationId;
  final String senderId;
  final String content;
  final bool isRead;
  final DateTime createdAt;

  Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    this.isRead = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'conversation_id': conversationId,
        'sender_id': senderId,
        'content': content,
        'is_read': isRead ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
      };

  factory Message.fromMap(Map<String, dynamic> map) => Message(
        id: map['id'],
        conversationId: map['conversation_id'],
        senderId: map['sender_id'],
        content: map['content'],
        isRead: map['is_read'] == 1,
        createdAt: DateTime.parse(map['created_at']),
      );
}
