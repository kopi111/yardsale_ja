import 'package:sqflite/sqflite.dart' show DatabaseExecutor;
import 'package:uuid/uuid.dart';
import '../../core/constants.dart';
import '../../core/utils.dart';
import '../database/database_helper.dart';
import '../models/app_notification.dart';
import '../models/listing.dart';
import '../models/listing_image.dart';
import '../models/bid.dart';
import 'notification_repository.dart';

class BidRejectedException implements Exception {
  final String reason;

  const BidRejectedException(this.reason);

  @override
  String toString() => reason;
}

class ListingCancellationRejectedException implements Exception {
  final String reason;

  const ListingCancellationRejectedException(this.reason);

  @override
  String toString() => reason;
}

/// Raised when a seller tries to change the terms of a lot that is already
/// being bid on.
class ListingEditRejectedException implements Exception {
  final String reason;

  const ListingEditRejectedException(this.reason);

  @override
  String toString() => reason;
}

class ListingRepository {
  static const String _selectListings = '''
    SELECT l.*, u.name as auctioneer_name, u.parish as auctioneer_parish,
           u_bidder.name as highest_bidder_name
    FROM listings l
    JOIN users u ON l.user_id = u.id
    LEFT JOIN users u_bidder ON l.highest_bidder_id = u_bidder.id
  ''';

  static const String _likeEscape = r'\';

  final DatabaseHelper _db = DatabaseHelper.instance;
  final NotificationRepository _notifications = NotificationRepository();

  /// A shopper typing "50%" is searching for a string, not writing a pattern.
  /// Left unescaped, LIKE reads % and _ as wildcards and answers with the
  /// whole catalogue.
  static String _escapeLikePattern(String query) {
    return query
        .replaceAll(_likeEscape, '$_likeEscape$_likeEscape')
        .replaceAll('%', '$_likeEscape%')
        .replaceAll('_', '${_likeEscape}_');
  }

  Future<List<Listing>> _withImages(List<Map<String, Object?>> rows) async {
    final listings = <Listing>[];
    for (final row in rows) {
      final listing = Listing.fromMap(row);
      final images = await getListingImages(listing.id);
      listings.add(listing.copyWith(
        imagePaths: images.map((i) => i.imagePath).toList(),
      ));
    }
    return listings;
  }

  Future<List<Listing>> getListings({
    String? category,
    String? parish,
    String? condition,
    double? minPrice,
    double? maxPrice,
    String? searchQuery,
    String? userId,
    String? status,
    String orderBy = 'created_at DESC',
    int? limit,
  }) async {
    final db = await _db.database;
    final where = <String>[];
    final args = <dynamic>[];

    final wantedStatus = status ?? 'active';
    where.add('l.status = ?');
    args.add(wantedStatus);

    // A lot whose clock has run out is not live, whatever its row still says.
    // Screens that read the repository directly would otherwise offer a
    // finished auction for bidding until some other screen swept it.
    if (wantedStatus == 'active') {
      where.add('l.auction_end_time > ?');
      args.add(DateTime.now().toIso8601String());
    }

    if (category != null) {
      where.add('l.category = ?');
      args.add(category);
    }
    if (parish != null) {
      where.add('l.parish = ?');
      args.add(parish);
    }
    if (condition != null) {
      where.add('l.condition = ?');
      args.add(condition);
    }
    if (minPrice != null) {
      where.add('COALESCE(l.current_bid, l.starting_bid) >= ?');
      args.add(minPrice);
    }
    if (maxPrice != null) {
      where.add('COALESCE(l.current_bid, l.starting_bid) <= ?');
      args.add(maxPrice);
    }
    if (searchQuery != null && searchQuery.isNotEmpty) {
      where.add(
          "(l.title LIKE ? ESCAPE '$_likeEscape' "
          "OR l.description LIKE ? ESCAPE '$_likeEscape')");
      final pattern = '%${_escapeLikePattern(searchQuery)}%';
      args.add(pattern);
      args.add(pattern);
    }
    if (userId != null) {
      where.add('l.user_id = ?');
      args.add(userId);
    }

    final limitClause = limit != null ? 'LIMIT $limit' : '';
    final result = await db.rawQuery('''
      $_selectListings
      WHERE ${where.join(' AND ')}
      ORDER BY $orderBy
      $limitClause
    ''', args);

    return _withImages(result);
  }

  /// Every lot a seller has consigned. Withdrawn lots belong to the seller's
  /// own record but not to the shopfront a buyer sees, so a public view asks
  /// for them to be left out.
  Future<List<Listing>> getListingsByOwner(
    String userId, {
    bool includeCancelled = false,
  }) async {
    final db = await _db.database;
    final cancelledClause = includeCancelled ? '' : "AND l.status <> 'cancelled'";
    final result = await db.rawQuery('''
      $_selectListings
      WHERE l.user_id = ? $cancelledClause
      ORDER BY l.created_at DESC
    ''', [userId]);

    return _withImages(result);
  }

