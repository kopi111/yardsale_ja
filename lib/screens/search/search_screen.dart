import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../core/palette.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../providers/search_provider.dart';
import '../../widgets/catalogue_grid.dart';
import '../../widgets/listing_card.dart';
import '../listing/listing_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showFilterSheet() {
    final provider = context.read<SearchProvider>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _FilterSheet(
        provider: provider,
        onApply: () {
          Navigator.pop(ctx);
          provider.search(_searchController.text);
        },
      ),
    );
  }

  void _clearSearch() {
    _searchController.clear();
    context.read<SearchProvider>().clearSearch();
    setState(() {});
  }

  void _onHistoryTap(String query) {
    _searchController.text = query;
    context.read<SearchProvider>().search(query);
  }

  /// The catalogue's way of saying there is nothing here yet.
  static Widget _emptyState(
    BuildContext context, {
    required IconData icon,
    required String headline,
    required String detail,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: context.palette.hairline),
            const SizedBox(height: 18),
            Text(headline, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Scaffold(
      backgroundColor: palette.canvas,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('SEARCH', style: AppTheme.money(32, palette.onSurface)),
                  const SizedBox(height: 4),
                  Text(
                    'EVERY LOT ON THE ISLAND',
                    style: AppTheme.sectionLabel(palette.gold),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 52,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: palette.surface,
                            border: Border.all(color: palette.hairline),
                            borderRadius:
                                BorderRadius.circular(AppTheme.fieldRadius),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.search,
                                  color: palette.muted, size: 21),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  style: TextStyle(
                                    fontFamily: AppFonts.body,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: palette.onSurface,
                                  ),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    filled: false,
                                    contentPadding: EdgeInsets.zero,
                                    hintText: 'Search lots, categories, '
                                        'or keywords',
                                    hintStyle: TextStyle(
                                      fontFamily: AppFonts.body,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: palette.muted,
                                    ),
                                  ),
                                  onChanged: (_) => setState(() {}),
                                  onSubmitted: (q) =>
                                      context.read<SearchProvider>().search(q),
                                ),
                              ),
                              if (_searchController.text.isNotEmpty)
                                GestureDetector(
                                  onTap: _clearSearch,
                                  child: Icon(Icons.close_rounded,
                                      size: 19, color: palette.muted),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Consumer<SearchProvider>(
                        builder: (_, provider, _) => _filterButton(
                          provider: provider,
                          onTap: _showFilterSheet,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Expanded(child: _buildResults()),
        ],
      ),
    );
  }

  Widget _buildResults() {
    return Consumer<SearchProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          // Show search history when no query
          if (provider.results.isEmpty && provider.query.isEmpty) {
            if (provider.searchHistory.isNotEmpty) {
              return _buildSearchHistory(provider);
            }
            return _emptyState(
              context,
              icon: Icons.search,
              headline: 'Find a lot',
              detail: 'Search every open lot on the island. '
                  'Try "iPhone", "car" or "furniture".',
            );
          }

          if (provider.results.isEmpty && provider.query.isNotEmpty) {
            return _emptyState(
              context,
              icon: Icons.search_off_rounded,
              headline: 'No lot answers to that',
              detail: 'Nothing on the floor matches "${provider.query}". '
                  'Try another word, or widen the filters.',
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 2, 20, 10),
                child: Text(
                  AppUtils.countOf(provider.results.length, 'lot').toUpperCase(),
                  style: AppTheme.sectionLabel(context.palette.muted),
                ),
              ),
              SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    _sortChip('Newest', 'newest', provider),
                    const SizedBox(width: 8),
                    _sortChip('Closing soonest', 'ending_soon', provider),
                    const SizedBox(width: 8),
                    _sortChip('Price \u2191', 'price_low', provider),
                    const SizedBox(width: 8),
                    _sortChip('Price \u2193', 'price_high', provider),
                  ],
                ),
              ),
              Expanded(
                child: CatalogueGrid(
                  itemCount: provider.results.length,
                  itemBuilder: (context, index) {
                    final listing = provider.results[index];
                    return ListingCard(
                      listing: listing,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ListingDetailScreen(
                              listingId: listing.id),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
    );
  }

  Widget _buildSearchHistory(SearchProvider provider) {
    final palette = context.palette;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'WHAT YOU LOOKED FOR',
                style: AppTheme.sectionLabel(palette.muted),
              ),
            ),
            GestureDetector(
              onTap: provider.clearHistory,
              child: Text(
                'Clear all',
                style: TextStyle(
                  fontFamily: AppFonts.body,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: palette.onSurface,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...provider.searchHistory.map(
          (query) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: palette.surface,
              borderRadius: BorderRadius.circular(AppTheme.fieldRadius),
              child: InkWell(
                onTap: () => _onHistoryTap(query),
                borderRadius: BorderRadius.circular(AppTheme.fieldRadius),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 13),
                  decoration: BoxDecoration(
                    border: Border.all(color: palette.hairline),
                    borderRadius:
                        BorderRadius.circular(AppTheme.fieldRadius),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.history_rounded,
                          size: 18, color: palette.muted),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Text(
                          query,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: AppFonts.body,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: palette.onSurface,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => provider.removeFromHistory(query),
                        child: Icon(Icons.close_rounded,
                            size: 17, color: palette.muted),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _sortChip(String label, String value, SearchProvider provider) {
    final palette = context.palette;
    final isSelected = provider.sortBy == value;

    return Material(
      color: isSelected ? palette.panel : palette.surface,
      borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      child: InkWell(
        onTap: () => provider.setSortBy(value),
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
          child: Text(
            label,
            style: TextStyle(
              fontFamily: AppFonts.body,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isSelected ? palette.onPanel : palette.onSurface,
            ),
          ),
        ),
      ),
    );
  }

  Widget _filterButton(
      {required SearchProvider provider, required VoidCallback onTap}) {
    final palette = context.palette;

    return Stack(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: provider.hasFilters ? palette.panel : palette.surface,
              border: Border.all(color: palette.hairline),
              borderRadius: BorderRadius.circular(AppTheme.fieldRadius),
            ),
            child: Icon(
              Icons.tune_rounded,
              size: 21,
              color: provider.hasFilters ? palette.onPanel : palette.muted,
            ),
          ),
        ),
        if (provider.hasFilters)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: context.palette.gold,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }
}

class _FilterSheet extends StatefulWidget {
  final SearchProvider provider;
  final VoidCallback onApply;

  const _FilterSheet({required this.provider, required this.onApply});

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late String? _category;
  late String? _parish;
  late String? _condition;
  final _minPriceController = TextEditingController();
  final _maxPriceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _category = widget.provider.selectedCategory;
    _parish = widget.provider.selectedParish;
    _condition = widget.provider.selectedCondition;
    if (widget.provider.minPrice != null) {
      _minPriceController.text =
          widget.provider.minPrice!.toInt().toString();
    }
    if (widget.provider.maxPrice != null) {
      _maxPriceController.text =
          widget.provider.maxPrice!.toInt().toString();
    }
  }

  @override
  void dispose() {
    _minPriceController.dispose();
    _maxPriceController.dispose();
    super.dispose();
  }

  /// Buyers type prices the way they read them, commas and all.
  static double? _parseAmount(String text) => AppUtils.readAmount(text);

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      minChildSize: 0.5,
      expand: false,
      builder: (_, controller) => Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          controller: controller,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'REFINE THE CATALOGUE',
                  style: AppTheme.sectionLabel(context.palette.gold),
                ),
                TextButton(
                  onPressed: () {
                    widget.provider.clearFilters();
                    widget.onApply();
                  },
                  child: const Text('Clear all'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('CATEGORY',
                style: AppTheme.sectionLabel(context.palette.muted)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration:
                  const InputDecoration(hintText: 'All Categories'),
              items: [
                const DropdownMenuItem(
                    value: null, child: Text('All')),
                ...AppCategories.selectableCategories.map((c) => DropdownMenuItem(
                      value: c['id'] as String,
                      child: Text(c['name'] as String),
                    )),
              ],
              onChanged: (v) => setState(() => _category = v),
            ),
            const SizedBox(height: 16),
            Text('PARISH',
                style: AppTheme.sectionLabel(context.palette.muted)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _parish,
              decoration:
                  const InputDecoration(hintText: 'All Parishes'),
              items: [
                const DropdownMenuItem(
                    value: null, child: Text('All')),
                ...AppParishes.parishes.map(
                    (p) => DropdownMenuItem(value: p, child: Text(p))),
              ],
              onChanged: (v) => setState(() => _parish = v),
            ),
            const SizedBox(height: 16),
            Text('CONDITION',
                style: AppTheme.sectionLabel(context.palette.muted)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _condition,
              decoration:
                  const InputDecoration(hintText: 'Any Condition'),
              items: [
                const DropdownMenuItem(
                    value: null, child: Text('Any')),
                ...AppConditions.conditions.map(
                    (c) => DropdownMenuItem(value: c, child: Text(c))),
              ],
              onChanged: (v) => setState(() => _condition = v),
            ),
            const SizedBox(height: 16),
            Text('PRICE RANGE (J\$)',
                style: AppTheme.sectionLabel(context.palette.muted)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _minPriceController,
                    decoration: const InputDecoration(
                      hintText: 'Min',
                      prefixText: 'J\$ ',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('-'),
                ),
                Expanded(
                  child: TextField(
                    controller: _maxPriceController,
                    decoration: const InputDecoration(
                      hintText: 'Max',
                      prefixText: 'J\$ ',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                widget.provider.setCategory(_category);
                widget.provider.setParish(_parish);
                widget.provider.setCondition(_condition);
                final min = _parseAmount(_minPriceController.text);
                final max = _parseAmount(_maxPriceController.text);
                widget.provider.setPriceRange(min, max);
                widget.onApply();
              },
              child: const Text('APPLY FILTERS'),
            ),
          ],
        ),
      ),
    );
  }
}
