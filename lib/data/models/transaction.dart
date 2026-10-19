class Transaction {
  final String id;
  final String listingId;
  final String winnerId;
  final String auctioneerId;
  final double winningBid;
  final String paymentMethod;
  final String? referenceNumber;
  final String status; // pending, paid, completed, cancelled
  /// A change one party has put to the other and nobody has signed yet.
  final String? proposedStatus;
  final String? proposedBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Joined fields
  final String? listingTitle;
  final String? listingImagePath;
  final String? otherUserName;

  Transaction({
    required this.id,
    required this.listingId,
    required this.winnerId,
    required this.auctioneerId,
    required this.winningBid,
    required this.paymentMethod,
    this.referenceNumber,
    this.status = 'pending',
    this.proposedStatus,
    this.proposedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.listingTitle,
    this.listingImagePath,
    this.otherUserName,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'listing_id': listingId,
        'winner_id': winnerId,
        'auctioneer_id': auctioneerId,
        'winning_bid': winningBid,
        'payment_method': paymentMethod,
        'reference_number': referenceNumber,
        'status': status,
        'proposed_status': proposedStatus,
        'proposed_by': proposedBy,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory Transaction.fromMap(Map<String, dynamic> map) => Transaction(
        id: map['id'],
        listingId: map['listing_id'],
        winnerId: map['winner_id'],
        auctioneerId: map['auctioneer_id'],
        winningBid: (map['winning_bid'] as num).toDouble(),
        paymentMethod: map['payment_method'],
        referenceNumber: map['reference_number'],
        status: map['status'] ?? 'pending',
        proposedStatus: map['proposed_status'],
        proposedBy: map['proposed_by'],
        createdAt: DateTime.parse(map['created_at']),
        updatedAt: DateTime.parse(map['updated_at']),
        listingTitle: map['listing_title'],
        listingImagePath: map['listing_image_path'],
        otherUserName: map['other_user_name'],
      );
}
