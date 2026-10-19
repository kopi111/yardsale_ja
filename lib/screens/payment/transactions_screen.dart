import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../core/palette.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/models/transaction.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/catalogue_marks.dart';
import 'transaction_detail_screen.dart';

/// The member's settlement book: every lot they have won or sold, and where
/// each one has got to.
class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  String? _error;

  @override
  void initState() {
    super.initState();
    // Notifying listeners while the first frame is still building throws;
    // defer the load until the frame is on screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _load();
    });
  }

  Future<void> _load() async {
    try {
      setState(() => _error = null);
      final userId = context.read<UserProvider>().currentUser?.id;
      if (userId != null) {
        await context.read<TransactionProvider>().loadTransactions(userId);
      }
    } catch (e) {
      setState(() => _error = 'Failed to load settlements. Pull to retry.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.palette.canvas,
      appBar: AppBar(title: const Text(AppStrings.settlements)),
      body: _error != null ? _retry() : _book(),
    );
  }

  Widget _book() {
    return Consumer<TransactionProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (provider.transactions.isEmpty) return _emptyBook();
        return RefreshIndicator(
          onRefresh: _load,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            itemCount: provider.transactions.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final settlement = provider.transactions[index];
              return _SettlementEntry(
                settlement: settlement,
                onTap: () => _openDetail(settlement),
              );
            },
          ),
        );
      },
    );
  }

  Widget _emptyBook() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 90, 20, 20),
      children: [
        Icon(Icons.receipt_long_outlined,
            size: 54, color: context.palette.muted),
        const SizedBox(height: 18),
        Text(
          AppStrings.noSettlements,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 6),
        Text(
          'Lots you win or sell settle here.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _retry() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 90, 20, 20),
      children: [
        Icon(Icons.error_outline, size: 54, color: context.palette.muted),
        const SizedBox(height: 18),
        Text(
          _error!,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 18),
        Center(
          child: OutlinedButton(onPressed: _load, child: const Text('RETRY')),
        ),
      ],
    );
  }

  Future<void> _openDetail(Transaction transaction) async {
    final currentUserId = context.read<UserProvider>().currentUser?.id;
    if (currentUserId == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TransactionDetailScreen(
          transaction: transaction,
          currentUserId: currentUserId,
        ),
      ),
    );
    if (mounted) _load();
  }
}

/// One line of the settlement book, ruled the way a saleroom rules an invoice.
class _SettlementEntry extends StatelessWidget {
  final Transaction settlement;
  final VoidCallback onTap;

  const _SettlementEntry({required this.settlement, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return InkWell(
      onTap: onTap,
      child: RuledPanel(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    SettlementStanding.labelFor(settlement.status),
                    style: AppTheme.sectionLabel(
                      SettlementStanding.colourFor(settlement.status, palette),
                    ),
                  ),
                ),
                Text(
                  AppUtils.formatDate(settlement.createdAt).toUpperCase(),
                  style: AppTheme.sectionLabel(palette.muted),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              settlement.listingTitle ?? 'Lot',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              [
                settlement.paymentMethod,
                if ((settlement.otherUserName ?? '').isNotEmpty)
                  settlement.otherUserName!,
              ].join(' · '),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Text(
              AppUtils.formatPrice(settlement.winningBid),
              style: AppTheme.money(24, palette.onSurface),
            ),
          ],
        ),
      ),
    );
  }
}

/// How a settlement's standing is named and coloured, in one place, so the
/// book and the settlement itself can never describe it differently.
class SettlementStanding {
  /// 'paid' on its own reads as finished. It is not: the seller still has to
  /// confirm the money arrived.
  static String labelFor(String status) {
    switch (status) {
      case TransactionStatus.pending:
        return 'AWAITING PAYMENT';
      case TransactionStatus.paid:
        return 'PAYMENT RECORDED';
      case TransactionStatus.completed:
        return 'SETTLED IN FULL';
      case TransactionStatus.cancelled:
        return 'CANCELLED';
      default:
        return status.toUpperCase();
    }
  }

  static Color colourFor(String status, AppPalette palette) {
    switch (status) {
      case TransactionStatus.completed:
        return AppColors.green;
      case TransactionStatus.cancelled:
        return palette.live;
      case TransactionStatus.paid:
        return palette.gold;
      default:
        return palette.muted;
    }
  }
}
