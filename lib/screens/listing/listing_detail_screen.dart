import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// ignore: deprecated_member_use
import 'package:share_plus/share_plus.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../core/constants.dart';
import '../../core/palette.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/models/listing.dart';
import '../../data/models/bid.dart';
import '../../data/models/transaction.dart';
import '../../data/repositories/transaction_repository.dart'
    show TransactionStatus;
import '../../data/repositories/listing_repository.dart'
    show ListingCancellationRejectedException;
import '../../providers/transaction_provider.dart';
import '../../providers/listing_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/message_provider.dart';
import '../chat/chat_screen.dart';
import '../profile/user_profile_screen.dart';
import '../payment/payment_screen.dart';
import '../payment/transaction_detail_screen.dart';
import '../../widgets/catalogue_marks.dart';
import '../../widgets/listing_image_widget.dart';
import '../../widgets/live_countdown.dart';
import 'create_listing_screen.dart';
import 'bid_screen.dart';

class ListingDetailScreen extends StatefulWidget {
  final String listingId;

  const ListingDetailScreen({super.key, required this.listingId});

  @override
  State<ListingDetailScreen> createState() => _ListingDetailScreenState();
}

class _ListingDetailScreenState extends State<ListingDetailScreen> {
  Listing? _listing;
  List<Bid> _bids = [];
  bool _isLoading = true;
  bool _isFavorited = false;
  int _currentImageIndex = 0;
  String? _error;
  Timer? _clock;
  bool _hasReloadedOnClose = false;
  Transaction? _settlement;

