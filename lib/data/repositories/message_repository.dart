import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../models/conversation.dart';
import '../models/message.dart';

class MessageRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  Future<List<Conversation>> getConversations(String userId) async {
    final db = await _db.database;
    final result = await db.rawQuery('''
      SELECT c.*,
        l.title as listing_title,
        COALESCE(l.current_bid, l.starting_bid) as listing_price,
        CASE WHEN c.buyer_id = ? THEN u_seller.name ELSE u_buyer.name END as other_user_name,
        (SELECT li.image_path FROM listing_images li WHERE li.listing_id = c.listing_id ORDER BY li.sort_order ASC LIMIT 1) as listing_image_path,
        (SELECT m.content FROM messages m WHERE m.conversation_id = c.id ORDER BY m.created_at DESC LIMIT 1) as last_message,
        (SELECT m.created_at FROM messages m WHERE m.conversation_id = c.id ORDER BY m.created_at DESC LIMIT 1) as last_message_at,
        (SELECT COUNT(*) FROM messages m WHERE m.conversation_id = c.id AND m.sender_id != ? AND m.is_read = 0) as unread_count
      FROM conversations c
      JOIN listings l ON c.listing_id = l.id
      JOIN users u_buyer ON c.buyer_id = u_buyer.id
      JOIN users u_seller ON c.seller_id = u_seller.id
      WHERE c.buyer_id = ? OR c.seller_id = ?
      ORDER BY c.updated_at DESC
    ''', [userId, userId, userId, userId]);
    return result.map((m) => Conversation.fromMap(m)).toList();
  }

  Future<Conversation?> getConversation(String id) async {
    final db = await _db.database;
    final result = await db.query('conversations', where: 'id = ?', whereArgs: [id]);
    if (result.isEmpty) return null;
    return Conversation.fromMap(result.first);
  }

  Future<Conversation?> findConversation(String listingId, String buyerId, String sellerId) async {
    final db = await _db.database;
    final result = await db.query('conversations',
        where: 'listing_id = ? AND buyer_id = ? AND seller_id = ?',
        whereArgs: [listingId, buyerId, sellerId]);
    if (result.isEmpty) return null;
    return Conversation.fromMap(result.first);
  }

  Future<void> insertConversation(Conversation conversation) async {
    final db = await _db.database;
    await db.insert('conversations', conversation.toMap());
  }

  Future<void> updateConversation(String id) async {
    final db = await _db.database;
    await db.update('conversations',
        {'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Message>> getMessages(String conversationId) async {
    final db = await _db.database;
    final result = await db.query('messages',
        where: 'conversation_id = ?',
        whereArgs: [conversationId],
        orderBy: 'created_at ASC');
    return result.map((m) => Message.fromMap(m)).toList();
  }

  Future<void> insertMessage(Message message) async {
    final db = await _db.database;
    await db.insert('messages', message.toMap());
    await updateConversation(message.conversationId);
  }

  Future<int> markMessagesAsRead(String conversationId, String currentUserId) async {
    final db = await _db.database;
    return await db.update('messages', {'is_read': 1},
        where: 'conversation_id = ? AND sender_id != ? AND is_read = 0',
        whereArgs: [conversationId, currentUserId]);
  }

  Future<int> getTotalUnreadCount(String userId) async {
    final db = await _db.database;
    final result = await db.rawQuery('''
      SELECT COUNT(*) as count FROM messages m
      JOIN conversations c ON m.conversation_id = c.id
      WHERE (c.buyer_id = ? OR c.seller_id = ?)
      AND m.sender_id != ? AND m.is_read = 0
    ''', [userId, userId, userId]);
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
