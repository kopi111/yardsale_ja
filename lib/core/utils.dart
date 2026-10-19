import 'package:intl/intl.dart';

class AppUtils {
  /// Reads a money amount a member typed.
  ///
  /// Returns null for anything that is not a plain amount of money, a minus
  /// sign included. Stripping the sign instead of refusing it is what once
  /// turned a mistyped "-200000" into a binding J$200,000 bid.
  static double? readAmount(String? text) {
    if (text == null) return null;
    final trimmed = text.replaceAll(',', '').replaceAll(' ', '').trim();
    if (trimmed.isEmpty) return null;
    if (!RegExp(r'^[0-9]+(\.[0-9]+)?$').hasMatch(trimmed)) return null;
    return double.tryParse(trimmed);
  }

  /// Whole amounts read as whole amounts; anything holding cents shows them,
  /// so a displayed price is never a rounded version of what is stored.
  static String formatPrice(double price) {
    final pattern = price == price.roundToDouble() ? '#,##0' : '#,##0.00';
    return 'J\$${NumberFormat(pattern, 'en_US').format(price)}';
  }

  /// Money at chip size: J$5K rather than J$5,000, so a row of raises fits.
  static String formatPriceShort(double price) {
    if (price >= 1000000) {
      final millions = price / 1000000;
      return 'J\$${_trimmed(millions)}M';
    }
    if (price >= 1000) {
      final thousands = price / 1000;
      return 'J\$${_trimmed(thousands)}K';
    }
    return formatPrice(price);
  }

  static String _trimmed(double value) {
    return value == value.roundToDouble()
        ? value.round().toString()
        : value.toStringAsFixed(1);
  }

  static bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// 'Today' and 'Yesterday' beat a date a reader has to work out.
  static String formatDayLabel(DateTime date) {
    final now = DateTime.now();
    if (isSameDay(date, now)) return 'Today';
    if (isSameDay(date, now.subtract(const Duration(days: 1)))) {
      return 'Yesterday';
    }
    return DateFormat('EEEE, MMM d').format(date);
  }

  static String formatTimeOfDay(DateTime date) {
    return DateFormat('h:mm a').format(date);
  }

  static String formatClockTime(DateTime date) {
    return DateFormat('h:mm:ss a').format(date);
  }

  static String formatDate(DateTime date) {
    return DateFormat('MMM d, yyyy').format(date);
  }

  static String formatYear(DateTime date) {
    return DateFormat('yyyy').format(date);
  }

  static String formatMonthYear(DateTime date) {
    return DateFormat('MMM yyyy').format(date);
  }

  static String formatDateTime(DateTime date) {
    return DateFormat('MMM d, yyyy h:mm a').format(date);
  }

  static String formatChatTime(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(date);
  }

  static String getInitials(String name) {
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) return words.first[0].toUpperCase();
    return '${words.first[0]}${words[1][0]}'.toUpperCase();
  }

  static String countOf(int count, String singular) {
    return count == 1 ? '1 $singular' : '$count ${singular}s';
  }

  static String truncate(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  /// The remaining time at the coarsest unit that still tells a bidder
  /// something. Inside the last minute that unit is seconds: '0m' for the
  /// whole closing minute hides exactly the moment a bidder needs to see.
  static String formatTimeRemaining(DateTime endTime) {
    final now = DateTime.now();
    if (now.isAfter(endTime)) return 'Ended';
    final diff = endTime.difference(now);
    if (diff.inDays > 0) {
      final hours = diff.inHours % 24;
      return '${diff.inDays}d ${hours}h';
    }
    if (diff.inHours > 0) {
      final minutes = diff.inMinutes % 60;
      return '${diff.inHours}h ${minutes}m';
    }
    if (diff.inMinutes > 0) {
      final seconds = diff.inSeconds % 60;
      return '${diff.inMinutes}m ${seconds}s';
    }
    return '${diff.inSeconds}s';
  }

  /// Every auction is a lot in the catalogue. The number is derived from the
  /// listing id so it stays the same wherever the lot is shown.
  static String lotNumberFor(String listingId) {
    var hash = 0;
    for (final unit in listingId.codeUnits) {
      hash = (hash * 31 + unit) & 0x7FFFFFFF;
    }
    return (hash % 999 + 1).toString().padLeft(3, '0');
  }

  /// A countdown broken into its parts so the UI can set each unit separately.
  /// Units above the largest non-zero one are dropped: a lot four minutes from
  /// closing reads '04m 36s', not '00h 04m 36s'.
  static List<String> timeRemainingParts(DateTime endTime) {
    final remaining = endTime.difference(DateTime.now());
    if (remaining.isNegative) return const [];
    String pad(int value) => value.toString().padLeft(2, '0');

    if (remaining.inDays > 0) {
      return [
        '${remaining.inDays}d',
        '${pad(remaining.inHours % 24)}h',
        '${pad(remaining.inMinutes % 60)}m',
      ];
    }
    if (remaining.inHours > 0) {
      return [
        '${remaining.inHours}h',
        '${pad(remaining.inMinutes % 60)}m',
        '${pad(remaining.inSeconds % 60)}s',
      ];
    }
    return [
      '${remaining.inMinutes}m',
      '${pad(remaining.inSeconds % 60)}s',
    ];
  }

  /// True once an auction is close enough that the UI should shout about it.
  static bool isClosingSoon(DateTime endTime) {
    final remaining = endTime.difference(DateTime.now());
    return !remaining.isNegative && remaining.inHours < 12;
  }
}
