import 'package:flutter/material.dart';

/// The YardSale JA palette is an auction-catalogue palette: warm paper stock,
/// heavy ink, gold reserved for money and red reserved for anything live.
class AppColors {
  // Paper — the surfaces a catalogue is printed on.
  static const Color paper = Color(0xFFF7F3EC);
  static const Color card = Color(0xFFFDFBF7);
  static const Color background = paper;
  static const Color white = Color(0xFFFFFFFF);
  static const Color lightGrey = Color(0xFFEFEADF);

  // Ink — display type, rules and the dark auction-floor panels.
  static const Color ink = Color(0xFF14130F);
  static const Color panel = Color(0xFF1A1917);
  static const Color inkSoft = Color(0xFF4A4640);
  static const Color black = ink;
  static const Color darkGrey = inkSoft;
  static const Color grey = Color(0xFF8A8378);
  static const Color hairline = Color(0xFFE2DCCE);

  // Night — the auction room after the lights go down.
  static const Color nightCanvas = Color(0xFF101010);
  static const Color nightSurface = Color(0xFF1A1A1A);
  static const Color nightRaised = Color(0xFF232322);
  static const Color nightRule = Color(0xFF2E2D2B);
  static const Color nightInk = Color(0xFFF2EFE9);
  static const Color nightGrey = Color(0xFF9C9690);

  // Gold is money. Three weights: one legible on paper, one that glows on ink,
  // and the amber a call to action is filled with.
  static const Color gold = Color(0xFFB0842C);
  static const Color goldBright = Color(0xFFE7AC49);
  static const Color amber = Color(0xFFDFA84C);

  // Jamaica green carries confirmation and winning bids.
  static const Color green = Color(0xFF0A6E43);
  static const Color greenBright = Color(0xFF35B47C);
  static const Color bidGreen = green;
  static const Color teal = ink;
  static const Color violet = ink;

  // Red is spent only on urgency: live auctions, closing soon, destruction.
  static const Color liveRed = Color(0xFFD8483A);
  static const Color red = Color(0xFFC0392B);
}

/// Type roles. [display] is the expanded cut used for money and headlines;
/// [body] carries everything a user reads at length.
class AppFonts {
  static const String display = 'ArchivoExp';
  static const String body = 'Archivo';
}

/// The saleroom's vocabulary. Every screen takes its wording from here, so a
/// menu row and the screen it opens cannot end up calling the same thing by
/// two different names.
class AppStrings {
  static const String appName = 'YardSale JA';
  static const String tagline = "Jamaica's Auction House";
  static const String currency = 'J\$';
  static const String welcomeTitle = 'Welcome to YardSale JA';
  static const String welcomeSubtitle = 'Bid on lots across Jamaica';
  static const String getStarted = 'Get Started';

  // The five places a member can stand.
  static const String floor = 'Floor';
  static const String search = 'Search';
  static const String sell = 'Consign';
  static const String inbox = 'Inbox';
  static const String profile = 'Profile';

  // The member's own record.
  static const String settings = 'Settings';
  static const String notices = 'Notices';
  static const String savedLots = 'Saved lots';
  static const String myListings = 'My auctions';
  static const String settlements = 'Settlements';

  // Nothing here yet.
  static const String noListings = 'No auctions yet';
  static const String noMessages = 'No messages yet';
  static const String noSavedLots = 'No saved lots yet';
  static const String noSettlements = 'No settlements yet';

  // Bidding.
  static const String placeBid = 'Place Bid';
  static const String startingBid = 'Starting Bid';
  static const String currentBid = 'Current Bid';
  static const String timeLeft = 'Time Left';
  static const String auctionEnded = 'Auction Ended';
}

class AppCategories {
  static const String allCategoryId = 'all';

  static const List<Map<String, dynamic>> categories = [
    {'id': 'all', 'name': 'All', 'icon': Icons.grid_view},
    {'id': 'electronics', 'name': 'Electronics', 'icon': Icons.devices},
    {'id': 'vehicles', 'name': 'Vehicles', 'icon': Icons.directions_car},
    {'id': 'clothing', 'name': 'Clothing', 'icon': Icons.checkroom},
    {'id': 'furniture', 'name': 'Furniture', 'icon': Icons.chair},
    {'id': 'phones', 'name': 'Phones', 'icon': Icons.phone_android},
    {'id': 'books', 'name': 'Books', 'icon': Icons.menu_book},
    {'id': 'sports', 'name': 'Sports', 'icon': Icons.sports_basketball},
    {'id': 'home_garden', 'name': 'Home & Garden', 'icon': Icons.home},
    {'id': 'services', 'name': 'Services', 'icon': Icons.build},
    {'id': 'other', 'name': 'Other', 'icon': Icons.more_horiz},
  ];

  static List<Map<String, dynamic>> get selectableCategories =>
      categories.where((category) => category['id'] != allCategoryId).toList();

  /// The display name behind a stored category id. Screens read lots straight
  /// out of the database, so without this they print the key itself.
  static String labelFor(String categoryId) {
    for (final category in categories) {
      if (category['id'] == categoryId) return category['name'] as String;
    }
    return 'Other';
  }
}

/// The rules a bid is held to, in one place: the repository enforces them and
/// the paddle screen explains them, and both must mean the same thing.
class AppBidding {
  /// The smallest raise the house accepts over the standing bid.
  static const double minimumIncrement = 1;

  /// No lot on this floor is worth a billion Jamaican dollars. A bid above
  /// this is a typo or a prank, and once accepted it locks the auction.
  static const double maximumBid = 1000000000;

  /// A bid this many times the standing price is confirmed before it is sent.
  static const double outsizedBidMultiple = 10;
}

class AppParishes {
  static const List<String> parishes = [
    'Kingston',
    'St. Andrew',
    'St. Thomas',
    'Portland',
    'St. Mary',
    'St. Ann',
    'Trelawny',
    'St. James',
    'Hanover',
    'Westmoreland',
    'St. Elizabeth',
    'Manchester',
    'Clarendon',
    'St. Catherine',
  ];
}

class AppConditions {
  static const List<String> conditions = [
    'New',
    'Like New',
    'Good',
    'Fair',
    'For Parts',
  ];
}

class AppPaymentMethods {
  static const List<String> methods = [
    'Cash on Pickup',
    'Bank Transfer',
    'Lynk',
  ];
}

class AppDurations {
  static const List<Map<String, dynamic>> auctionDurations = [
    {'label': '1 Day', 'days': 1},
    {'label': '3 Days', 'days': 3},
    {'label': '7 Days', 'days': 7},
    {'label': '14 Days', 'days': 14},
  ];
}