  @override
  void initState() {
    super.initState();
    _loadListing();
    // The screen shows a live countdown, so it has to keep its own time. The
    // moment the clock passes the close time the listing is reloaded once, so
    // settlement runs and the winner bar can appear without leaving the page.
    _clock = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  void _onTick() {
    if (!mounted) return;
    final listing = _listing;
    if (listing != null && listing.isEnded && !_hasReloadedOnClose) {
      _hasReloadedOnClose = true;
      _loadListing();
      return;
    }
    setState(() {});
  }

  Future<void> _loadListing() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final provider = context.read<ListingProvider>();
      final userId = context.read<UserProvider>().currentUser?.id;
      final listing = await provider.getListingById(widget.listingId);
      if (listing == null) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        return;
      }
      final isFavorited =
          userId != null ? await provider.isFavorited(userId, listing.id) : false;
      final bids = await provider.getBidHistory(listing.id);
      final settlement = await _settlementFor(listing);
      if (!mounted) return;
      setState(() {
        _listing = listing;
        _bids = bids;
        _isFavorited = isFavorited;
        _settlement = settlement;
        _isLoading = false;
        _hasReloadedOnClose = listing.isEnded;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load auction';
        _isLoading = false;
      });
    }
  }

  /// A closed lot with a winner has a settlement behind it. Both the buyer
  /// and the seller need to reach it from the lot itself.
  Future<Transaction?> _settlementFor(Listing listing) async {
    if (!listing.isEnded || listing.bidCount == 0) return null;
    final transactionId = await context
        .read<ListingProvider>()
        .settleAndGetTransactionId(listing.id);
    if (transactionId == null || !mounted) return null;
    final viewerId = context.read<UserProvider>().currentUser?.id;
    return context.read<TransactionProvider>().getTransactionById(
          transactionId,
          viewerId: viewerId,
        );
  }

  Future<void> _openSettlement() async {
    final settlement = _settlement;
    final userId = context.read<UserProvider>().currentUser?.id;
    if (settlement == null || userId == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TransactionDetailScreen(
          transaction: settlement,
          currentUserId: userId,
        ),
      ),
    );
    if (mounted) _loadListing();
  }

  Future<void> _messageSeller() async {
    final user = context.read<UserProvider>().currentUser;
    final listing = _listing;
    if (user == null || listing == null) return;

    final conversation =
        await context.read<MessageProvider>().getOrCreateConversation(
              listingId: listing.id,
              buyerId: user.id,
              sellerId: listing.userId,
            );
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          conversationId: conversation.id,
          listingId: listing.id,
          otherUserName: listing.auctioneerName ?? 'Auctioneer',
          otherUserId: listing.userId,
          listingTitle: listing.title,
        ),
      ),
    );
  }

  Future<void> _toggleFavorite() async {
    final userId = context.read<UserProvider>().currentUser?.id;
    final listing = _listing;
    if (userId == null || listing == null) return;

    await context.read<ListingProvider>().toggleFavorite(userId, listing.id);
    if (!mounted) return;
    setState(() => _isFavorited = !_isFavorited);
    _announce(_isFavorited ? 'Saved to your list' : 'Removed from your list');
  }

  void _shareListing() {
    final listing = _listing;
    if (listing == null) return;
    final currentBid = listing.currentBid;
    final text = 'LOT ${AppUtils.lotNumberFor(listing.id)} — ${listing.title}\n'
        '${currentBid != null ? 'Current bid' : 'Starting bid'}: '
        '${AppUtils.formatPrice(currentBid ?? listing.startingBid)}\n'
        '${listing.condition} · ${listing.parish}\n\n'
        '${listing.description}\n\n'
        'On YardSale JA — ${AppStrings.tagline}';
    Share.share(text);
  }

  void _announce(String message, {Color background = AppColors.ink}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: background),
    );
  }

  Future<void> _openEditor() async {
    final listing = _listing;
    if (listing == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CreateListingScreen(listing: listing)),
    );
    if (mounted) _loadListing();
  }

  void _confirmCancel() {
    final listing = _listing!;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Withdraw this lot?'),
        content: Text(
          '"${listing.title}" will be taken off the floor. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('KEEP IT LISTED'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _cancelListing();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
            child: const Text('WITHDRAW'),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelListing() async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<ListingProvider>().deleteListing(_listing!.id);
    } on ListingCancellationRejectedException catch (e) {
      if (!mounted) return;
      _announce(e.reason, background: AppColors.red);
      return;
    }
    if (!mounted) return;
    navigator.pop();
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Lot withdrawn'),
        backgroundColor: AppColors.ink,
      ),
    );
  }

  void _confirmEndAuction() {
    final listing = _listing!;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Bring down the hammer?'),
        content: Text(
          '"${listing.title}" closes immediately and the highest bidder wins. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('KEEP RUNNING'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _endAuction();
            },
            child: const Text('CLOSE THE LOT'),
          ),
        ],
      ),
    );
  }

  Future<void> _endAuction() async {
    await context.read<ListingProvider>().endAuction(_listing!.id);
    if (!mounted) return;
    _announce('Lot closed');
    _loadListing();
  }

  Future<void> _payNow() async {
    final listing = _listing!;
    final transactionId =
        await context.read<ListingProvider>().settleAndGetTransactionId(listing.id);
    if (!mounted) return;
    if (transactionId == null) {
      // Settlement is what names the winner. Without it there is nothing to
      // pay against, and letting payment proceed would invent a record.
      _announce(
        'This lot has not been settled yet. Pull to refresh and try again.',
        background: AppColors.red,
      );
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PaymentScreen(listing: listing)),
    );
    if (mounted) _loadListing();
  }

  Future<void> _openBidScreen() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => BidScreen(listing: _listing!)),
    );
    if (result == true && mounted) _loadListing();
  }

  bool get _isWinner {
    final listing = _listing;
    if (listing == null || !listing.isEnded) return false;
    final userId = context.read<UserProvider>().currentUser?.id;
    return userId != null &&
        listing.highestBidderId == userId &&
        listing.bidCount > 0;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: palette.canvas,
        body: Center(child: CircularProgressIndicator(color: palette.amber)),
      );
    }
    if (_error != null) return _messageScaffold(_error!, showRetry: true);
    if (_listing == null) return _messageScaffold('Lot not found');

    final listing = _listing!;
    final isOwner =
        listing.userId == context.read<UserProvider>().currentUser?.id;

    return Scaffold(
      backgroundColor: palette.canvas,
      appBar: _buildAppBar(listing, isOwner),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildPlate(listing)),
          SliverToBoxAdapter(child: _MoneyPanel(listing: listing)),
          SliverToBoxAdapter(child: _buildCatalogueEntry(listing)),
        ],
      ),
      bottomNavigationBar: _buildActionBar(listing, isOwner),
    );
  }

  Scaffold _messageScaffold(String message, {bool showRetry = false}) {
    return Scaffold(
      backgroundColor: context.palette.canvas,
      appBar: AppBar(),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, style: Theme.of(context).textTheme.headlineSmall),
            if (showRetry) ...[
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: _loadListing,
                child: const Text('TRY AGAIN'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(Listing listing, bool isOwner) {
    final palette = context.palette;

    return AppBar(
      backgroundColor: palette.canvas,
      foregroundColor: palette.onSurface,
      actions: [
        IconButton(
          icon: const Icon(Icons.ios_share, size: 22),
          onPressed: _shareListing,
        ),
        IconButton(
          icon: Icon(
            _isFavorited ? Icons.bookmark : Icons.bookmark_border,
            size: 22,
            color: _isFavorited ? palette.gold : palette.onSurface,
          ),
          onPressed: _toggleFavorite,
        ),
        if (isOwner) _buildOwnerMenu(listing),
      ],
    );
  }

  Widget _buildPlate(Listing listing) {
    return SizedBox(
      height: 300,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _buildImages(listing),
          Positioned(
            top: 14,
            left: 16,
            child: LotBadge(lotNumber: AppUtils.lotNumberFor(listing.id)),
          ),
          if (!listing.isEnded)
            const Positioned(top: 14, right: 16, child: LivePill()),
          if (listing.imagePaths.length > 1)
            Positioned(
              bottom: 14,
              right: 16,
              child: GalleryCounter(
                position: _currentImageIndex + 1,
                total: listing.imagePaths.length,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOwnerMenu(Listing listing) {
    final isEnded = listing.isEnded;
    final hasBids = listing.bidCount > 0;
    return PopupMenuButton<String>(
      onSelected: (value) {
        if (value == 'edit') _openEditor();
        if (value == 'end') _confirmEndAuction();
        if (value == 'cancel') _confirmCancel();
      },
      itemBuilder: (_) => [
        if (!isEnded)
          const PopupMenuItem(value: 'edit', child: Text('Edit lot')),
        if (!isEnded)
          const PopupMenuItem(value: 'end', child: Text('Close the lot now')),
        // A lot with bids on it has been promised to someone; withdrawing it
        // after the fact would leave the bidder holding a settled transaction.
        if (!isEnded && !hasBids)
          const PopupMenuItem(
            value: 'cancel',
            child: Text('Withdraw lot', style: TextStyle(color: AppColors.red)),
          ),
      ],
    );
  }

  static const double _photoHeight = 300;

  Widget _buildImages(Listing listing) {
    if (listing.imagePaths.isEmpty) {
      return SizedBox(height: _photoHeight, child: _categoryPlate(listing));
    }
    if (listing.imagePaths.length == 1) return _photo(listing, 0);
    return SizedBox(
      height: _photoHeight,
      child: PageView.builder(
        itemCount: listing.imagePaths.length,
        onPageChanged: (index) => setState(() => _currentImageIndex = index),
        itemBuilder: (_, index) => _photo(listing, index),
      ),
    );
  }

  /// The same widget every other lot picture in the app is drawn with.
  Widget _photo(Listing listing, int index) => ListingImageWidget(
        imagePaths: [listing.imagePaths[index]],
        category: listing.category,
        title: listing.title,
      );

  Widget _categoryPlate(Listing listing) => ListingImageWidget(
        imagePaths: const [],
        category: listing.category,
        title: listing.title,
      );

  Widget _buildCatalogueEntry(Listing listing) {
    final palette = context.palette;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  listing.title,
                  style: Theme.of(context).textTheme.displaySmall,
                ),
              ),
              const SizedBox(width: 12),
              _FavoriteButton(
                isFavorited: _isFavorited,
                onPressed: _toggleFavorite,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${AppCategories.labelFor(listing.category)} · '
            '${listing.condition} · ${listing.parish}',
            style: TextStyle(
              fontFamily: AppFonts.body,
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: palette.gold,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Consigned ${timeago.format(listing.createdAt)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          _EntrySection(
            label: 'DESCRIPTION',
            child: Text(
              listing.description,
              style: const TextStyle(fontSize: 15, height: 1.55),
            ),
          ),
          const SizedBox(height: 24),
          _TrustStrip(listing: listing),
          _EntrySection(
            label: 'CONSIGNED BY',
            child: _SellerRow(
              listing: listing,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => UserProfileScreen(userId: listing.userId),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          const _BuyerProtectionPanel(),
          if (_bids.isNotEmpty)
            _EntrySection(
              label: 'BIDDING HISTORY',
              child: _BidLedger(bids: _bids),
            ),
        ],
      ),
    );
  }

  /// What the winner is asked to do next, read off the settlement rather than
  /// assumed. Offering "SETTLE UP" to a buyer who has already paid sent them
  /// back into a blank payment form that overwrote what they had recorded.
  Widget _winnersActionBar() {
    switch (_settlement?.status) {
      case TransactionStatus.paid:
        return _ActionBar(
          note: 'PAYMENT RECORDED',
          primaryLabel: 'VIEW SETTLEMENT',
          onPrimary: _openSettlement,
        );
      case TransactionStatus.completed:
        return _ActionBar(
          note: 'SETTLED IN FULL',
          primaryLabel: 'VIEW SETTLEMENT',
          onPrimary: _openSettlement,
        );
      case TransactionStatus.cancelled:
        return _ActionBar(
          note: 'SALE CANCELLED',
          primaryLabel: 'VIEW SETTLEMENT',
          onPrimary: _openSettlement,
        );
      default:
        return _ActionBar(
          note: 'THE LOT IS YOURS',
          primaryLabel: 'SETTLE UP',
          onPrimary: _payNow,
        );
    }
  }

  Widget? _buildActionBar(Listing listing, bool isOwner) {
    if (_isWinner) return _winnersActionBar();
    // A seller whose lot has just sold was shown nothing at all: no winner,
    // no money, no next step. The hammer falling is the moment they most
    // need the settlement.
    if (isOwner && listing.isEnded) {
      if (_settlement == null) {
        return _ActionBar(
          note: listing.bidCount > 0 ? 'SETTLING…' : 'CLOSED · NO BIDS',
          primaryLabel: 'REFRESH',
          onPrimary: _loadListing,
        );
      }
      final winner = listing.highestBidderName ?? 'the winning bidder';
      return _ActionBar(
        note: 'SOLD TO ${winner.toUpperCase()}',
        primaryLabel: 'VIEW SETTLEMENT',
        onPrimary: _openSettlement,
      );
    }
    if (listing.isEnded) return null;
    if (isOwner) {
      return _ActionBar(
        secondaryLabel: 'EDIT',
        onSecondary: listing.bidCount > 0 ? null : _openEditor,
        primaryLabel: 'CLOSE THE LOT',
        onPrimary: _confirmEndAuction,
      );
    }
    return _ActionBar(
      secondaryLabel: 'MESSAGE SELLER',
      secondaryIcon: Icons.chat_bubble_outline_rounded,
      onSecondary: _messageSeller,
      primaryLabel: 'PLACE BID '
          '${AppUtils.formatPrice(listing.currentBid ?? listing.startingBid)}',
      onPrimary: _openBidScreen,
    );
  }
}

/// The ink panel that carries the money — the one thing a bidder came for.
class _MoneyPanel extends StatelessWidget {
  final Listing listing;

  const _MoneyPanel({required this.listing});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final currentBid = listing.currentBid;
    final isEnded = listing.isEnded;

    return Container(
      width: double.infinity,
      color: palette.panel,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Column(
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
                        currentBid != null
                            ? (isEnded ? 'HAMMER PRICE' : 'CURRENT BID')
                            : 'STARTING BID',
                        style: AppTheme.sectionLabel(palette.panelMuted),
                      ),
                      const SizedBox(height: 9),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          AppUtils.formatPrice(
                            currentBid ?? listing.startingBid,
                          ),
                          style: AppTheme.money(34, palette.money),
                        ),
                      ),
                    ],
                  ),
                ),
                VerticalDivider(
                  width: 33,
                  thickness: 1,
                  color: palette.panelHairline,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEnded ? 'STATUS' : 'CLOSES IN',
                        style: AppTheme.sectionLabel(palette.panelMuted),
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
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Divider(height: 1, thickness: 1, color: palette.panelHairline),
          const SizedBox(height: 13),
          Row(
            children: [
              Icon(Icons.gavel_rounded, size: 14, color: palette.money),
              const SizedBox(width: 7),
              Text(
                AppUtils.countOf(listing.bidCount, 'bid').toUpperCase(),
                style: AppTheme.sectionLabel(palette.onPanel),
              ),
              const Spacer(),
              Text(
                'Min. bid increment '
                '${AppUtils.formatPrice(AppBidding.minimumIncrement)}',
                style: TextStyle(
                  fontFamily: AppFonts.body,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: palette.panelMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A labelled block in the catalogue entry, ruled off above.
class _EntrySection extends StatelessWidget {
  final String label;
  final Widget child;

  const _EntrySection({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(height: 1, thickness: 1, color: palette.hairline),
          const SizedBox(height: 16),
          Text(label, style: AppTheme.sectionLabel(palette.muted)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

/// The bookmark, sized to be tapped rather than aimed at.
class _FavoriteButton extends StatelessWidget {
  final bool isFavorited;
  final VoidCallback onPressed;

  const _FavoriteButton({required this.isFavorited, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Material(
      color: palette.surface,
      shape: CircleBorder(side: BorderSide(color: palette.hairline)),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 46,
          height: 46,
          child: Icon(
            isFavorited ? Icons.favorite : Icons.favorite_border,
            size: 21,
            color: isFavorited ? palette.live : palette.onSurface,
          ),
        ),
      ),
    );
  }
}

/// The four facts a bidder checks before they raise their paddle. Every
/// one of them is read from the lot — the strip never vouches for anything
/// the app has not actually checked.
class _TrustStrip extends StatelessWidget {
  final Listing listing;

  const _TrustStrip({required this.listing});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        border: Border.symmetric(
          horizontal: BorderSide(color: palette.hairline),
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            const _AssuranceColumn(
              icon: Icons.handshake_outlined,
              title: 'Settlement',
              detail: 'Direct to seller',
            ),
            _AssuranceRule(),
            _AssuranceColumn(
              icon: Icons.schedule_rounded,
              title: 'Consigned',
              detail: timeago.format(listing.createdAt),
            ),
            _AssuranceRule(),
            _AssuranceColumn(
              icon: Icons.place_outlined,
              title: 'Location',
              detail: listing.parish,
            ),
            _AssuranceRule(),
            const _AssuranceColumn(
              icon: Icons.inventory_2_outlined,
              title: 'Pickup',
              detail: 'Local pickup only',
            ),
          ],
        ),
      ),
    );
  }
}

class _AssuranceColumn extends StatelessWidget {
  final IconData icon;
  final String title;
  final String detail;

  const _AssuranceColumn({
    required this.icon,
    required this.title,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: palette.onSurface),
          const SizedBox(height: 9),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppFonts.body,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: palette.onSurface,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            detail,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: AppFonts.body,
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
              height: 1.3,
              color: palette.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _AssuranceRule extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return VerticalDivider(
      width: 1,
      thickness: 1,
      color: context.palette.hairline,
    );
  }
}

/// The house standing behind the sale, said plainly.
class _BuyerProtectionPanel extends StatelessWidget {
  const _BuyerProtectionPanel();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return RuledPanel(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, size: 21, color: palette.gold),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'How settlement works',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 3),
                Text(
                  'You pay the seller directly — no money moves through '
                  'YardSale JA. Record the payment here so you and the seller '
                  'hold the same record of it.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SellerRow extends StatelessWidget {
  final Listing listing;
  final VoidCallback onTap;

  const _SellerRow({required this.listing, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final name = listing.auctioneerName ?? 'Auctioneer';

    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          MemberInitials(name: name, diameter: 46),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  [
                    if ((listing.auctioneerParish ?? '').isNotEmpty)
                      listing.auctioneerParish!,
                    'Member since ${AppUtils.formatYear(listing.createdAt)}',
                  ].join(' · '),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: palette.muted),
        ],
      ),
    );
  }
}

/// The bidding history, read as a ledger: newest at the top, leader in gold.
class _BidLedger extends StatelessWidget {
  static const int _visibleRows = 5;

  final List<Bid> bids;

  const _BidLedger({required this.bids});

  @override
  Widget build(BuildContext context) {
    final shown = bids.take(_visibleRows).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < shown.length; i++) _row(context, shown[i], i == 0),
        if (bids.length > _visibleRows)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              '+ ${bids.length - _visibleRows} EARLIER BIDS',
              style: AppTheme.sectionLabel(context.palette.muted),
            ),
          ),
      ],
    );
  }

  Widget _row(BuildContext context, Bid bid, bool isLeader) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: palette.hairline)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bid.bidderName ?? 'Bidder',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  AppUtils.formatDateTime(bid.createdAt),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
          Text(
            AppUtils.formatPrice(bid.amount),
            style: AppTheme.money(
              16,
              isLeader ? palette.gold : palette.muted,
            ),
          ),
        ],
      ),
    );
  }
}

