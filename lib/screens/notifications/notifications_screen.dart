import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../core/palette.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/models/app_notification.dart';
import '../../providers/notification_provider.dart';
import '../../providers/user_provider.dart';
import '../listing/listing_detail_screen.dart';

/// What the house has told this member: lots they lost the lead on, lots they
/// won, lots that sold, and money that changed hands.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final userId = context.read<UserProvider>().currentUser?.id;
      if (userId == null) return;
      context.read<NotificationProvider>().markAllRead(userId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.palette.canvas,
      appBar: AppBar(title: const Text('NOTICES')),
      body: Consumer<NotificationProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return Center(
              child: CircularProgressIndicator(color: context.palette.amber),
            );
          }
          if (provider.notifications.isEmpty) return const _EmptyBoard();
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: provider.notifications.length,
            itemBuilder: (_, index) => _NoticeRow(
              notification: provider.notifications[index],
              onTap: () => _openLot(provider.notifications[index]),
            ),
          );
        },
      ),
    );
  }

  void _openLot(AppNotification notification) {
    final listingId = notification.listingId;
    if (listingId == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ListingDetailScreen(listingId: listingId),
      ),
    );
  }
}

class _EmptyBoard extends StatelessWidget {
  const _EmptyBoard();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.notifications_none,
              size: 64, color: AppColors.grey.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          const Text('Nothing to report',
              style: TextStyle(color: AppColors.grey, fontSize: 16)),
          const SizedBox(height: 8),
          const Text('Bid on a lot and the house will keep you posted.',
              style: TextStyle(color: AppColors.grey, fontSize: 13)),
        ],
      ),
    );
  }
}

class _NoticeRow extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;

  const _NoticeRow({required this.notification, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: notification.listingId == null ? null : onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: context.palette.hairline)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(_glyph, size: 20, color: _tone),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(notification.title,
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text(notification.body,
                      style: const TextStyle(fontSize: 13.5, height: 1.45)),
                  const SizedBox(height: 6),
                  Text(
                    AppUtils.formatChatTime(notification.createdAt)
                        .toUpperCase(),
                    style: AppTheme.sectionLabel(AppColors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData get _glyph {
    switch (notification.kind) {
      case NotificationKinds.outbid:
        return Icons.trending_up;
      case NotificationKinds.won:
        return Icons.gavel_rounded;
      case NotificationKinds.sold:
        return Icons.sell_outlined;
      case NotificationKinds.paymentRecorded:
        return Icons.receipt_long;
      case NotificationKinds.saleCompleted:
        return Icons.check_circle_outline;
      default:
        return Icons.campaign_outlined;
    }
  }

  Color get _tone {
    switch (notification.kind) {
      case NotificationKinds.outbid:
        return AppColors.liveRed;
      case NotificationKinds.won:
      case NotificationKinds.saleCompleted:
        return AppColors.green;
      default:
        return AppColors.gold;
    }
  }
}
