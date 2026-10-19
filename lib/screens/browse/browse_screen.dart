import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../core/palette.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../providers/listing_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/user_provider.dart';
import '../../data/models/listing.dart';
import '../../widgets/catalogue_marks.dart';
import '../../widgets/listing_card.dart';
import '../../widgets/live_countdown.dart';
import '../../widgets/lot_plate.dart';
import '../listing/listing_detail_screen.dart';
import '../notifications/notifications_screen.dart';
import '../listing/create_listing_screen.dart';

class BrowseScreen extends StatefulWidget {
  final VoidCallback? onSearchTap;

  const BrowseScreen({super.key, this.onSearchTap});

  @override
  State<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends State<BrowseScreen> {
  static const int _railLength = 6;

  String _selectedCategory = AppCategories.allCategoryId;

  @override
  void initState() {
    super.initState();
    // Notifying listeners while the first frame is still building throws;
    // defer the load until the frame is on screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ListingProvider>().loadListings();
      final userId = context.read<UserProvider>().currentUser?.id;
      if (userId != null) {
        context.read<NotificationProvider>().load(userId);
        context.read<ListingProvider>().loadFavorites(userId);
      }
    });
  }

  /// A lot the member has already put aside must show as put aside wherever
  /// it appears; the catalogue query does not carry that mark itself.
  Listing _markedAsSaved(Listing listing, List<Listing> saved) {
    final isSaved = saved.any((candidate) => candidate.id == listing.id);
    return isSaved == listing.isFavorited
        ? listing
        : listing.copyWith(isFavorited: isSaved);
  }

  Future<void> _toggleSaved(Listing listing) async {
    final userId = context.read<UserProvider>().currentUser?.id;
    if (userId == null) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<ListingProvider>().toggleFavorite(userId, listing.id);
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Could not update your list.'),
          backgroundColor: AppColors.red,
        ),
      );
    }
  }

  /// Pulling the floor down also picks up any notice raised since the screen
  /// was opened, so the bell is not a frozen number.
  Future<void> _refreshFloor() async {
    await context.read<ListingProvider>().loadListings();
    if (!mounted) return;
    final userId = context.read<UserProvider>().currentUser?.id;
    if (userId == null) return;
    await context.read<NotificationProvider>().load(userId);
  }

  List<Listing> _inSelectedCategory(List<Listing> listings) {
    if (_selectedCategory == AppCategories.allCategoryId) return listings;
    return listings.where((l) => l.category == _selectedCategory).toList();
  }

  List<Listing> _closingSoonest(List<Listing> listings) {
    final live = listings.where((l) => !l.isEnded).toList()
      ..sort((a, b) => a.auctionEndTime.compareTo(b.auctionEndTime));
    return live.take(_railLength).toList();
  }

  void _openListing(Listing listing) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ListingDetailScreen(listingId: listing.id),
      ),
    );
  }

  void _openCreateListing() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateListingScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Scaffold(
      backgroundColor: palette.canvas,
      body: Consumer<ListingProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) return const _LoadingFloor();

          final listings = provider.listings;
          final inCategory = _inSelectedCategory(listings);
          final closingSoon = _closingSoonest(listings);

          return RefreshIndicator(
            color: palette.amber,
            onRefresh: _refreshFloor,
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _Masthead(
                    listings: listings,
                    onSearchTap: widget.onSearchTap,
                  ),
                ),
                SliverToBoxAdapter(
                  child: _CategoryRail(
                    selectedCategory: _selectedCategory,
                    onSelect: (id) => setState(() => _selectedCategory = id),
                  ),
                ),
                if (closingSoon.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _ClosingSoonRail(
                      listings: closingSoon,
                      onOpen: _openListing,
                      onViewAll: widget.onSearchTap,
                    ),
                  ),
                SliverToBoxAdapter(
                  child: SectionHeading(
                    label: 'ALL LOTS',
                    title: _selectedCategory == AppCategories.allCategoryId
                        ? 'Browse the catalogue'
                        : AppCategories.labelFor(_selectedCategory),
                    trailing: Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        AppUtils.countOf(inCategory.length, 'lot'),
                        style: TextStyle(
                          fontFamily: AppFonts.body,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: palette.muted,
                        ),
                      ),
                    ),
                  ),
                ),
                if (inCategory.isEmpty)
                  SliverToBoxAdapter(
                    child: _EmptyFloor(onCreate: _openCreateListing),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        childAspectRatio: 0.66,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final listing = _markedAsSaved(
                            inCategory[index],
                            provider.favorites,
                          );
                          return ListingCard(
                            listing: listing,
                            showFavorite: true,
                            onFavorite: () => _toggleSaved(listing),
                            onTap: () => _openListing(listing),
                          );
                        },
                        childCount: inCategory.length,
                      ),
                    ),
                  ),
                const SliverPadding(padding: EdgeInsets.only(bottom: 28)),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// The masthead: the house name, the state of the floor, and the way in.
