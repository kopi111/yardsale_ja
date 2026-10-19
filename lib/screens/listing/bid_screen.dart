import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../core/palette.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/models/bid.dart';
import '../../data/models/listing.dart';
import '../../data/repositories/listing_repository.dart';
import '../../providers/listing_provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/catalogue_marks.dart';
import '../../widgets/listing_image_widget.dart';
import '../../widgets/live_countdown.dart';

/// The auction room. The lights go down here whatever the rest of the app is
/// set to: one number matters, and everything else gets out of its way.
class BidScreen extends StatefulWidget {
  final Listing listing;

  const BidScreen({super.key, required this.listing});

  @override
  State<BidScreen> createState() => _BidScreenState();
}

class _BidScreenState extends State<BidScreen> {
  static const List<double> _raiseSteps = [1000, 5000, 10000, 25000, 50000];
  static const AppPalette _room = AppPalette.night;

  final _bidController = TextEditingController();
  List<Bid> _activity = const [];
  double? _selectedStep;
  bool _isLoading = false;
  String? _error;

  double get _minimumBid {
    final currentBid = widget.listing.currentBid;
    return currentBid != null
        ? currentBid + AppBidding.minimumIncrement
        : widget.listing.startingBid;
  }

  /// A bid many times the standing price is far more often a slipped finger
  /// than an intention. Bids are binding, so this one is read back first.
  bool _isOutsized(double amount) =>
      amount >= _standingPrice * AppBidding.outsizedBidMultiple;

  double get _standingPrice =>
      widget.listing.currentBid ?? widget.listing.startingBid;

  double? get _enteredBid => AppUtils.readAmount(_bidController.text);

  /// How many separate people have raised their paddle on this lot.
  int get _bidderCount =>
      _activity.map((bid) => bid.bidderId).toSet().length;

  @override
  void initState() {
    super.initState();
    _bidController.addListener(_onBidChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadActivity());
  }

  @override
  void dispose() {
    _bidController.removeListener(_onBidChanged);
    _bidController.dispose();
    super.dispose();
  }

  Future<void> _loadActivity() async {
    final activity =
        await context.read<ListingProvider>().getBidHistory(widget.listing.id);
    if (!mounted) return;
    setState(() => _activity = activity);
  }

  void _onBidChanged() => setState(() {});

  void _raiseBy(double step) {
    setState(() => _selectedStep = step);
    _raiseTo(_standingPrice + step);
  }

  void _raiseTo(double amount) {
    _bidController.text = amount.round().toString();
    _bidController.selection =
        TextSelection.collapsed(offset: _bidController.text.length);
  }

  void _clearBid() {
    _bidController.clear();
    setState(() => _selectedStep = null);
  }

