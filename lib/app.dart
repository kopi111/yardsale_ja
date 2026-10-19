import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/auction_closer.dart';
import 'core/theme.dart';
import 'core/constants.dart';
import 'providers/user_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/listing_provider.dart';
import 'screens/welcome/welcome_screen.dart';
import 'screens/home_screen.dart';

class YardSaleApp extends StatefulWidget {
  const YardSaleApp({super.key});

  @override
  State<YardSaleApp> createState() => _YardSaleAppState();
}

class _YardSaleAppState extends State<YardSaleApp> with WidgetsBindingObserver {
  late final AuctionCloser _auctionCloser =
      AuctionCloser(onLotsClosed: _refreshWhatTheHammerChanged);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    context.read<UserProvider>().init();
    _auctionCloser.start();
  }

  /// A closed lot changes two things a member may be looking at right now: the
  /// floor no longer holds it, and the house has written them a notice about
  /// it. Without this the catalogue went on showing a closed lot as LIVE and
  /// the notices board stayed empty until the screen was reopened.
  void _refreshWhatTheHammerChanged() {
    if (!mounted) return;
    context.read<ListingProvider>().loadListings();
    final userId = context.read<UserProvider>().currentUser?.id;
    if (userId == null) return;
    context.read<NotificationProvider>().load(userId);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _auctionCloser.stop();
    super.dispose();
  }

  /// Time passes while the app is in the background, and lots close in it.
  /// Coming back to the foreground sweeps before anything is drawn.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _auctionCloser.sweep();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    return MaterialApp(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.themeMode,
      home: Consumer<UserProvider>(
        builder: (context, userProvider, _) {
          if (userProvider.isLoading) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (userProvider.isLoggedIn) {
            return const HomeScreen();
          }
          return const WelcomeScreen();
        },
      ),
    );
  }
}
