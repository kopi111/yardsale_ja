import '../database/database_helper.dart';
import '../models/user.dart';

class UserRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  Future<User?> getCurrentUser() async {
    final db = await _db.database;
    final result = await db.query('users', where: 'is_current = 1', limit: 1);
    if (result.isEmpty) return null;
    return User.fromMap(result.first);
  }

  Future<User> createUser(User user) async {
    final db = await _db.database;
    await db.insert('users', user.toMap());
    return user;
  }

  Future<void> updateUser(User user) async {
    final db = await _db.database;
    await db.update('users', user.toMap(), where: 'id = ?', whereArgs: [user.id]);
  }

  Future<User?> getUserById(String id) async {
    final db = await _db.database;
    final result = await db.query('users', where: 'id = ?', whereArgs: [id]);
    if (result.isEmpty) return null;
    return User.fromMap(result.first);
  }

  Future<List<User>> getDemoUsers() async {
    final db = await _db.database;
    final result = await db.query('users', where: 'is_demo = 1');
    return result.map((m) => User.fromMap(m)).toList();
  }

  Future<bool> hasCurrentUser() async {
    final user = await getCurrentUser();
    return user != null;
  }

  Future<int> getUserListingCount(String userId) async {
    final db = await _db.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM listings WHERE user_id = ? AND status <> ?',
      [userId, 'cancelled'],
    );
    return result.first['count'] as int;
  }

  Future<double> getUserRating(String userId) async {
    final db = await _db.database;
    final result = await db.rawQuery(
      'SELECT AVG(rating) as avg_rating FROM reviews WHERE reviewee_id = ?',
      [userId],
    );
    final avg = result.first['avg_rating'];
    return avg != null ? (avg as num).toDouble() : 0.0;
  }
}
