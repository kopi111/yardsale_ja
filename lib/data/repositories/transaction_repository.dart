import 'package:sqflite/sqflite.dart' show DatabaseException, DatabaseExecutor;
import '../../core/utils.dart';
import '../database/database_helper.dart';
import '../models/app_notification.dart';
import '../models/transaction.dart';
import '../models/review.dart';
import 'notification_repository.dart';

class DuplicateReviewException implements Exception {
  final String reason;

  const DuplicateReviewException(this.reason);

  @override
  String toString() => reason;
}

/// Raised when a member tries to move a settlement they are not entitled to
/// move, or to move it somewhere the settlement cannot go from where it is.
class TransactionActionRejectedException implements Exception {
  final String reason;

  const TransactionActionRejectedException(this.reason);

  @override
  String toString() => reason;
}

/// Where a settlement can be in its life. A sale is finished only when the
/// seller has confirmed the money the buyer says they sent.
class TransactionStatus {
  static const String pending = 'pending';
  static const String paid = 'paid';
  static const String completed = 'completed';
  static const String cancelled = 'cancelled';

  /// The states a member may propose moving to, and what they may be proposed
  /// from. Neither side decides alone: the other party has to agree.
  static const Map<String, List<String>> proposableFrom = {
    cancelled: [pending, paid],
    pending: [cancelled],
  };
}

class TransactionRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;
  final NotificationRepository _notifications = NotificationRepository();

  Future<List<Transaction>> getTransactions(String userId) async {
    final db = await _db.database;
    final result = await db.rawQuery('''
      SELECT t.*,
        l.title as listing_title,
        (SELECT li.image_path FROM listing_images li WHERE li.listing_id = t.listing_id ORDER BY li.sort_order ASC LIMIT 1) as listing_image_path,
        CASE WHEN t.winner_id = ? THEN u_auctioneer.name ELSE u_winner.name END as other_user_name
      FROM transactions t
      JOIN listings l ON t.listing_id = l.id
      JOIN users u_winner ON t.winner_id = u_winner.id
      JOIN users u_auctioneer ON t.auctioneer_id = u_auctioneer.id
      WHERE t.winner_id = ? OR t.auctioneer_id = ?
      ORDER BY t.created_at DESC
    ''', [userId, userId, userId]);
    return result.map((m) => Transaction.fromMap(m)).toList();
  }

  Future<Transaction?> getTransactionForListing(String listingId) async {
    final db = await _db.database;
    final result = await db.query(
      'transactions',
      where: 'listing_id = ?',
      whereArgs: [listingId],
      limit: 1,
    );
    if (result.isEmpty) return null;
    return Transaction.fromMap(result.first);
  }

  Future<void> insertTransaction(Transaction transaction) async {
    final db = await _db.database;
    await db.insert('transactions', transaction.toMap());
  }

  /// The buyer states how they paid and for what. Recording it moves the
  /// settlement to [TransactionStatus.paid] and asks the seller to confirm.
  /// No money moves through the app, so the buyer's word and the seller's
  /// confirmation are the whole mechanism, and both are recorded.
  Future<void> recordPayment(Transaction transaction, String actorId) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      final existing = await _requireTransactionForListing(
          txn, transaction.listingId);
      _requireRole(
        actorId: actorId,
        allowedId: existing['winner_id'] as String,
        action: 'record a payment on this lot',
      );
      final status = existing['status'] as String;
      if (status != TransactionStatus.pending &&
          status != TransactionStatus.paid) {
        throw TransactionActionRejectedException(
          'This settlement is already $status, so a payment cannot be '
          'recorded against it.',
        );
      }

      await txn.update(
        'transactions',
        {
          'payment_method': transaction.paymentMethod,
          'reference_number': transaction.referenceNumber,
          'status': TransactionStatus.paid,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [existing['id']],
      );

      await _notifications.notifyWithin(
        txn,
        userId: existing['auctioneer_id'] as String,
        kind: NotificationKinds.paymentRecorded,
        title: 'Payment recorded',
        listingId: transaction.listingId,
        body: 'The buyer says they have paid '
            '${AppUtils.formatPrice((existing['winning_bid'] as num).toDouble())} '
            'by ${transaction.paymentMethod}. Confirm it to complete the sale.',
      );
    });
  }

  /// The seller confirms the money arrived. Only they can: the buyer saying a
  /// sale is complete proves nothing about whether the seller was paid.
  Future<void> confirmPayment(String id, String actorId) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      final existing = await _requireTransaction(txn, id);
      _requireRole(
        actorId: actorId,
        allowedId: existing['auctioneer_id'] as String,
        action: 'confirm payment on this lot',
      );
      if (existing['status'] != TransactionStatus.paid) {
        throw const TransactionActionRejectedException(
          'The buyer has not recorded a payment on this lot yet.',
        );
      }

      await _writeStatus(txn, id, TransactionStatus.completed);
      await _notifications.notifyWithin(
        txn,
        userId: existing['winner_id'] as String,
        kind: NotificationKinds.saleCompleted,
        title: 'Sale completed',
        listingId: existing['listing_id'] as String,
        body: 'The seller confirmed your payment. You can now leave a review.',
      );
    });
  }

  /// Puts a change to the other party rather than making it. Cancelling a sale
  /// or reinstating a cancelled one costs the other side something, so it
  /// takes both signatures.
  Future<void> proposeStatusChange({
    required String id,
    required String actorId,
    required String status,
  }) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      final existing = await _requireTransaction(txn, id);
      final counterparty = _counterpartyOf(existing, actorId);
      final allowedFrom = TransactionStatus.proposableFrom[status];
      if (allowedFrom == null ||
          !allowedFrom.contains(existing['status'] as String)) {
        throw TransactionActionRejectedException(
          'A settlement that is ${existing['status']} cannot be moved to '
          '$status.',
        );
      }

      await txn.update(
        'transactions',
        {
          'proposed_status': status,
          'proposed_by': actorId,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      await _notifications.notifyWithin(
        txn,
        userId: counterparty,
        kind: NotificationKinds.statusProposed,
        title: status == TransactionStatus.cancelled
            ? 'Cancellation proposed'
            : 'Reinstatement proposed',
        listingId: existing['listing_id'] as String,
        body: status == TransactionStatus.cancelled
            ? 'The other party wants to cancel this sale. Open the settlement '
                'to agree or leave it standing.'
            : 'The other party wants to put this sale back on. Open the '
                'settlement to agree.',
      );
    });
  }

  /// The other party signs the proposal, and only then does it take effect.
  Future<void> agreeToProposedStatus(String id, String actorId) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      final existing = await _requireTransaction(txn, id);
      final proposedStatus = existing['proposed_status'] as String?;
      final proposedBy = existing['proposed_by'] as String?;
      if (proposedStatus == null || proposedBy == null) {
        throw const TransactionActionRejectedException(
          'There is nothing to agree to on this settlement.',
        );
      }
      if (proposedBy == actorId) {
        throw const TransactionActionRejectedException(
          'You proposed this change, so the other party has to agree to it.',
        );
      }
      _counterpartyOf(existing, actorId);

      await _writeStatus(txn, id, proposedStatus);
      await _notifications.notifyWithin(
        txn,
        userId: proposedBy,
        kind: NotificationKinds.statusAgreed,
        title: proposedStatus == TransactionStatus.cancelled
            ? 'Sale cancelled'
            : 'Sale reinstated',
        listingId: existing['listing_id'] as String,
        body: 'The other party agreed. The settlement is now $proposedStatus.',
      );
    });
  }

  /// Takes back a proposal the member made and nobody has signed.
  Future<void> withdrawProposedStatus(String id, String actorId) async {
    final db = await _db.database;
    final existing = await _requireTransaction(db, id);
    if (existing['proposed_by'] != actorId) {
      throw const TransactionActionRejectedException(
        'Only the member who proposed this change can withdraw it.',
      );
    }
    await db.update(
      'transactions',
      {
        'proposed_status': null,
        'proposed_by': null,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> _writeStatus(
      DatabaseExecutor txn, String id, String status) async {
    await txn.update(
      'transactions',
      {
        'status': status,
        'proposed_status': null,
        'proposed_by': null,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<Map<String, Object?>> _requireTransaction(
      DatabaseExecutor txn, String id) async {
    final rows = await txn.query(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw const TransactionActionRejectedException(
        'This settlement no longer exists.',
      );
    }
    return rows.first;
  }

  Future<Map<String, Object?>> _requireTransactionForListing(
      DatabaseExecutor txn, String listingId) async {
    final rows = await txn.query(
      'transactions',
      where: 'listing_id = ?',
      whereArgs: [listingId],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw const TransactionActionRejectedException(
        'This lot has not been settled, so there is nothing to pay against.',
      );
    }
    return rows.first;
  }

  void _requireRole({
    required String actorId,
    required String allowedId,
    required String action,
  }) {
    if (actorId == allowedId) return;
    throw TransactionActionRejectedException('You are not the party who can $action.');
  }

  String _counterpartyOf(Map<String, Object?> transaction, String actorId) {
    final winnerId = transaction['winner_id'] as String;
    final auctioneerId = transaction['auctioneer_id'] as String;
    if (actorId == winnerId) return auctioneerId;
    if (actorId == auctioneerId) return winnerId;
    throw const TransactionActionRejectedException(
      'You are not a party to this settlement.',
    );
  }

  /// [viewerId] names the other party from the reader's side. Without it the
  /// settlement screen can only call the person it is about "Other party".
  Future<Transaction?> getTransactionById(String id, {String? viewerId}) async {
    final db = await _db.database;
    final result = await db.rawQuery('''
      SELECT t.*,
        l.title as listing_title,
        (SELECT li.image_path FROM listing_images li WHERE li.listing_id = t.listing_id ORDER BY li.sort_order ASC LIMIT 1) as listing_image_path,
        CASE WHEN t.winner_id = ? THEN u_auctioneer.name ELSE u_winner.name END as other_user_name
      FROM transactions t
      JOIN listings l ON t.listing_id = l.id
      JOIN users u_winner ON t.winner_id = u_winner.id
      JOIN users u_auctioneer ON t.auctioneer_id = u_auctioneer.id
      WHERE t.id = ?
    ''', [viewerId, id]);
    if (result.isEmpty) return null;
    return Transaction.fromMap(result.first);
  }

  // Reviews
  Future<void> insertReview(Review review) async {
    final db = await _db.database;
    try {
      await db.insert('reviews', review.toMap());
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) {
        throw const DuplicateReviewException(
            'You have already reviewed this transaction.');
      }
      rethrow;
    }
  }

  Future<bool> hasReviewed(String transactionId, String reviewerId) async {
    final db = await _db.database;
    final result = await db.query(
      'reviews',
      columns: ['id'],
      where: 'transaction_id = ? AND reviewer_id = ?',
      whereArgs: [transactionId, reviewerId],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  Future<List<Review>> getReviewsForUser(String userId) async {
    final db = await _db.database;
    final result = await db.rawQuery('''
      SELECT r.*, u.name as reviewer_name
      FROM reviews r
      JOIN users u ON r.reviewer_id = u.id
      WHERE r.reviewee_id = ?
      ORDER BY r.created_at DESC
    ''', [userId]);
    return result.map((m) => Review.fromMap(m)).toList();
  }
}
