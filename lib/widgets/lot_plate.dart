import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../core/utils.dart';
import '../data/models/listing.dart';
import 'catalogue_marks.dart';
import 'listing_image_widget.dart';

/// The photograph a lot is shown by, wearing its lot number and its state.
class LotPlate extends StatelessWidget {
  final Listing listing;
  final double height;
  final bool showLivePill;
  final bool showTimeChip;
  final Widget? corner;

  const LotPlate({
    super.key,
    required this.listing,
    required this.height,
    this.showLivePill = false,
    this.showTimeChip = false,
    this.corner,
  });

  @override
  Widget build(BuildContext context) {
    final isLive = !listing.isEnded;

    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ListingImageWidget(
            imagePaths: listing.imagePaths,
            category: listing.category,
            title: listing.title,
          ),
          if (!isLive) Container(color: AppColors.ink.withValues(alpha: 0.58)),
          Positioned(
            top: 9,
            left: 9,
            child: LotBadge(lotNumber: AppUtils.lotNumberFor(listing.id)),
          ),
          // The state of the lot and the member's own mark on it are two
          // different things, so a card that carries one still shows the other.
          Positioned(
            top: 5,
            right: 5,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showLivePill && isLive)
                  Padding(
                    padding: EdgeInsets.only(
                      top: 4,
                      right: corner == null ? 4 : 6,
                    ),
                    child: const LivePill(),
                  ),
                ?corner,
              ],
            ),
          ),
          if (showTimeChip && isLive)
            Positioned(
              bottom: 9,
              left: 9,
              child: Ticking(
                builder: (_) => TimeChip(
                  label: AppUtils.formatTimeRemaining(listing.auctionEndTime),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
