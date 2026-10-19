import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../core/palette.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../data/models/listing.dart';
import 'lot_plate.dart';

/// The compact catalogue entry used wherever lots are shown in a grid.
class ListingCard extends StatelessWidget {
  static const double _plateHeight = 136;

  final Listing listing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool showFavorite;
  final VoidCallback? onFavorite;

  const ListingCard({
    super.key,
    required this.listing,
    this.onTap,
    this.onLongPress,
    this.showFavorite = false,
    this.onFavorite,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Material(
      color: palette.surface,
      borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: palette.hairline),
            borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _plate(context),
              Expanded(child: _entry(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _plate(BuildContext context) {
    return LotPlate(
      listing: listing,
      height: _plateHeight,
      showLivePill: true,
      corner: showFavorite ? _favoriteButton(context) : null,
    );
  }

  Widget _favoriteButton(BuildContext context) {
    return Material(
      color: context.palette.surface,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onFavorite,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 34,
          height: 34,
          child: Icon(
            listing.isFavorited ? Icons.bookmark : Icons.bookmark_border,
            size: 18,
            color: listing.isFavorited
                ? context.palette.gold
                : context.palette.onSurface,
          ),
        ),
      ),
    );
  }

  Widget _entry(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            listing.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 3),
          Text(
            listing.parish,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
          const Spacer(),
          Text(
            listing.currentBid != null ? 'CURRENT BID' : 'STARTING BID',
            style: AppTheme.sectionLabel(palette.muted),
          ),
          const SizedBox(height: 5),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    AppUtils.formatPrice(
                      listing.currentBid ?? listing.startingBid,
                    ),
                    style: AppTheme.money(18, palette.onSurface),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                AppUtils.countOf(listing.bidCount, 'bid'),
                style: TextStyle(
                  fontFamily: AppFonts.body,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: listing.bidCount > 0 ? palette.positive : palette.muted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