  Future<void> _placeBid() async {
    final bidAmount = _enteredBid;
    if (bidAmount == null) {
      setState(() => _error = 'Enter the amount you want to bid.');
      return;
    }
    if (bidAmount < _minimumBid) {
      setState(() => _error =
          'The lowest bid accepted is ${AppUtils.formatPrice(_minimumBid)}.');
      return;
    }
    if (bidAmount > AppBidding.maximumBid) {
      setState(() => _error =
          'The highest bid this house accepts is '
          '${AppUtils.formatPrice(AppBidding.maximumBid)}.');
      return;
    }
    if (widget.listing.isEnded) {
      setState(() => _error = 'This lot has already closed.');
      return;
    }
    if (_isOutsized(bidAmount) && !await _confirmOutsizedBid(bidAmount)) return;
    if (!mounted) return;

    final user = context.read<UserProvider>().currentUser;
    if (user == null) {
      setState(() => _error = 'You must be signed in to bid.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context
          .read<ListingProvider>()
          .placeBid(widget.listing.id, user.id, bidAmount);
    } on BidRejectedException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.reason;
      });
      return;
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'The bid could not be placed. Please try again.';
      });
      return;
    }

    if (!mounted) return;
    // The messenger is read before the pop so the confirmation still has a
    // scaffold to land in once this route is gone.
    navigator.pop(true);
    messenger.showSnackBar(
      SnackBar(
        content: Text('Bid placed at ${AppUtils.formatPrice(bidAmount)}'),
      ),
    );
  }

  /// Reads an outsized bid back to the bidder before it is sent, in the money
  /// they typed rather than the digits.
  Future<bool> _confirmOutsizedBid(double amount) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm this bid'),
        content: Text(
          'You are bidding ${AppUtils.formatPrice(amount)} on a lot standing '
          'at ${AppUtils.formatPrice(_standingPrice)}. Bids are binding.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('GO BACK'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('BID ${AppUtils.formatPrice(amount)}'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final listing = widget.listing;
    final bidAmount = _enteredBid;
    final canSubmit = bidAmount != null && bidAmount >= _minimumBid;

    return Theme(
      data: AppTheme.darkTheme,
      child: Scaffold(
        backgroundColor: _room.canvas,
        appBar: _RoomAppBar(),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _RoomStrip(bidderCount: _bidderCount, bidCount: listing.bidCount),
                const SizedBox(height: 16),
                _LotSummary(listing: listing),
                const SizedBox(height: 18),
                Divider(height: 1, thickness: 1, color: _room.hairline),
                const SizedBox(height: 18),
                _StandingsRow(listing: listing, minimumBid: _minimumBid),
                const SizedBox(height: 18),
                _RaisePanel(
                  steps: _raiseSteps,
                  standingPrice: _standingPrice,
                  selectedStep: _selectedStep,
                  onRaise: _raiseBy,
                ),
                const SizedBox(height: 20),
                Text(
                  'PLACE YOUR BID',
                  style: AppTheme.sectionLabel(_room.muted),
                ),
                const SizedBox(height: 10),
                _BidField(controller: _bidController, onClear: _clearBid),
                const SizedBox(height: 12),
                _MinimumLine(minimumBid: _minimumBid, isLive: !listing.isEnded),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  _ErrorNote(message: _error!),
                ],
                const SizedBox(height: 18),
                _SubmitButton(
                  label: canSubmit
                      ? 'SUBMIT BID ${AppUtils.formatPrice(bidAmount)}'
                      : 'ENTER A BID',
                  isLoading: _isLoading,
                  onPressed: _isLoading || !canSubmit ? null : _placeBid,
                ),
                const SizedBox(height: 14),
                const _BindingNotice(),
                const SizedBox(height: 24),
                _ActivityLedger(
                  bids: _activity,
                  viewerId: context.read<UserProvider>().currentUser?.id,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The room's own header: where you are, and what you can do about the lot
/// besides bid on it.
class _RoomAppBar extends StatelessWidget implements PreferredSizeWidget {
  static const AppPalette _room = AppPalette.night;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: _room.canvas,
      foregroundColor: _room.onSurface,
      toolbarHeight: 64,
      centerTitle: true,
      title: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('LIVE BIDDING', style: AppTheme.money(17, _room.onSurface)),
          const SizedBox(height: 3),
          Text(
            'YARDSALE JA AUCTION ROOM',
            style: AppTheme.sectionLabel(_room.gold),
          ),
        ],
      ),
    );
  }
}

/// Who else is in the room, counted from the bids actually on the book.
class _RoomStrip extends StatelessWidget {
  static const AppPalette _room = AppPalette.night;

  final int bidderCount;
  final int bidCount;

  const _RoomStrip({required this.bidderCount, required this.bidCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: _room.surface,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      ),
      child: Row(
        children: [
          const LivePill(),
          const SizedBox(width: 14),
          Icon(Icons.people_outline, size: 17, color: _room.muted),
          const SizedBox(width: 7),
          Text(
            AppUtils.countOf(bidderCount, 'bidder'),
            style: TextStyle(
              fontFamily: AppFonts.body,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _room.onSurface,
            ),
          ),
          const Spacer(),
          Icon(Icons.gavel_rounded, size: 16, color: _room.muted),
          const SizedBox(width: 7),
          Text(
            AppUtils.countOf(bidCount, 'bid'),
            style: TextStyle(
              fontFamily: AppFonts.body,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _room.muted,
            ),
          ),
        ],
      ),
    );
  }
}

/// The lot itself, small: enough to be sure you are bidding on the right thing.
class _LotSummary extends StatelessWidget {
  static const AppPalette _room = AppPalette.night;

  final Listing listing;

