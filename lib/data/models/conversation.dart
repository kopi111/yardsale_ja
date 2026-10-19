class Conversation {
  final String id;
  final String listingId;
  final String buyerId;
  final String sellerId;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Joined fields
  final String? listingTitle;
  final String? listingImagePath;
  final double? listingPrice;
  final String? otherUserName;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final int unreadCount;

  Conversation({
    required this.id,
    required this.listingId,
    required this.buyerId,
    required this.sellerId,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.listingTitle,
    this.listingImagePath,
    this.listingPrice,
    this.otherUserName,
    this.lastMessage,
    this.lastMessageAt,
    this.unreadCount = 0,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// The other party to this conversation, seen from [viewerId]'s side.
  String otherParticipantId(String viewerId) =>
      viewerId == buyerId ? sellerId : buyerId;

  Map<String, dynamic> toMap() => {
        'id': id,
        'listing_id': listingId,
        'buyer_id': buyerId,
        'seller_id': sellerId,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory Conversation.fromMap(Map<String, dynamic> map) => Conversation(
        id: map['id'],
        listingId: map['listing_id'],
        buyerId: map['buyer_id'],
        sellerId: map['seller_id'],
        createdAt: DateTime.parse(map['created_at']),
        updatedAt: DateTime.parse(map['updated_at']),
        listingTitle: map['listing_title'],
        listingImagePath: map['listing_image_path'],
        listingPrice: map['listing_price'] != null
            ? (map['listing_price'] as num).toDouble()
            : null,
        otherUserName: map['other_user_name'],
        lastMessage: map['last_message'],
        lastMessageAt: map['last_message_at'] != null
            ? DateTime.parse(map['last_message_at'])
            : null,
        unreadCount: map['unread_count'] ?? 0,
      );
}
