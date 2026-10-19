class Review {
  final String id;
  final String transactionId;
  final String reviewerId;
  final String revieweeId;
  final int rating;
  final String? comment;
  final DateTime createdAt;

  // Joined fields
  final String? reviewerName;

  Review({
    required this.id,
    required this.transactionId,
    required this.reviewerId,
    required this.revieweeId,
    required this.rating,
    this.comment,
    DateTime? createdAt,
    this.reviewerName,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'transaction_id': transactionId,
        'reviewer_id': reviewerId,
        'reviewee_id': revieweeId,
        'rating': rating,
        'comment': comment,
        'created_at': createdAt.toIso8601String(),
      };

  factory Review.fromMap(Map<String, dynamic> map) => Review(
        id: map['id'],
        transactionId: map['transaction_id'],
        reviewerId: map['reviewer_id'],
        revieweeId: map['reviewee_id'],
        rating: map['rating'],
        comment: map['comment'],
        createdAt: DateTime.parse(map['created_at']),
        reviewerName: map['reviewer_name'],
      );
}