  const _LotSummary({required this.listing});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          child: SizedBox(
            width: 104,
            height: 104,
            child: ListingImageWidget(
              imagePaths: listing.imagePaths,
              category: listing.category,
              title: listing.title,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppTheme.markRadius),
                  border: Border.all(color: _room.gold),
                ),
                child: Text(
                  'LOT ${AppUtils.lotNumberFor(listing.id)}',
                  style: AppTheme.sectionLabel(_room.gold),
                ),
              ),
              const SizedBox(height: 9),
              Text(
                listing.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.money(21, _room.onSurface),
              ),
              const SizedBox(height: 3),
              Text(
                listing.parish,
                style: TextStyle(
                  fontFamily: AppFonts.body,
                  fontSize: 13,
                  color: _room.muted,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'STARTING BID',
                style: AppTheme.sectionLabel(_room.muted),
              ),
              const SizedBox(height: 4),
              Text(
                AppUtils.formatPrice(listing.startingBid),
                style: AppTheme.money(19, _room.money),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Where the lot stands right now, kept live while the paddle is open.
class _StandingsRow extends StatelessWidget {
  static const AppPalette _room = AppPalette.night;

  final Listing listing;
  final double minimumBid;

  const _StandingsRow({required this.listing, required this.minimumBid});

  @override
  Widget build(BuildContext context) {
    final currentBid = listing.currentBid;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentBid != null ? 'CURRENT BID' : 'STARTING BID',
                      style: AppTheme.sectionLabel(_room.muted),
                    ),
                    const SizedBox(height: 9),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        AppUtils.formatPrice(currentBid ?? listing.startingBid),
                        style: AppTheme.money(31, _room.money),
                      ),
                    ),
                  ],
                ),
              ),
              VerticalDivider(width: 29, thickness: 1, color: _room.hairline),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      listing.isEnded ? 'STATUS' : 'TIME LEFT',
                      style: AppTheme.sectionLabel(_room.muted),
                    ),
                    const SizedBox(height: 9),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: LiveCountdown(
                        endTime: listing.auctionEndTime,
                        size: 25,
                        onInk: true,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Ends ${AppUtils.formatDateTime(listing.auctionEndTime)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppFonts.body,
                        fontSize: 11,
                        color: _room.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Next minimum bid: ${AppUtils.formatPrice(minimumBid)}',
          style: TextStyle(
            fontFamily: AppFonts.body,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: _room.muted,
          ),
        ),
      ],
    );
  }
}

/// Preset raises above the standing price, so bidding is one tap in practice.
class _RaisePanel extends StatelessWidget {
  static const AppPalette _room = AppPalette.night;

  final List<double> steps;
  final double standingPrice;
  final double? selectedStep;
  final ValueChanged<double> onRaise;

  const _RaisePanel({
    required this.steps,
    required this.standingPrice,
    required this.selectedStep,
    required this.onRaise,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
      decoration: BoxDecoration(
        color: _room.surface,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('BID INCREMENTS', style: AppTheme.sectionLabel(_room.muted)),
          const SizedBox(height: 11),
          Row(
            children: [
              for (final step in steps)
                Expanded(
                  child: Padding(
                    padding:
                        EdgeInsets.only(right: step == steps.last ? 0 : 7),
                    child: _RaiseChip(
                      step: step,
                      resultingBid: standingPrice + step,
                      isSelected: selectedStep == step,
                      onTap: () => onRaise(step),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RaiseChip extends StatelessWidget {
  static const AppPalette _room = AppPalette.night;

  final double step;
  final double resultingBid;
  final bool isSelected;
  final VoidCallback onTap;

  const _RaiseChip({
    required this.step,
    required this.resultingBid,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected
          ? _room.amber.withValues(alpha: 0.22)
          : _room.raisedSurface,
      borderRadius: BorderRadius.circular(AppTheme.markRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.markRadius),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.markRadius),
            border: Border.all(
              color: isSelected ? _room.amber : Colors.transparent,
            ),
          ),
          child: Column(
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '+${AppUtils.formatPriceShort(step)}',
                  style: TextStyle(
                    fontFamily: AppFonts.body,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: isSelected ? _room.money : _room.onSurface,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  AppUtils.formatPrice(resultingBid),
                  style: TextStyle(
                    fontFamily: AppFonts.body,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    color: _room.muted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BidField extends StatelessWidget {
  static const AppPalette _room = AppPalette.night;

  final TextEditingController controller;
  final VoidCallback onClear;

  const _BidField({required this.controller, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: _room.surface,
        borderRadius: BorderRadius.circular(AppTheme.fieldRadius),
        border: Border.all(color: _room.amber),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              // A minus sign is allowed through so the bidder sees what they
              // typed and the bid is refused. Swallowing it showed a positive
              // number back and offered to bind them to it.
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[-0-9.]')),
              ],
              style: AppTheme.money(30, _room.money),
              cursorColor: _room.live,
              decoration: InputDecoration(
                filled: false,
                prefixText: r'J$',
                prefixStyle: AppTheme.money(30, _room.money),
                hintText: '0',
                hintStyle: AppTheme.money(30, _room.hairline),
                contentPadding: const EdgeInsets.symmetric(vertical: 18),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ),
          IconButton(
            onPressed: onClear,
            icon: Icon(Icons.cancel_outlined, size: 21, color: _room.muted),
          ),
        ],
      ),
    );
  }
}

class _MinimumLine extends StatelessWidget {
  static const AppPalette _room = AppPalette.night;

  final double minimumBid;
  final bool isLive;

  const _MinimumLine({required this.minimumBid, required this.isLive});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.verified_user_outlined, size: 15, color: _room.positive),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            'Minimum bid: ${AppUtils.formatPrice(minimumBid)}',
            style: TextStyle(
              fontFamily: AppFonts.body,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: _room.muted,
            ),
          ),
        ),
        if (isLive) LiveMark(label: 'LIVE', color: _room.positive),
      ],
    );
  }
}

class _SubmitButton extends StatelessWidget {
  static const AppPalette _room = AppPalette.night;

  final String label;
  final bool isLoading;
  final VoidCallback? onPressed;

  const _SubmitButton({
    required this.label,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _room.amber,
          foregroundColor: _room.onAmber,
          disabledBackgroundColor: _room.raisedSurface,
          disabledForegroundColor: _room.muted,
          padding: const EdgeInsets.symmetric(vertical: 19),
        ),
        child: isLoading
            ? SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _room.onAmber,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.gavel_rounded, size: 18),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _BindingNotice extends StatelessWidget {
  static const AppPalette _room = AppPalette.night;

  const _BindingNotice();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.lock_outline_rounded, size: 15, color: _room.muted),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            'Bids are binding and cannot be withdrawn. If your bid is the '
            'highest when the timer hits zero, you win.',
            style: TextStyle(
              fontFamily: AppFonts.body,
              fontSize: 12.5,
              height: 1.45,
              color: _room.muted,
            ),
          ),
        ),
      ],
    );
  }
}

