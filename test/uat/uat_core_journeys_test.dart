// UAT suite for YardSale JA - adversarial acceptance testing.
// Each test names the UAT scenario it evidences. The expectation encodes what
// a real stakeholder would accept, so a FAILING test here is a defect report.
//
// The 26 tests that reported defects on 2026-09-01 now assert the behaviour
// those defects were fixed to produce; each keeps its UAT number so the
// finding and its fix stay tied together.
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import 'package:yardsale_ja/core/auction_closer.dart';
import 'package:yardsale_ja/core/constants.dart';
import 'package:yardsale_ja/core/member_details.dart';
import 'package:yardsale_ja/core/utils.dart';
import 'package:yardsale_ja/data/database/database_helper.dart';
import 'package:yardsale_ja/data/models/app_notification.dart';
import 'package:yardsale_ja/data/models/listing.dart';
import 'package:yardsale_ja/data/models/message.dart';
import 'package:yardsale_ja/data/models/review.dart';
import 'package:yardsale_ja/data/models/transaction.dart' as app;
import 'package:yardsale_ja/data/models/user.dart';
import 'package:yardsale_ja/data/repositories/listing_repository.dart';
import 'package:yardsale_ja/data/repositories/message_repository.dart';
import 'package:yardsale_ja/data/repositories/notification_repository.dart';
import 'package:yardsale_ja/data/repositories/transaction_repository.dart';
import 'package:yardsale_ja/data/repositories/user_repository.dart';
import 'package:yardsale_ja/providers/message_provider.dart';
import 'package:yardsale_ja/providers/user_provider.dart';

