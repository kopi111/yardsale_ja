import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:yardsale_ja/data/database/database_helper.dart';

/// The v3 shape of the tables this migration has to carry forward. It is
/// written out in full deliberately: a migration test that builds its fixture
/// from the current schema would pass even if the migration were removed.
const String _v3Users = '''
  CREATE TABLE users (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    email TEXT,
    phone TEXT,
    parish TEXT NOT NULL,
    avatar_path TEXT,
    is_demo INTEGER DEFAULT 0,
    created_at TEXT NOT NULL
  )
''';

const String _v3Listings = '''
  CREATE TABLE listings (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    starting_bid REAL NOT NULL,
    category TEXT NOT NULL,
    condition TEXT NOT NULL,
    parish TEXT NOT NULL,
    status TEXT DEFAULT 'active',
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    auction_end_time TEXT NOT NULL,
    current_bid REAL,
    highest_bidder_id TEXT,
    bid_count INTEGER DEFAULT 0,
    FOREIGN KEY (user_id) REFERENCES users(id)
  )
''';

const String _v3Bids = '''
  CREATE TABLE bids (
    id TEXT PRIMARY KEY,
    listing_id TEXT NOT NULL,
    bidder_id TEXT NOT NULL,
    amount REAL NOT NULL,
    created_at TEXT NOT NULL,
    FOREIGN KEY (listing_id) REFERENCES listings(id),
    FOREIGN KEY (bidder_id) REFERENCES users(id)
  )
''';

/// v3 allowed any number of transactions per listing; v4 allows one.
const String _v3Transactions = '''
  CREATE TABLE transactions (
    id TEXT PRIMARY KEY,
    listing_id TEXT NOT NULL,
    winner_id TEXT NOT NULL,
    auctioneer_id TEXT NOT NULL,
    winning_bid REAL NOT NULL,
    payment_method TEXT NOT NULL,
    reference_number TEXT,
    status TEXT DEFAULT 'pending',
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    FOREIGN KEY (listing_id) REFERENCES listings(id),
    FOREIGN KEY (winner_id) REFERENCES users(id),
    FOREIGN KEY (auctioneer_id) REFERENCES users(id)
  )
''';

void main() {
  late String databasePath;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    databasePath = join(await getDatabasesPath(), 'yardsale_ja.db');
    await DatabaseHelper.instance.close();
    await deleteDatabase(databasePath);
    await _seedVersion3Database(databasePath);
  });

  tearDown(() async {
    await DatabaseHelper.instance.close();
    await deleteDatabase(databasePath);
  });

  group('upgrade from v3', () {
    test('keeps the user, their listing and its bids', () async {
      final db = await DatabaseHelper.instance.database;

      final users = await db.query('users', where: 'id = ?', whereArgs: ['u1']);
      expect(users, hasLength(1), reason: 'the real user must survive');
      expect(users.first['name'], 'Real Person');

      final listings =
          await db.query('listings', where: 'id = ?', whereArgs: ['l1']);
      expect(listings, hasLength(1), reason: 'their listing must survive');
      expect(listings.first['title'], 'Real Listing');
      expect(listings.first['current_bid'], 25000.0);
      expect(listings.first['bid_count'], 2);

      final bids = await db.query('bids');
      expect(bids, hasLength(2), reason: 'the bid history must survive');
    });

    test('reaches the current schema version', () async {
      final db = await DatabaseHelper.instance.database;
      expect(await db.getVersion(), 6);
    });

    test('adds the notice board without losing the data already there',
        () async {
      final db = await DatabaseHelper.instance.database;
      final notices = await db.query('notifications');
      expect(notices, isEmpty, reason: 'a migrated database starts quiet');

      final listings = await db.query('listings');
      expect(listings, hasLength(1),
          reason: 'v5 is a rebuild, so it must still preserve every row');
    });

    test('adds the unique-settlement constraint the new schema promises',
        () async {
      final db = await DatabaseHelper.instance.database;
      final now = DateTime.now().toIso8601String();

      expect(
        () => db.insert('transactions', {
          'id': 't-duplicate',
          'listing_id': 'l1',
          'winner_id': 'u1',
          'auctioneer_id': 'u1',
          'winning_bid': 25000.0,
          'payment_method': 'Cash on Pickup',
          'status': 'pending',
          'created_at': now,
          'updated_at': now,
        }),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('collapses pre-existing duplicate settlements to the earliest',
        () async {
      final db = await DatabaseHelper.instance.database;
      final settlements =
          await db.query('transactions', where: 'listing_id = ?', whereArgs: ['l1']);

      expect(settlements, hasLength(1));
      expect(settlements.first['id'], 't-first');
    });

    test('does not re-seed demo data over a database that already has rows',
        () async {
      final db = await DatabaseHelper.instance.database;
      final demoUsers = await db.query('users', where: 'is_demo = 1');
      expect(demoUsers, isEmpty);
    });
  });

  test('a brand new database is seeded with an openable floor', () async {
    await DatabaseHelper.instance.close();
    await deleteDatabase(databasePath);

    final db = await DatabaseHelper.instance.database;
    final listings = await db.query('listings', where: "status = 'active'");
    expect(listings, isNotEmpty,
        reason: 'a first run must land on a populated floor');
  });
}

Future<void> _seedVersion3Database(String path) async {
  final db = await openDatabase(path, version: 3, onCreate: (db, _) async {
    await db.execute(_v3Users);
    await db.execute(_v3Listings);
    await db.execute(_v3Bids);
    await db.execute(_v3Transactions);
  });

  final now = DateTime.now().toIso8601String();
  await db.insert('users', {
    'id': 'u1',
    'name': 'Real Person',
    'email': 'real@example.com',
    'phone': '876-555-0000',
    'parish': 'Kingston',
    'is_demo': 0,
    'created_at': now,
  });
  await db.insert('listings', {
    'id': 'l1',
    'user_id': 'u1',
    'title': 'Real Listing',
    'description': 'Something a real user listed before the upgrade.',
    'starting_bid': 20000.0,
    'category': 'other',
    'condition': 'Good',
    'parish': 'Kingston',
    'status': 'ended',
    'created_at': now,
    'updated_at': now,
    'auction_end_time': now,
    'current_bid': 25000.0,
    'highest_bidder_id': 'u1',
    'bid_count': 2,
  });
  for (final bid in [
    {'id': 'b1', 'amount': 22000.0},
    {'id': 'b2', 'amount': 25000.0},
  ]) {
    await db.insert('bids', {
      'id': bid['id'],
      'listing_id': 'l1',
      'bidder_id': 'u1',
      'amount': bid['amount'],
      'created_at': now,
    });
  }
  // Two settlements for one lot — legal in v3, impossible in v4.
  await db.insert('transactions', {
    'id': 't-first',
    'listing_id': 'l1',
    'winner_id': 'u1',
    'auctioneer_id': 'u1',
    'winning_bid': 25000.0,
    'payment_method': 'Cash on Pickup',
    'status': 'pending',
    'created_at': '2026-01-01T00:00:00.000',
    'updated_at': '2026-01-01T00:00:00.000',
  });
  await db.insert('transactions', {
    'id': 't-second',
    'listing_id': 'l1',
    'winner_id': 'u1',
    'auctioneer_id': 'u1',
    'winning_bid': 25000.0,
    'payment_method': 'Lynk',
    'status': 'pending',
    'created_at': '2026-02-01T00:00:00.000',
    'updated_at': '2026-02-01T00:00:00.000',
  });
  await db.close();
}
