import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../data/database/database_helper.dart';
import '../../providers/theme_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/listing_provider.dart';
import '../../providers/search_provider.dart';
import '../../providers/message_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/notification_provider.dart';
import '../welcome/welcome_screen.dart';
import '../../core/palette.dart';
import '../../core/theme.dart';
import '../../widgets/catalogue_marks.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return Scaffold(
      backgroundColor: context.palette.canvas,
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Text('THE HOUSE', style: AppTheme.sectionLabel(context.palette.gold)),
          const SizedBox(height: 12),
          _SettingRow(
            icon: themeProvider.isDarkMode
                ? Icons.dark_mode_outlined
                : Icons.light_mode_outlined,
            title: 'Night saleroom',
            detail: 'Dim the house lights',
            trailing: Switch(
              value: themeProvider.isDarkMode,
              onChanged: (_) => themeProvider.toggleTheme(),
            ),
          ),
          const SizedBox(height: 12),
          _SettingRow(
            icon: Icons.refresh_rounded,
            title: 'Restock the floor',
            detail: 'Clear unsold demo lots and put a fresh set up',
            onTap: () => _showResetDialog(context, resetDemoOnly: true),
          ),
          const SizedBox(height: 12),
          _SettingRow(
            icon: Icons.delete_outline_rounded,
            title: 'Clear everything',
            detail: 'Delete your record and start over',
            isDestructive: true,
            onTap: () => _showResetDialog(context, resetDemoOnly: false),
          ),
          const SizedBox(height: 32),
          Center(
            child: Column(
              children: [
                Text(AppStrings.appName.toUpperCase(),
                    style: AppTheme.sectionLabel(context.palette.muted)),
                const SizedBox(height: 6),
                Text(AppStrings.tagline,
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 2),
                Text('VERSION 1.0.0',
                    style: AppTheme.sectionLabel(context.palette.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showResetDialog(BuildContext context, {required bool resetDemoOnly}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(resetDemoOnly ? 'Reset Demo Data?' : 'Clear All Data?'),
        content: Text(resetDemoOnly
            ? 'Unsold demo lots are cleared and a fresh set is put on the '
                'floor. Lots you bid on, won, saved or messaged about stay '
                'exactly as they are, and so do your purchases and reviews.'
            : 'This will delete ALL data including your profile, your bids, '
                'your purchases and your reviews. You will need to set up '
                'again. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              if (resetDemoOnly) {
                await _resetDemoData(context);
              } else {
                await _clearAllData(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: resetDemoOnly ? AppColors.green : AppColors.red,
            ),
            child: Text(resetDemoOnly ? 'Reset' : 'Clear Everything'),
          ),
        ],
      ),
    );
  }

  Future<void> _resetDemoData(BuildContext context) async {
    await DatabaseHelper.instance.resetDemoData();
    if (!context.mounted) return;
    _clearProviders(context);
    await context.read<UserProvider>().init();
    if (!context.mounted) return;
    await context.read<ListingProvider>().loadListings();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Demo data reset!'),
        backgroundColor: AppColors.green,
      ),
    );
  }

  Future<void> _clearAllData(BuildContext context) async {
    await DatabaseHelper.instance.resetDatabase();
    if (!context.mounted) return;
    _clearProviders(context);
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (_) => false,
    );
  }

  void _clearProviders(BuildContext context) {
    context.read<UserProvider>().clear();
    context.read<ListingProvider>().clear();
    context.read<SearchProvider>().clear();
    context.read<MessageProvider>().clear();
    context.read<TransactionProvider>().clear();
    context.read<NotificationProvider>().clear();
  }
}

/// One switch or one door out of the settings panel, ruled like every other
/// panel in the house.
class _SettingRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String detail;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool isDestructive;

  const _SettingRow({
    required this.icon,
    required this.title,
    required this.detail,
    this.trailing,
    this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tint = isDestructive ? palette.live : palette.onSurface;

    return InkWell(
      onTap: onTap,
      child: RuledPanel(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, size: 21, color: tint),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(color: tint),
                  ),
                  const SizedBox(height: 2),
                  Text(detail, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            ?trailing,
            if (trailing == null && onTap != null)
              Icon(Icons.chevron_right, color: palette.muted),
          ],
        ),
      ),
    );
  }
}