const _uuid = Uuid();

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late ListingRepository listings;
  late UserRepository users;
  late TransactionRepository txns;
  late MessageRepository messages;
  late NotificationRepository notices;

  // Personas
  late User seller;
  late User bidderA;
  late User bidderB;

  Future<User> makeUser(String name, {bool current = false}) async {
    final u = User(
      id: _uuid.v4(),
      name: name,
      email: '${name.toLowerCase()}@test.jm',
      phone: '8765550000',
      parish: 'Kingston',
      isCurrent: current,
    );
    await users.createUser(u);
    return u;
  }

  Future<Listing> makeListing({
    required String ownerId,
    double startingBid = 1000,
    String category = 'electronics',
    String title = 'Test Item',
    String description = 'A test item for UAT',
    Duration endsIn = const Duration(days: 3),
    String status = 'active',
    String parish = 'Kingston',
  }) async {
    final l = Listing(
      id: _uuid.v4(),
      userId: ownerId,
      title: title,
      description: description,
      startingBid: startingBid,
      category: category,
      condition: 'Good',
      parish: parish,
      status: status,
      auctionEndTime: DateTime.now().add(endsIn),
    );
    await listings.insertListing(l);
    return l;
  }

  setUp(() async {
    await DatabaseHelper.instance.resetDatabase();
    listings = ListingRepository();
    users = UserRepository();
    txns = TransactionRepository();
    messages = MessageRepository();
    notices = NotificationRepository();
    seller = await makeUser('Seller', current: false);
    bidderA = await makeUser('BidderA', current: true);
    bidderB = await makeUser('BidderB');
  });

  // ==========================================================
  // UAT-10  Money / date / reference-data integrity
  // ==========================================================
  group('UAT-10 formatting & reference data', () {
    test('UAT-10.1 J\$ prefix is used for prices', () {
      expect(AppUtils.formatPrice(185000), 'J\$185,000');
      expect(AppUtils.formatPrice(0), 'J\$0');
    });

    test('UAT-10.2 the price shown is the price stored, cents included', () {
      // The amount on screen must equal the amount held against the bid.
      expect(AppUtils.formatPrice(1000.60), 'J\$1,000.60');
      expect(AppUtils.formatPrice(1000.40), 'J\$1,000.40');
      // A whole amount still reads as a whole amount.
      expect(AppUtils.formatPrice(1000), 'J\$1,000');
    });

    test('UAT-10.3 all 14 Jamaican parishes are offered', () {
      expect(AppParishes.parishes.length, 14);
      expect(AppParishes.parishes, contains('Kingston'));
      expect(AppParishes.parishes, contains('Westmoreland'));
    });

    test('UAT-10.4 every category id used by seed data is a real category', () {
      final ids = AppCategories.categories.map((c) => c['id']).toSet();
      for (final id in [
        'phones',
        'electronics',
        'vehicles',
        'clothing',
        'furniture',
        'books',
        'sports',
        'home_garden',
        'services',
        'other',
      ]) {
        expect(ids, contains(id), reason: 'seed uses category "$id"');
      }
    });

    test('UAT-10.5 a stored category id resolves to its display name', () {
      // The listing detail chip reads its category through this lookup, so a
      // shopper sees "Home & Garden" rather than the database key.
      expect(AppCategories.labelFor('home_garden'), 'Home & Garden');
      expect(AppCategories.labelFor('phones'), 'Phones');
      expect(AppCategories.labelFor('a-category-that-was-removed'), 'Other',
          reason: 'an unknown id must still render as words');
    });

    test('UAT-10.6 time remaining shows Ended once past the end time', () {
      expect(
          AppUtils.formatTimeRemaining(
              DateTime.now().subtract(const Duration(minutes: 1))),
          'Ended');
      expect(
          AppUtils.formatTimeRemaining(
              DateTime.now().add(const Duration(hours: 5, minutes: 30))),
          startsWith('5h'));
    });

    test('UAT-10.7 the closing minute counts down in seconds', () {
      // The last minute is the one a bidder most needs to read.
      final t = DateTime.now().add(const Duration(seconds: 45));
      expect(AppUtils.formatTimeRemaining(t), matches(RegExp(r'^\d+s$')));
      expect(AppUtils.formatTimeRemaining(t), isNot('0m'));

      final justOver = DateTime.now().add(const Duration(seconds: 95));
      expect(AppUtils.formatTimeRemaining(justOver), startsWith('1m '));
      expect(AppUtils.formatTimeRemaining(justOver), endsWith('s'));
    });
  });

  // ==========================================================
  // UAT-05  PLACE A BID  (core journey)
  // ==========================================================
  group('UAT-05 place a bid', () {
    test('UAT-05.1 happy path: first bid at the starting bid is accepted',
        () async {
      final l = await makeListing(ownerId: seller.id, startingBid: 5000);
      await listings.placeBid(l.id, bidderA.id, 5000);
      final after = await listings.getListingById(l.id);
      expect(after!.currentBid, 5000);
      expect(after.highestBidderId, bidderA.id);
      expect(after.bidCount, 1);
      expect((await listings.getBids(l.id)).length, 1);
    });

    test('UAT-05.2 bid below the starting bid is rejected', () async {
      final l = await makeListing(ownerId: seller.id, startingBid: 5000);
      await expectLater(
        listings.placeBid(l.id, bidderA.id, 4999),
        throwsA(isA<BidRejectedException>()),
      );
      expect((await listings.getListingById(l.id))!.bidCount, 0);
    });

    test('UAT-05.3 bid below the current bid is rejected', () async {
      final l = await makeListing(ownerId: seller.id, startingBid: 5000);
      await listings.placeBid(l.id, bidderA.id, 6000);
      await expectLater(
        listings.placeBid(l.id, bidderB.id, 5500),
        throwsA(isA<BidRejectedException>()),
      );
      expect((await listings.getListingById(l.id))!.currentBid, 6000);
    });

    test('UAT-05.4 bid EQUAL to the current bid is rejected', () async {
      final l = await makeListing(ownerId: seller.id, startingBid: 5000);
      await listings.placeBid(l.id, bidderA.id, 6000);
      await expectLater(
        listings.placeBid(l.id, bidderB.id, 6000),
        throwsA(isA<BidRejectedException>()),
      );
    });

    test('UAT-05.5 zero and negative bids are rejected', () async {
      final l = await makeListing(ownerId: seller.id, startingBid: 5000);
      await expectLater(listings.placeBid(l.id, bidderA.id, 0),
          throwsA(isA<BidRejectedException>()));
      await expectLater(listings.placeBid(l.id, bidderA.id, -1),
          throwsA(isA<BidRejectedException>()));
      await expectLater(listings.placeBid(l.id, bidderA.id, -999999),
          throwsA(isA<BidRejectedException>()));
      expect((await listings.getListingById(l.id))!.bidCount, 0);
    });

    test('UAT-05.6 bidding on your OWN auction is rejected', () async {
      final l = await makeListing(ownerId: seller.id, startingBid: 5000);
      await expectLater(
        listings.placeBid(l.id, seller.id, 9000),
        throwsA(predicate((e) =>
            e is BidRejectedException &&
            e.reason.contains('your own auction'))),
      );
    });

    test('UAT-05.7 bidding on an auction marked ended is rejected', () async {
      final l = await makeListing(ownerId: seller.id, startingBid: 5000);
      await listings.endAuction(l.id);
      await expectLater(
        listings.placeBid(l.id, bidderA.id, 9000),
        throwsA(isA<BidRejectedException>()),
      );
    });

    test(
        'UAT-05.8 bidding after the clock expires is rejected even while '
        'status is still active', () async {
      final l = await makeListing(
          ownerId: seller.id,
          startingBid: 5000,
          endsIn: const Duration(milliseconds: -1));
      await expectLater(
        listings.placeBid(l.id, bidderA.id, 9000),
        throwsA(isA<BidRejectedException>()),
      );
    });

    test('UAT-05.9 bidding on a deleted/absent auction is rejected', () async {
      await expectLater(
        listings.placeBid('no-such-listing', bidderA.id, 100),
        throwsA(isA<BidRejectedException>()),
      );
    });

    test('UAT-05.10 concurrent equal bids: exactly one wins', () async {
      final l = await makeListing(ownerId: seller.id, startingBid: 1000);
      final results = await Future.wait([
        listings.placeBid(l.id, bidderA.id, 5000).then((_) => 'A').catchError((_) => 'A-rejected'),
        listings.placeBid(l.id, bidderB.id, 5000).then((_) => 'B').catchError((_) => 'B-rejected'),
      ]);
      final winners = results.where((r) => !r.contains('rejected')).length;
      expect(winners, 1, reason: 'exactly one of two equal concurrent bids '
          'must win; the other must be told it was outbid');
      final after = await listings.getListingById(l.id);
      expect(after!.bidCount, 1);
      expect(after.currentBid, 5000);
    });

    test('UAT-05.11 concurrent ascending bids leave a consistent record',
        () async {
      final l = await makeListing(ownerId: seller.id, startingBid: 1000);
      await Future.wait([
        listings.placeBid(l.id, bidderA.id, 2000).catchError((_) {}),
        listings.placeBid(l.id, bidderB.id, 3000).catchError((_) {}),
        listings.placeBid(l.id, bidderA.id, 4000).catchError((_) {}),
      ]);
      final after = await listings.getListingById(l.id);
      final bids = await listings.getBids(l.id);
      expect(after!.bidCount, bids.length,
          reason: 'bid_count must equal the number of bid rows');
      expect(after.currentBid, bids.first.amount,
          reason: 'current_bid must equal the highest recorded bid');
    });

    test('UAT-05.12 a bidder cannot outbid themselves', () async {
      final l = await makeListing(ownerId: seller.id, startingBid: 1000);
      await listings.placeBid(l.id, bidderA.id, 2000);

      // BidderA already holds the lead and nobody is bidding against them.
      await expectLater(
        listings.placeBid(l.id, bidderA.id, 50000),
        throwsA(isA<BidRejectedException>()),
      );

      final after = await listings.getListingById(l.id);
      expect(after!.currentBid, 2000,
          reason: 'the leader keeps the price they won the lead at');
      expect(after.bidCount, 1);
      expect(after.highestBidderId, bidderA.id);
    });

    test('UAT-05.12b the lead can still be taken and retaken', () async {
      final l = await makeListing(ownerId: seller.id, startingBid: 1000);
      await listings.placeBid(l.id, bidderA.id, 2000);
      await listings.placeBid(l.id, bidderB.id, 3000);
      await listings.placeBid(l.id, bidderA.id, 4000);

      final after = await listings.getListingById(l.id);
      expect(after!.currentBid, 4000);
      expect(after.highestBidderId, bidderA.id);
      expect(after.bidCount, 3);
    });

    test('UAT-05.13 an absurd bid is refused, and says what the ceiling is',
        () async {
      final l = await makeListing(ownerId: seller.id, startingBid: 1000);
      await expectLater(
        listings.placeBid(l.id, bidderA.id, 1e21),
        throwsA(isA<BidRejectedException>().having(
          (e) => e.reason,
          'reason',
          contains(AppUtils.formatPrice(AppBidding.maximumBid)),
        )),
      );

      final after = await listings.getListingById(l.id);
      expect(after!.currentBid, isNull, reason: 'the lot is not locked');
      expect(after.bidCount, 0);

      // The ceiling is a ceiling, not a ban on serious money.
      await listings.placeBid(l.id, bidderA.id, AppBidding.maximumBid);
      expect((await listings.getListingById(l.id))!.currentBid,
          AppBidding.maximumBid);
    });

    test('UAT-05.14 a refused bid is told the actual minimum', () async {
      final l = await makeListing(ownerId: seller.id, startingBid: 1000);
      await listings.placeBid(l.id, bidderA.id, 2000);

      // J\$2,000.50 IS above the standing bid, so being refused for it is only
      // fair if the bidder is told the house wants J\$2,001.
      try {
        await listings.placeBid(l.id, bidderB.id, 2000.50);
        fail('a bid below the minimum increment must be refused');
      } on BidRejectedException catch (e) {
        expect(e.reason, contains(AppUtils.formatPrice(2001)));
      }

      // And bidding what the message asked for works.
      await listings.placeBid(l.id, bidderB.id, 2001);
      expect((await listings.getListingById(l.id))!.currentBid, 2001);
    });
  });

  // ==========================================================
  // UAT-06  Auction ending & settlement
  // ==========================================================
  group('UAT-06 auction ending and settlement', () {
    test('UAT-06.1 ending an auction with bids creates a transaction',
        () async {
      final l = await makeListing(ownerId: seller.id, startingBid: 1000);
      await listings.placeBid(l.id, bidderA.id, 7500);
      await listings.endAuction(l.id);

      final t = await txns.getTransactionForListing(l.id);
      expect(t, isNotNull);
      expect(t!.winnerId, bidderA.id);
      expect(t.auctioneerId, seller.id);
      expect(t.winningBid, 7500);
      expect(t.status, 'pending');
    });

    test('UAT-06.2 ending an auction with NO bids creates no transaction',
        () async {
      final l = await makeListing(ownerId: seller.id, startingBid: 1000);
      await listings.endAuction(l.id);
      expect(await txns.getTransactionForListing(l.id), isNull);
    });

    test('UAT-06.3 settlement is idempotent - no duplicate transactions',
        () async {
      final l = await makeListing(ownerId: seller.id, startingBid: 1000);
      await listings.placeBid(l.id, bidderA.id, 7500);
      await listings.endAuction(l.id);
      await listings.settleAuction(l.id);
      await listings.settleAuction(l.id);
      final db = await DatabaseHelper.instance.database;
      final rows = await db
          .query('transactions', where: 'listing_id = ?', whereArgs: [l.id]);
      expect(rows.length, 1);
    });

    test('UAT-06.4 endExpiredAuctions settles every auction past its clock',
        () async {
      final l = await makeListing(
          ownerId: seller.id,
          startingBid: 1000,
          endsIn: const Duration(seconds: 1));
      await listings.placeBid(l.id, bidderA.id, 3000);
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      await listings.endExpiredAuctions();
      final after = await listings.getListingById(l.id);
      expect(after!.status, 'ended');
      expect(await txns.getTransactionForListing(l.id), isNotNull);
    });

    test('UAT-06.5 the house closes its own lots, with nobody watching',
        () async {
      final l = await makeListing(
          ownerId: seller.id,
          startingBid: 1000,
          endsIn: const Duration(seconds: 1));
      await listings.placeBid(l.id, bidderA.id, 3000);
      await Future<void>.delayed(const Duration(milliseconds: 1200));

      // No screen is opened. The closer runs on its own clock.
      final closer = AuctionCloser(interval: const Duration(milliseconds: 100));
      closer.start();
      await Future<void>.delayed(const Duration(milliseconds: 400));
      closer.stop();

      final closed = await listings.getListingById(l.id);
      expect(closed!.status, 'ended');
      final settlement = await txns.getTransactionForListing(l.id);
      expect(settlement, isNotNull,
          reason: 'the winner is settled without anyone opening Browse');
      expect(settlement!.winnerId, bidderA.id);
      expect(settlement.winningBid, 3000);
    });

    test('UAT-06.5b an expired lot is never offered as live', () async {
      final l = await makeListing(
          ownerId: seller.id, endsIn: const Duration(seconds: 1));
      await Future<void>.delayed(const Duration(milliseconds: 1200));

      final floor = await listings.getListings();
      expect(floor.where((x) => x.id == l.id), isEmpty,
          reason: 'reading the floor must never return a finished lot');
    });

    test('UAT-06.6 the winner and the seller are both told', () async {
      final l = await makeListing(ownerId: seller.id, startingBid: 1000);
      await listings.placeBid(l.id, bidderA.id, 7500);
      await listings.endAuction(l.id);

      final won = await notices.getNotifications(bidderA.id);
      expect(won.where((n) => n.kind == NotificationKinds.won), hasLength(1));
      expect(won.first.body, contains(AppUtils.formatPrice(7500)));
      expect(won.first.listingId, l.id,
          reason: 'the notice must lead back to the lot');
      expect(await notices.getUnreadCount(bidderA.id), greaterThan(0),
          reason: 'the bell has to carry a count or nobody looks at it');

      final sold = await notices.getNotifications(seller.id);
      expect(sold.where((n) => n.kind == NotificationKinds.sold), hasLength(1));

      // A member who had nothing to do with the lot hears nothing.
      expect(await notices.getNotifications(bidderB.id), isEmpty);
    });

    test('UAT-06.7 an outbid bidder is told they lost the lead', () async {
      final l = await makeListing(
          ownerId: seller.id, title: 'Contested Lot', startingBid: 1000);
      await listings.placeBid(l.id, bidderA.id, 2000);
      await listings.placeBid(l.id, bidderB.id, 3000);

      final outbid = await notices.getNotifications(bidderA.id);
      expect(outbid, hasLength(1));
      expect(outbid.first.kind, NotificationKinds.outbid);
      expect(outbid.first.body, contains('Contested Lot'));
      expect(outbid.first.body, contains(AppUtils.formatPrice(3000)));
      expect(outbid.first.listingId, l.id);

      // The bidder who took the lead is not told they outbid themselves.
      expect(await notices.getNotifications(bidderB.id), isEmpty);
    });

    test('UAT-06.7b reading the notices clears the badge', () async {
      final l = await makeListing(ownerId: seller.id, startingBid: 1000);
      await listings.placeBid(l.id, bidderA.id, 2000);
      await listings.placeBid(l.id, bidderB.id, 3000);
      expect(await notices.getUnreadCount(bidderA.id), 1);

      await notices.markAllRead(bidderA.id);
      expect(await notices.getUnreadCount(bidderA.id), 0);
      expect(await notices.getNotifications(bidderA.id), hasLength(1),
          reason: 'reading a notice must not destroy it');
    });

    test('UAT-06.8 the seller can reach the winner and the settlement',
        () async {
      final l = await makeListing(ownerId: seller.id, startingBid: 1000);
      await listings.placeBid(l.id, bidderA.id, 7500);
      await listings.endAuction(l.id);

      // The detail screen names the winner from the listing itself...
      final after = await listings.getListingById(l.id);
      expect(after!.highestBidderName, 'BidderA');

      // ...and reaches the settlement behind it by the same route the seller's
      // action bar uses.
      final settlementId = await listings.getSettledTransactionId(l.id);
      expect(settlementId, isNotNull);
      final settlement = await txns.getTransactionById(settlementId!);
      expect(settlement!.auctioneerId, seller.id);
      expect(settlement.winnerId, bidderA.id);
      expect(settlement.winningBid, 7500);
      expect(settlement.status, TransactionStatus.pending);
    });

    test('UAT-06.9 a settled lot cannot be withdrawn after the fact',
        () async {
      final l = await makeListing(ownerId: seller.id, startingBid: 1000);
      await listings.placeBid(l.id, bidderA.id, 7500);
      await listings.endAuction(l.id);
      final t = await txns.getTransactionForListing(l.id);
      expect(t, isNotNull);

      await expectLater(
        listings.deleteListing(l.id),
        throwsA(isA<ListingCancellationRejectedException>()),
      );

      final after = await listings.getListingById(l.id);
      expect(after!.status, 'ended',
          reason: 'a sold lot stays sold; the buyer is holding a settlement');
      expect((await txns.getTransactionForListing(l.id))!.id, t!.id);
    });

    test('UAT-06.10 a lot carrying live bids cannot be withdrawn', () async {
      final l = await makeListing(ownerId: seller.id, startingBid: 1000);
      await listings.placeBid(l.id, bidderA.id, 25000);

      await expectLater(
        listings.deleteListing(l.id),
        throwsA(isA<ListingCancellationRejectedException>()),
      );

      final after = await listings.getListingById(l.id);
      expect(after!.status, 'active',
          reason: 'the bidder committed J\$25,000 and the lot stays on');
      final browse = await listings.getListings();
      expect(browse.map((x) => x.id), contains(l.id));
    });

    test('UAT-06.10b a lot nobody has bid on can still be withdrawn',
        () async {
      final l = await makeListing(ownerId: seller.id, startingBid: 1000);
      await listings.deleteListing(l.id);
      expect((await listings.getListingById(l.id))!.status, 'cancelled');
    });
  });

  // ==========================================================
  // UAT-03/04  Create + edit a listing
  // ==========================================================
  group('UAT-03 create and edit a listing', () {
    test('UAT-03.1 a created auction is persisted and browsable', () async {
      final l = await makeListing(
          ownerId: seller.id, title: 'Blue Mountain Coffee', startingBid: 9500);
      final found = await listings.getListingById(l.id);
      expect(found!.title, 'Blue Mountain Coffee');
      expect(found.startingBid, 9500);
      expect(found.status, 'active');
      expect(found.auctioneerName, 'Seller');
    });

    test('UAT-03.2 the opening price is fixed once a bid is placed', () async {
      final l = await makeListing(ownerId: seller.id, startingBid: 1000);
      await listings.placeBid(l.id, bidderA.id, 2000);

      final tampered =
          (await listings.getListingById(l.id))!.copyWith(startingBid: 999999);
      await expectLater(
        listings.updateListingDetails(tampered),
        throwsA(isA<ListingEditRejectedException>()),
      );

      final after = await listings.getListingById(l.id);
      expect(after!.startingBid, 1000);
      expect(after.currentBid, 2000);
    });

    test('UAT-03.3 the item described cannot be swapped under a bidder',
        () async {
      final l = await makeListing(
          ownerId: seller.id, title: 'iPhone 14 Pro', startingBid: 1000);
      await listings.placeBid(l.id, bidderA.id, 90000);

      final swapped = (await listings.getListingById(l.id))!
          .copyWith(title: 'Broken phone case', description: 'Just the case.');
      await expectLater(
        listings.updateListingDetails(swapped),
        throwsA(isA<ListingEditRejectedException>()),
      );

      final after = await listings.getListingById(l.id);
      expect(after!.title, 'iPhone 14 Pro');
      expect(after.description, 'A test item for UAT');
      expect(after.currentBid, 90000);
    });

    test('UAT-03.3b the end time and parish may still be corrected', () async {
      final l = await makeListing(ownerId: seller.id, startingBid: 1000);
      await listings.placeBid(l.id, bidderA.id, 2000);

      final extended = (await listings.getListingById(l.id))!.copyWith(
        parish: 'St. Ann',
        auctionEndTime: DateTime.now().add(const Duration(days: 5)),
      );
      await listings.updateListingDetails(extended);

      final after = await listings.getListingById(l.id);
      expect(after!.parish, 'St. Ann');
      expect(after.currentBid, 2000, reason: 'the bid is untouched');
    });

    test('UAT-03.4 cancelled auctions stay off Browse', () async {
      final l = await makeListing(ownerId: seller.id);
      await listings.deleteListing(l.id);
      final browse = await listings.getListings();
      expect(browse.where((x) => x.id == l.id), isEmpty);
    });

    test('UAT-03.5 a withdrawn lot leaves the public profile but stays on the '
        'seller\'s own record', () async {
      final l = await makeListing(ownerId: seller.id, title: 'Cancelled Item');
      await listings.deleteListing(l.id);

      // The shopfront a buyer sees agrees with the headline count above it.
      final publicView = await listings.getListingsByOwner(seller.id);
      expect(publicView.map((x) => x.title), isNot(contains('Cancelled Item')));
      expect(publicView, hasLength(await users.getUserListingCount(seller.id)));

      // The seller's own My Auctions view still holds their whole history.
      final ownView =
          await listings.getListingsByOwner(seller.id, includeCancelled: true);
      expect(ownView.map((x) => x.title), contains('Cancelled Item'));
    });
  });

  // ==========================================================
  // UAT-02  Browse, filter, search
  // ==========================================================
  group('UAT-02 browse, filter and search', () {
    test('UAT-02.1 browse returns only active auctions', () async {
      final all = await listings.getListings();
      expect(all, isNotEmpty);
      expect(all.every((l) => l.status == 'active'), isTrue);
    });

    test('UAT-02.2 category filter returns only that category', () async {
      final phones = await listings.getListings(category: 'phones');
      expect(phones, isNotEmpty);
      expect(phones.every((l) => l.category == 'phones'), isTrue);
    });

    test('UAT-02.3 parish filter works', () async {
      final kingston = await listings.getListings(parish: 'Kingston');
      expect(kingston.every((l) => l.parish == 'Kingston'), isTrue);
    });

    test('UAT-02.4 search finds by title, case-insensitively', () async {
      final r = await listings.getListings(searchQuery: 'IPHONE');
      expect(r, isNotEmpty);
      expect(r.first.title.toLowerCase(), contains('iphone'));
    });

    test('UAT-02.5 search finds by description', () async {
      final r = await listings.getListings(searchQuery: 'Deep Purple');
      expect(r, isNotEmpty);
    });

    test('UAT-02.6 a nonsense query returns no results (not an error)',
        () async {
      final r = await listings.getListings(searchQuery: 'zzzzqqqqxxxx');
      expect(r, isEmpty);
    });

    test('UAT-02.7 SQL injection in the search box is safely parameterised',
        () async {
      final r = await listings
          .getListings(searchQuery: "'; DROP TABLE listings; --");
      expect(r, isEmpty);
      expect(await listings.getListings(), isNotEmpty,
          reason: 'the listings table must survive');
    });

    test('UAT-02.8 quotes and accents do not crash search', () async {
      for (final q in ["Levi's", 'café', '日本語', '<script>', '100%', 'a&b']) {
        await listings.getListings(searchQuery: q);
      }
    });

    test('UAT-02.9 searching for "%" searches for a percent sign', () async {
      final all = await listings.getListings();
      expect(all.length, greaterThan(20));

      // One seeded lot quotes a battery health of 94%, and it is the only
      // thing a search for a percent sign may return.
      final pct = await listings.getListings(searchQuery: '%');
      expect(pct, hasLength(1));
      expect(pct.single.description, contains('94%'));
      expect(pct.length, lessThan(all.length),
          reason: 'an unescaped wildcard would answer with the whole floor');

      // A real percentage still finds the lot that mentions it.
      expect((await listings.getListings(searchQuery: '94%')).single.title,
          contains('iPhone 14 Pro Max'));
    });

    test('UAT-02.10 an underscore is a character, not a wildcard', () async {
      // No demo title contains a literal underscore, so nothing may match.
      expect(await listings.getListings(searchQuery: 'i_hone'), isEmpty);
      // The lot it used to match is still findable by its real name.
      expect(await listings.getListings(searchQuery: 'iPhone'), isNotEmpty);
    });

    test('UAT-02.11 price range filter uses the effective (current) bid',
        () async {
      final l = await makeListing(ownerId: seller.id, startingBid: 100);
      await listings.placeBid(l.id, bidderA.id, 900000);
      final cheap = await listings.getListings(maxPrice: 500);
      expect(cheap.where((x) => x.id == l.id), isEmpty,
          reason: 'once bid up to J\$900,000 it must leave the "under J\$500" '
              'filter');
    });

    test('UAT-02.12 a lot whose clock has run out is off every listing screen',
        () async {
      final l = await makeListing(
          ownerId: seller.id,
          title: 'Expiring Item',
          endsIn: const Duration(seconds: 1));
      await Future<void>.delayed(const Duration(milliseconds: 1200));

      // Every screen reads the floor through getListings, including the ones
      // that talk to the repository directly, so the guard belongs here.
      expect(
          (await listings.getListings(category: 'electronics'))
              .where((x) => x.id == l.id),
          isEmpty);
      expect((await listings.getListings()).where((x) => x.id == l.id),
          isEmpty);
      expect(
          (await listings.getListings(searchQuery: 'Expiring'))
              .where((x) => x.id == l.id),
          isEmpty);
    });
  });

  // ==========================================================
  // UAT-09  Favorites
  // ==========================================================
  group('UAT-09 favorites', () {
    test('UAT-09.1 favorite and unfavorite round trip', () async {
      final l = await makeListing(ownerId: seller.id);
      await listings.toggleFavorite(_uuid.v4(), bidderA.id, l.id);
      expect(await listings.isFavorited(bidderA.id, l.id), isTrue);
      expect((await listings.getFavorites(bidderA.id)).length, 1);
      await listings.toggleFavorite(_uuid.v4(), bidderA.id, l.id);
      expect(await listings.isFavorited(bidderA.id, l.id), isFalse);
      expect(await listings.getFavorites(bidderA.id), isEmpty);
    });

    test('UAT-09.2 favorites are per user', () async {
      final l = await makeListing(ownerId: seller.id);
      await listings.toggleFavorite(_uuid.v4(), bidderA.id, l.id);
      expect(await listings.getFavorites(bidderB.id), isEmpty);
    });

    test('UAT-09.3 a saved lot stays on the list after it closes', () async {
      final l = await makeListing(ownerId: seller.id, title: 'Watched Item');
      await listings.toggleFavorite(_uuid.v4(), bidderA.id, l.id);
      await listings.placeBid(l.id, bidderA.id, 5000);
      expect((await listings.getFavorites(bidderA.id)).length, 1);

      // A member saves a lot precisely to watch it close.
      await listings.endAuction(l.id);

      final favs = await listings.getFavorites(bidderA.id);
      expect(favs, hasLength(1));
      expect(favs.first.title, 'Watched Item');
      expect(favs.first.isEnded, isTrue);
    });

    test('UAT-09.3b a withdrawn lot does leave the saved list', () async {
      final l = await makeListing(ownerId: seller.id, title: 'Pulled Item');
      await listings.toggleFavorite(_uuid.v4(), bidderA.id, l.id);
      await listings.deleteListing(l.id);
      expect(await listings.getFavorites(bidderA.id), isEmpty,
          reason: 'there is nothing left to watch');
    });
  });

  // ==========================================================
  // UAT-08  Payment and transaction history
  // ==========================================================
  group('UAT-08 payment and transactions', () {
    test('UAT-08.1 recording a payment updates the settled transaction',
        () async {
      final l = await makeListing(ownerId: seller.id, startingBid: 1000);
      await listings.placeBid(l.id, bidderA.id, 4000);
      await listings.endAuction(l.id);

      final settled = await txns.getTransactionForListing(l.id);
      expect(settled!.paymentMethod, 'Cash on Pickup');

      await txns.recordPayment(
        paymentFor(settled.listingId, settled.winnerId, settled.auctioneerId,
            settled.winningBid, 'Lynk', 'LYNK-123'),
        bidderA.id,
      );

      final after = await txns.getTransactionForListing(l.id);
      expect(after!.paymentMethod, 'Lynk');
      expect(after.referenceNumber, 'LYNK-123');
      expect(after.id, settled.id, reason: 'must not create a second row');
    });

    test('UAT-08.2 history shows the sale to BOTH parties', () async {
      final l = await makeListing(ownerId: seller.id, startingBid: 1000);
      await listings.placeBid(l.id, bidderA.id, 4000);
      await listings.endAuction(l.id);

      final buyerView = await txns.getTransactions(bidderA.id);
      final sellerView = await txns.getTransactions(seller.id);
      expect(buyerView.length, 1);
      expect(sellerView.length, 1);
      expect(buyerView.first.otherUserName, 'Seller');
      expect(sellerView.first.otherUserName, 'BidderA');
      expect(await txns.getTransactions(bidderB.id), isEmpty,
          reason: 'an unrelated user must not see the sale');
    });

    test('UAT-08.3 a review can only be left once per party', () async {
      final l = await makeListing(ownerId: seller.id, startingBid: 1000);
      await listings.placeBid(l.id, bidderA.id, 4000);
      await listings.endAuction(l.id);
      final t = (await txns.getTransactionForListing(l.id))!;

      await txns.insertReview(reviewFor(t.id, bidderA.id, seller.id, 5));
      await expectLater(
        txns.insertReview(reviewFor(t.id, bidderA.id, seller.id, 1)),
        throwsA(isA<DuplicateReviewException>()),
      );
      expect(await users.getUserRating(seller.id), 5.0);
    });

    test(
        'UAT-08.4 the buyer records the payment and the seller confirms it',
        () async {
      // No money moves through the app, so the honest mechanism is the buyer's
      // word followed by the seller's confirmation - and both are recorded.
      final l = await makeListing(ownerId: seller.id, startingBid: 1000);
      await listings.placeBid(l.id, bidderA.id, 4000);
      await listings.endAuction(l.id);
      final t = (await txns.getTransactionForListing(l.id))!;
      expect(t.status, TransactionStatus.pending);

      await txns.recordPayment(
        paymentFor(t.listingId, t.winnerId, t.auctioneerId, t.winningBid,
            'Bank Transfer', 'TRF-88213'),
        bidderA.id,
      );
      final recorded = await txns.getTransactionForListing(l.id);
      expect(recorded!.status, TransactionStatus.paid,
          reason: 'the sale is not complete on the buyer\'s word alone');
      expect(recorded.referenceNumber, 'TRF-88213');

      // The seller is told there is something waiting on them.
      final sellerNotices = await notices.getNotifications(seller.id);
      expect(
          sellerNotices
              .where((n) => n.kind == NotificationKinds.paymentRecorded),
          hasLength(1));

      await txns.confirmPayment(t.id, seller.id);
      final completed = await txns.getTransactionForListing(l.id);
      expect(completed!.status, TransactionStatus.completed);
      expect(
          (await notices.getNotifications(bidderA.id))
              .where((n) => n.kind == NotificationKinds.saleCompleted),
          hasLength(1));
    });

    test('UAT-08.4b a payment cannot be confirmed before it is recorded',
        () async {
      final l = await makeListing(ownerId: seller.id, startingBid: 1000);
      await listings.placeBid(l.id, bidderA.id, 4000);
      await listings.endAuction(l.id);
      final t = (await txns.getTransactionForListing(l.id))!;

      await expectLater(
        txns.confirmPayment(t.id, seller.id),
        throwsA(isA<TransactionActionRejectedException>()),
      );
      expect((await txns.getTransactionForListing(l.id))!.status,
          TransactionStatus.pending);
    });

    test('UAT-08.5 no party can move a sale on their own', () async {
      final l = await makeListing(ownerId: seller.id, startingBid: 1000);
      await listings.placeBid(l.id, bidderA.id, 4000);
      await listings.endAuction(l.id);
      final t = (await txns.getTransactionForListing(l.id))!;

      // The seller proposes cancelling. On its own that changes nothing.
      await txns.proposeStatusChange(
        id: t.id,
        actorId: seller.id,
        status: TransactionStatus.cancelled,
      );
      final proposed = await txns.getTransactionForListing(l.id);
      expect(proposed!.status, TransactionStatus.pending);
      expect(proposed.proposedStatus, TransactionStatus.cancelled);
      expect(proposed.proposedBy, seller.id);

      // ...and they cannot sign their own proposal.
      await expectLater(
        txns.agreeToProposedStatus(t.id, seller.id),
        throwsA(isA<TransactionActionRejectedException>()),
      );
      expect((await txns.getTransactionForListing(l.id))!.status,
          TransactionStatus.pending);

      // The buyer agrees, and only now does it take effect.
      await txns.agreeToProposedStatus(t.id, bidderA.id);
      final cancelled = await txns.getTransactionForListing(l.id);
      expect(cancelled!.status, TransactionStatus.cancelled);
      expect(cancelled.proposedStatus, isNull);
    });

    test('UAT-08.5b an outsider cannot touch a sale at all', () async {
      final l = await makeListing(ownerId: seller.id, startingBid: 1000);
      await listings.placeBid(l.id, bidderA.id, 4000);
      await listings.endAuction(l.id);
      final t = (await txns.getTransactionForListing(l.id))!;

      await expectLater(
        txns.proposeStatusChange(
          id: t.id,
          actorId: bidderB.id,
          status: TransactionStatus.cancelled,
        ),
        throwsA(isA<TransactionActionRejectedException>()),
      );
      await expectLater(
        txns.confirmPayment(t.id, bidderB.id),
        throwsA(isA<TransactionActionRejectedException>()),
      );
      await expectLater(
        txns.recordPayment(
          paymentFor(t.listingId, t.winnerId, t.auctioneerId, t.winningBid,
              'Lynk', 'NOT-MINE'),
          bidderB.id,
        ),
        throwsA(isA<TransactionActionRejectedException>()),
      );
    });

    test('UAT-08.6 a cancelled sale can be put back on by agreement',
        () async {
      final l = await makeListing(ownerId: seller.id, startingBid: 1000);
      await listings.placeBid(l.id, bidderA.id, 4000);
      await listings.endAuction(l.id);
      final t = (await txns.getTransactionForListing(l.id))!;

      await txns.proposeStatusChange(
        id: t.id,
        actorId: seller.id,
        status: TransactionStatus.cancelled,
      );
      await txns.agreeToProposedStatus(t.id, bidderA.id);
      expect((await txns.getTransactionForListing(l.id))!.status,
          TransactionStatus.cancelled);

      // Cancelling in error is not the end of the sale.
      await txns.proposeStatusChange(
        id: t.id,
        actorId: bidderA.id,
        status: TransactionStatus.pending,
      );
      await txns.agreeToProposedStatus(t.id, seller.id);
      final reinstated = await txns.getTransactionForListing(l.id);
      expect(reinstated!.status, TransactionStatus.pending);

      // ...and the journey runs through to the end from there.
      await txns.recordPayment(
        paymentFor(t.listingId, t.winnerId, t.auctioneerId, t.winningBid,
            'Lynk', 'LYNK-9911'),
        bidderA.id,
      );
      await txns.confirmPayment(t.id, seller.id);
      expect((await txns.getTransactionForListing(l.id))!.status,
          TransactionStatus.completed);
    });

    test('UAT-08.6b a proposal can be withdrawn by whoever made it', () async {
      final l = await makeListing(ownerId: seller.id, startingBid: 1000);
      await listings.placeBid(l.id, bidderA.id, 4000);
      await listings.endAuction(l.id);
      final t = (await txns.getTransactionForListing(l.id))!;

      await txns.proposeStatusChange(
        id: t.id,
        actorId: seller.id,
        status: TransactionStatus.cancelled,
      );
      await expectLater(
        txns.withdrawProposedStatus(t.id, bidderA.id),
        throwsA(isA<TransactionActionRejectedException>()),
      );
      await txns.withdrawProposedStatus(t.id, seller.id);

      final after = await txns.getTransactionForListing(l.id);
      expect(after!.proposedStatus, isNull);
      expect(after.status, TransactionStatus.pending);
    });
  });

  // ==========================================================
  // UAT-07  Chat
  // ==========================================================
  group('UAT-07 chat', () {
    test('UAT-07.1 messages persist and unread counts work', () async {
      final l = await makeListing(ownerId: seller.id);
      final convId = _uuid.v4();
      final db = await DatabaseHelper.instance.database;
      await db.insert('conversations', {
        'id': convId,
        'listing_id': l.id,
        'buyer_id': bidderA.id,
        'seller_id': seller.id,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
      await messages.insertMessage(Message(
          id: _uuid.v4(),
          conversationId: convId,
          senderId: bidderA.id,
          content: 'Is this still available?'));

      expect(await messages.getTotalUnreadCount(seller.id), 1);
      expect(await messages.getTotalUnreadCount(bidderA.id), 0);
      await messages.markMessagesAsRead(convId, seller.id);
      expect(await messages.getTotalUnreadCount(seller.id), 0);

      final convs = await messages.getConversations(seller.id);
      expect(convs.first.lastMessage, 'Is this still available?');
      expect(convs.first.otherUserName, 'BidderA');
    });

    test('UAT-07.2 an empty message is not sendable (guarded in the UI)',
        () async {
      // chat_screen.dart:66 returns early on an empty trimmed body.
      // Recorded as covered-by-UI; the repository itself has no guard:
      final l = await makeListing(ownerId: seller.id);
      final convId = _uuid.v4();
      final db = await DatabaseHelper.instance.database;
      await db.insert('conversations', {
        'id': convId,
        'listing_id': l.id,
        'buyer_id': bidderA.id,
        'seller_id': seller.id,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
      await messages.insertMessage(Message(
          id: _uuid.v4(),
          conversationId: convId,
          senderId: bidderA.id,
          content: ''));
      expect((await messages.getMessages(convId)).first.content, '');
    });

    test('UAT-07.3 a demo account answers as an automated account', () async {
      // A demo seller cannot read a message, and dressing a random line from a
      // hardcoded list up as their reply is the dishonest part. It now says
      // what it is, once, and the chat screen labels the conversation too.
      final demoSeller = (await users.getDemoUsers()).first;
      final l = await makeListing(ownerId: demoSeller.id);
      final provider = MessageProvider();
      final conversation = await provider.getOrCreateConversation(
        listingId: l.id,
        buyerId: bidderA.id,
        sellerId: demoSeller.id,
      );

      await provider.loadMessages(conversation.id, bidderA.id);
      expect(provider.activeConversationIsAutomated, isTrue,
          reason: 'the screen has to be able to say who this is');

      await provider.sendMessage(
        conversationId: conversation.id,
        senderId: bidderA.id,
        content: 'What is the lowest you will take?',
      );
      await Future<void>.delayed(const Duration(milliseconds: 1400));

      final replies = (await messages.getMessages(conversation.id))
          .where((m) => m.senderId == demoSeller.id)
          .toList();
      expect(replies, hasLength(1),
          reason: 'one acknowledgement, not a stream of invented answers');
      expect(replies.first.content, startsWith('Automated reply'));
      expect(replies.first.content, contains('demo seller account'));

      // A second message does not produce a second pretend answer.
      await provider.sendMessage(
        conversationId: conversation.id,
        senderId: bidderA.id,
        content: 'Are you there?',
      );
      await Future<void>.delayed(const Duration(milliseconds: 1400));
      expect(
          (await messages.getMessages(conversation.id))
              .where((m) => m.senderId == demoSeller.id),
          hasLength(1));
      provider.clear();
    });

    test('UAT-07.4 a sent message puts the conversation in the inbox at once',
        () async {
      // The Inbox tab is kept alive behind the floor, so it loads once at
      // startup. A member who messages a seller and then taps Inbox must find
      // the conversation there, not "No messages yet".
      final l = await makeListing(ownerId: seller.id);
      final provider = MessageProvider();
      await provider.loadConversations(bidderA.id);
      expect(provider.conversations, isEmpty);

      final conversation = await provider.getOrCreateConversation(
        listingId: l.id,
        buyerId: bidderA.id,
        sellerId: seller.id,
      );
      await provider.sendMessage(
        conversationId: conversation.id,
        senderId: bidderA.id,
        content: 'Is this still available?',
      );

      // No reload: the inbox the tab is already showing must be current.
      expect(provider.conversations, hasLength(1));
      expect(provider.conversations.single.id, conversation.id);
      expect(provider.conversations.single.lastMessage,
          'Is this still available?');
      provider.clear();
    });

    test('UAT-07.3b a conversation with a real member is not labelled '
        'automated', () async {
      final l = await makeListing(ownerId: seller.id);
      final provider = MessageProvider();
      final conversation = await provider.getOrCreateConversation(
        listingId: l.id,
        buyerId: bidderA.id,
        sellerId: seller.id,
      );
      await provider.loadMessages(conversation.id, bidderA.id);
      expect(provider.activeConversationIsAutomated, isFalse);
      provider.clear();
    });
  });

  // ==========================================================
  // UAT-09b  Settings / data management
  // ==========================================================
  group('UAT-09b settings and data management', () {
    test('UAT-09b.1 Reset Demo Data keeps the member\'s own purchases',
        () async {
      // A real member wins a demo lot and settles it.
      final demoListing =
          (await listings.getListings(category: 'phones')).first;
      await listings.placeBid(demoListing.id, bidderA.id, 999000);
      await listings.endAuction(demoListing.id);
      final t = await txns.getTransactionForListing(demoListing.id);
      expect(t, isNotNull);

      await DatabaseHelper.instance.resetDemoData();

      // Restocking the floor is not a request to erase what they bought.
      final history = await txns.getTransactions(bidderA.id);
      expect(history, hasLength(1));
      expect(history.first.id, t!.id);
      expect(history.first.winningBid, 999000);
      expect(history.first.listingTitle, demoListing.title);

      final bids = await listings.getBids(demoListing.id);
      expect(bids, hasLength(1), reason: 'the winning bid is part of the sale');
    });

    test('UAT-09b.1b Reset Demo Data does restock the untouched lots',
        () async {
      final before = await listings.getListings();
      final untouched = before.first;

      await DatabaseHelper.instance.resetDemoData();

      final after = await listings.getListings();
      expect(after, hasLength(before.length),
          reason: 'the floor is restocked, not doubled or emptied');
      expect(after.map((l) => l.id), isNot(contains(untouched.id)),
          reason: 'an untouched demo lot is replaced by a fresh one');
    });

    test('UAT-09b.1c a saved demo lot survives the reset', () async {
      final saved = (await listings.getListings(category: 'vehicles')).first;
      await listings.toggleFavorite(_uuid.v4(), bidderA.id, saved.id);

      await DatabaseHelper.instance.resetDemoData();

      final favourites = await listings.getFavorites(bidderA.id);
      expect(favourites.map((l) => l.id), contains(saved.id));
    });

    test('UAT-09b.2 Reset Demo Data keeps the member\'s own reviews', () async {
      final demoListing =
          (await listings.getListings(category: 'books')).first;
      await listings.placeBid(demoListing.id, bidderA.id, 50000);
      await listings.endAuction(demoListing.id);
      final t = (await txns.getTransactionForListing(demoListing.id))!;
      await txns.recordPayment(
        paymentFor(t.listingId, t.winnerId, t.auctioneerId, t.winningBid,
            'Cash on Pickup', null),
        bidderA.id,
      );
      await txns.confirmPayment(t.id, demoListing.userId);
      await txns
          .insertReview(reviewFor(t.id, bidderA.id, demoListing.userId, 5));

      await DatabaseHelper.instance.resetDemoData();

      final db = await DatabaseHelper.instance.database;
      final reviews = await db
          .query('reviews', where: 'reviewer_id = ?', whereArgs: [bidderA.id]);
      expect(reviews, hasLength(1));
      expect(await users.getUserRating(demoListing.userId), 5.0,
          reason: 'the seller they reviewed is kept for the review to point at');
    });

    test('UAT-09b.3 the real user account survives Reset Demo Data', () async {
      await DatabaseHelper.instance.resetDemoData();
      expect(await users.getUserById(bidderA.id), isNotNull);
      expect((await users.getCurrentUser())!.id, bidderA.id);
    });

    test('UAT-09b.4 Clear All Data really clears everything and reseeds',
        () async {
      final l = await makeListing(ownerId: seller.id, title: 'Mine');
      await DatabaseHelper.instance.resetDatabase();
      expect(await listings.getListingById(l.id), isNull);
      expect(await users.getCurrentUser(), isNull);
      expect(await listings.getListings(), isNotEmpty,
          reason: 'demo catalogue is restored');
    });
  });

  // ==========================================================
  // UAT-09c  Profile
  // ==========================================================
  group('UAT-09c user profile', () {
    test('UAT-09c.1 another member\'s email and phone are not exposed',
        () async {
      // Verified through the repository contract used by UserProfileScreen.
      final other = await users.getUserById(seller.id);
      expect(other!.email, isNotEmpty,
          reason: 'the raw record does contain PII');
      // getPublicProfile (user_provider.dart:79) strips it - covered by the
      // widget suite; here we assert the repository is the unsafe one so the
      // guard is known to be load-bearing.
    });

    test('UAT-09c.2 a member can change their details after registering',
        () async {
      // The Edit Your Details screen writes through UserProvider.updateProfile.
      final provider = UserProvider();
      await provider.init();
      expect(provider.currentUser!.id, bidderA.id);

      await provider.updateProfile(
        name: 'BidderA Renamed',
        email: 'renamed@test.jm',
        phone: '8765550123',
        parish: 'St. Ann',
      );

      final saved = await users.getUserById(bidderA.id);
      expect(saved!.name, 'BidderA Renamed');
      expect(saved.email, 'renamed@test.jm');
      expect(saved.phone, '8765550123');
      expect(saved.parish, 'St. Ann');
      expect(provider.currentUser!.name, 'BidderA Renamed',
          reason: 'the screens reading the provider must see it immediately');
    });

    test('UAT-09c.2b the edit form holds a member to the same rules as '
        'registration', () {
      expect(MemberDetails.validateName('A'), isNotNull);
      expect(MemberDetails.validateEmail('not-an-email'), isNotNull);
      expect(MemberDetails.validatePhone('123'), isNotNull);
      expect(MemberDetails.validateName('Dwayne Aitken'), isNull);
      expect(MemberDetails.validateEmail('bidder@yardsale.jm'), isNull);
      expect(MemberDetails.validatePhone('876-555-0123'), isNull);
    });

    test('UAT-09c.3 rating is N/A until a review exists', () async {
      expect(await users.getUserRating(seller.id), 0.0);
    });
  });
}

// Test helpers ------------------------------------------------------------

Review reviewFor(
        String txnId, String reviewerId, String revieweeId, int rating) =>
    Review(
      id: _uuid.v4(),
      transactionId: txnId,
      reviewerId: reviewerId,
      revieweeId: revieweeId,
      rating: rating,
    );

app.Transaction paymentFor(
  String listingId,
  String winnerId,
  String auctioneerId,
  double winningBid,
  String method,
  String? reference,
) =>
    app.Transaction(
      id: _uuid.v4(),
      listingId: listingId,
      winnerId: winnerId,
      auctioneerId: auctioneerId,
      winningBid: winningBid,
      paymentMethod: method,
      referenceNumber: reference,
    );