/// The book: every raise on this lot, newest first, with the standing bid
/// called out so a bidder can see at a glance whether they are still leading.
class _ActivityLedger extends StatelessWidget {
  static const AppPalette _room = AppPalette.night;
  static const int _visibleRows = 6;

  final List<Bid> bids;
  final String? viewerId;

  const _ActivityLedger({required this.bids, required this.viewerId});

  @override
  Widget build(BuildContext context) {
    final shown = bids.take(_visibleRows).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'AUCTION ACTIVITY',
                style: AppTheme.sectionLabel(_room.muted),
              ),
            ),
            if (bids.length > _visibleRows)
              Text(
                '+ ${bids.length - _visibleRows} earlier',
                style: TextStyle(
                  fontFamily: AppFonts.body,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _room.muted,
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (shown.isEmpty)
          Text(
            'No bids on this lot yet. Yours would open it.',
            style: TextStyle(
              fontFamily: AppFonts.body,
              fontSize: 13,
              color: _room.muted,
            ),
          )
        else
          for (var i = 0; i < shown.length; i++)
            _ActivityRow(
              bid: shown[i],
              isLeader: i == 0,
              isViewer: shown[i].bidderId == viewerId,
            ),
      ],
    );
  }
}

class _ActivityRow extends StatelessWidget {
  static const AppPalette _room = AppPalette.night;

  final Bid bid;
  final bool isLeader;
  final bool isViewer;

  const _ActivityRow({
    required this.bid,
    required this.isLeader,
    required this.isViewer,
  });

  @override
  Widget build(BuildContext context) {
    final highlight = isLeader && isViewer;

    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: highlight
            ? _room.amber.withValues(alpha: 0.16)
            : _room.surface,
        borderRadius: BorderRadius.circular(AppTheme.markRadius),
      ),
      child: Row(
        children: [
          Text(
            isViewer ? 'You' : (bid.bidderName ?? 'Bidder'),
            style: TextStyle(
              fontFamily: AppFonts.body,
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: _room.onSurface,
            ),
          ),
          if (isLeader) ...[
            const SizedBox(width: 9),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: _room.amber.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(AppTheme.markRadius),
              ),
              child: Text(
                'TOP BID',
                style: AppTheme.sectionLabel(_room.money),
              ),
            ),
          ],
          const Spacer(),
          Text(
            AppUtils.formatPrice(bid.amount),
            style: AppTheme.money(
              15,
              isLeader ? _room.money : _room.onSurface,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            AppUtils.formatClockTime(bid.createdAt),
            style: TextStyle(
              fontFamily: AppFonts.body,
              fontSize: 11.5,
              color: _room.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorNote extends StatelessWidget {
  static const AppPalette _room = AppPalette.night;

  final String message;

  const _ErrorNote({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: _room.live),
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: _room.live, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontFamily: AppFonts.body,
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: _room.live,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
