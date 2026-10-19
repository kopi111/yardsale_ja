import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../core/palette.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/models/listing.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/catalogue_marks.dart';
import '../../widgets/listing_image_widget.dart';

/// The settlement note: what was won, at what price, and how it gets paid for.
class PaymentScreen extends StatefulWidget {
  final Listing listing;

  const PaymentScreen({super.key, required this.listing});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  static const String _cashOnPickup = 'Cash on Pickup';

  String _selectedMethod = AppPaymentMethods.methods[0];
  final _refController = TextEditingController();
  bool _isLoading = false;

  double get _winningBid =>
      widget.listing.currentBid ?? widget.listing.startingBid;

  @override
  void dispose() {
    _refController.dispose();
    super.dispose();
  }

  Future<void> _processPayment() async {
    final user = context.read<UserProvider>().currentUser;
    if (user == null) {
      _showError('You must be signed in to settle a lot.');
      return;
    }

    setState(() => _isLoading = true);
    final reference = _refController.text.trim();
    try {
      await context.read<TransactionProvider>().recordPayment(
            listingId: widget.listing.id,
            winnerId: user.id,
            auctioneerId: widget.listing.userId,
            winningBid: _winningBid,
            paymentMethod: _selectedMethod,
            referenceNumber: reference.isNotEmpty ? reference : null,
          );
    } on TransactionActionRejectedException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError(e.reason);
      return;
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError('Could not record the settlement. Please retry.');
      return;
    }

    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Payment recorded — the seller has been asked to '
            'confirm it'),
        backgroundColor: AppColors.ink,
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.palette.canvas,
      appBar: AppBar(title: const Text('SETTLEMENT')),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildNote(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 26, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'HOW YOU WILL SETTLE',
                    style: AppTheme.sectionLabel(AppColors.grey),
                  ),
                  const SizedBox(height: 12),
                  for (final method in AppPaymentMethods.methods)
                    _MethodRow(
                      method: method,
                      description: _describe(method),
                      isSelected: _selectedMethod == method,
                      onSelect: () =>
                          setState(() => _selectedMethod = method),
                    ),
                  if (_selectedMethod != _cashOnPickup) ...[
                    const SizedBox(height: 22),
                    TextField(
                      controller: _refController,
                      decoration: const InputDecoration(
                        labelText: 'Reference number (optional)',
                        hintText: 'e.g. the transfer reference',
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _processPayment,
                    child: _isLoading
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.paper,
                            ),
                          )
                        : const Text('I HAVE PAID — RECORD IT'),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'No money moves through YardSale JA. You pay the seller '
                    'directly; this records how you paid, and the seller '
                    'confirms it before the sale is marked complete.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The ink note at the head of the page: the lot, and what it went for.
  Widget _buildNote() {
    final listing = widget.listing;
    return Container(
      color: AppColors.ink,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 62,
                height: 62,
                child: ListingImageWidget(
                  imagePaths: listing.imagePaths,
                  category: listing.category,
                  title: listing.title,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LotMark(
                      lotNumber: AppUtils.lotNumberFor(listing.id),
                      onInk: true,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      listing.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: AppFonts.body,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.paper,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'CONSIGNED BY '
                      '${(listing.auctioneerName ?? 'AUCTIONEER').toUpperCase()}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.sectionLabel(AppColors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(height: 1, color: const Color(0xFF2B2721)),
          const SizedBox(height: 16),
          Text('HAMMER PRICE', style: AppTheme.sectionLabel(AppColors.grey)),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              AppUtils.formatPrice(_winningBid),
              style: AppTheme.money(38, AppColors.goldBright),
            ),
          ),
        ],
      ),
    );
  }

  String _describe(String method) {
    switch (method) {
      case _cashOnPickup:
        return 'Pay cash when you collect the lot.';
      case 'Bank Transfer':
        return "Transfer to the seller's bank account.";
      case 'Lynk':
        return 'Pay by Lynk mobile money.';
      default:
        return '';
    }
  }
}

/// A settlement method, marked the way a catalogue marks a chosen line.
class _MethodRow extends StatelessWidget {
  final String method;
  final String description;
  final bool isSelected;
  final VoidCallback onSelect;

  const _MethodRow({
    required this.method,
    required this.description,
    required this.isSelected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: isSelected ? context.palette.surface : Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        child: InkWell(
          onTap: onSelect,
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            decoration: BoxDecoration(
              border: Border.all(
                color: isSelected
                    ? context.palette.onSurface
                    : context.palette.hairline,
                width: isSelected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(AppTheme.cardRadius),
            ),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 32,
                  color: isSelected
                      ? context.palette.gold
                      : Colors.transparent,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        method.toUpperCase(),
                        style: AppTheme.sectionLabel(
                          isSelected
                              ? context.palette.onSurface
                              : context.palette.muted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Icon(Icons.check,
                      size: 18, color: context.palette.onSurface),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
