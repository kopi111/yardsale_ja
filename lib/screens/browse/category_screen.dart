import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../data/models/listing.dart';
import '../../data/repositories/listing_repository.dart';
import '../../widgets/catalogue_grid.dart';
import '../../widgets/listing_card.dart';
import '../listing/listing_detail_screen.dart';

class CategoryScreen extends StatefulWidget {
  final String categoryId;
  final String categoryName;

  const CategoryScreen({
    super.key,
    required this.categoryId,
    required this.categoryName,
  });

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  final ListingRepository _repo = ListingRepository();
  List<Listing> _listings = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCategoryListings();
  }

  Future<void> _loadCategoryListings() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      // Close anything whose time is up before listing the category, so a
      // finished lot is settled rather than shown as still running.
      await _repo.endExpiredAuctions();
      final listings = await _repo.getListings(category: widget.categoryId);
      if (!mounted) return;
      setState(() {
        _listings = listings;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load this category. Pull to retry.';
        _isLoading = false;
      });
    }
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_error!, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: _loadCategoryListings,
            child: const Text('TRY AGAIN'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.categoryName)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _listings.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.inbox,
                          size: 64,
                          color: AppColors.grey.withValues(alpha: 0.5)),
                      const SizedBox(height: 16),
                      Text('No ${widget.categoryName} listings yet',
                          style: const TextStyle(
                              color: AppColors.grey, fontSize: 16)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadCategoryListings,
                  child: CatalogueGrid(
                    itemCount: _listings.length,
                    itemBuilder: (context, index) {
                      final listing = _listings[index];
                      return ListingCard(
                        listing: listing,
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
                ),
    );
  }
}
