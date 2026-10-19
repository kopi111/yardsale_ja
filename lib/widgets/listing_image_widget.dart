import 'package:flutter/material.dart';
import '../core/constants.dart';
import 'lot_photo.dart';

/// The picture that stands for a lot.
///
/// A lot shows its own photograph or it shows a plate bearing its category and
/// title. It is never dressed in a stock picture of somebody else's item: a
/// bidder reads the picture as the thing they are bidding on.
class ListingImageWidget extends StatelessWidget {
  final List<String> imagePaths;
  final String category;
  final String title;
  final double? width;
  final double? height;
  final BoxFit fit;

  const ListingImageWidget({
    super.key,
    required this.imagePaths,
    required this.category,
    required this.title,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    if (imagePaths.isEmpty) return _categoryPlate(context);
    return LotPhoto(
      path: imagePaths.first,
      width: width,
      height: height,
      fit: fit,
      onUnreadable: _categoryPlate,
    );
  }

  Widget _categoryPlate(BuildContext context) {
    final style = _CategoryStyle.of(category);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: style.colors,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(style.icon, size: 40, color: Colors.white.withValues(alpha: 0.9)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryStyle {
  final IconData icon;
  final List<Color> colors;

  const _CategoryStyle({required this.icon, required this.colors});

  static _CategoryStyle of(String category) {
    switch (category) {
      case 'electronics':
        return const _CategoryStyle(
          icon: Icons.devices,
          colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
        );
      case 'vehicles':
        return const _CategoryStyle(
          icon: Icons.directions_car,
          colors: [Color(0xFF37474F), Color(0xFF263238)],
        );
      case 'clothing':
        return const _CategoryStyle(
          icon: Icons.checkroom,
          colors: [Color(0xFFAD1457), Color(0xFF880E4F)],
        );
      case 'furniture':
        return const _CategoryStyle(
          icon: Icons.chair,
          colors: [Color(0xFF5D4037), Color(0xFF3E2723)],
        );
      case 'phones':
        return const _CategoryStyle(
          icon: Icons.phone_android,
          colors: [Color(0xFF00897B), Color(0xFF00695C)],
        );
      case 'books':
        return const _CategoryStyle(
          icon: Icons.menu_book,
          colors: [Color(0xFF6A1B9A), Color(0xFF4A148C)],
        );
      case 'sports':
        return const _CategoryStyle(
          icon: Icons.sports_basketball,
          colors: [Color(0xFFE65100), Color(0xFFBF360C)],
        );
      case 'home_garden':
        return const _CategoryStyle(
          icon: Icons.home,
          colors: [Color(0xFF2E7D32), Color(0xFF1B5E20)],
        );
      case 'services':
        return const _CategoryStyle(
          icon: Icons.build,
          colors: [Color(0xFF546E7A), Color(0xFF37474F)],
        );
      default:
        return const _CategoryStyle(
          icon: Icons.sell,
          colors: [AppColors.green, Color(0xFF006B28)],
        );
    }
  }
}
