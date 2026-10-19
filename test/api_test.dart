import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:yardsale_ja/data/database/database_helper.dart';
import 'package:yardsale_ja/data/models/listing.dart';
import 'package:yardsale_ja/data/models/bid.dart';
import 'package:yardsale_ja/data/models/transaction.dart' as app;
import 'package:yardsale_ja/data/models/user.dart';
import 'package:yardsale_ja/data/models/listing_image.dart';
import 'package:yardsale_ja/data/models/review.dart';
import 'package:yardsale_ja/data/repositories/listing_repository.dart';
import 'package:yardsale_ja/data/repositories/user_repository.dart';
import 'package:yardsale_ja/data/repositories/transaction_repository.dart';
import 'package:yardsale_ja/data/repositories/message_repository.dart';
import 'package:yardsale_ja/core/utils.dart';
import 'package:yardsale_ja/core/constants.dart';

/// 25 long-running demo auctions plus 3 that close within minutes.
const int seededActiveListings = 28;

void main() {
  // Use FFI for desktop testing
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late ListingRepository listingRepo;
  late UserRepository userRepo;
  late TransactionRepository txnRepo;
  late MessageRepository msgRepo;

  setUpAll(() async {
    // Reset DB before all tests
    await DatabaseHelper.instance.resetDatabase();
    listingRepo = ListingRepository();
    userRepo = UserRepository();
    txnRepo = TransactionRepository();
    msgRepo = MessageRepository();
  });

  // ============================================================
  // UTILS TESTS
  // ============================================================
  group('AppUtils', () {
    test('formatPrice formats correctly', () {
      expect(AppUtils.formatPrice(185000), 'J\$185,000');
      expect(AppUtils.formatPrice(5000.0), 'J\$5,000');
      expect(AppUtils.formatPrice(0), 'J\$0');
      expect(AppUtils.formatPrice(2800000), 'J\$2,800,000');
    });

    test('formatDate returns correct format', () {
      final date = DateTime(2024, 3, 15);
      expect(AppUtils.formatDate(date), 'Mar 15, 2024');
    });

    test('formatDateTime returns correct format', () {
      final date = DateTime(2024, 3, 15, 14, 30);
      expect(AppUtils.formatDateTime(date), contains('Mar 15, 2024'));
      expect(AppUtils.formatDateTime(date), contains('2:30 PM'));
    });

    test('getInitials returns correct initials', () {
      expect(AppUtils.getInitials('Marcus Brown'), 'MB');
      expect(AppUtils.getInitials('Shantel'), 'S');
      expect(AppUtils.getInitials(''), '?');
    });

    test('truncate works correctly', () {
      expect(AppUtils.truncate('Hello World', 5), 'Hello...');
      expect(AppUtils.truncate('Hi', 10), 'Hi');
    });

    test('formatTimeRemaining returns Ended for past times', () {
      final past = DateTime.now().subtract(const Duration(hours: 1));
      expect(AppUtils.formatTimeRemaining(past), 'Ended');
    });

    test('formatTimeRemaining returns days+hours for future', () {
      final future = DateTime.now().add(const Duration(days: 2, hours: 5));
      final result = AppUtils.formatTimeRemaining(future);
      expect(result, contains('2d'));
      expect(result, contains('h'));
    });

    test('formatTimeRemaining returns hours+minutes', () {
      final future = DateTime.now().add(const Duration(hours: 3, minutes: 20));
      final result = AppUtils.formatTimeRemaining(future);
      expect(result, contains('3h'));
      expect(result, contains('m'));
    });

    test('formatTimeRemaining returns minutes only', () {
      final future = DateTime.now().add(const Duration(minutes: 15));
      final result = AppUtils.formatTimeRemaining(future);
      expect(result, contains('m'));
      expect(result.contains('d'), false);
      expect(result.contains('h'), false);
    });

    test('formatChatTime shows relative times', () {
      expect(AppUtils.formatChatTime(DateTime.now()), 'Just now');
      expect(
        AppUtils.formatChatTime(DateTime.now().subtract(const Duration(minutes: 5))),
        '5m ago',
      );
      expect(
        AppUtils.formatChatTime(DateTime.now().subtract(const Duration(hours: 2))),
        '2h ago',
      );
    });
  });

  // ============================================================
  // CONSTANTS TESTS
  // ============================================================
  group('AppConstants', () {
    test('AppStrings has auction branding', () {
      expect(AppStrings.tagline, "Jamaica's Auction House");
      expect(AppStrings.welcomeSubtitle, 'Bid on lots across Jamaica');
      expect(AppStrings.sell, 'Consign');
      expect(AppStrings.myListings, 'My auctions');
      expect(AppStrings.settlements, 'Settlements');
      expect(AppStrings.savedLots, 'Saved lots');
      expect(AppStrings.noListings, 'No auctions yet');
      expect(AppStrings.noSettlements, 'No settlements yet');
      expect(AppStrings.noSavedLots, 'No saved lots yet');
      expect(AppStrings.placeBid, 'Place Bid');
      expect(AppStrings.startingBid, 'Starting Bid');
      expect(AppStrings.currentBid, 'Current Bid');
      expect(AppStrings.timeLeft, 'Time Left');
      expect(AppStrings.auctionEnded, 'Auction Ended');
    });

    test('AppDurations has correct auction durations', () {
      expect(AppDurations.auctionDurations.length, 4);
      expect(AppDurations.auctionDurations[0]['days'], 1);
      expect(AppDurations.auctionDurations[1]['days'], 3);
      expect(AppDurations.auctionDurations[2]['days'], 7);
      expect(AppDurations.auctionDurations[3]['days'], 14);
    });

    test('AppCategories has 10 selectable categories plus the All filter', () {
      expect(AppCategories.selectableCategories.length, 10);
      expect(AppCategories.categories.length, 11);
      expect(
        AppCategories.selectableCategories
            .any((category) => category['id'] == AppCategories.allCategoryId),
        false,
      );
      expect(AppCategories.categories.first['id'], AppCategories.allCategoryId);
    });

    test('AppParishes has 14 parishes', () {
      expect(AppParishes.parishes.length, 14);
    });
  });

  // ============================================================
  // MODEL SERIALIZATION TESTS
  // ============================================================
  group('Listing Model', () {
    test('toMap/fromMap round-trip', () {
      final now = DateTime.now();
      final endTime = now.add(const Duration(days: 3));
      final listing = Listing(
        id: 'test-1',
        userId: 'user-1',
        title: 'Test Item',
        description: 'A test listing',
        startingBid: 50000,
        category: 'electronics',
        condition: 'New',
        parish: 'Kingston',
        auctionEndTime: endTime,
        currentBid: 55000,
        highestBidderId: 'user-2',
        bidCount: 3,
      );

      final map = listing.toMap();
      expect(map['starting_bid'], 50000);
      expect(map['auction_end_time'], endTime.toIso8601String());
      expect(map['current_bid'], 55000);
      expect(map['highest_bidder_id'], 'user-2');
      expect(map['bid_count'], 3);

      final restored = Listing.fromMap(map);
      expect(restored.id, 'test-1');
      expect(restored.startingBid, 50000);
      expect(restored.currentBid, 55000);
      expect(restored.highestBidderId, 'user-2');
      expect(restored.bidCount, 3);
    });

    test('isEnded returns true for past end time', () {
      final listing = Listing(
        id: 'x',
        userId: 'u',
        title: 't',
        description: 'd',
        startingBid: 100,
        category: 'other',
        condition: 'Good',
        parish: 'Kingston',
        auctionEndTime: DateTime.now().subtract(const Duration(hours: 1)),
      );
      expect(listing.isEnded, true);
    });

    test('isEnded returns false for future end time', () {
      final listing = Listing(
        id: 'x',
        userId: 'u',
        title: 't',
        description: 'd',
        startingBid: 100,
        category: 'other',
        condition: 'Good',
        parish: 'Kingston',
        auctionEndTime: DateTime.now().add(const Duration(hours: 1)),
      );
      expect(listing.isEnded, false);
    });

    test('isEnded returns true when status is ended', () {
      final listing = Listing(
        id: 'x',
        userId: 'u',
        title: 't',
        description: 'd',
        startingBid: 100,
        category: 'other',
        condition: 'Good',
        parish: 'Kingston',
        status: 'ended',
        auctionEndTime: DateTime.now().add(const Duration(hours: 1)),
      );
      expect(listing.isEnded, true);
    });

    test('copyWith preserves and overrides fields', () {
      final listing = Listing(
        id: 'x',
        userId: 'u',
        title: 'Original',
        description: 'desc',
        startingBid: 100,
        category: 'other',
        condition: 'Good',
        parish: 'Kingston',
      );
      final copy = listing.copyWith(title: 'Updated', startingBid: 200);
      expect(copy.title, 'Updated');
      expect(copy.startingBid, 200);
      expect(copy.id, 'x');
      expect(copy.description, 'desc');
    });

    test('fromMap handles null current_bid', () {
      final map = {
        'id': 'x',
        'user_id': 'u',
        'title': 't',
        'description': 'd',
        'starting_bid': 100,
        'category': 'other',
        'condition': 'Good',
        'parish': 'Kingston',
        'status': 'active',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'auction_end_time': DateTime.now().add(const Duration(days: 1)).toIso8601String(),
        'current_bid': null,
        'highest_bidder_id': null,
        'bid_count': 0,
      };
      final listing = Listing.fromMap(map);
      expect(listing.currentBid, isNull);
      expect(listing.highestBidderId, isNull);
      expect(listing.bidCount, 0);
    });
  });

  group('Bid Model', () {
    test('toMap/fromMap round-trip', () {
      final bid = Bid(
        id: 'bid-1',
        listingId: 'listing-1',
        bidderId: 'user-1',
        amount: 55000,
      );
      final map = bid.toMap();
      expect(map['listing_id'], 'listing-1');
      expect(map['amount'], 55000);

      final restored = Bid.fromMap({...map, 'bidder_name': 'Test User'});
      expect(restored.id, 'bid-1');
      expect(restored.amount, 55000);
      expect(restored.bidderName, 'Test User');
    });
  });

  group('Transaction Model', () {
    test('toMap/fromMap round-trip with new field names', () {
      final txn = app.Transaction(
        id: 'txn-1',
        listingId: 'listing-1',
        winnerId: 'winner-1',
        auctioneerId: 'auctioneer-1',
        winningBid: 75000,
        paymentMethod: 'Cash on Pickup',
      );
      final map = txn.toMap();
      expect(map['winner_id'], 'winner-1');
      expect(map['auctioneer_id'], 'auctioneer-1');
      expect(map['winning_bid'], 75000);
      expect(map.containsKey('buyer_id'), false);
      expect(map.containsKey('seller_id'), false);
      expect(map.containsKey('amount'), false);

      final restored = app.Transaction.fromMap(map);
      expect(restored.winnerId, 'winner-1');
      expect(restored.auctioneerId, 'auctioneer-1');
      expect(restored.winningBid, 75000);
    });
  });

  // ============================================================
  // DATABASE SEED DATA TESTS
  // ============================================================
  group('Database Seed Data', () {
    test('seed creates 8 demo users', () async {
      final users = await userRepo.getDemoUsers();
      expect(users.length, 8);
      expect(users.first.isDemo, true);
    });

    test('seed creates the expected number of active listings', () async {
      final listings = await listingRepo.getListings();
      expect(listings.length, seededActiveListings);
    });

    test('seed listings have auction_end_time in the future', () async {
      final listings = await listingRepo.getListings();
      final now = DateTime.now();
      for (final l in listings) {
        expect(l.auctionEndTime.isAfter(now), true,
            reason: '${l.title} should have future end time');
      }
    });

    test('seed listings have starting_bid > 0', () async {
      final listings = await listingRepo.getListings();
      for (final l in listings) {
        expect(l.startingBid, greaterThan(0),
            reason: '${l.title} should have positive starting bid');
      }
    });

    test('seed listings have no bids initially', () async {
      final listings = await listingRepo.getListings();
      for (final l in listings) {
        expect(l.currentBid, isNull);
        expect(l.highestBidderId, isNull);
        expect(l.bidCount, 0);
      }
    });

    test('seed listings have auctioneerName joined', () async {
      final listings = await listingRepo.getListings();
      for (final l in listings) {
        expect(l.auctioneerName, isNotNull,
            reason: '${l.title} should have auctioneerName');
        expect(l.auctioneerName!.isNotEmpty, true);
      }
    });

    test('seed listings have auctioneerParish joined', () async {
      final listings = await listingRepo.getListings();
      for (final l in listings) {
        expect(l.auctioneerParish, isNotNull);
      }
    });
  });

  // ============================================================
  // USER REPOSITORY TESTS
  // ============================================================
  group('UserRepository', () {
    test('no current user initially', () async {
      final user = await userRepo.getCurrentUser();
      expect(user, isNull);
    });

    test('hasCurrentUser returns false initially', () async {
      final has = await userRepo.hasCurrentUser();
      expect(has, false);
    });

    test('createUser and getCurrentUser', () async {
      final user = User(
        id: 'test-user-1',
        name: 'Test Bidder',
        email: 'test@test.com',
        phone: '876-555-9999',
        parish: 'Kingston',
        isCurrent: true,
      );
      await userRepo.createUser(user);
      final current = await userRepo.getCurrentUser();
      expect(current, isNotNull);
      expect(current!.name, 'Test Bidder');
      expect(current.isCurrent, true);
    });

    test('getUserById returns correct user', () async {
      final user = await userRepo.getUserById('demo_1');
      expect(user, isNotNull);
      expect(user!.name, 'Marcus Brown');
      expect(user.parish, 'Kingston');
    });

    test('getUserById returns null for non-existent', () async {
      final user = await userRepo.getUserById('non-existent');
      expect(user, isNull);
    });

    test('getUserListingCount returns correct count', () async {
      final count = await userRepo.getUserListingCount('demo_1');
      expect(count, greaterThan(0));
    });

    test('getUserRating returns 0 with no reviews', () async {
      final rating = await userRepo.getUserRating('demo_1');
      expect(rating, 0.0);
    });

    test('updateUser works', () async {
      var user = await userRepo.getUserById('test-user-1');
      expect(user!.name, 'Test Bidder');
      final updated = user.copyWith(name: 'Updated Bidder');
      await userRepo.updateUser(updated);
      user = await userRepo.getUserById('test-user-1');
      expect(user!.name, 'Updated Bidder');
    });
  });

  // ============================================================
  // LISTING REPOSITORY TESTS
  // ============================================================
  group('ListingRepository', () {
    test('getListings returns all active listings', () async {
      final listings = await listingRepo.getListings();
      expect(listings.length, seededActiveListings);
      for (final l in listings) {
        expect(l.status, 'active');
      }
    });

    test('getListings filters by category', () async {
      final listings = await listingRepo.getListings(category: 'vehicles');
      expect(listings.length, greaterThan(0));
      for (final l in listings) {
        expect(l.category, 'vehicles');
      }
    });

    test('getListings filters by parish', () async {
      final listings = await listingRepo.getListings(parish: 'Kingston');
      expect(listings.length, greaterThan(0));
      for (final l in listings) {
        expect(l.parish, 'Kingston');
      }
    });

    test('getListings filters by condition', () async {
      final listings = await listingRepo.getListings(condition: 'New');
      expect(listings.length, greaterThan(0));
      for (final l in listings) {
        expect(l.condition, 'New');
      }
    });

    test('getListings filters by price range', () async {
      final listings =
          await listingRepo.getListings(minPrice: 50000, maxPrice: 100000);
      expect(listings.length, greaterThan(0));
      for (final l in listings) {
        expect(l.startingBid, greaterThanOrEqualTo(50000));
        expect(l.startingBid, lessThanOrEqualTo(100000));
      }
    });

    test('getListings filters by search query', () async {
      final listings = await listingRepo.getListings(searchQuery: 'iPhone');
      expect(listings.length, greaterThan(0));
      expect(
        listings.any((l) =>
            l.title.toLowerCase().contains('iphone') ||
            l.description.toLowerCase().contains('iphone')),
        true,
      );
    });

    test('getListings filters by userId', () async {
      final listings = await listingRepo.getListings(userId: 'demo_1');
      expect(listings.length, greaterThan(0));
      for (final l in listings) {
        expect(l.userId, 'demo_1');
      }
    });

    test('getListings with limit', () async {
      final listings = await listingRepo.getListings(limit: 5);
      expect(listings.length, 5);
    });

    test('getListings orders by price ASC', () async {
      final listings =
          await listingRepo.getListings(orderBy: 'l.starting_bid ASC');
      for (int i = 1; i < listings.length; i++) {
        expect(listings[i].startingBid,
            greaterThanOrEqualTo(listings[i - 1].startingBid));
      }
    });

    test('getListings orders by auction_end_time ASC (ending soon)', () async {
      final listings =
          await listingRepo.getListings(orderBy: 'l.auction_end_time ASC');
      for (int i = 1; i < listings.length; i++) {
        expect(
          listings[i].auctionEndTime.isAfter(listings[i - 1].auctionEndTime) ||
              listings[i].auctionEndTime == listings[i - 1].auctionEndTime,
          true,
        );
      }
    });

    test('getListingById returns correct listing', () async {
      final all = await listingRepo.getListings(limit: 1);
      final id = all.first.id;
      final listing = await listingRepo.getListingById(id);
      expect(listing, isNotNull);
      expect(listing!.id, id);
      expect(listing.auctioneerName, isNotNull);
    });

    test('getListingById returns null for non-existent', () async {
      final listing = await listingRepo.getListingById('non-existent');
      expect(listing, isNull);
    });

    test('insertListing creates a new listing', () async {
      final listing = Listing(
        id: 'new-auction-1',
        userId: 'test-user-1',
        title: 'Test Auction Item',
        description: 'A brand new test auction item',
        startingBid: 25000,
        category: 'electronics',
        condition: 'New',
        parish: 'Kingston',
        auctionEndTime: DateTime.now().add(const Duration(days: 7)),
      );
      await listingRepo.insertListing(listing);
      final fetched = await listingRepo.getListingById('new-auction-1');
      expect(fetched, isNotNull);
      expect(fetched!.title, 'Test Auction Item');
      expect(fetched.startingBid, 25000);
      expect(fetched.bidCount, 0);
      expect(fetched.currentBid, isNull);
    });

    test('updateListingDetails modifies existing listing', () async {
      var listing = await listingRepo.getListingById('new-auction-1');
      final updated = listing!.copyWith(
        title: 'Updated Auction Item',
        startingBid: 30000,
      );
      await listingRepo.updateListingDetails(updated);
      listing = await listingRepo.getListingById('new-auction-1');
      expect(listing!.title, 'Updated Auction Item');
      expect(listing.startingBid, 30000);
    });

    test('updateListingDetails refuses to change the terms of a bid-on lot',
        () async {
      await listingRepo.insertListing(Listing(
        id: 'edit-race-1',
        userId: 'demo_2',
        title: 'Edit Race Lot',
        description: 'Used to prove an edit cannot erase a live bid.',
        startingBid: 10000,
        category: 'other',
        condition: 'Good',
        parish: 'Kingston',
        auctionEndTime: DateTime.now().add(const Duration(days: 3)),
      ));

      // The seller's screen is holding a snapshot taken before the bid landed.
      final stale = await listingRepo.getListingById('edit-race-1');
      await listingRepo.placeBid('edit-race-1', 'demo_1', 12000);

      expect(
        () => listingRepo.updateListingDetails(
          stale!.copyWith(title: 'Edited While Bidding'),
        ),
        throwsA(isA<ListingEditRejectedException>()),
        reason: 'a bidder committed to the lot as described',
      );

      final listing = await listingRepo.getListingById('edit-race-1');
      expect(listing!.title, 'Edit Race Lot');
      expect(listing.currentBid, 12000);
      expect(listing.bidCount, 1);
      expect(listing.highestBidderId, 'demo_1');
    });

    test('updateListingDetails still saves an edit to a lot with no bids',
        () async {
      await listingRepo.insertListing(Listing(
        id: 'edit-quiet-1',
        userId: 'demo_2',
        title: 'Quiet Lot',
        description: 'Nobody has bid on this one yet.',
        startingBid: 10000,
        category: 'other',
        condition: 'Good',
        parish: 'Kingston',
        auctionEndTime: DateTime.now().add(const Duration(days: 3)),
      ));
      final listing = await listingRepo.getListingById('edit-quiet-1');
      await listingRepo.updateListingDetails(
        listing!.copyWith(title: 'Quiet Lot, Renamed', startingBid: 12500),
      );

      final edited = await listingRepo.getListingById('edit-quiet-1');
      expect(edited!.title, 'Quiet Lot, Renamed');
      expect(edited.startingBid, 12500);
    });

    // --- BIDDING ---
    test('placeBid creates a bid and updates listing', () async {
      await listingRepo.placeBid('new-auction-1', 'demo_1', 35000);
      final listing = await listingRepo.getListingById('new-auction-1');
      expect(listing!.currentBid, 35000);
      expect(listing.highestBidderId, 'demo_1');
      expect(listing.bidCount, 1);
    });

    test('placeBid with higher amount updates correctly', () async {
      await listingRepo.placeBid('new-auction-1', 'demo_2', 40000);
      final listing = await listingRepo.getListingById('new-auction-1');
      expect(listing!.currentBid, 40000);
      expect(listing.highestBidderId, 'demo_2');
      expect(listing.bidCount, 2);
    });

    test('placeBid multiple times increments bid count', () async {
      await listingRepo.placeBid('new-auction-1', 'demo_3', 45000);
      await listingRepo.placeBid('new-auction-1', 'demo_1', 50000);
      final listing = await listingRepo.getListingById('new-auction-1');
      expect(listing!.currentBid, 50000);
      expect(listing.highestBidderId, 'demo_1');
      expect(listing.bidCount, 4);
    });

    test('getBids returns bids ordered by amount DESC', () async {
      final bids = await listingRepo.getBids('new-auction-1');
      expect(bids.length, 4);
      expect(bids[0].amount, 50000); // highest first
      expect(bids[1].amount, 45000);
      expect(bids[2].amount, 40000);
      expect(bids[3].amount, 35000);
    });

    test('getBids includes bidder names', () async {
      final bids = await listingRepo.getBids('new-auction-1');
      for (final bid in bids) {
        expect(bid.bidderName, isNotNull);
        expect(bid.bidderName!.isNotEmpty, true);
      }
      expect(bids[0].bidderName, 'Marcus Brown'); // demo_1
    });

    test('getBids returns empty for listing with no bids', () async {
      // Use a listing that has never been bid on (skip the ones we bid on earlier)
      final all = await listingRepo.getListings();
      // Find a seed listing that wasn't used in bid tests
      final unbidListing = all.firstWhere((l) => l.id != all.first.id && l.bidCount == 0);
      final bids = await listingRepo.getBids(unbidListing.id);
      expect(bids, isEmpty);
    });

    // --- END AUCTION ---
    test('endAuction changes status to ended', () async {
      await listingRepo.endAuction('new-auction-1');
      final listing = await listingRepo.getListingById('new-auction-1');
      expect(listing!.status, 'ended');
    });

    test('ended auction not returned in active listings', () async {
      final active = await listingRepo.getListings();
      expect(active.any((l) => l.id == 'new-auction-1'), false);
    });

    test('ended auction returned when filtering by ended status', () async {
      final ended = await listingRepo.getListings(status: 'ended');
      expect(ended.any((l) => l.id == 'new-auction-1'), true);
    });

    // --- EXPIRE AUCTIONS ---
    test('endExpiredAuctions marks past-due auctions as ended', () async {
      // Create a listing with past end time
      final expired = Listing(
        id: 'expired-1',
        userId: 'demo_1',
        title: 'Expired Item',
        description: 'Should be auto-ended',
        startingBid: 1000,
        category: 'other',
        condition: 'Good',
        parish: 'Kingston',
        auctionEndTime: DateTime.now().subtract(const Duration(hours: 1)),
      );
      await listingRepo.insertListing(expired);

      // Verify it's active
      var fetched = await listingRepo.getListingById('expired-1');
      expect(fetched!.status, 'active');

      // Run expiration
      await listingRepo.endExpiredAuctions();

      // Verify it's now ended
      fetched = await listingRepo.getListingById('expired-1');
      expect(fetched!.status, 'ended');
    });

    test('endExpiredAuctions does not affect future auctions', () async {
      final active = await listingRepo.getListings();
      // All remaining active listings should still have future end times
      for (final l in active) {
        expect(l.auctionEndTime.isAfter(DateTime.now()), true,
            reason: '${l.title} should still be active');
      }
    });

    // --- DELETE (CANCEL) ---
    test('deleteListing sets status to cancelled', () async {
      // Create then cancel
      final listing = Listing(
        id: 'cancel-test-1',
        userId: 'test-user-1',
        title: 'Cancel Me',
        description: 'This auction will be cancelled',
        startingBid: 5000,
        category: 'other',
        condition: 'Good',
        parish: 'Kingston',
        auctionEndTime: DateTime.now().add(const Duration(days: 3)),
      );
      await listingRepo.insertListing(listing);
      await listingRepo.deleteListing('cancel-test-1');
      final fetched = await listingRepo.getListingById('cancel-test-1');
      expect(fetched!.status, 'cancelled');
    });

    // --- LISTING IMAGES ---
    test('insertListingImage and getListingImages', () async {
      final img = ListingImage(
        id: 'img-1',
        listingId: 'new-auction-1',
        imagePath: '/path/to/image.jpg',
        sortOrder: 0,
      );
      await listingRepo.insertListingImage(img);
      final images = await listingRepo.getListingImages('new-auction-1');
      expect(images.length, 1);
      expect(images[0].imagePath, '/path/to/image.jpg');
    });

    test('deleteListingImages removes all images', () async {
      await listingRepo.deleteListingImages('new-auction-1');
      final images = await listingRepo.getListingImages('new-auction-1');
      expect(images, isEmpty);
    });

    // --- FAVORITES ---
    test('isFavorited returns false initially', () async {
      final all = await listingRepo.getListings(limit: 1);
      final result =
          await listingRepo.isFavorited('test-user-1', all.first.id);
      expect(result, false);
    });

    test('toggleFavorite adds a favorite', () async {
      final all = await listingRepo.getListings(limit: 1);
      final listingId = all.first.id;
      await listingRepo.toggleFavorite('fav-1', 'test-user-1', listingId);
      final result = await listingRepo.isFavorited('test-user-1', listingId);
      expect(result, true);
    });

    test('getFavorites returns favorited listings', () async {
      final favorites = await listingRepo.getFavorites('test-user-1');
      expect(favorites.length, 1);
      expect(favorites[0].isFavorited, true);
    });

    test('toggleFavorite removes a favorite', () async {
      final favorites = await listingRepo.getFavorites('test-user-1');
      final listingId = favorites[0].id;
      await listingRepo.toggleFavorite('fav-2', 'test-user-1', listingId);
      final result = await listingRepo.isFavorited('test-user-1', listingId);
      expect(result, false);
    });

    test('getFavorites returns empty after removing', () async {
      final favorites = await listingRepo.getFavorites('test-user-1');
      expect(favorites, isEmpty);
    });

    test(
        'getListingsByOwner keeps ended and cancelled auctions on the seller\'s '
        'own view', () async {
      Listing ownerListing(String id, String title) => Listing(
            id: id,
            userId: 'owner-history-user',
            title: title,
            description: 'Owner history fixture',
            startingBid: 1000,
            category: 'other',
            condition: 'Good',
            parish: 'Kingston',
            auctionEndTime: DateTime.now().add(const Duration(days: 2)),
          );

      await userRepo.createUser(User(
        id: 'owner-history-user',
        name: 'Owner History',
        email: 'owner.history@yardsale.jm',
        phone: '876-555-0199',
        parish: 'Kingston',
      ));
      await listingRepo.insertListing(ownerListing('owner-active', 'Active'));
      await listingRepo.insertListing(ownerListing('owner-ended', 'Ended'));
      await listingRepo
          .insertListing(ownerListing('owner-cancelled', 'Cancelled'));
      await listingRepo.endAuction('owner-ended');
      await listingRepo.deleteListing('owner-cancelled');

      final owned = await listingRepo.getListingsByOwner('owner-history-user',
          includeCancelled: true);

      expect(owned.map((l) => l.id),
          containsAll(['owner-active', 'owner-ended', 'owner-cancelled']));
    });

    test('getListingsByOwner returns only that owner\'s auctions', () async {
      final owned = await listingRepo.getListingsByOwner('owner-history-user',
          includeCancelled: true);
      for (final listing in owned) {
        expect(listing.userId, 'owner-history-user');
      }
    });

    test('the public view of a seller leaves their withdrawn lots off',
        () async {
      final shopfront =
          await listingRepo.getListingsByOwner('owner-history-user');
      expect(shopfront.map((l) => l.id),
          containsAll(['owner-active', 'owner-ended']));
      expect(shopfront.map((l) => l.id), isNot(contains('owner-cancelled')),
          reason: 'a withdrawn lot is not on offer to a shopper');
    });

    test('getUserListingCount counts ended auctions but not cancelled',
        () async {
      final count = await userRepo.getUserListingCount('owner-history-user');
      expect(count, 2);
    });
  });

  // ============================================================
  // TRANSACTION REPOSITORY TESTS
  // ============================================================
  group('TransactionRepository', () {
    // Ending an auction with bids now settles it into a pending transaction
    // (auction-winner pipeline). Clear those settlement rows so this group
    // exercises transaction/review CRUD from a known-empty state.
    setUpAll(() async {
      final db = await DatabaseHelper.instance.database;
      await db.delete('reviews');
      await db.delete('transactions');
    });

    test('getTransactions returns empty initially', () async {
      final txns = await txnRepo.getTransactions('test-user-1');
      expect(txns, isEmpty);
    });

    test('insertTransaction creates a transaction', () async {
      final txn = app.Transaction(
        id: 'txn-test-1',
        listingId: 'new-auction-1',
        winnerId: 'test-user-1',
        auctioneerId: 'demo_1',
        winningBid: 50000,
        paymentMethod: 'Cash on Pickup',
      );
      await txnRepo.insertTransaction(txn);
      final txns = await txnRepo.getTransactions('test-user-1');
      expect(txns.length, 1);
      expect(txns[0].winningBid, 50000);
      expect(txns[0].winnerId, 'test-user-1');
      expect(txns[0].auctioneerId, 'demo_1');
      expect(txns[0].listingTitle, isNotNull);
    });

    test('getTransactions shows for both winner and auctioneer', () async {
      final winnerTxns = await txnRepo.getTransactions('test-user-1');
      final auctioneerTxns = await txnRepo.getTransactions('demo_1');
      expect(winnerTxns.length, 1);
      expect(auctioneerTxns.length, 1);
      expect(winnerTxns[0].id, auctioneerTxns[0].id);
    });

    test('getTransactions shows otherUserName correctly', () async {
      // For winner, otherUserName should be auctioneer
      final winnerTxns = await txnRepo.getTransactions('test-user-1');
      expect(winnerTxns[0].otherUserName, 'Marcus Brown');

      // For auctioneer, otherUserName should be winner
      final auctioneerTxns = await txnRepo.getTransactions('demo_1');
      expect(auctioneerTxns[0].otherUserName, 'Updated Bidder');
    });

    test('getTransactionById returns correct transaction', () async {
      final txn = await txnRepo.getTransactionById('txn-test-1');
      expect(txn, isNotNull);
      expect(txn!.winningBid, 50000);
      expect(txn.listingTitle, isNotNull);
    });

    test('the buyer records payment and the seller confirms it', () async {
      await txnRepo.recordPayment(
        app.Transaction(
          id: 'ignored-the-settlement-already-exists',
          listingId: 'new-auction-1',
          winnerId: 'test-user-1',
          auctioneerId: 'demo_1',
          winningBid: 50000,
          paymentMethod: 'Bank Transfer',
          referenceNumber: 'REF-PAID',
        ),
        'test-user-1',
      );
      final paid = await txnRepo.getTransactionById('txn-test-1');
      expect(paid!.status, TransactionStatus.paid);
      expect(paid.referenceNumber, 'REF-PAID');

      await txnRepo.confirmPayment('txn-test-1', 'demo_1');
      final completed = await txnRepo.getTransactionById('txn-test-1');
      expect(completed!.status, TransactionStatus.completed);
    });

    test('cancelling takes both signatures', () async {
      // A second transaction needs its own lot: the schema allows exactly one
      // settlement per listing.
      final txn2 = app.Transaction(
        id: 'txn-test-2',
        listingId: 'edit-race-1',
        winnerId: 'demo_2',
        auctioneerId: 'demo_1',
        winningBid: 40000,
        paymentMethod: 'Bank Transfer',
        referenceNumber: 'REF-123',
      );
      await txnRepo.insertTransaction(txn2);

      await txnRepo.proposeStatusChange(
        id: 'txn-test-2',
        actorId: 'demo_1',
        status: TransactionStatus.cancelled,
      );
      final proposed = await txnRepo.getTransactionById('txn-test-2');
      expect(proposed!.status, TransactionStatus.pending,
          reason: 'a proposal on its own changes nothing');
      expect(proposed.proposedStatus, TransactionStatus.cancelled);

      await txnRepo.agreeToProposedStatus('txn-test-2', 'demo_2');
      final fetched = await txnRepo.getTransactionById('txn-test-2');
      expect(fetched!.status, TransactionStatus.cancelled);
      expect(fetched.proposedStatus, isNull);
      expect(fetched.referenceNumber, 'REF-123');
    });

    // --- REVIEWS ---
    test('insertReview and getReviewsForUser', () async {
      final review = Review(
        id: 'review-1',
        transactionId: 'txn-test-1',
        reviewerId: 'test-user-1',
        revieweeId: 'demo_1',
        rating: 5,
        comment: 'Great auctioneer!',
      );
      await txnRepo.insertReview(review);
      final reviews = await txnRepo.getReviewsForUser('demo_1');
      expect(reviews.length, 1);
      expect(reviews[0].rating, 5);
      expect(reviews[0].comment, 'Great auctioneer!');
      expect(reviews[0].reviewerName, 'Updated Bidder');
    });

    test('getUserRating returns correct average after review', () async {
      final rating = await userRepo.getUserRating('demo_1');
      expect(rating, 5.0);
    });
  });

  // ============================================================
  // MESSAGE REPOSITORY TESTS
  // ============================================================
  group('MessageRepository', () {
    test('getConversations returns empty initially', () async {
      final convos = await msgRepo.getConversations('test-user-1');
      expect(convos, isEmpty);
    });

    test('getTotalUnreadCount returns 0 initially', () async {
      final count = await msgRepo.getTotalUnreadCount('test-user-1');
      expect(count, 0);
    });
  });

  // ============================================================
  // DATABASE RESET TEST
  // ============================================================
  group('Database Reset', () {
    test('resetDatabase recreates all data', () async {
      await DatabaseHelper.instance.resetDatabase();
      // Verify seed data is back
      final users = await userRepo.getDemoUsers();
      expect(users.length, 8);
      final listings = await listingRepo.getListings();
      expect(listings.length, seededActiveListings);
      // Custom user should be gone
      final customUser = await userRepo.getUserById('test-user-1');
      expect(customUser, isNull);
    });
  });
}