class _Masthead extends StatelessWidget {
  final List<Listing> listings;
  final VoidCallback? onSearchTap;

  const _Masthead({required this.listings, this.onSearchTap});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      AppStrings.appName.toUpperCase(),
                      style: AppTheme.money(32, palette.onSurface),
                    ),
                  ),
                ),
                const _NoticeBell(),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              AppStrings.tagline.toUpperCase(),
              style: AppTheme.sectionLabel(palette.gold),
            ),
            const SizedBox(height: 18),
            _SearchBox(onTap: onSearchTap),
            const SizedBox(height: 16),
            Ticking(builder: (_) => _FloorPanel(listings: listings)),
          ],
        ),
      ),
    );
  }
}

class _SearchBox extends StatelessWidget {
  final VoidCallback? onTap;

  const _SearchBox({this.onTap});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: palette.surface,
          border: Border.all(color: palette.hairline),
          borderRadius: BorderRadius.circular(AppTheme.fieldRadius),
        ),
        child: Row(
          children: [
            Icon(Icons.search, color: palette.muted, size: 21),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                'Search lots, categories, or keywords',
                style: TextStyle(
                  fontFamily: AppFonts.body,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: palette.muted,
                ),
              ),
            ),
            Icon(Icons.tune_rounded, color: palette.muted, size: 20),
          ],
        ),
      ),
    );
  }
}

/// Three numbers that say what is actually happening on the floor right now.
class _FloorPanel extends StatelessWidget {
  final List<Listing> listings;

  const _FloorPanel({required this.listings});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final live = listings.where((l) => !l.isEnded).toList();
    final onTheFloor = live.fold<double>(
      0,
      (sum, l) => sum + (l.currentBid ?? l.startingBid),
    );
    final nextToClose = _nextToClose(live);

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: palette.panel,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: FloorStat(
              value: '${live.length}',
              label: 'LIVE LOTS',
              valueColor: palette.onPanel,
              labelColor: palette.panelMuted,
              note: live.isEmpty
                  ? StatNote('FLOOR CLOSED', color: palette.panelMuted)
                  : const LiveMark(label: 'LIVE NOW'),
            ),
          ),
          _PanelRule(),
          Expanded(
            flex: 5,
            child: FloorStat(
              value: onTheFloor > 0 ? AppUtils.formatPrice(onTheFloor) : '—',
              label: 'ON THE FLOOR',
              valueColor: palette.money,
              labelColor: palette.panelMuted,
              note: StatNote(
                '${AppUtils.countOf(_bidsPlaced(live), 'bid')} so far',
                color: palette.panelMuted,
              ),
            ),
          ),
          _PanelRule(),
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: nextToClose == null
                      ? Text('—', style: AppTheme.money(22, palette.onPanel))
                      : LiveCountdown(
                          endTime: nextToClose.auctionEndTime,
                          size: 20,
                          onInk: true,
                        ),
                ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'NEXT CLOSING',
                    maxLines: 1,
                    style: AppTheme.sectionLabel(palette.panelMuted),
                  ),
                ),
                const SizedBox(height: 5),
                StatNote(
                  nextToClose == null
                      ? '—'
                      : 'Lot ${AppUtils.lotNumberFor(nextToClose.id)}',
                  color: palette.panelMuted,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  int _bidsPlaced(List<Listing> live) {
    return live.fold<int>(0, (sum, listing) => sum + listing.bidCount);
  }

  Listing? _nextToClose(List<Listing> live) {
    if (live.isEmpty) return null;
    return live.reduce(
      (a, b) => a.auctionEndTime.isBefore(b.auctionEndTime) ? a : b,
    );
  }
}

class _PanelRule extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 54,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      color: context.palette.panelHairline,
    );
  }
}

/// Categories as chips, the way a saleroom lists its departments.
class _CategoryRail extends StatelessWidget {
  final String selectedCategory;
  final ValueChanged<String> onSelect;

