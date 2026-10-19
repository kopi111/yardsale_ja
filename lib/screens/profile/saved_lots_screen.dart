import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../providers/listing_provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/catalogue_grid.dart';
import '../../widgets/listing_card.dart';
import '../listing/listing_detail_screen.dart';

class SavedLotsScreen extends StatefulWidget {
  const SavedLotsScreen({super.key});

  @override
  State<SavedLotsScreen> createState() => _SavedLotsScreenState();
}

class _SavedLotsScreenState extends State<SavedLotsScreen> {
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      setState(() => _error = null);
      final userId = context.read<UserProvider>().currentUser?.id;
      if (userId != null) {
        await context.read<ListingProvider>().loadFavorites(userId);
      }
    } catch (e) {
      setState(() => _error = 'Failed to load favorites. Pull to retry.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = context.read<UserProvider>().currentUser?.id;

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.savedLots)),
      body: _error != null
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
          : Consumer<ListingProvider>(
              builder: (context, provider, _) {
                final favorites = provider.favorites;
                if (favorites.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bookmark_border,
                            size: 64,
                            color: AppColors.grey.withValues(alpha: 0.5)),
                        const SizedBox(height: 16),
                        const Text(AppStrings.noSavedLots,
                            style: TextStyle(
                                color: AppColors.grey, fontSize: 16)),
                        const SizedBox(height: 8),
                        const Text(
                            'Bookmark a lot to keep an eye on it',
                            style: TextStyle(
                                color: AppColors.grey, fontSize: 13)),
                        const SizedBox(height: 20),
                        OutlinedButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.gavel_rounded),
                          label: const Text('Back to the floor'),
                        ),
                      ],
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: _load,
                  child: CatalogueGrid(
                    itemCount: favorites.length,
                    itemBuilder: (context, index) {
                      final listing = favorites[index];
                      return ListingCard(
                        listing: listing,
                        showFavorite: true,
                        onFavorite: () async {
                          if (userId == null) return;
                          final messenger = ScaffoldMessenger.of(context);
                          try {
                            await provider.toggleFavorite(userId, listing.id);
                          } catch (_) {
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Could not update your list.'),
                                backgroundColor: AppColors.red,
                              ),
                            );
                            return;
                          }
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('Removed from your list'),
                              backgroundColor: AppColors.ink,
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                ListingDetailScreen(listingId: listing.id),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}
