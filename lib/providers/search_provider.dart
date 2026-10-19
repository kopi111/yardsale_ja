import 'package:flutter/material.dart';
import '../data/models/listing.dart';
import '../data/repositories/listing_repository.dart';

class SearchProvider with ChangeNotifier {
  final ListingRepository _repo = ListingRepository();
  List<Listing> _results = [];
  bool _isLoading = false;
  String _query = '';
  String? _selectedCategory;
  String? _selectedParish;
  String? _selectedCondition;
  double? _minPrice;
  double? _maxPrice;
  String _sortBy = 'newest';
  final List<String> _searchHistory = [];
  int _searchGeneration = 0;

  List<Listing> get results => _results;
  bool get isLoading => _isLoading;
  String get query => _query;
  String? get selectedCategory => _selectedCategory;
  String? get selectedParish => _selectedParish;
  String? get selectedCondition => _selectedCondition;
  double? get minPrice => _minPrice;
  double? get maxPrice => _maxPrice;
  String get sortBy => _sortBy;
  List<String> get searchHistory => List.unmodifiable(_searchHistory);
  bool get hasFilters =>
      _selectedCategory != null ||
      _selectedParish != null ||
      _selectedCondition != null ||
      _minPrice != null ||
      _maxPrice != null;

  void setCategory(String? category) {
    _selectedCategory = category;
    notifyListeners();
  }

  void setParish(String? parish) {
    _selectedParish = parish;
    notifyListeners();
  }

  void setCondition(String? condition) {
    _selectedCondition = condition;
    notifyListeners();
  }

  void setPriceRange(double? min, double? max) {
    _minPrice = min;
    _maxPrice = max;
    notifyListeners();
  }

  void setSortBy(String sort) {
    if (_sortBy == sort) return;
    _sortBy = sort;
    if (_hasActiveSearch) {
      search(_query);
    } else {
      notifyListeners();
    }
  }

  bool get _hasActiveSearch =>
      _query.isNotEmpty || hasFilters || _results.isNotEmpty;

  void clearSearch() {
    _searchGeneration++;
    _query = '';
    _results = [];
    _isLoading = false;
    notifyListeners();
  }

  void clear() {
    _query = '';
    _results = [];
    _selectedCategory = null;
    _selectedParish = null;
    _selectedCondition = null;
    _minPrice = null;
    _maxPrice = null;
    _sortBy = 'newest';
    _isLoading = false;
    _searchGeneration++;
    _searchHistory.clear();
    notifyListeners();
  }

  void clearFilters() {
    _selectedCategory = null;
    _selectedParish = null;
    _selectedCondition = null;
    _minPrice = null;
    _maxPrice = null;
    notifyListeners();
  }

  void removeFromHistory(String query) {
    _searchHistory.remove(query);
    notifyListeners();
  }

  void clearHistory() {
    _searchHistory.clear();
    notifyListeners();
  }

  static const String _effectivePrice =
      'COALESCE(l.current_bid, l.starting_bid)';

  String _getOrderBy() {
    switch (_sortBy) {
      case 'price_low':
        return '$_effectivePrice ASC';
      case 'price_high':
        return '$_effectivePrice DESC';
      case 'ending_soon':
        return 'l.auction_end_time ASC';
      case 'oldest':
        return 'l.created_at ASC';
      default:
        return 'l.created_at DESC';
    }
  }

  Future<void> search(String query) async {
    final trimmedQuery = query.trim();
    _query = trimmedQuery;
    _recordHistory(trimmedQuery);
    final generation = ++_searchGeneration;
    _isLoading = true;
    notifyListeners();
    try {
      await _repo.endExpiredAuctions();
      final results = await _repo.getListings(
        searchQuery: trimmedQuery.isNotEmpty ? trimmedQuery : null,
        category: _selectedCategory,
        parish: _selectedParish,
        condition: _selectedCondition,
        minPrice: _minPrice,
        maxPrice: _maxPrice,
        orderBy: _getOrderBy(),
      );
      if (generation != _searchGeneration) return;
      _results = results;
    } finally {
      if (generation == _searchGeneration) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  void _recordHistory(String trimmedQuery) {
    if (trimmedQuery.isEmpty) return;
    _searchHistory
        .removeWhere((entry) => entry.toLowerCase() == trimmedQuery.toLowerCase());
    _searchHistory.insert(0, trimmedQuery);
    if (_searchHistory.length > 10) {
      _searchHistory.removeLast();
    }
  }
}
