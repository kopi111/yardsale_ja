import 'package:flutter/material.dart';

/// The two-column catalogue every screen lays its lots out in.
///
/// A [ListingCard] pins its price to the foot of the cell it is given, which
/// only works when the cell has a height. Left to a masonry grid the card is
/// handed an unbounded one and renders as nothing at all, so the cell shape
/// is settled here, once, for every screen that shows a catalogue.
class CatalogueGrid extends StatelessWidget {
  static const double _cellRatio = 0.66;
  static const double _gutter = 14;

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final EdgeInsetsGeometry padding;
  final bool shrinkWrap;

  const CatalogueGrid({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.padding = const EdgeInsets.fromLTRB(20, 14, 20, 24),
    this.shrinkWrap = false,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: padding,
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: _gutter,
        crossAxisSpacing: _gutter,
        childAspectRatio: _cellRatio,
      ),
      itemCount: itemCount,
      itemBuilder: itemBuilder,
    );
  }
}
