import 'package:flutter/material.dart';
import 'constants.dart';

/// The palette resolved for the brightness currently in force.
///
/// Screens read every surface, rule and accent from here rather than from
/// [AppColors] directly. A hardcoded surface beside a themed text colour is
/// how the catalogue lost its titles in the dark; naming both ends of every
/// pairing in one place is what stops it happening again.
class AppPalette {
  /// The page a screen is printed on.
  final Color canvas;

  /// A card, sheet or field sitting on the canvas.
  final Color surface;

  /// A surface that needs to read as lifted off the one behind it.
  final Color raisedSurface;

  /// Body and display type on [canvas] and [surface].
  final Color onSurface;

  /// Secondary type: captions, labels, anything supporting.
  final Color muted;

  /// The rule drawn instead of a shadow.
  final Color hairline;

  /// The dark band that carries the state of the floor.
  final Color panel;

  /// Type on [panel].
  final Color onPanel;

  /// Supporting type on [panel].
  final Color panelMuted;

  /// The rule inside a [panel].
  final Color panelHairline;

  /// Gold for labels and marks set on [canvas] or [surface].
  final Color gold;

  /// Gold for money, which always sits on a [panel] or in the dark.
  final Color money;

  /// The fill of a call to action.
  final Color amber;

  /// Type on [amber].
  final Color onAmber;

  /// Anything live, closing or being destroyed.
  final Color live;

  /// Confirmation and winning bids.
  final Color positive;

  const AppPalette._({
    required this.canvas,
    required this.surface,
    required this.raisedSurface,
    required this.onSurface,
    required this.muted,
    required this.hairline,
    required this.panel,
    required this.onPanel,
    required this.panelMuted,
    required this.panelHairline,
    required this.gold,
    required this.money,
    required this.amber,
    required this.onAmber,
    required this.live,
    required this.positive,
  });

  static AppPalette of(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? night : day;
  }

  static const AppPalette day = AppPalette._(
    canvas: AppColors.paper,
    surface: AppColors.card,
    raisedSurface: AppColors.lightGrey,
    onSurface: AppColors.ink,
    muted: AppColors.grey,
    hairline: AppColors.hairline,
    panel: AppColors.panel,
    onPanel: AppColors.paper,
    panelMuted: AppColors.grey,
    panelHairline: Color(0x33FFFFFF),
    gold: AppColors.gold,
    money: AppColors.goldBright,
    amber: AppColors.amber,
    onAmber: AppColors.ink,
    live: AppColors.liveRed,
    positive: AppColors.green,
  );

  static const AppPalette night = AppPalette._(
    canvas: AppColors.nightCanvas,
    surface: AppColors.nightSurface,
    raisedSurface: AppColors.nightRaised,
    onSurface: AppColors.nightInk,
    muted: AppColors.nightGrey,
    hairline: AppColors.nightRule,
    panel: AppColors.nightRaised,
    onPanel: AppColors.nightInk,
    panelMuted: AppColors.nightGrey,
    panelHairline: Color(0x1FFFFFFF),
    gold: AppColors.goldBright,
    money: AppColors.goldBright,
    amber: AppColors.amber,
    onAmber: AppColors.ink,
    live: AppColors.liveRed,
    positive: AppColors.greenBright,
  );
}

/// Sugar so a build method reads `context.palette.surface` rather than
/// repeating the lookup on every line.
extension PaletteContext on BuildContext {
  AppPalette get palette => AppPalette.of(this);
}
