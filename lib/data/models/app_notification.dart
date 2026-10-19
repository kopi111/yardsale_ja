/// Something the house needs to tell a member about a lot they are involved
/// in. Named [AppNotification] because `Notification` is a Flutter widget type.
class AppNotification {
  final String id;
  final String userId;
  final String kind;
  final String title;
  final String body;
  final String? listingId;
  final bool isRead;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.userId,
    required this.kind,
    required this.title,
    required this.body,
    this.listingId,
    this.isRead = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'user_id': userId,
        'kind': kind,
        'title': title,
        'body': body,
        'listing_id': listingId,
        'is_read': isRead ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
      };

  factory AppNotification.fromMap(Map<String, dynamic> map) => AppNotification(
        id: map['id'],
        userId: map['user_id'],
        kind: map['kind'],
        title: map['title'],
        body: map['body'],
        listingId: map['listing_id'],
        isRead: (map['is_read'] as num?)?.toInt() == 1,
        createdAt: DateTime.parse(map['created_at']),
      );
}

/// The events a member is told about. Kinds are stored, so they are named
/// once here rather than spelled out at each call site.
class NotificationKinds {
  static const String outbid = 'outbid';
  static const String won = 'won';
  static const String sold = 'sold';
  static const String paymentRecorded = 'payment_recorded';
  static const String saleCompleted = 'sale_completed';
  static const String statusProposed = 'status_proposed';
  static const String statusAgreed = 'status_agreed';
}
