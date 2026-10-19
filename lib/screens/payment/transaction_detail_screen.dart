import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../core/palette.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/models/transaction.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../providers/listing_provider.dart';
import '../../providers/transaction_provider.dart';
import 'payment_screen.dart';
import 'transactions_screen.dart' show SettlementStanding;

/// One settlement, and what each party may do about it. Every action here is
/// tied to a role: the buyer says they paid, the seller confirms they were
/// paid, and neither can cancel or reinstate the sale without the other.
class TransactionDetailScreen extends StatefulWidget {
  final Transaction transaction;
  final String currentUserId;

  const TransactionDetailScreen({
    super.key,
    required this.transaction,
    required this.currentUserId,
  });

  @override
  State<TransactionDetailScreen> createState() =>
      _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  late Transaction _transaction;
  bool _isBusy = false;
  bool _hasReviewed = false;

  @override
  void initState() {
    super.initState();
    _transaction = widget.transaction;
    _loadReviewState();
  }

  bool get _isWinner => widget.currentUserId == _transaction.winnerId;

  bool get _isAuctioneer => widget.currentUserId == _transaction.auctioneerId;

  String get _revieweeId =>
      _isWinner ? _transaction.auctioneerId : _transaction.winnerId;

  String get _otherPartyRole => _isWinner ? 'seller' : 'buyer';

  Future<void> _loadReviewState() async {
    final hasReviewed = await context
        .read<TransactionProvider>()
        .hasReviewed(_transaction.id, widget.currentUserId);
    if (mounted) setState(() => _hasReviewed = hasReviewed);
  }

  Future<void> _reload() async {
    final refreshed = await context
        .read<TransactionProvider>()
        .getTransactionById(_transaction.id, viewerId: widget.currentUserId);
    if (!mounted || refreshed == null) return;
    setState(() => _transaction = refreshed);
  }

  /// Runs a settlement action and reports whatever the repository says about
  /// it, so a refusal reaches the member as words rather than a dead button.
  Future<void> _run(Future<void> Function() action, String done) async {
    setState(() => _isBusy = true);
    try {
      await action();
      await _reload();
      if (mounted) _showSnack(done, AppColors.green);
    } on TransactionActionRejectedException catch (e) {
      if (mounted) _showSnack(e.reason, AppColors.red);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _recordPayment() async {
    final listing = await context
        .read<ListingProvider>()
        .getListingById(_transaction.listingId);
    if (!mounted) return;
    if (listing == null) {
      _showSnack('This lot is no longer available.', AppColors.red);
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PaymentScreen(listing: listing)),
    );
    await _reload();
  }

  Future<void> _leaveReview() async {
    final transactionProvider = context.read<TransactionProvider>();
    final result = await showModalBottomSheet<_ReviewInput>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _ReviewSheet(),
    );
    if (result == null) return;

    try {
      await transactionProvider.addReview(
        transactionId: _transaction.id,
        reviewerId: widget.currentUserId,
        revieweeId: _revieweeId,
        rating: result.rating,
        comment: result.comment,
      );
      if (mounted) {
        setState(() => _hasReviewed = true);
        _showSnack('Review submitted. Thank you!', AppColors.green);
      }
    } on DuplicateReviewException catch (e) {
      if (mounted) {
        setState(() => _hasReviewed = true);
        _showSnack(e.reason, AppColors.red);
      }
    }
  }