  Future<Listing?> getListingById(String id) async {
    final db = await _db.database;
    final result = await db.rawQuery('''
      $_selectListings
      WHERE l.id = ?
    ''', [id]);
    if (result.isEmpty) return null;
    final listing = Listing.fromMap(result.first);
    final images = await getListingImages(id);
    return listing.copyWith(
      imagePaths: images.map((i) => i.imagePath).toList(),
    );
  }

  Future<void> insertListing(Listing listing) async {
    final db = await _db.database;
    await db.insert('listings', listing.toMap());
  }

  /// Saves the fields a seller may edit. The bid columns and the auction
  /// status are deliberately absent: writing a whole [Listing] snapshot back
  /// would silently undo any bid placed since that snapshot was read.
  ///
  /// Once a bid is on the lot the terms are fixed. A bidder committed money to
  /// the item as described at the price advertised, so neither the description
  /// nor the opening price may move under them afterwards.
  Future<void> updateListingDetails(
    Listing listing, {
    List<String>? imagePaths,
  }) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      await _rejectEditIfBidsExist(txn, listing);
      await txn.update(
        'listings',
        {
          'title': listing.title,
          'description': listing.description,
          'starting_bid': listing.startingBid,
          'category': listing.category,
          'condition': listing.condition,
          'parish': listing.parish,
          'auction_end_time': listing.auctionEndTime.toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [listing.id],
      );
      if (imagePaths == null) return;
      await txn.delete('listing_images',
          where: 'listing_id = ?', whereArgs: [listing.id]);
      const uuid = Uuid();
      for (int i = 0; i < imagePaths.length; i++) {
        final image = ListingImage(
          id: uuid.v4(),
          listingId: listing.id,
          imagePath: imagePaths[i],
          sortOrder: i,
        );
        await txn.insert('listing_images', image.toMap());
      }
    });
  }

  /// The terms a bidder relied on when they committed. Changing any of these
  /// after a bid is a different lot at the same money.
  static const List<String> _termsFixedOnceBidsExist = [
    'title',
    'description',
    'starting_bid',
    'category',
    'condition',
  ];

  Future<void> _rejectEditIfBidsExist(
      DatabaseExecutor txn, Listing listing) async {
    final rows = await txn.query(
      'listings',
      columns: ['bid_count', ..._termsFixedOnceBidsExist],
      where: 'id = ?',
      whereArgs: [listing.id],
      limit: 1,
    );
    if (rows.isEmpty) return;
    final stored = rows.first;
    if ((stored['bid_count'] as int? ?? 0) == 0) return;

    final wanted = {
      'title': listing.title,
      'description': listing.description,
      'starting_bid': listing.startingBid,
      'category': listing.category,
      'condition': listing.condition,
    };
    for (final field in _termsFixedOnceBidsExist) {
      if (stored[field] == wanted[field]) continue;
      throw const ListingEditRejectedException(
        'Bidding has started on this lot, so its description and opening '
        'price are now fixed.',
      );
    }
  }

  Future<void> deleteListing(String id) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      final settled = await txn.query(
        'transactions',
        columns: ['id'],
        where: 'listing_id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (settled.isNotEmpty) {
        throw const ListingCancellationRejectedException(
          'This auction has already been settled with a winner and cannot be '
          'cancelled.',
        );
      }
      final rows = await txn.query(
        'listings',
        columns: ['bid_count'],
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      final bidCount = rows.isEmpty ? 0 : (rows.first['bid_count'] as int? ?? 0);
      if (bidCount > 0) {
        throw const ListingCancellationRejectedException(
          'Bids have already been placed on this auction, so it cannot be '
          'cancelled.',
        );
      }
      await txn.update(
        'listings',
        {
          'status': 'cancelled',
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  Future<void> endAuction(String id) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      await txn.update(
        'listings',
        {'status': 'ended', 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [id],
      );
      await _settleWithinTransaction(txn, id);
    });
  }

  /// Closes and settles every lot whose time is up, and reports how many, so
  /// a caller can tell whether anything a member is looking at just changed.
  Future<int> endExpiredAuctions() async {
    final db = await _db.database;
    final now = DateTime.now().toIso8601String();
    var closed = 0;
    await db.transaction((txn) async {
      final expired = await txn.query(
        'listings',
        columns: ['id'],
        where: "status = 'active' AND auction_end_time <= ?",
        whereArgs: [now],
      );
      await txn.rawUpdate('''
        UPDATE listings SET status = 'ended', updated_at = ?
        WHERE status = 'active' AND auction_end_time <= ?
      ''', [now, now]);
      for (final row in expired) {
        await _settleWithinTransaction(txn, row['id'] as String);
      }
      closed = expired.length;
    });
    return closed;
  }

  Future<void> settleAuction(String listingId) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      await _settleWithinTransaction(txn, listingId);
    });
  }

  Future<void> _settleWithinTransaction(
      DatabaseExecutor txn, String listingId) async {
    final listingRows = await txn.query(
      'listings',
      columns: [
        'user_id',
        'title',
        'status',
        'current_bid',
        'highest_bidder_id',
        'bid_count',
        'auction_end_time',
      ],
      where: 'id = ?',
      whereArgs: [listingId],
    );
    if (listingRows.isEmpty) return;
    final listing = listingRows.first;
    if (listing['status'] == 'cancelled') return;
    if (listing['status'] != 'ended') {
      // An auction reached straight from a favourite or a deep link can be
      // past its close time while nothing has yet flipped its status. Close it
      // here so the winner is settled instead of silently skipped.
      final endTime = DateTime.parse(listing['auction_end_time'] as String);
      if (DateTime.now().isBefore(endTime)) return;
      await txn.update(
        'listings',
        {'status': 'ended', 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [listingId],
      );
    }

    final hasWinningBid = listing['highest_bidder_id'] != null &&
        listing['current_bid'] != null &&
        (listing['bid_count'] as int? ?? 0) > 0;
    if (!hasWinningBid) return;

    final alreadySettled = await txn.query(
      'transactions',
      columns: ['id'],
      where: 'listing_id = ?',
      whereArgs: [listingId],
      limit: 1,
    );
    if (alreadySettled.isNotEmpty) return;

    final now = DateTime.now().toIso8601String();
    await txn.insert('transactions', {
      'id': const Uuid().v4(),
      'listing_id': listingId,
      'winner_id': listing['highest_bidder_id'],
      'auctioneer_id': listing['user_id'],
      'winning_bid': listing['current_bid'],
      'payment_method': 'Cash on Pickup',
      'reference_number': null,
      'status': 'pending',
      'created_at': now,
      'updated_at': now,
    });

    await _announceResult(txn, listing, listingId);
  }

  /// Both sides of a struck lot are told. A win a member only discovers by
  /// reopening the exact page they bid on is a win the house never announced.
  Future<void> _announceResult(
    DatabaseExecutor txn,
    Map<String, Object?> listing,
    String listingId,
  ) async {
    final title = listing['title'] as String;
    final hammerPrice =
        AppUtils.formatPrice((listing['current_bid'] as num).toDouble());

    await _notifications.notifyWithin(
      txn,
      userId: listing['highest_bidder_id'] as String,
      kind: NotificationKinds.won,
      title: 'You won $title',
      listingId: listingId,
      body: 'The hammer fell at $hammerPrice. Settle up with the seller to '
          'collect the lot.',
    );
    await _notifications.notifyWithin(
      txn,
      userId: listing['user_id'] as String,
      kind: NotificationKinds.sold,
      title: '$title sold',
      listingId: listingId,
      body: 'The lot closed at $hammerPrice. Await the buyer\'s payment, then '
          'confirm it to complete the sale.',
    );
  }

  Future<String?> getSettledTransactionId(String listingId) async {
    final db = await _db.database;
    final rows = await db.query(
      'transactions',
      columns: ['id'],
      where: 'listing_id = ?',
      whereArgs: [listingId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['id'] as String;
  }

  // Bidding
  Future<void> placeBid(String listingId, String bidderId, double amount) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      final listingRows = await txn.query(
        'listings',
        columns: [
          'user_id',
          'title',
          'status',
          'starting_bid',
          'current_bid',
          'highest_bidder_id',
          'auction_end_time',
        ],
        where: 'id = ?',
        whereArgs: [listingId],
      );
      if (listingRows.isEmpty) {
        throw const BidRejectedException('This auction no longer exists.');
      }
      final listing = listingRows.first;

      if (listing['user_id'] == bidderId) {
        throw const BidRejectedException(
            'You cannot bid on your own auction.');
      }
      if (listing['status'] != 'active') {
        throw const BidRejectedException('This auction has ended.');
      }
      final auctionEnd = DateTime.parse(listing['auction_end_time'] as String);
      if (DateTime.now().isAfter(auctionEnd)) {
        throw const BidRejectedException('This auction has ended.');
      }
      // Bidding against yourself only raises the price you will pay. The house
      // holds the lead for you until somebody else takes it.
      final outgoingLeader = listing['highest_bidder_id'] as String?;
      if (outgoingLeader == bidderId) {
        throw const BidRejectedException(
            'You already hold the highest bid on this lot.');
      }

      final currentBid = (listing['current_bid'] as num?)?.toDouble();
      final startingBid = (listing['starting_bid'] as num).toDouble();
      final minimumBid = currentBid != null
          ? currentBid + AppBidding.minimumIncrement
          : startingBid;
      if (amount < minimumBid) {
        throw BidRejectedException(
            'The lowest bid accepted on this lot is '
            '${AppUtils.formatPrice(minimumBid)}.');
      }
      if (amount > AppBidding.maximumBid) {
        throw BidRejectedException(
            'The highest bid this house accepts is '
            '${AppUtils.formatPrice(AppBidding.maximumBid)}.');
      }

      final affectedRows = await txn.rawUpdate('''
        UPDATE listings
        SET current_bid = ?, highest_bidder_id = ?, bid_count = bid_count + 1,
            updated_at = ?
        WHERE id = ?
          AND status = 'active'
          AND auction_end_time > ?
          AND user_id <> ?
          AND (current_bid IS NULL AND ? >= starting_bid
               OR current_bid IS NOT NULL AND ? > current_bid)
      ''', [
        amount,
        bidderId,
        DateTime.now().toIso8601String(),
        listingId,
        DateTime.now().toIso8601String(),
        bidderId,
        amount,
        amount,
      ]);

      if (affectedRows != 1) {
        throw const BidRejectedException(
            'Your bid could not be placed. Someone may have outbid you.');
      }

      final bid = Bid(
        id: const Uuid().v4(),
        listingId: listingId,
        bidderId: bidderId,
        amount: amount,
      );
      await txn.insert('bids', bid.toMap());

      if (outgoingLeader != null) {
        await _notifications.notifyWithin(
          txn,
          userId: outgoingLeader,
          kind: NotificationKinds.outbid,
          title: 'You have been outbid',
          listingId: listingId,
          body: '${listing['title']} is now at '
              '${AppUtils.formatPrice(amount)}. Bid again to take the lead.',
        );
      }
    });
  }

  Future<List<Bid>> getBids(String listingId) async {
    final db = await _db.database;
    final result = await db.rawQuery('''
      SELECT b.*, u.name as bidder_name
      FROM bids b
      JOIN users u ON b.bidder_id = u.id
      WHERE b.listing_id = ?
      ORDER BY b.amount DESC
    ''', [listingId]);
    return result.map((m) => Bid.fromMap(m)).toList();
  }

  // Listing images
  Future<List<ListingImage>> getListingImages(String listingId) async {
    final db = await _db.database;
    final result = await db.query('listing_images',
        where: 'listing_id = ?',
        whereArgs: [listingId],
        orderBy: 'sort_order ASC');
    return result.map((m) => ListingImage.fromMap(m)).toList();
  }

  Future<void> insertListingImage(ListingImage image) async {
    final db = await _db.database;
    await db.insert('listing_images', image.toMap());
  }

  Future<void> deleteListingImages(String listingId) async {
    final db = await _db.database;
    await db.delete('listing_images',
        where: 'listing_id = ?', whereArgs: [listingId]);
  }

  // Favorites
  Future<bool> isFavorited(String userId, String listingId) async {
    final db = await _db.database;
    final result = await db.query('favorites',
        where: 'user_id = ? AND listing_id = ?',
        whereArgs: [userId, listingId]);
    return result.isNotEmpty;
  }

  Future<void> toggleFavorite(String favId, String userId, String listingId) async {
    final db = await _db.database;
    final existing = await db.query('favorites',
        where: 'user_id = ? AND listing_id = ?',
        whereArgs: [userId, listingId]);
    if (existing.isNotEmpty) {
      await db.delete('favorites',
          where: 'user_id = ? AND listing_id = ?',
          whereArgs: [userId, listingId]);
    } else {
      await db.insert('favorites', {
        'id': favId,
        'user_id': userId,
        'listing_id': listingId,
        'created_at': DateTime.now().toIso8601String(),
      });
    }
  }

  /// A member saves a lot to watch it close, so a saved lot stays on the list
  /// once it has closed. Only a withdrawn lot leaves, because there is no
  /// longer anything to watch.
  Future<List<Listing>> getFavorites(String userId) async {
    final db = await _db.database;
    final result = await db.rawQuery('''
      $_selectListings
      JOIN favorites f ON f.listing_id = l.id
      WHERE f.user_id = ? AND l.status <> 'cancelled'
      ORDER BY f.created_at DESC
    ''', [userId]);

    final listings = await _withImages(result);
    return listings
        .map((listing) => listing.copyWith(isFavorited: true))
        .toList();
  }
}
