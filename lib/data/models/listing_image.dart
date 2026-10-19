class ListingImage {
  final String id;
  final String listingId;
  final String imagePath;
  final int sortOrder;

  ListingImage({
    required this.id,
    required this.listingId,
    required this.imagePath,
    this.sortOrder = 0,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'listing_id': listingId,
        'image_path': imagePath,
        'sort_order': sortOrder,
      };

  factory ListingImage.fromMap(Map<String, dynamic> map) => ListingImage(
        id: map['id'],
        listingId: map['listing_id'],
        imagePath: map['image_path'],
        sortOrder: map['sort_order'] ?? 0,
      );
}