  void _showSnack(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    final txn = _transaction;
    final palette = context.palette;
    return Scaffold(
      backgroundColor: palette.canvas,
      appBar: AppBar(title: const Text('Settlement')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            SettlementStanding.labelFor(txn.status),
            style: AppTheme.sectionLabel(
              SettlementStanding.colourFor(txn.status, palette),
            ),
          ),
          const SizedBox(height: 6),
          Text(txn.listingTitle ?? 'Lot',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(AppUtils.formatPrice(txn.winningBid),
              style: AppTheme.money(34, palette.onSurface)),
          const SizedBox(height: 20),
          _detailRow('Paid by', txn.paymentMethod),
          if (txn.referenceNumber != null && txn.referenceNumber!.isNotEmpty)
            _detailRow('Reference', txn.referenceNumber!),
          _detailRow(_isWinner ? 'Seller' : 'Buyer',
              txn.otherUserName ?? 'Other party'),
          _detailRow('Settled on', AppUtils.formatDate(txn.createdAt)),
          const SizedBox(height: 20),
          ..._buildProposalNotice(),
          _StepNote(text: _whatHappensNext),
          const SizedBox(height: 20),
          ..._buildActions(),
        ],
      ),
    );
  }

  /// The one sentence that tells a member where the sale stands and whose
  /// move it is. Both parties see the same story from their own side.
  String get _whatHappensNext {
    switch (_transaction.status) {
      case TransactionStatus.pending:
        return _isWinner
            ? 'Pay the seller directly, then record here how you paid.'
            : 'Waiting for the buyer to pay you and record it here.';
      case TransactionStatus.paid:
        return _isWinner
            ? 'The seller has been told. The sale completes once they confirm '
                'your payment arrived.'
            : 'The buyer says they have paid. Confirm it once the money is '
                'with you.';
      case TransactionStatus.completed:
        return 'This sale is complete. You can leave a review of the '
            '$_otherPartyRole.';
      default:
        return 'This sale was cancelled by agreement. Either party can '
            'propose putting it back on.';
    }
  }

  List<Widget> _buildProposalNotice() {
    final proposed = _transaction.proposedStatus;
    final proposedBy = _transaction.proposedBy;
    if (proposed == null || proposedBy == null) return const [];

    final isMine = proposedBy == widget.currentUserId;
    final change = proposed == TransactionStatus.cancelled
        ? 'cancel this sale'
        : 'put this sale back on';
    return [
      _ProposalNotice(
        message: isMine
            ? 'You asked to $change. It takes effect when the '
                '$_otherPartyRole agrees.'
            : 'The $_otherPartyRole asked to $change.',
        actionLabel: isMine ? 'WITHDRAW THE REQUEST' : 'AGREE',
        onAction: _isBusy
            ? null
            : () => isMine ? _withdrawProposal() : _agreeToProposal(),
      ),
      const SizedBox(height: 16),
    ];
  }

  Future<void> _agreeToProposal() {
    return _run(
      () => context
          .read<TransactionProvider>()
          .agreeToProposedStatus(_transaction.id, widget.currentUserId),
      'Agreed. The settlement has been updated.',
    );
  }

  Future<void> _withdrawProposal() {
    return _run(
      () => context
          .read<TransactionProvider>()
          .withdrawProposedStatus(_transaction.id, widget.currentUserId),
      'Request withdrawn.',
    );
  }

  Future<void> _propose(String status, String done) {
    return _run(
      () => context.read<TransactionProvider>().proposeStatusChange(
            transactionId: _transaction.id,
            actorId: widget.currentUserId,
            status: status,
          ),
      done,
    );
  }

  List<Widget> _buildActions() {
    final actions = <Widget>[];
    if (_transaction.status == TransactionStatus.pending && _isWinner) {
      actions.add(_primaryButton(
        label: 'Record my payment',
        icon: Icons.receipt_long,
        onPressed: _recordPayment,
      ));
    }
    if (_transaction.status == TransactionStatus.paid && _isAuctioneer) {
      actions.add(_primaryButton(
        label: 'Confirm payment received',
        icon: Icons.check_circle,
        onPressed: () => _run(
          () => context
              .read<TransactionProvider>()
              .confirmPayment(_transaction.id, widget.currentUserId),
          'Payment confirmed. The sale is complete.',
        ),
      ));
    }
    if (_transaction.status == TransactionStatus.completed) {
      actions.add(_buildReviewButton());
    }
    if (_transaction.status == TransactionStatus.cancelled) {
      actions.add(_secondaryButton(
        label: 'Ask to reinstate this sale',
        icon: Icons.restart_alt,
        color: AppColors.green,
        onPressed: () => _propose(
          TransactionStatus.pending,
          'The $_otherPartyRole has been asked to reinstate the sale.',
        ),
      ));
    }
    if (_canProposeCancellation) {
      actions.add(_secondaryButton(
        label: 'Ask to cancel this sale',
        icon: Icons.cancel,
        color: AppColors.red,
        onPressed: () => _propose(
          TransactionStatus.cancelled,
          'The $_otherPartyRole has been asked to cancel the sale.',
        ),
      ));
    }

    return [
      for (final action in actions) ...[action, const SizedBox(height: 12)],
    ];
  }

  bool get _canProposeCancellation {
    if (_transaction.proposedStatus != null) return false;
    return _transaction.status == TransactionStatus.pending ||
        _transaction.status == TransactionStatus.paid;
  }

  Widget _primaryButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: _isBusy ? null : onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.green,
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
    );
  }

  Widget _secondaryButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: _isBusy ? null : onPressed,
      icon: Icon(icon, color: color),
      label: Text(label, style: TextStyle(color: color)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
    );
  }

  Widget _buildReviewButton() {
    if (_hasReviewed) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text('You reviewed this transaction.',
              style: TextStyle(color: AppColors.grey)),
        ),
      );
    }
    return _primaryButton(
      label: 'Leave Review',
      icon: Icons.star,
      onPressed: _leaveReview,
    );
  }

  Widget _detailRow(String label, String value) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: palette.hairline)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label.toUpperCase(),
              style: AppTheme.sectionLabel(palette.muted)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
        ],
      ),
    );
  }
}

/// What the member should expect next, in plain words.
class _StepNote extends StatelessWidget {
  final String text;

  const _StepNote({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.palette.surface,
        border: Border.all(color: context.palette.hairline),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: const TextStyle(height: 1.45)),
    );
  }
}

/// A change one party has put to the other, with the other party's answer.
class _ProposalNotice extends StatelessWidget {
  final String message;
  final String actionLabel;
  final VoidCallback? onAction;

  const _ProposalNotice({
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: context.palette.gold, width: 1.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(message, style: const TextStyle(height: 1.45)),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    );
  }
}

class _ReviewInput {
  final int rating;
  final String? comment;

  const _ReviewInput(this.rating, this.comment);
}

class _ReviewSheet extends StatefulWidget {
  const _ReviewSheet();

  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  int _rating = 5;
  final _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _submit() {
    final comment = _commentController.text.trim();
    Navigator.pop(
      context,
      _ReviewInput(_rating, comment.isNotEmpty ? comment : null),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Rate this transaction',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final value = index + 1;
              return IconButton(
                icon: Icon(
                  value <= _rating ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                  size: 36,
                ),
                onPressed: () => setState(() => _rating = value),
              );
            }),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _commentController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Comment (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _submit,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text('Submit Review'),
          ),
        ],
      ),
    );
  }
}
