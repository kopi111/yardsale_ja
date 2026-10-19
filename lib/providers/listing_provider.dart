import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../data/models/listing.dart';
import '../data/models/listing_image.dart';
import '../data/models/bid.dart';
import '../data/repositories/listing_repository.dart';

class ListingProvider with ChangeNotifier {
  final ListingRepository _repo = ListingRepository();
  List<Listing> _listings = [];
  List<Listing> _favorites = [];
  bool _isLoading = true;

  List<Listing> get listings => _listings;
  List<Listing> get favorites => _favorites;
  bool get isLoading => _isLoading;

  /// Rises every time the catalogue changes. A screen that caches a count
  /// rather than a list has no other way to tell that its count went stale —
  /// the member's profile showed "0 lots listed" beside a lot they had just
  /// consigned because it had none.
  int get revision => _revision;
  int _revision = 0;

  Future<void> loadListings({
    String? category,
    String? parish,
    String? condition,
    double? minPrice,
    double? maxPrice,
    String? searchQuery,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _repo.endExpiredAuctions();
      _listings = await _repo.getListings(
        category: category,
        parish: parish,
        condition: condition,
        minPrice: minPrice,
        maxPrice: maxPrice,
        searchQuery: searchQuery,
      );
    } catch (e) {
      debugPrint('loadListings failed: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// The seller's own record of their lots, withdrawn ones included.
  Future<List<Listing>> getUserListings(String userId) async {
    return _repo.getListingsByOwner(userId, includeCancelled: true);
  }

  /// What a shopper sees on somebody else's profile. A withdrawn lot is not
  /// on offer, so it does not belong on a public shopfront.
  Future<List<Listing>> getPublicListings(String userId) async {
    return _repo.getListingsByOwner(userId);
  }

  Future<Listing?> getListingById(String id) async {
    return _repo.getListingById(id);
  }

  Future<void> createListing({
    required String userId,
    required String title,
    required String description,
    required double startingBid,
    required String category,
    required String condition,
    required String parish,
    required List<String> imagePaths,
    required int durationDays,
  }) async {
    const uuid = Uuid();
    final listing = Listing(
      id: uuid.v4(),
      userId: userId,
      title: title,
      description: description,
      startingBid: startingBid,
      category: category,
      condition: condition,
      parish: parish,
      auctionEndTime: DateTime.now().add(Duration(days: durationDays)),
    );
    await _repo.insertListing(listing);

    for (int i = 0; i < imagePaths.length; i++) {
      final image = ListingImage(
        id: uuid.v4(),
        listingId: listing.id,
        imagePath: imagePaths[i],
        sortOrder: i,
      );
      await _repo.insertListingImage(image);
    }

    _revision++;
    await loadListings();
  }

  Future<void> updateListingDetails(
    Listing listing, {
    List<String>? imagePaths,
  }) async {
    await _repo.updateListingDetails(listing, imagePaths: imagePaths);
    await loadListings();
  }

  Future<void> deleteListing(String id) async {
    await _repo.deleteListing(id);
    _revision++;
    await loadListings();
  }

  Future<void> endAuction(String id) async {
    await _repo.endAuction(id);
    _revision++;
    await loadListings();
  }

  Future<void> placeBid(String listingId, String bidderId, double amount) async {
    await _repo.placeBid(listingId, bidderId, amount);
    await loadListings();
  }

  Future<String?> settleAndGetTransactionId(String listingId) async {
    await _repo.settleAuction(listingId);
    return _repo.getSettledTransactionId(listingId);
  }

  Future<List<Bid>> getBidHistory(String listingId) async {
    return _repo.getBids(listingId);
  }

  Future<void> toggleFavorite(String userId, String listingId) async {
    await _repo.toggleFavorite(const Uuid().v4(), userId, listingId);
    await loadFavorites(userId);
    notifyListeners();
  }

  void clear() {
    _listings = [];
    _favorites = [];
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadFavorites(String userId) async {
    _favorites = await _repo.getFavorites(userId);
    notifyListeners();
  }

  Future<bool> isFavorited(String userId, String listingId) async {
    return _repo.isFavorited(userId, listingId);
  }
}
