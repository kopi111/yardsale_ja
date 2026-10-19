import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../core/palette.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/models/conversation.dart';
import '../../providers/message_provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/catalogue_marks.dart';
import '../../widgets/listing_image_widget.dart';
import 'chat_screen.dart';

/// Every thread the member has open, filed by the lot it is about. A message
/// in this house is always about something under the hammer, so the lot leads
/// the row and the person follows it.
class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({super.key});

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  @override
  void initState() {
    super.initState();
    // Notifying listeners while the first frame is still building throws;
    // defer the load until the frame is on screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadConversations();
    });
  }

  Future<void> _loadConversations() async {
    final userId = context.read<UserProvider>().currentUser?.id;
    if (userId != null) {
      await context.read<MessageProvider>().loadConversations(userId);
    }
  }

  void _openThread(Conversation conversation, String? viewerId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          conversationId: conversation.id,
          listingId: conversation.listingId,
          otherUserName: conversation.otherUserName ?? 'User',
          otherUserId: viewerId == null
              ? null
              : conversation.otherParticipantId(viewerId),
          listingTitle: conversation.listingTitle,
        ),
      ),
    ).then((_) => _loadConversations());
  }

  @override
  Widget build(BuildContext context) {
    final viewerId = context.watch<UserProvider>().currentUser?.id;
    final palette = context.palette;

    return Scaffold(
      backgroundColor: palette.canvas,
      body: SafeArea(
        bottom: false,
        child: Consumer<MessageProvider>(
          builder: (context, provider, _) {
            return RefreshIndicator(
              onRefresh: _loadConversations,
              color: palette.amber,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                children: [
                  const _InboxMasthead(),
                  const SizedBox(height: 18),
                  if (provider.isLoading)
                    Padding(
                      padding: const EdgeInsets.only(top: 80),
                      child: Center(
                        child: CircularProgressIndicator(color: palette.amber),
                      ),
                    )
                  else if (provider.conversations.isEmpty)
                    const _EmptyInbox()
                  else
                    ...provider.conversations.map(
                      (conversation) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _ThreadCard(
                          conversation: conversation,
                          onTap: () => _openThread(conversation, viewerId),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// The masthead every top-level screen in the house wears.
class _InboxMasthead extends StatelessWidget {
  const _InboxMasthead();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final unread = context.watch<MessageProvider>().conversations.fold<int>(
          0,
          (sum, conversation) => sum + conversation.unreadCount,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('INBOX', style: AppTheme.money(32, palette.onSurface)),
        const SizedBox(height: 4),
        Text(
          unread > 0
              ? AppUtils.countOf(unread, 'unread message').toUpperCase()
              : 'YOUR THREADS, LOT BY LOT',
          style: AppTheme.sectionLabel(palette.gold),
        ),
      ],
    );
  }
}

/// One thread: the lot it concerns, who is on the other end, and the last
/// thing either of them said.
class _ThreadCard extends StatelessWidget {
  final Conversation conversation;
  final VoidCallback onTap;

  const _ThreadCard({required this.conversation, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isUnread = conversation.unreadCount > 0;

    return Material(
      color: palette.surface,
      borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(
              color: isUnread ? palette.gold : palette.hairline,
            ),
            borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _LotThumbnail(conversation: conversation),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            conversation.otherUserName ?? 'Unknown member',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (conversation.lastMessageAt != null)
                          Text(
                            AppUtils.formatChatTime(conversation.lastMessageAt!),
                            style: TextStyle(
                              fontFamily: AppFonts.body,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: isUnread ? palette.gold : palette.muted,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        LotMark(
                          lotNumber:
                              AppUtils.lotNumberFor(conversation.listingId),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            conversation.listingTitle ?? 'Withdrawn lot',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                    if (conversation.lastMessage != null) ...[
                      const SizedBox(height: 7),
                      Text(
                        conversation.lastMessage!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppFonts.body,
                          fontSize: 13,
                          height: 1.35,
                          fontWeight:
                              isUnread ? FontWeight.w700 : FontWeight.w500,
                          color: isUnread ? palette.onSurface : palette.muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (isUnread) ...[
                const SizedBox(width: 10),
                _UnreadCount(count: conversation.unreadCount),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The lot's photograph, small, so a thread is recognised before it is read.
class _LotThumbnail extends StatelessWidget {
  static const double _size = 58;

  final Conversation conversation;

  const _LotThumbnail({required this.conversation});

  @override
  Widget build(BuildContext context) {
    final title = conversation.listingTitle;
    if (title == null) {
      return MemberInitials(
        name: conversation.otherUserName ?? 'Unknown member',
        diameter: _size,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.fieldRadius),
      child: SizedBox(
        width: _size,
        height: _size,
        child: ListingImageWidget(
          imagePaths: conversation.listingImagePath == null
              ? const []
              : [conversation.listingImagePath!],
          category: '',
          title: title,
        ),
      ),
    );
  }
}

/// How many messages are waiting, worn as a gold paddle number.
class _UnreadCount extends StatelessWidget {
  final int count;

  const _UnreadCount({required this.count});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: palette.amber, shape: BoxShape.circle),
      child: Text(
        count > 9 ? '9+' : '$count',
        style: AppTheme.money(12, palette.onAmber),
      ),
    );
  }
}

class _EmptyInbox extends StatelessWidget {
  const _EmptyInbox();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: RuledPanel(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 34),
        child: Column(
          children: [
            Icon(Icons.forum_outlined, size: 34, color: palette.muted),
            const SizedBox(height: 16),
            Text(
              AppStrings.noMessages,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Ask a question on any lot and the thread opens here.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
