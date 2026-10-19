import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();
  static Database? _database;
  static Future<Database>? _initFuture;
  static const _uuid = Uuid();

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _initFuture ??= _initDatabase();
    try {
      _database = await _initFuture!;
    } catch (_) {
      _initFuture = null;
      rethrow;
    }
    return _database!;
  }

  static const _databaseVersion = 6;

  Future<Database> _initDatabase() async {
    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWeb;
      return await openDatabase(
        'yardsale_ja.db',
        version: _databaseVersion,
        onConfigure: _enableForeignKeys,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );
    }
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'yardsale_ja.db');
    return await openDatabase(
      path,
      version: _databaseVersion,
      onConfigure: _enableForeignKeys,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _enableForeignKeys(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _onCreate(Database db, int version) async {
    await _createSchema(db);
    await _createIndexes(db);
    await _seedData(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // v3 added cascading foreign keys, v4 made transactions unique per lot, and
    // v5 added notifications and the counter-signature columns. All are
    // table-definition changes, which SQLite can only make by rebuilding the
    // table, so a single rebuild covers any starting point.
    if (oldVersion < 6) {
      await _rebuildSchemaPreservingData(db);
    }
    // v6 gives every demo lot its own photograph. Older databases seeded their
    // lots without one and relied on the catalogue guessing a picture.
    await _consignPhotosToDemoLotsMissingOne(db);
  }

  /// Files a photograph against each demo lot that has none. Runs after the
  /// rebuild, so it also covers lots the rebuild carried across.
  Future<void> _consignPhotosToDemoLotsMissingOne(DatabaseExecutor db) async {
    final unillustrated = await db.rawQuery('''
      SELECT l.id, l.title FROM listings l
      JOIN users u ON u.id = l.user_id
      WHERE u.is_demo = 1
        AND NOT EXISTS (
          SELECT 1 FROM listing_images li WHERE li.listing_id = l.id
        )
    ''');
    for (final lot in unillustrated) {
      final slug = _demoPhotos[lot['title']];
      if (slug == null) continue;
      await db.insert('listing_images', {
        'id': _uuid.v4(),
        'listing_id': lot['id'],
        'image_path': _demoPhotoUrl(slug),
        'sort_order': 0,
      });
    }
  }

  /// Rebuilds every table against the current schema and puts the existing
  /// rows back. A migration must never cost a user their listings, bids or
  /// chats, so nothing here drops data it has not first read out.
  Future<void> _rebuildSchemaPreservingData(Database db) async {
    // `PRAGMA foreign_keys` is ignored inside a transaction, and sqflite runs
    // onUpgrade in one. Deferring the checks to commit is the form that works.
    await db.execute('PRAGMA defer_foreign_keys = ON');

    final preserved = <String, List<Map<String, Object?>>>{};
    for (final table in _schemaTables) {
      preserved[table] = await _readTableIfPresent(db, table);
    }

    await _dropSchema(db);
    await _createSchema(db);
    await _createIndexes(db);

    // Parents first, so every restored row finds the row it references.
    for (final table in _schemaTables.reversed) {
      final rows = table == 'transactions'
          ? _oneTransactionPerListing(preserved[table]!)
          : preserved[table]!;
      for (final row in rows) {
        await db.insert(table, row,
            conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    }

    final restored = preserved.values.fold<int>(0, (sum, r) => sum + r.length);
    if (restored == 0) await _seedData(db);
  }

  Future<List<Map<String, Object?>>> _readTableIfPresent(
      Database db, String table) async {
    final exists = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
      [table],
    );
    if (exists.isEmpty) return const [];
    return db.query(table);
  }

  /// v4 allows a single transaction per lot. An older database may hold more
  /// than one; the earliest is the settlement, so it is the one kept.
  List<Map<String, Object?>> _oneTransactionPerListing(
      List<Map<String, Object?>> rows) {
    final sorted = [...rows]..sort((a, b) =>
        (a['created_at'] as String).compareTo(b['created_at'] as String));
    final seen = <Object?>{};
    return sorted.where((row) => seen.add(row['listing_id'])).toList();
  }


  /// The photograph each demo lot is consigned with. A demo lot keeps its
  /// picture in `listing_images` like any other lot, so nothing downstream has
  /// to infer a picture from a title.
  ///
  /// A lot missing from this map is consigned without a photograph and shows
  /// the category plate — which is the point: better no picture than a picture
  /// of something else.
  static const Map<String, String> _demoPhotos = {
    'iPhone 14 Pro Max - 256GB': 'photo-1678685888221-cda773a3dcdb',
    'Samsung 55" Smart TV': 'photo-1593359677879-a4bb92f829d1',
    '2019 Toyota Vitz': 'photo-1619767886558-efdc259cde1a',
    'Nike Air Jordan 1 Retro': 'photo-1600269452121-4f2416e55c28',
    'L-Shaped Office Desk': 'photo-1518455027359-f3f8164ba6bd',
    'PS5 + 3 Games Bundle': 'photo-1606144042614-b2417e99c4e3',
    'Samsung Galaxy S24 Ultra': 'photo-1610945265064-0e34e5519bbf',
    'Mountain Bike - Trek Marlin 7': 'photo-1576435728678-68d0fbf94e91',
    'Textbooks - UWI Computer Science': 'photo-1497633762265-9d179a990aa6',
    'Washing Machine - LG 8kg': 'photo-1626806787461-102c1bfaaea1',
    'Honda CRV 2020': 'photo-1494976388531-d1058494cdd8',
    'MacBook Pro M2 - 16"': 'photo-1517336714731-489689fd1ca8',
    'Dining Table Set - 6 Chairs': 'photo-1617806118233-18e1de247200',
    'iPad Air 5th Gen': 'photo-1544244015-0df4b3ffc6b0',
    'Adidas Predator Football Boots': 'photo-1511886929837-354d827aafe2',
    'Plumbing & Electrical Services': 'photo-1621905251189-08b45d6a269e',
    'Beats Studio Pro Headphones': 'photo-1505740420928-5e560c06d30e',
    'Vintage Levi\'s 501 Jeans': 'photo-1542272604-787c3835535d',
    'King Size Bed Frame': 'photo-1505693416388-ac5ce068fe85',
    'Garden Tool Set - 12 Piece': 'photo-1416879595882-3373a0480b5b',
    'Nintendo Switch OLED': 'photo-1578303512597-81e6cc155b3e',
    'Toyota Corolla 2018': 'photo-1621007947382-bb3c3994e3fb',
    'Web Design Services': 'photo-1547658719-da2b51169166',
    'Acoustic Guitar - Yamaha': 'photo-1510915361894-db8b60106cb1',
    'Air Fryer - Ninja 5.5L': 'photo-1648500659547-8b65a1c21968',
    'Blue Mountain Coffee - 5lb Gift Box': 'photo-1447933601403-0c6688de566e',
    'Canon EOS 250D DSLR + 18-55mm Lens': 'photo-1502920917128-1aa500764cbd',
  };

  static String _demoPhotoUrl(String slug) =>
      'https://images.unsplash.com/$slug?w=800&h=800&fit=crop';

  static const List<String> _schemaTables = [
    'notifications',
    'reviews',
    'transactions',
    'messages',
    'conversations',
    'favorites',
    'bids',
    'listing_images',
    'listings',
    'categories',
    'users',
  ];

  Future<void> _dropSchema(Database db) async {
    for (final table in _schemaTables) {
      await db.execute('DROP TABLE IF EXISTS $table');
    }
  }

  Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        email TEXT,
        phone TEXT,
        parish TEXT,
        avatar_path TEXT,
        is_current INTEGER DEFAULT 0,
        is_demo INTEGER DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        icon_name TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE listings (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        title TEXT NOT NULL,
        description TEXT,
        starting_bid REAL NOT NULL,
        category TEXT NOT NULL,
        condition TEXT,
        parish TEXT,
        status TEXT DEFAULT 'active',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        auction_end_time TEXT NOT NULL,
        current_bid REAL,
        highest_bidder_id TEXT,
        bid_count INTEGER DEFAULT 0,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
        FOREIGN KEY (highest_bidder_id) REFERENCES users(id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE listing_images (
        id TEXT PRIMARY KEY,
        listing_id TEXT NOT NULL,
        image_path TEXT NOT NULL,
        sort_order INTEGER DEFAULT 0,
        FOREIGN KEY (listing_id) REFERENCES listings(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE bids (
        id TEXT PRIMARY KEY,
        listing_id TEXT NOT NULL,
        bidder_id TEXT NOT NULL,
        amount REAL NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (listing_id) REFERENCES listings(id) ON DELETE CASCADE,
        FOREIGN KEY (bidder_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE favorites (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        listing_id TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
        FOREIGN KEY (listing_id) REFERENCES listings(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE conversations (
        id TEXT PRIMARY KEY,
        listing_id TEXT NOT NULL,
        buyer_id TEXT NOT NULL,
        seller_id TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (listing_id) REFERENCES listings(id) ON DELETE CASCADE,
        FOREIGN KEY (buyer_id) REFERENCES users(id) ON DELETE CASCADE,
        FOREIGN KEY (seller_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE messages (
        id TEXT PRIMARY KEY,
        conversation_id TEXT NOT NULL,
        sender_id TEXT NOT NULL,
        content TEXT NOT NULL,
        is_read INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        FOREIGN KEY (conversation_id) REFERENCES conversations(id) ON DELETE CASCADE,
        FOREIGN KEY (sender_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE transactions (
        id TEXT PRIMARY KEY,
        listing_id TEXT NOT NULL,
        winner_id TEXT NOT NULL,
        auctioneer_id TEXT NOT NULL,
        winning_bid REAL NOT NULL,
        payment_method TEXT NOT NULL,
        reference_number TEXT,
        status TEXT DEFAULT 'pending',
        proposed_status TEXT,
        proposed_by TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (listing_id) REFERENCES listings(id) ON DELETE CASCADE,
        FOREIGN KEY (winner_id) REFERENCES users(id) ON DELETE CASCADE,
        FOREIGN KEY (auctioneer_id) REFERENCES users(id) ON DELETE CASCADE,
        FOREIGN KEY (proposed_by) REFERENCES users(id) ON DELETE SET NULL,
        UNIQUE (listing_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE reviews (
        id TEXT PRIMARY KEY,
        transaction_id TEXT NOT NULL,
        reviewer_id TEXT NOT NULL,
        reviewee_id TEXT NOT NULL,
        rating INTEGER NOT NULL,
        comment TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (transaction_id) REFERENCES transactions(id) ON DELETE CASCADE,
        FOREIGN KEY (reviewer_id) REFERENCES users(id) ON DELETE CASCADE,
        FOREIGN KEY (reviewee_id) REFERENCES users(id) ON DELETE CASCADE,
        UNIQUE (transaction_id, reviewer_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE notifications (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        kind TEXT NOT NULL,
        title TEXT NOT NULL,
        body TEXT NOT NULL,
        listing_id TEXT,
        is_read INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
        FOREIGN KEY (listing_id) REFERENCES listings(id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _createIndexes(Database db) async {
    await db.execute(
        'CREATE INDEX idx_listings_user_id ON listings(user_id)');
    await db.execute(
        'CREATE INDEX idx_listings_highest_bidder_id ON listings(highest_bidder_id)');
    await db.execute(
        'CREATE INDEX idx_listings_status_end ON listings(status, auction_end_time)');
    await db.execute(
        'CREATE INDEX idx_listing_images_listing_id ON listing_images(listing_id)');
    await db.execute(
        'CREATE INDEX idx_bids_listing_id ON bids(listing_id)');
    await db.execute(
        'CREATE INDEX idx_bids_bidder_id ON bids(bidder_id)');
    await db.execute(
        'CREATE INDEX idx_favorites_user_id ON favorites(user_id)');
    await db.execute(
        'CREATE INDEX idx_favorites_listing_id ON favorites(listing_id)');
    await db.execute(
        'CREATE INDEX idx_conversations_listing_id ON conversations(listing_id)');
    await db.execute(
        'CREATE INDEX idx_messages_conversation_id ON messages(conversation_id)');
    await db.execute(
        'CREATE INDEX idx_transactions_listing_id ON transactions(listing_id)');
    await db.execute(
        'CREATE INDEX idx_transactions_winner_id ON transactions(winner_id)');
    await db.execute(
        'CREATE INDEX idx_transactions_auctioneer_id ON transactions(auctioneer_id)');
    await db.execute(
        'CREATE INDEX idx_reviews_reviewee_id ON reviews(reviewee_id)');
    await db.execute(
        'CREATE INDEX idx_reviews_transaction_id ON reviews(transaction_id)');
    await db.execute(
        'CREATE INDEX idx_notifications_user_id ON notifications(user_id, is_read)');
  }

  Future<void> _seedData(DatabaseExecutor db) async {
    final now = DateTime.now();

    // Demo users
    final demoUsers = [
      {'id': 'demo_1', 'name': 'Marcus Brown', 'email': 'marcus@demo.com', 'phone': '876-555-0101', 'parish': 'Kingston'},
      {'id': 'demo_2', 'name': 'Shantel Williams', 'email': 'shantel@demo.com', 'phone': '876-555-0102', 'parish': 'St. Andrew'},
      {'id': 'demo_3', 'name': 'Devon Campbell', 'email': 'devon@demo.com', 'phone': '876-555-0103', 'parish': 'St. James'},
      {'id': 'demo_4', 'name': 'Keisha Thompson', 'email': 'keisha@demo.com', 'phone': '876-555-0104', 'parish': 'St. Ann'},
      {'id': 'demo_5', 'name': 'Andre Mitchell', 'email': 'andre@demo.com', 'phone': '876-555-0105', 'parish': 'Manchester'},
      {'id': 'demo_6', 'name': 'Tanya Reid', 'email': 'tanya@demo.com', 'phone': '876-555-0106', 'parish': 'Clarendon'},
      {'id': 'demo_7', 'name': 'Ryan Edwards', 'email': 'ryan@demo.com', 'phone': '876-555-0107', 'parish': 'St. Catherine'},
      {'id': 'demo_8', 'name': 'Patrice Morgan', 'email': 'patrice@demo.com', 'phone': '876-555-0108', 'parish': 'Portland'},
    ];

    // A reseed after a demo reset can meet demo members that were retained
    // because the member's own history leans on them. Those keep their record.
    for (final u in demoUsers) {
      await db.insert(
        'users',
        {
          ...u,
          'is_current': 0,
          'is_demo': 1,
          'created_at':
              now.subtract(const Duration(days: 30)).toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }

    final standingTitles = await _demoTitlesAlreadyOnTheFloor(db);

    // Auction durations in hours for variety
    final auctionHours = [
      2, 6, 12, 24, 36, 48, 72, 96, 120, 168, // 2h to 7d
      4, 8, 18, 30, 42, 60, 84, 108, 144, 192, // varied
      3, 10, 20, 48, 336, // more varied
    ];

    // Demo listings with auction data
    final demoListings = [
      {'user': 'demo_1', 'title': 'iPhone 14 Pro Max - 256GB', 'desc': 'Slightly used iPhone 14 Pro Max in excellent condition. Deep Purple color, 256GB storage. Comes with original box, charger, and case. Battery health at 94%.', 'price': 185000.0, 'cat': 'phones', 'cond': 'Like New', 'parish': 'Kingston'},
      {'user': 'demo_2', 'title': 'Samsung 55" Smart TV', 'desc': 'Samsung Crystal UHD 55 inch Smart TV. Perfect working condition, selling because upgrading to larger size. Remote included.', 'price': 75000.0, 'cat': 'electronics', 'cond': 'Good', 'parish': 'St. Andrew'},
      {'user': 'demo_3', 'title': '2019 Toyota Vitz', 'desc': 'Well maintained 2019 Toyota Vitz. Low mileage, AC cold, everything works. Recently serviced with new tires. Serious inquiries only.', 'price': 2800000.0, 'cat': 'vehicles', 'cond': 'Good', 'parish': 'St. James'},
      {'user': 'demo_4', 'title': 'Nike Air Jordan 1 Retro', 'desc': 'Brand new Nike Air Jordan 1 Retro High OG. Size 10 US. Bred colorway, deadstock with receipt.', 'price': 32000.0, 'cat': 'clothing', 'cond': 'New', 'parish': 'St. Ann'},
      {'user': 'demo_5', 'title': 'L-Shaped Office Desk', 'desc': 'Solid wood L-shaped office desk. Perfect for home office setup. Some minor scratches but very sturdy. Dimensions: 60" x 60".', 'price': 45000.0, 'cat': 'furniture', 'cond': 'Good', 'parish': 'Manchester'},
      {'user': 'demo_6', 'title': 'PS5 + 3 Games Bundle', 'desc': 'PlayStation 5 disc edition with 3 games: Spider-Man 2, God of War Ragnarok, and FIFA 24. Two controllers included.', 'price': 120000.0, 'cat': 'electronics', 'cond': 'Like New', 'parish': 'Clarendon'},
      {'user': 'demo_7', 'title': 'Samsung Galaxy S24 Ultra', 'desc': 'Samsung Galaxy S24 Ultra 512GB Titanium Black. Dual sim, unlocked. Comes with S Pen and clear case.', 'price': 195000.0, 'cat': 'phones', 'cond': 'Like New', 'parish': 'St. Catherine'},
      {'user': 'demo_1', 'title': 'Mountain Bike - Trek Marlin 7', 'desc': 'Trek Marlin 7 mountain bike, 29er wheels. Great for trails and road. Recently tuned up with new brake pads.', 'price': 85000.0, 'cat': 'sports', 'cond': 'Good', 'parish': 'Kingston'},
      {'user': 'demo_8', 'title': 'Textbooks - UWI Computer Science', 'desc': 'Collection of UWI Computer Science textbooks. Includes Data Structures, Algorithms, and Database Systems. All in good condition.', 'price': 12000.0, 'cat': 'books', 'cond': 'Good', 'parish': 'Portland'},
      {'user': 'demo_2', 'title': 'Washing Machine - LG 8kg', 'desc': 'LG 8kg front load washing machine. Top loader, energy efficient. Works perfectly, selling due to relocation.', 'price': 55000.0, 'cat': 'home_garden', 'cond': 'Good', 'parish': 'St. Andrew'},
      {'user': 'demo_3', 'title': 'Honda CRV 2020', 'desc': 'Honda CRV 2020 model, fully loaded. Leather interior, sunroof, reverse camera. Single owner, dealer maintained.', 'price': 5500000.0, 'cat': 'vehicles', 'cond': 'Like New', 'parish': 'St. James'},
      {'user': 'demo_4', 'title': 'MacBook Pro M2 - 16"', 'desc': 'MacBook Pro 16 inch with M2 Pro chip. 16GB RAM, 512GB SSD. AppleCare+ until 2025. Space Gray.', 'price': 320000.0, 'cat': 'electronics', 'cond': 'Like New', 'parish': 'St. Ann'},
      {'user': 'demo_5', 'title': 'Dining Table Set - 6 Chairs', 'desc': 'Beautiful mahogany dining table with 6 matching chairs. Hand-crafted locally. Seats 6 comfortably.', 'price': 95000.0, 'cat': 'furniture', 'cond': 'Good', 'parish': 'Manchester'},
      {'user': 'demo_6', 'title': 'iPad Air 5th Gen', 'desc': 'iPad Air 5th generation, 64GB WiFi model. Blue color. Comes with Apple Pencil 2nd gen and keyboard case.', 'price': 85000.0, 'cat': 'electronics', 'cond': 'Like New', 'parish': 'Clarendon'},
      {'user': 'demo_7', 'title': 'Adidas Predator Football Boots', 'desc': 'Adidas Predator Edge.1 FG football boots. Size 9 UK. Worn twice on grass pitch only.', 'price': 18000.0, 'cat': 'sports', 'cond': 'Like New', 'parish': 'St. Catherine'},
      {'user': 'demo_8', 'title': 'Plumbing & Electrical Services', 'desc': 'Professional plumbing and electrical services across Portland and St. Thomas. Licensed and insured. Free estimates.', 'price': 5000.0, 'cat': 'services', 'cond': 'New', 'parish': 'Portland'},
      {'user': 'demo_1', 'title': 'Beats Studio Pro Headphones', 'desc': 'Beats Studio Pro wireless noise cancelling headphones. Black color. Excellent sound quality, barely used.', 'price': 35000.0, 'cat': 'electronics', 'cond': 'Like New', 'parish': 'Kingston'},
      {'user': 'demo_2', 'title': 'Vintage Levi\'s 501 Jeans', 'desc': 'Authentic vintage Levi\'s 501 jeans. Size 32x32. Classic medium wash, great condition for vintage.', 'price': 8000.0, 'cat': 'clothing', 'cond': 'Good', 'parish': 'St. Andrew'},
      {'user': 'demo_3', 'title': 'King Size Bed Frame', 'desc': 'Solid wood king size bed frame with headboard. Mahogany finish. Mattress not included. Must pick up.', 'price': 65000.0, 'cat': 'furniture', 'cond': 'Good', 'parish': 'St. James'},
      {'user': 'demo_4', 'title': 'Garden Tool Set - 12 Piece', 'desc': 'Complete 12-piece garden tool set. Includes rake, shovel, pruners, gloves, and more. Great for starting a garden.', 'price': 6500.0, 'cat': 'home_garden', 'cond': 'New', 'parish': 'St. Ann'},
      {'user': 'demo_5', 'title': 'Nintendo Switch OLED', 'desc': 'Nintendo Switch OLED model, white edition. Includes Pro Controller and 5 games. Screen protector applied since day one.', 'price': 65000.0, 'cat': 'electronics', 'cond': 'Like New', 'parish': 'Manchester'},
      {'user': 'demo_6', 'title': 'Toyota Corolla 2018', 'desc': 'Toyota Corolla 2018, automatic transmission. Well maintained, AC cold, clean interior. Perfect daily driver.', 'price': 3200000.0, 'cat': 'vehicles', 'cond': 'Good', 'parish': 'Clarendon'},
      {'user': 'demo_7', 'title': 'Web Design Services', 'desc': 'Professional web design and development. WordPress, Shopify, custom sites. Portfolio available on request. Starting from J\$50,000.', 'price': 50000.0, 'cat': 'services', 'cond': 'New', 'parish': 'St. Catherine'},
      {'user': 'demo_8', 'title': 'Acoustic Guitar - Yamaha', 'desc': 'Yamaha FG800 acoustic guitar. Perfect for beginners and intermediate players. Comes with gig bag, tuner, and picks.', 'price': 28000.0, 'cat': 'other', 'cond': 'Good', 'parish': 'Portland'},
      {'user': 'demo_1', 'title': 'Air Fryer - Ninja 5.5L', 'desc': 'Ninja Air Fryer 5.5 litre capacity. Used a few times, basically new. Makes crispy food with less oil.', 'price': 15000.0, 'cat': 'home_garden', 'cond': 'Like New', 'parish': 'Kingston'},
    ];

    for (int i = 0; i < demoListings.length; i++) {
      if (standingTitles.contains(demoListings[i]['title'])) continue;
      final daysAgo = (i * 2) + 1;
      await _insertSeedListing(
        db,
        listing: demoListings[i],
        createdAt: now.subtract(Duration(days: daysAgo, hours: i * 3)),
        endsAt: now.add(Duration(hours: auctionHours[i])),
      );
    }

    // Auctions that close within minutes rather than hours, so the
    // bid -> ended -> winner -> payment -> review flow can be walked end to end
    // without waiting out the long-running demo auctions.
    final closingSoonListings = [
      {
        'user': 'demo_2',
        'title': 'Blue Mountain Coffee - 5lb Gift Box',
        'desc':
            'Authentic Jamaica Blue Mountain coffee, 5lb box of whole beans. Sealed and freshly roasted this month. Collected from the estate in Irish Town.',
        'price': 9500.0,
        'cat': 'other',
        'cond': 'New',
        'parish': 'St. Andrew',
        'minutes': 6},
      {
        'user': 'demo_3',
        'title': 'Canon EOS 250D DSLR + 18-55mm Lens',
        'desc':
            'Canon EOS 250D with the 18-55mm kit lens. Shutter count under 4,000. Includes battery, charger, 64GB card and padded bag.',
        'price': 78000.0,
        'cat': 'electronics',
        'cond': 'Like New',
        'parish': 'St. James',
        'minutes': 10},
      {
        'user': 'demo_5',
        'title': 'Honda EU22i Portable Generator',
        'desc':
            'Honda EU22i inverter generator, 2.2kVA. Quiet enough for the yard, serviced with fresh oil. Ideal for hurricane season backup.',
        'price': 145000.0,
        'cat': 'home_garden',
        'cond': 'Good',
        'parish': 'Manchester',
        'minutes': 15},
    ];

    for (final listing in closingSoonListings) {
      if (standingTitles.contains(listing['title'])) continue;
      await _insertSeedListing(
        db,
        listing: listing,
        createdAt: now.subtract(const Duration(days: 1)),
        endsAt: now.add(Duration(minutes: listing['minutes'] as int)),
      );
    }
  }

  /// Titles of demo lots still standing. A reseed skips these so a lot the
  /// member is holding does not reappear beside a fresh copy of itself.
  Future<Set<String>> _demoTitlesAlreadyOnTheFloor(DatabaseExecutor db) async {
    final rows = await db.rawQuery('''
      SELECT l.title FROM listings l
      JOIN users u ON u.id = l.user_id
      WHERE u.is_demo = 1
    ''');
    return rows.map((row) => row['title'] as String).toSet();
  }

  Future<void> _insertSeedListing(
    DatabaseExecutor db, {
    required Map<String, Object> listing,
    required DateTime createdAt,
    required DateTime endsAt,
  }) async {
    final listingId = _uuid.v4();
    await db.insert('listings', {
      'id': listingId,
      'user_id': listing['user'],
      'title': listing['title'],
      'description': listing['desc'],
      'starting_bid': listing['price'],
      'category': listing['cat'],
      'condition': listing['cond'],
      'parish': listing['parish'],
      'status': 'active',
      'created_at': createdAt.toIso8601String(),
      'updated_at': createdAt.toIso8601String(),
      'auction_end_time': endsAt.toIso8601String(),
      'current_bid': null,
      'highest_bidder_id': null,
      'bid_count': 0,
    });
    await _insertSeedPhoto(db, listingId: listingId, listing: listing);
  }

  /// A demo lot carries its photograph in the data, like any other lot, so no
  /// screen has to guess a picture from a title.
  Future<void> _insertSeedPhoto(
    DatabaseExecutor db, {
    required String listingId,
    required Map<String, Object> listing,
  }) async {
    final slug = _demoPhotos[listing['title']];
    if (slug == null) return;
    await db.insert('listing_images', {
      'id': _uuid.v4(),
      'listing_id': listingId,
      'image_path': _demoPhotoUrl(slug),
      'sort_order': 0,
    });
  }

  /// Releases the open handle. The next call to [database] opens a fresh one.
  Future<void> close() async {
    await _database?.close();
    _database = null;
    _initFuture = null;
  }

  Future<void> resetDatabase() async {
    await close();
    if (kIsWeb) {
      await databaseFactory.deleteDatabase('yardsale_ja.db');
    } else {
      final dbPath = await getDatabasesPath();
      await deleteDatabase(join(dbPath, 'yardsale_ja.db'));
    }
    await database;
  }

  Future<void> resetDemoData() async {
    final db = await database;
    await db.transaction((txn) async {
      await _deleteDemoData(txn);
      await _seedData(txn);
    });
  }

  /// Clears the demo catalogue and leaves the member's own history standing.
  /// Resetting the demo data is a request to restock the floor, never a
  /// request to destroy the bids, purchases and reviews the member made
  /// against it, so anything their history depends on is retained.
  Future<void> _deleteDemoData(Transaction txn) async {
    await txn.rawDelete('''
      DELETE FROM users
      WHERE is_demo = 1 AND id NOT IN ($_demoUsersMemberHistoryNeeds)
    ''');
    await txn.rawDelete('''
      DELETE FROM listings
      WHERE user_id IN (SELECT id FROM users WHERE is_demo = 1)
        AND id NOT IN ($_demoLotsMemberHistoryNeeds)
    ''');
    await _recomputeBidCounters(txn);
  }

  /// Demo lots a member has taken part in: bid on, won, saved or asked about.
  static const String _demoLotsMemberHistoryNeeds = '''
    SELECT l.id FROM listings l
    JOIN users owner ON owner.id = l.user_id AND owner.is_demo = 1
    WHERE EXISTS (SELECT 1 FROM transactions t WHERE t.listing_id = l.id)
       OR EXISTS (SELECT 1 FROM bids b JOIN users u ON u.id = b.bidder_id
                  WHERE b.listing_id = l.id AND u.is_demo = 0)
       OR EXISTS (SELECT 1 FROM favorites f JOIN users u ON u.id = f.user_id
                  WHERE f.listing_id = l.id AND u.is_demo = 0)
       OR EXISTS (SELECT 1 FROM conversations c JOIN users u ON u.id = c.buyer_id
                  WHERE c.listing_id = l.id AND u.is_demo = 0)
  ''';

  /// Demo members who are the other party to something the member did. Delete
  /// one of these and the sale, bid or review on the member's side goes with
  /// it, because every reference to a user cascades.
  static const String _demoUsersMemberHistoryNeeds = '''
    SELECT u.id FROM users u
    WHERE u.is_demo = 1
      AND (u.id IN (SELECT l.user_id FROM listings l
                    WHERE l.id IN ($_demoLotsMemberHistoryNeeds))
        OR EXISTS (SELECT 1 FROM transactions t
                   WHERE t.auctioneer_id = u.id OR t.winner_id = u.id)
        OR EXISTS (SELECT 1 FROM reviews r
                   WHERE r.reviewer_id = u.id OR r.reviewee_id = u.id)
        OR EXISTS (SELECT 1 FROM bids b
                   JOIN listings bl ON bl.id = b.listing_id
                   JOIN users owner ON owner.id = bl.user_id
                   WHERE b.bidder_id = u.id AND owner.is_demo = 0)
        OR EXISTS (SELECT 1 FROM conversations c
                   JOIN users other ON other.id = CASE
                     WHEN c.buyer_id = u.id THEN c.seller_id ELSE c.buyer_id END
                   WHERE (c.buyer_id = u.id OR c.seller_id = u.id)
                     AND other.is_demo = 0))
  ''';

  /// Removing the swept demo bidders takes their bids with them. Recompute the
  /// counters from the bids that are left rather than zeroing them, or a
  /// listing ends up advertising no bids above a visible bid history. A lot
  /// that has already been settled keeps its hammer price untouched: the
  /// transaction was struck at that number.
  Future<void> _recomputeBidCounters(DatabaseExecutor db) async {
    await db.rawUpdate('''
      UPDATE listings SET
        current_bid = (
          SELECT MAX(b.amount) FROM bids b WHERE b.listing_id = listings.id
        ),
        bid_count = (
          SELECT COUNT(*) FROM bids b WHERE b.listing_id = listings.id
        ),
        highest_bidder_id = (
          SELECT b.bidder_id FROM bids b
          WHERE b.listing_id = listings.id
          ORDER BY b.amount DESC, b.created_at ASC LIMIT 1
        )
      WHERE (bid_count > 0 OR current_bid IS NOT NULL)
        AND NOT EXISTS (
          SELECT 1 FROM transactions t WHERE t.listing_id = listings.id
        )
    ''');
  }
}
