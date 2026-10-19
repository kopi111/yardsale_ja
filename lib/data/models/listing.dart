class Listing {
  final String id;
  final String userId;
  final String title;
  final String description;
  final double startingBid;
  final String category;
  final String condition;
  final String parish;
  final String status; // active, ended, cancelled
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime auctionEndTime;
  final double? currentBid;
  final String? highestBidderId;
  final int bidCount;

  // Joined fields (not stored in listings table)
  final String? auctioneerName;
  final String? auctioneerParish;
  final String? highestBidderName;
  final List<String> imagePaths;
  final bool isFavorited;

  Listing({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    required this.startingBid,
    required this.category,
    required this.condition,
    required this.parish,
    this.status = 'active',
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? auctionEndTime,
    this.currentBid,
    this.highestBidderId,
    this.bidCount = 0,
    this.auctioneerName,
    this.auctioneerParish,
    this.highestBidderName,
    this.imagePaths = const [],
    this.isFavorited = false,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now(),
        auctionEndTime = auctionEndTime ?? DateTime.now().add(const Duration(days: 7));

  bool get isEnded => status == 'ended' || DateTime.now().isAfter(auctionEndTime);

  Map<String, dynamic> toMap() => {
        'id': id,
        'user_id': userId,
        'title': title,
        'description': description,
        'starting_bid': startingBid,
        'category': category,
        'condition': condition,
        'parish': parish,
        'status': status,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'auction_end_time': auctionEndTime.toIso8601String(),
        'current_bid': currentBid,
        'highest_bidder_id': highestBidderId,
        'bid_count': bidCount,
      };

  factory Listing.fromMap(Map<String, dynamic> map) => Listing(
        id: map['id'],
        userId: map['user_id'],
        title: map['title'],
        description: map['description'] ?? '',
        startingBid: (map['starting_bid'] as num).toDouble(),
        category: map['category'],
        condition: map['condition'] ?? 'Good',
        parish: map['parish'] ?? '',
        status: map['status'] ?? 'active',
        createdAt: DateTime.parse(map['created_at']),
        updatedAt: DateTime.parse(map['updated_at']),
        auctionEndTime: map['auction_end_time'] != null
            ? DateTime.parse(map['auction_end_time'])
            : DateTime.now().add(const Duration(days: 7)),
        currentBid: map['current_bid'] != null
            ? (map['current_bid'] as num).toDouble()
            : null,
        highestBidderId: map['highest_bidder_id'],
        bidCount: (map['bid_count'] as num?)?.toInt() ?? 0,
        auctioneerName: map['auctioneer_name'],
        auctioneerParish: map['auctioneer_parish'],
        highestBidderName: map['highest_bidder_name'],
      );

  Listing copyWith({
    String? title,
    String? description,
    double? startingBid,
    String? category,
    String? condition,
    String? parish,
    String? status,
    DateTime? auctionEndTime,
    double? currentBid,
    String? highestBidderId,
    int? bidCount,
    String? highestBidderName,
    List<String>? imagePaths,
    bool? isFavorited,
  }) =>
      Listing(
        id: id,
        userId: userId,
        title: title ?? this.title,
        description: description ?? this.description,
        startingBid: startingBid ?? this.startingBid,
        category: category ?? this.category,
        condition: condition ?? this.condition,
        parish: parish ?? this.parish,
        status: status ?? this.status,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
        auctionEndTime: auctionEndTime ?? this.auctionEndTime,
        currentBid: currentBid ?? this.currentBid,
        highestBidderId: highestBidderId ?? this.highestBidderId,
        bidCount: bidCount ?? this.bidCount,
        auctioneerName: auctioneerName,
        auctioneerParish: auctioneerParish,
        highestBidderName: highestBidderName ?? this.highestBidderName,
        imagePaths: imagePaths ?? this.imagePaths,
        isFavorited: isFavorited ?? this.isFavorited,
      );
}
