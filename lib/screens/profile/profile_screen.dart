import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../core/palette.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/models/user.dart';
import '../../providers/user_provider.dart';
import '../../providers/listing_provider.dart';
import '../../widgets/catalogue_marks.dart';
import '../../widgets/member_reputation.dart';
import '../payment/transactions_screen.dart';
import '../notifications/notifications_screen.dart';
import '../settings/settings_screen.dart';
import '../welcome/welcome_screen.dart';
import 'edit_profile_screen.dart';
import 'saved_lots_screen.dart';
import 'my_listings_screen.dart';

/// The bidder's own record: who they are on the floor and what they have done.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // These futures are created once per user rather than per build. Building
  // them inside build() re-queries the database on every rebuild and flashes
  // each value back to its placeholder while the query re-runs.
  String? _loadedUserId;
  int? _loadedRevision;
  Future<int>? _listingCount;
  Future<double>? _rating;

  /// Creates the stat queries the first time a user is seen, and again when
  /// either the member or the catalogue changes. Guarding keeps this off the
  /// per-build path; guarding on the id *alone* is what left the member's
  /// standing frozen at the moment they registered.
  void _loadStatsFor(User user, int revision) {
    if (user.id == _loadedUserId && revision == _loadedRevision) return;
    final provider = context.read<UserProvider>();
    _loadedUserId = user.id;
    _loadedRevision = revision;
    _listingCount = provider.getUserListingCount(user.id);
    _rating = provider.getUserRating(user.id);
  }

  void _open(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().currentUser;
    if (user == null) return const WelcomeScreen();
    _loadStatsFor(user, context.watch<ListingProvider>().revision);

    return Scaffold(
      backgroundColor: context.palette.canvas,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ProfileMasthead(
                  onNotices: () => _open(const NotificationsScreen()),
                ),
                const SizedBox(height: 18),
                _PaddleCard(user: user, onSettings: _openSettings),
                const SizedBox(height: 14),
                _StandingTiles(
                  listingCount: _listingCount,
                  rating: _rating,
                  userId: user.id,
                ),
                const SizedBox(height: 18),
                _MenuPanel(rows: _menuRows()),
                const SizedBox(height: 20),
                MemberReputation(userId: user.id),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openSettings() => _open(const SettingsScreen());

  /// The saleroom vocabulary, applied once here so the row and the screen it
  /// opens cannot say different things.
  List<_MenuRow> _menuRows() {
    return [
      _MenuRow(
        title: 'Edit your details',
        detail: 'Update your profile and payout info',
        icon: Icons.badge_outlined,
        onTap: () => _open(const EditProfileScreen()),
      ),
      _MenuRow(
        title: AppStrings.notices,
        detail: 'Important updates and alerts',
        icon: Icons.notifications_none,
        onTap: () => _open(const NotificationsScreen()),
      ),
      _MenuRow(
        title: AppStrings.myListings,
        detail: 'Manage your active and past lots',
        icon: Icons.gavel_rounded,
        onTap: () => _open(const MyListingsScreen()),
      ),
      _MenuRow(
        title: AppStrings.savedLots,
        detail: 'Lots you are keeping an eye on',
        icon: Icons.bookmark_border,
        onTap: () => _open(const SavedLotsScreen()),
      ),
      _MenuRow(
        title: AppStrings.settlements,
        detail: 'Payouts, invoices and history',
        icon: Icons.receipt_long_outlined,
        onTap: () => _open(const TransactionsScreen()),
      ),
      _MenuRow(
        title: AppStrings.settings,
        detail: 'Preferences and account settings',
        icon: Icons.tune,
        onTap: _openSettings,
      ),
    ];
  }
}

/// The masthead of the member's own record.
class _ProfileMasthead extends StatelessWidget {
  final VoidCallback onNotices;

  const _ProfileMasthead({required this.onNotices});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('PROFILE', style: AppTheme.money(32, palette.onSurface)),
              const SizedBox(height: 4),
              Text(
                'YOUR SELLER DASHBOARD',
                style: AppTheme.sectionLabel(palette.gold),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: onNotices,
          icon: Icon(
            Icons.notifications_none_rounded,
            size: 26,
            color: palette.onSurface,
          ),
        ),
      ],
    );
  }
}

