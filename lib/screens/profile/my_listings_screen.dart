import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../core/palette.dart';
import '../../data/models/listing.dart';
import '../../data/repositories/listing_repository.dart'
    show ListingCancellationRejectedException;
import '../../providers/listing_provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/catalogue_grid.dart';
import '../../widgets/listing_card.dart';
import '../listing/listing_detail_screen.dart';
import '../listing/create_listing_screen.dart';

class MyListingsScreen extends StatefulWidget {
  const MyListingsScreen({super.key});

  @override
  State<MyListingsScreen> createState() => _MyListingsScreenState();
}

class _MyListingsScreenState extends State<MyListingsScreen> {
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
      final userId = context.read<UserProvider>().currentUser?.id;
      if (userId != null) {
        final listings =
            await context.read<ListingProvider>().getUserListings(userId);
        if (!mounted) return;
        setState(() {
          _listings = listings;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load auctions. Pull to retry.';
        _isLoading = false;
      });
    }
  }

  void _confirmDelete(Listing listing) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Auction?'),
        content: Text(
            'Are you sure you want to cancel "${listing.title}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Keep'),
          ),
          ElevatedButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(ctx);
              try {
                await context
                    .read<ListingProvider>()
                    .deleteListing(listing.id);
              } on ListingCancellationRejectedException catch (e) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(e.reason),
                    backgroundColor: AppColors.red,
                  ),
                );
                return;
              }
              if (!mounted) return;
              messenger.showSnackBar(
                const SnackBar(
                  content: Text('Lot withdrawn'),
                  backgroundColor: AppColors.ink,
                ),
              );
              _load();
            },
            style:
                ElevatedButton.styleFrom(backgroundColor: AppColors.red),
            child: const Text('Cancel Auction'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.myListings)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline,
                          size: 64,
                          color: AppColors.grey.withValues(alpha: 0.5)),
                      const SizedBox(height: 16),
                      Text(_error!,
                          style: const TextStyle(
                              color: AppColors.grey, fontSize: 16)),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _listings.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.gavel_rounded,
                                size: 40, color: context.palette.hairline),
                            const SizedBox(height: 18),
                            Text(
                              'Nothing consigned yet',
                              style:
                                  Theme.of(context).textTheme.headlineMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Send your first lot to the floor and it '
                              'will be listed here.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 22),
                            ElevatedButton(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const CreateListingScreen()),
                              ).then((_) => _load()),
                              child: const Text('CONSIGN A LOT'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: CatalogueGrid(
                        itemCount: _listings.length,
                        itemBuilder: (context, index) {
                          final listing = _listings[index];
                          return ListingCard(
                            listing: listing,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ListingDetailScreen(
                                    listingId: listing.id),
                              ),
                            ).then((_) => _load()),
                            onLongPress: () => _confirmDelete(listing),
                          );
                        },
                      ),
                    ),
    );
  }
}
