import 'package:flutter/material.dart';
import 'constants.dart';
import 'palette.dart';

/// The auction-catalogue theme: warm paper, hairline rules instead of shadows,
/// and heavy expanded type reserved for money.
class AppTheme {
  static const double cardRadius = 12;
  static const double fieldRadius = 12;
  static const double markRadius = 6;
  static const double pillRadius = 999;

  static ThemeData get lightTheme => _build(AppPalette.day, Brightness.light);

  static ThemeData get darkTheme => _build(AppPalette.night, Brightness.dark);

  static ThemeData _build(AppPalette palette, Brightness brightness) {
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: AppFonts.body,
      scaffoldBackgroundColor: palette.canvas,
      canvasColor: palette.canvas,
      dividerColor: palette.hairline,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: palette.onSurface,
        onPrimary: palette.canvas,
        secondary: palette.amber,
        onSecondary: palette.onAmber,
        tertiary: palette.positive,
        onTertiary: AppColors.white,
        error: AppColors.red,
        onError: AppColors.white,
        surface: palette.surface,
        onSurface: palette.onSurface,
        surfaceContainerHighest: palette.raisedSurface,
        onSurfaceVariant: palette.muted,
        outline: palette.hairline,
      ),
      textTheme: _textTheme(palette.onSurface, palette.muted),
      appBarTheme: AppBarTheme(
        backgroundColor: palette.canvas,
        foregroundColor: palette.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: AppFonts.display,
          fontWeight: FontWeight.w900,
          fontSize: 18,
          letterSpacing: -0.2,
          color: palette.onSurface,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: palette.hairline,
        thickness: 1,
        space: 1,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: palette.amber,
        foregroundColor: palette.onAmber,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: palette.amber,
          foregroundColor: palette.onAmber,
          disabledBackgroundColor: palette.hairline,
          disabledForegroundColor: palette.muted,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 17),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(cardRadius)),
          ),
          textStyle: const TextStyle(
            fontFamily: AppFonts.body,
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.9,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.onSurface,
          side: BorderSide(color: palette.hairline, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(cardRadius)),
          ),
          textStyle: const TextStyle(
            fontFamily: AppFonts.body,
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.9,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: palette.onSurface,
          textStyle: const TextStyle(
            fontFamily: AppFonts.body,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.surface,
        border: _fieldBorder(palette.hairline),
        enabledBorder: _fieldBorder(palette.hairline),
        focusedBorder: _fieldBorder(palette.amber, width: 1.6),
        errorBorder: _fieldBorder(AppColors.red),
        focusedErrorBorder: _fieldBorder(AppColors.red, width: 1.6),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        labelStyle: TextStyle(color: palette.muted, fontSize: 14),
        hintStyle: TextStyle(color: palette.muted, fontSize: 14),
      ),
      cardTheme: CardThemeData(
        color: palette.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(cardRadius)),
          side: BorderSide(color: palette.hairline),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: palette.surface,
        selectedColor: palette.onSurface,
        side: BorderSide(color: palette.hairline),
        labelStyle: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
          color: palette.onSurface,
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(cardRadius)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: palette.panel,
        contentTextStyle: TextStyle(
          fontFamily: AppFonts.body,
          color: palette.onPanel,
          fontWeight: FontWeight.w600,
        ),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(cardRadius)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(cardRadius)),
          side: BorderSide(color: palette.hairline),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.surface,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: palette.amber),
      listTileTheme: ListTileThemeData(
        iconColor: palette.muted,
        textColor: palette.onSurface,
      ),
    );
  }

  static OutlineInputBorder _fieldBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: const BorderRadius.all(Radius.circular(fieldRadius)),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  static TextTheme _textTheme(Color onSurface, Color muted) {
    TextStyle display(double size, {double tracking = -0.6}) => TextStyle(
          fontFamily: AppFonts.display,
          fontWeight: FontWeight.w900,
          fontSize: size,
          height: 1.05,
          letterSpacing: tracking,
          color: onSurface,
        );

    TextStyle body(double size, FontWeight weight, {Color? color}) => TextStyle(
          fontFamily: AppFonts.body,
          fontWeight: weight,
          fontSize: size,
          height: 1.4,
          color: color ?? onSurface,
        );

    return TextTheme(
      displayLarge: display(44, tracking: -1.4),
      displayMedium: display(34, tracking: -1),
      displaySmall: display(28, tracking: -0.8),
      headlineMedium: display(22),
      headlineSmall: display(18, tracking: -0.3),
      titleLarge: body(17, FontWeight.w800),
      titleMedium: body(15, FontWeight.w700),
      titleSmall: body(13.5, FontWeight.w700),
      bodyLarge: body(15, FontWeight.w400),
      bodyMedium: body(14, FontWeight.w400),
      bodySmall: body(12.5, FontWeight.w400, color: muted),
      labelLarge: body(13, FontWeight.w800),
      labelMedium: body(11, FontWeight.w700, color: muted),
      labelSmall: body(10, FontWeight.w700, color: muted),
    );
  }

  /// The all-caps hairline label that runs above every catalogue section.
  static TextStyle sectionLabel(Color color) => TextStyle(
        fontFamily: AppFonts.body,
        fontSize: 10.5,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.6,
        color: color,
      );

  /// Money is always set in the expanded cut so a price reads as a price.
  static TextStyle money(double size, Color color) => TextStyle(
        fontFamily: AppFonts.display,
        fontSize: size,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.5,
        height: 1,
        color: color,
        fontFeatures: const [FontFeature.tabularFigures()],
      );
}
