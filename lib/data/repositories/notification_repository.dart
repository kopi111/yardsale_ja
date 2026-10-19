import 'package:sqflite/sqflite.dart' show DatabaseExecutor;
import 'package:uuid/uuid.dart';
import '../database/database_helper.dart';
import '../models/app_notification.dart';

class NotificationRepository {
  static const Uuid _uuid = Uuid();

  final DatabaseHelper _db = DatabaseHelper.instance;

  Future<List<AppNotification>> getNotifications(String userId) async {
    final db = await _db.database;
    final rows = await db.query(
      'notifications',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    );
    return rows.map(AppNotification.fromMap).toList();
  }

  Future<int> getUnreadCount(String userId) async {
    final db = await _db.database;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) as count FROM notifications '
      'WHERE user_id = ? AND is_read = 0',
      [userId],
    );
    return rows.first['count'] as int;
  }

  Future<void> markAllRead(String userId) async {
    final db = await _db.database;
    await db.update(
      'notifications',
      {'is_read': 1},
      where: 'user_id = ? AND is_read = 0',
      whereArgs: [userId],
    );
  }

  Future<void> notify({
    required String userId,
    required String kind,
    required String title,
    required String body,
    String? listingId,
  }) async {
    final db = await _db.database;
    await notifyWithin(
      db,
      userId: userId,
      kind: kind,
      title: title,
      body: body,
      listingId: listingId,
    );
  }

  /// Writes the notice inside a caller's transaction, so a member is never
  /// told about an event that then rolls back.
  Future<void> notifyWithin(
    DatabaseExecutor txn, {
    required String userId,
    required String kind,
    required String title,
    required String body,
    String? listingId,
  }) async {
    final notification = AppNotification(
      id: _uuid.v4(),
      userId: userId,
      kind: kind,
      title: title,
      body: body,
      listingId: listingId,
    );
    await txn.insert('notifications', notification.toMap());
  }
}