  const _CategoryRail({
    required this.selectedCategory,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 68,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
        itemCount: AppCategories.categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 9),
        itemBuilder: (context, index) {
          final category = AppCategories.categories[index];
          final id = category['id'] as String;

          return _CategoryChip(
            label: id == AppCategories.allCategoryId
                ? 'All Lots'
                : category['name'] as String,
            icon: category['icon'] as IconData,
            isSelected: selectedCategory == id,
            onTap: () => onSelect(id),
          );
        },
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final background = isSelected ? palette.panel : palette.surface;
    final foreground = isSelected ? palette.onPanel : palette.onSurface;
    final glyph = isSelected ? palette.money : palette.muted;

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.cardRadius),
            border: Border.all(
              color: isSelected ? palette.panel : palette.hairline,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17, color: glyph),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontFamily: AppFonts.body,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The lots about to go under the hammer, in the order they will close.
class _ClosingSoonRail extends StatelessWidget {
  static const double _railHeight = 278;

  final List<Listing> listings;
  final ValueChanged<Listing> onOpen;
  final VoidCallback? onViewAll;

  const _ClosingSoonRail({
    required this.listings,
    required this.onOpen,
    this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 14),
          child: Row(
            children: [
              Icon(
                Icons.schedule_rounded,
                size: 16,
                color: palette.live,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  'CLOSING SOONEST',
                  style: AppTheme.sectionLabel(palette.live),
                ),
              ),
              GestureDetector(
                onTap: onViewAll,
                child: Row(
                  children: [
                    Text(
                      'View all',
                      style: TextStyle(
                        fontFamily: AppFonts.body,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: palette.onSurface,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 19,
                      color: palette.onSurface,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: _railHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: listings.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) => _HammerCard(
              listing: listings[index],
              onTap: () => onOpen(listings[index]),
            ),
          ),
        ),
      ],
    );
  }
}

/// A lot in the closing-soonest rail: photograph, lot number, and the clock.
class _HammerCard extends StatelessWidget {
  static const double _width = 176;

  final Listing listing;
  final VoidCallback onTap;

  const _HammerCard({required this.listing, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return SizedBox(
      width: _width,
      child: Material(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: palette.hairline),
              borderRadius: BorderRadius.circular(AppTheme.cardRadius),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LotPlate(
                  listing: listing,
                  height: 128,
                  showTimeChip: true,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        listing.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        listing.parish,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 11),
                      Text(
                        listing.currentBid != null
                            ? 'CURRENT BID'
                            : 'STARTING BID',
                        style: AppTheme.sectionLabel(palette.muted),
                      ),
                      const SizedBox(height: 5),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          AppUtils.formatPrice(
                            listing.currentBid ?? listing.startingBid,
                          ),
                          style: AppTheme.money(19, palette.onSurface),
                        ),
                      ),
                      const SizedBox(height: 7),
                      _TimeLeftLine(listing: listing),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// How long is left, in the red a saleroom clock is painted.
class _TimeLeftLine extends StatelessWidget {
  final Listing listing;

  const _TimeLeftLine({required this.listing});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Ticking(
      builder: (_) {
        if (listing.isEnded) {
          return Text('CLOSED', style: AppTheme.sectionLabel(palette.muted));
        }
        return Text(
          '${AppUtils.formatTimeRemaining(listing.auctionEndTime)} left',
          style: TextStyle(
            fontFamily: AppFonts.body,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: palette.live,
          ),
        );
      },
    );
  }
}

class _NoticeBell extends StatelessWidget {
  const _NoticeBell();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final unread = context.watch<NotificationProvider>().unreadCount;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const NotificationsScreen()),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(
            Icons.notifications_none_rounded,
            size: 27,
            color: palette.onSurface,
          ),
          if (unread > 0)
            Positioned(
              top: 1,
              right: 1,
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: palette.live,
                  shape: BoxShape.circle,
                  border: Border.all(color: palette.canvas, width: 1.5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyFloor extends StatelessWidget {
  final VoidCallback onCreate;

  const _EmptyFloor({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      child: RuledPanel(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 34),
        child: Column(
          children: [
            Icon(Icons.gavel_rounded, size: 34, color: palette.muted),
            const SizedBox(height: 16),
            Text(
              'The floor is empty',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Nothing is under the hammer in this department yet.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: onCreate,
              child: const Text('CONSIGN A LOT'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingFloor extends StatelessWidget {
  const _LoadingFloor();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: CircularProgressIndicator(color: context.palette.amber),
    );
  }
}
