import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/palette.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/models/user.dart';
import '../../data/models/listing.dart';
import '../../providers/user_provider.dart';
import '../../providers/listing_provider.dart';
import '../../widgets/catalogue_grid.dart';
import '../../widgets/catalogue_marks.dart';
import '../../widgets/listing_card.dart';
import '../../widgets/member_reputation.dart';
import '../listing/listing_detail_screen.dart';

/// A consignor's public record, as a bidder reads it before they bid: who they
/// are, what buyers have said about them, and what else they have on the floor.
class UserProfileScreen extends StatefulWidget {
  final String userId;
  const UserProfileScreen({super.key, required this.userId});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  User? _user;
  List<Listing> _listings = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });
      // Both providers are read before the first await, so neither lookup
      // reaches for a context that may already be gone.
      final userProvider = context.read<UserProvider>();
      final listingProvider = context.read<ListingProvider>();
      final user = await userProvider.getPublicProfile(widget.userId);
      final listings = await listingProvider.getPublicListings(widget.userId);
      if (!mounted) return;
      setState(() {
        _user = user;
        _listings = listings;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load profile. Pull to retry.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final user = _user;

    return Scaffold(
      backgroundColor: palette.canvas,
      appBar: AppBar(title: Text(user?.name ?? 'Consignor')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _body(user),
      ),
    );
  }

  Widget _body(User? user) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) return _RetryPanel(message: _error!, onRetry: _load);
    if (user == null) {
      return const _RetryPanel(message: 'This member is no longer listed.');
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ConsignorCard(user: user, lotCount: _listings.length),
          const SizedBox(height: 18),
          MemberReputation(userId: widget.userId),
          const SizedBox(height: 22),
          Text('ON THE FLOOR', style: AppTheme.sectionLabel(context.palette.gold)),
          const SizedBox(height: 4),
          Text(
            _listings.isEmpty
                ? 'Nothing standing'
                : AppUtils.countOf(_listings.length, 'open lot'),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 14),
          if (_listings.isNotEmpty) _catalogue(),
        ],
      ),
    );
  }

  Widget _catalogue() {
    return CatalogueGrid(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      itemCount: _listings.length,
      itemBuilder: (context, index) {
        final listing = _listings[index];
        return ListingCard(
          listing: listing,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ListingDetailScreen(listingId: listing.id),
            ),
          ),
        );
      },
    );
  }
}

/// The consignor's own plate: who they are and where they sell from.
class _ConsignorCard extends StatelessWidget {
  final User user;
  final int lotCount;

  const _ConsignorCard({required this.user, required this.lotCount});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: palette.panel,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('CONSIGNOR', style: AppTheme.sectionLabel(palette.gold)),
                const SizedBox(height: 8),
                Text(
                  user.name,
                  style: Theme.of(context)
                      .textTheme
                      .displaySmall
                      ?.copyWith(color: palette.onPanel),
                ),
                const SizedBox(height: 6),
                Text(
                  '${user.parish.toUpperCase()} · '
                  '${AppUtils.countOf(lotCount, 'OPEN LOT').toUpperCase()}',
                  style: AppTheme.sectionLabel(palette.panelMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          MemberInitials(name: user.name, diameter: 62),
        ],
      ),
    );
  }
}

class _RetryPanel extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const _RetryPanel({required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 80),
      children: [
        Icon(Icons.error_outline,
            size: 56, color: context.palette.muted),
        const SizedBox(height: 16),
        Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        if (onRetry != null) ...[
          const SizedBox(height: 16),
          Center(
            child: OutlinedButton(
              onPressed: onRetry,
              child: const Text('RETRY'),
            ),
          ),
        ],
      ],
    );
  }
}