/// The bidder's paddle: their name and standing, set on ink.
class _PaddleCard extends StatelessWidget {
  final User user;
  final VoidCallback onSettings;

  const _PaddleCard({required this.user, required this.onSettings});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 12, 18),
      decoration: BoxDecoration(
        color: palette.panel,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'PADDLE ${AppUtils.lotNumberFor(user.id)}',
                style: AppTheme.sectionLabel(palette.money),
              ),
              const SizedBox(width: 10),
              const _VerifiedChip(),
              const Spacer(),
              IconButton(
                onPressed: onSettings,
                icon: Icon(Icons.tune, size: 21, color: palette.onPanel),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        user.name,
                        style: AppTheme.money(28, palette.onPanel),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${user.parish.toUpperCase()}  ·  MEMBER SINCE '
                      '${AppUtils.formatMonthYear(user.createdAt).toUpperCase()}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.sectionLabel(palette.panelMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              MemberInitials(
                name: user.name,
                diameter: 66,
                background: AppColors.paper,
                foreground: AppColors.panel,
              ),
              const SizedBox(width: 6),
            ],
          ),
        ],
      ),
    );
  }
}

/// States that the member is registered — which is all the app knows. It does
/// not claim an identity check nobody performed.
class _VerifiedChip extends StatelessWidget {
  const _VerifiedChip();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: palette.panelHairline,
        borderRadius: BorderRadius.circular(AppTheme.pillRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.confirmation_number_outlined,
              size: 12, color: palette.onPanel),
          const SizedBox(width: 5),
          Text(
            'REGISTERED BIDDER',
            style: AppTheme.sectionLabel(palette.onPanel),
          ),
        ],
      ),
    );
  }
}

/// Four measurements of how a member is doing on the floor.
class _StandingTiles extends StatelessWidget {
  final Future<int>? listingCount;
  final Future<double>? rating;
  final String userId;

  const _StandingTiles({
    required this.listingCount,
    required this.rating,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    return RuledPanel(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: _FutureTile(
                future: listingCount,
                icon: Icons.gavel_rounded,
                label: 'Lots listed',
                format: (value) => '$value',
              ),
            ),
            _TileRule(),
            Expanded(
              child: _FutureTile(
                future: rating,
                icon: Icons.star_outline_rounded,
                label: 'Avg rating',
                format: (value) =>
                    value > 0 ? value.toStringAsFixed(1) : '—',
              ),
            ),
            _TileRule(),
            Expanded(
              child: StatTile(
                icon: Icons.confirmation_number_outlined,
                value: AppUtils.lotNumberFor(userId),
                label: 'Paddle',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TileRule extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return VerticalDivider(
      width: 1,
      thickness: 1,
      color: context.palette.hairline,
    );
  }
}

class _FutureTile<T extends num> extends StatelessWidget {
  final Future<T>? future;
  final IconData icon;
  final String label;
  final String Function(T value) format;

  const _FutureTile({
    required this.future,
    required this.icon,
    required this.label,
    required this.format,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: future,
      builder: (_, snapshot) {
        final value = snapshot.data;
        return StatTile(
          icon: icon,
          value: value == null ? '—' : format(value),
          label: label,
        );
      },
    );
  }
}

/// The member's own menu, in the vocabulary the rest of the app uses.
class _MenuPanel extends StatelessWidget {
  final List<_MenuRow> rows;

  const _MenuPanel({required this.rows});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(color: palette.hairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) Divider(height: 1, thickness: 1, color: palette.hairline),
            rows[i],
          ],
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final String title;
  final String detail;
  final IconData icon;
  final VoidCallback onTap;

  const _MenuRow({
    required this.title,
    required this.detail,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        child: Row(
          children: [
            Icon(icon, size: 21, color: palette.onSurface),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(detail, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: palette.muted),
          ],
        ),
      ),
    );
  }
}
