import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../core/palette.dart';
import '../core/theme.dart';
import '../providers/message_provider.dart';
import '../providers/user_provider.dart';
import 'browse/browse_screen.dart';
import 'search/search_screen.dart';
import 'listing/create_listing_screen.dart';
import 'chat/conversations_screen.dart';
import 'profile/profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const int _sellTabIndex = 2;

  int _currentIndex = 0;
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      BrowseScreen(onSearchTap: () => setState(() => _currentIndex = 1)),
      const SearchScreen(),
      const SizedBox.shrink(),
      const ConversationsScreen(),
      const ProfileScreen(),
    ];
    final userId = context.read<UserProvider>().currentUser?.id;
    if (userId != null) {
      context.read<MessageProvider>().refreshUnreadCount(userId);
    }
  }

  void _onTabTapped(int index) {
    if (index == _sellTabIndex) {
      _openCreateListing();
      return;
    }
    setState(() => _currentIndex = index);
  }

  void _openCreateListing() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateListingScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = context.watch<MessageProvider>().totalUnread;

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: _FloorBar(
        currentIndex: _currentIndex,
        unreadCount: unreadCount,
        onTap: _onTabTapped,
      ),
    );
  }
}

/// The navigation rail along the bottom of the auction floor: the floor's own
/// paper, ruled off at the top, with the gavel sitting proud in the middle.
class _FloorBar extends StatelessWidget {
  static const double _barHeight = 68;

  final int currentIndex;
  final int unreadCount;
  final ValueChanged<int> onTap;

  const _FloorBar({
    required this.currentIndex,
    required this.unreadCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      decoration: BoxDecoration(
        color: palette.canvas,
        border: Border(top: BorderSide(color: palette.hairline)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: _barHeight,
          child: Row(
            children: [
              _tab(context, 0, Icons.gavel_rounded, 'FLOOR'),
              _tab(context, 1, Icons.search_rounded, 'SEARCH'),
              Expanded(child: _SellButton(onTap: () => onTap(2))),
              _tab(
                context,
                3,
                Icons.forum_outlined,
                'INBOX',
                badgeCount: unreadCount,
              ),
              _tab(context, 4, Icons.person_outline_rounded, 'PROFILE'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tab(
    BuildContext context,
    int index,
    IconData icon,
    String label, {
    int badgeCount = 0,
  }) {
    final palette = context.palette;
    final isSelected = currentIndex == index;
    final color = isSelected ? palette.gold : palette.muted;

    return Expanded(
      child: InkWell(
        onTap: () => onTap(index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _IconWithBadge(icon: icon, color: color, badgeCount: badgeCount),
            const SizedBox(height: 5),
            Text(label, style: AppTheme.sectionLabel(color)),
          ],
        ),
      ),
    );
  }
}

class _IconWithBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final int badgeCount;

  const _IconWithBadge({
    required this.icon,
    required this.color,
    required this.badgeCount,
  });

  @override
  Widget build(BuildContext context) {
    final glyph = Icon(icon, size: 22, color: color);
    if (badgeCount <= 0) return glyph;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        glyph,
        Positioned(
          top: -5,
          right: -9,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1),
            constraints: const BoxConstraints(minWidth: 16),
            decoration: BoxDecoration(
              color: AppColors.liveRed,
              shape: BoxShape.circle,
            ),
            child: Text(
              badgeCount > 9 ? '9+' : '$badgeCount',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The gavel: the one round, filled thing in an app built out of rules.
class _SellButton extends StatelessWidget {
  static const double _diameter = 50;

  final VoidCallback onTap;

  const _SellButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: palette.amber,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: _diameter,
              height: _diameter,
              child: Icon(Icons.add, size: 25, color: palette.onAmber),
            ),
          ),
        ),
        const SizedBox(height: 3),
        Text('SELL', style: AppTheme.sectionLabel(palette.onSurface)),
      ],
    );
  }
}
