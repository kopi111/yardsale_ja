class Bid {
  final String id;
  final String listingId;
  final String bidderId;
  final double amount;
  final DateTime createdAt;

  // Joined fields
  final String? bidderName;

  Bid({
    required this.id,
    required this.listingId,
    required this.bidderId,
    required this.amount,
    DateTime? createdAt,
    this.bidderName,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'listing_id': listingId,
        'bidder_id': bidderId,
        'amount': amount,
        'created_at': createdAt.toIso8601String(),
      };

  factory Bid.fromMap(Map<String, dynamic> map) => Bid(
        id: map['id'],
        listingId: map['listing_id'],
        bidderId: map['bidder_id'],
        amount: (map['amount'] as num).toDouble(),
        createdAt: DateTime.parse(map['created_at']),
        bidderName: map['bidder_name'],
      );
}