/// The bar pinned to the foot of the lot: what you can do about it.
class _ActionBar extends StatelessWidget {
  final String? note;
  final String? secondaryLabel;
  final IconData? secondaryIcon;
  final VoidCallback? onSecondary;
  final String primaryLabel;
  final VoidCallback onPrimary;

  const _ActionBar({
    this.note,
    this.secondaryLabel,
    this.secondaryIcon,
    this.onSecondary,
    required this.primaryLabel,
    required this.onPrimary,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      decoration: BoxDecoration(
        color: palette.panel,
        border: Border(top: BorderSide(color: palette.panelHairline)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              if (note != null)
                Expanded(
                  flex: 4,
                  child: Text(
                    note!,
                    style: AppTheme.sectionLabel(palette.money),
                  ),
                ),
              if (secondaryLabel != null)
                Expanded(
                  flex: 4,
                  child: OutlinedButton(
                    onPressed: onSecondary,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: palette.onPanel,
                      disabledForegroundColor: palette.panelMuted,
                      side: BorderSide(color: palette.panelMuted),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(
                        fontFamily: AppFonts.body,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.7,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (secondaryIcon != null) ...[
                          Icon(secondaryIcon, size: 16),
                          const SizedBox(width: 8),
                        ],
                        Flexible(
                          child: Text(
                            secondaryLabel!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(width: 10),
              Expanded(
                flex: secondaryLabel != null ? 5 : 4,
                child: ElevatedButton(
                  onPressed: onPrimary,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: palette.amber,
                    foregroundColor: palette.onAmber,
                    padding: const EdgeInsets.symmetric(vertical: 17),
                    textStyle: const TextStyle(
                      fontFamily: AppFonts.body,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.7,
                    ),
                  ),
                  child: Text(
                    primaryLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
