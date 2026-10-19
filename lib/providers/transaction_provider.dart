import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../data/models/transaction.dart';
import '../data/models/review.dart';
import '../data/repositories/transaction_repository.dart';
import '../data/repositories/user_repository.dart';

class TransactionProvider with ChangeNotifier {
  final TransactionRepository _repo = TransactionRepository();
  final UserRepository _users = UserRepository();
  List<Transaction> _transactions = [];
  bool _isLoading = true;

  List<Transaction> get transactions => _transactions;
  bool get isLoading => _isLoading;

  Future<void> loadTransactions(String userId) async {
    _isLoading = true;
    notifyListeners();
    try {
      _transactions = await _repo.getTransactions(userId);
    } finally {
      // Without this the loading flag survives a failed read, and the retry
      // the screen offers only ever reveals a spinner that cannot resolve.
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> recordPayment({
    required String listingId,
    required String winnerId,
    required String auctioneerId,
    required double winningBid,
    required String paymentMethod,
    String? referenceNumber,
  }) async {
    final transaction = Transaction(
      id: const Uuid().v4(),
      listingId: listingId,
      winnerId: winnerId,
      auctioneerId: auctioneerId,
      winningBid: winningBid,
      paymentMethod: paymentMethod,
      referenceNumber: referenceNumber,
    );
    await _repo.recordPayment(transaction, winnerId);
    await _confirmIfSellerIsADemoAccount(transaction);
    notifyListeners();
  }

  /// A demo seller counter-signs on its own.
  ///
  /// A sale completes only when the seller confirms the money arrived. Nobody
  /// is behind a demo account to do that, so a member who wins a demo lot
  /// would otherwise be stranded at "payment recorded" and could never reach
  /// the review. Confirming here is the settlement counterpart of the demo
  /// seller's automated chat reply.
  Future<void> _confirmIfSellerIsADemoAccount(Transaction transaction) async {
    final seller = await _users.getUserById(transaction.auctioneerId);
    if (seller == null || !seller.isDemo) return;
    final settlement = await _repo.getTransactionForListing(
      transaction.listingId,
    );
    if (settlement == null) return;
    await _repo.confirmPayment(settlement.id, seller.id);
  }

  void clear() {
    _transactions = [];
    _isLoading = false;
    notifyListeners();
  }

  Future<List<Review>> getReviewsForUser(String userId) async {
    return _repo.getReviewsForUser(userId);
  }

  Future<bool> hasReviewed(String transactionId, String reviewerId) async {
    return _repo.hasReviewed(transactionId, reviewerId);
  }

  Future<void> confirmPayment(String transactionId, String actorId) async {
    await _repo.confirmPayment(transactionId, actorId);
    notifyListeners();
  }

  Future<void> proposeStatusChange({
    required String transactionId,
    required String actorId,
    required String status,
  }) async {
    await _repo.proposeStatusChange(
      id: transactionId,
      actorId: actorId,
      status: status,
    );
    notifyListeners();
  }

  Future<void> agreeToProposedStatus(
      String transactionId, String actorId) async {
    await _repo.agreeToProposedStatus(transactionId, actorId);
    notifyListeners();
  }

  Future<void> withdrawProposedStatus(
      String transactionId, String actorId) async {
    await _repo.withdrawProposedStatus(transactionId, actorId);
    notifyListeners();
  }

  Future<Transaction?> getTransactionById(String transactionId,
      {String? viewerId}) async {
    return _repo.getTransactionById(transactionId, viewerId: viewerId);
  }

  Future<void> addReview({
    required String transactionId,
    required String reviewerId,
    required String revieweeId,
    required int rating,
    String? comment,
  }) async {
    final review = Review(
      id: const Uuid().v4(),
      transactionId: transactionId,
      reviewerId: reviewerId,
      revieweeId: revieweeId,
      rating: rating,
      comment: comment,
    );
    await _repo.insertReview(review);
    notifyListeners();
  }
}
