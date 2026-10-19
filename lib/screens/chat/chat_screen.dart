import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../core/palette.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/models/listing.dart';
import '../../data/models/message.dart';
import '../../providers/listing_provider.dart';
import '../../providers/message_provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/catalogue_marks.dart';
import '../../widgets/listing_image_widget.dart';
import '../listing/listing_detail_screen.dart';
import '../profile/user_profile_screen.dart';

class ChatScreen extends StatefulWidget {
  final String conversationId;
  final String listingId;
  final String otherUserName;
  final String? otherUserId;
  final String? listingTitle;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.listingId,
    required this.otherUserName,
    this.otherUserId,
    this.listingTitle,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  late final MessageProvider _messageProvider;
  Listing? _listing;
  double? _correspondentRating;

  @override
  void initState() {
    super.initState();
    _messageProvider = context.read<MessageProvider>();
    _loadMessages();
    _loadListing();
    _loadCorrespondentRating();
  }

  @override
  void dispose() {
    _messageProvider.leaveConversation();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    final userId = context.read<UserProvider>().currentUser?.id;
    if (userId == null) return;
    await _messageProvider.loadMessages(widget.conversationId, userId);
    _scrollToBottom();
  }

  /// The lot is the whole reason for the conversation, so it sits at the top of
  /// it rather than being named in the app bar and left at that.
  Future<void> _loadListing() async {
    final listing =
        await context.read<ListingProvider>().getListingById(widget.listingId);
    if (!mounted) return;
    setState(() => _listing = listing);
  }

  /// A member is judged by their standing on the floor, so it travels with
  /// their name wherever the name appears.
  Future<void> _loadCorrespondentRating() async {
    final otherUserId = widget.otherUserId;
    if (otherUserId == null) return;
    final rating = await context.read<UserProvider>().getUserRating(otherUserId);
    if (!mounted) return;
    setState(() => _correspondentRating = rating);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    final userId = context.read<UserProvider>().currentUser?.id;
    if (userId == null) return;

    _messageController.clear();
    await _messageProvider.sendMessage(
      conversationId: widget.conversationId,
      senderId: userId,
      content: text,
    );
    _scrollToBottom();
  }

  void _openLot() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ListingDetailScreen(listingId: widget.listingId),
      ),
    );
  }

  void _openSellerProfile() {
    final sellerId = widget.otherUserId;
    if (sellerId == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => UserProfileScreen(userId: sellerId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final currentUserId = context.read<UserProvider>().currentUser?.id;
    final isAutomated =
        context.watch<MessageProvider>().activeConversationIsAutomated;

    return Scaffold(
      backgroundColor: palette.canvas,
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppStrings.appName.toUpperCase(),
              style: AppTheme.money(19, palette.onSurface),
            ),
            const SizedBox(height: 2),
            Text(
              AppStrings.tagline.toUpperCase(),
              style: AppTheme.sectionLabel(palette.gold),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Column(
              children: [
                if (_listing != null)
                  _LotContextCard(listing: _listing!, onTap: _openLot),
                const SizedBox(height: 12),
                _CorrespondentRow(
                  name: widget.otherUserName,
                  rating: _correspondentRating,
                  onViewProfile:
                      widget.otherUserId == null ? null : _openSellerProfile,
                ),
                const SizedBox(height: 12),
                const _SafetyBanner(),
              ],
            ),
          ),
          Expanded(
            child: Consumer<MessageProvider>(
              builder: (context, provider, _) {
                final messages = provider.messages;
                if (messages.isEmpty) return const _EmptyThread();
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final previous = index == 0 ? null : messages[index - 1];
                    return _ThreadEntry(
                      message: message,
                      previous: previous,
                      isMine: message.senderId == currentUserId,
                      correspondent: widget.otherUserName,
                    );
                  },
                );
              },
            ),
          ),
          if (isAutomated) const _AutomatedAccountNotice(),
          _Composer(
            controller: _messageController,
            onSend: _sendMessage,
          ),
        ],
      ),
    );
  }
}

/// The lot the conversation is about, kept in view the whole way down.
class _LotContextCard extends StatelessWidget {
  final Listing listing;
  final VoidCallback onTap;

  const _LotContextCard({required this.listing, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Material(
      color: palette.surface,
      borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.cardRadius),
            border: Border.all(color: palette.hairline),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.markRadius),
                child: SizedBox(
                  width: 66,
                  height: 66,
                  child: ListingImageWidget(
                    imagePaths: listing.imagePaths,
                    category: listing.category,
                    title: listing.title,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        LotBadge(
                          lotNumber: AppUtils.lotNumberFor(listing.id),
                        ),
                        const SizedBox(width: 7),
                        if (!listing.isEnded)
                          Ticking(
                            builder: (_) => TimeChip(
                              label: AppUtils.formatTimeRemaining(
                                listing.auctionEndTime,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      listing.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      listing.parish,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    listing.currentBid != null ? 'CURRENT BID' : 'STARTING BID',
                    style: AppTheme.sectionLabel(palette.muted),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    AppUtils.formatPrice(
                      listing.currentBid ?? listing.startingBid,
                    ),
                    style: AppTheme.money(17, palette.onSurface),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Who is on the other end, and the way to check them out.
class _CorrespondentRow extends StatelessWidget {
  final String name;
  final double? rating;
  final VoidCallback? onViewProfile;

  const _CorrespondentRow({
    required this.name,
    this.rating,
    this.onViewProfile,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final standing = rating;

    return Row(
      children: [
        MemberInitials(name: name, diameter: 44),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(name, style: Theme.of(context).textTheme.titleLarge),
              if (standing != null && standing > 0) ...[
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(Icons.star_rounded, size: 15, color: palette.gold),
                    const SizedBox(width: 4),
                    Text(
                      standing.toStringAsFixed(1),
                      style: TextStyle(
                        fontFamily: AppFonts.body,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: palette.muted,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        if (onViewProfile != null)
          OutlinedButton(
            onPressed: onViewProfile,
            style: OutlinedButton.styleFrom(
              foregroundColor: palette.gold,
              side: BorderSide(color: palette.gold),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: const StadiumBorder(),
              textStyle: const TextStyle(
                fontFamily: AppFonts.body,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
            child: const Text('View profile'),
          ),
      ],
    );
  }
}

class _SafetyBanner extends StatelessWidget {
  const _SafetyBanner();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return RuledPanel(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Icon(Icons.shield_outlined, size: 20, color: palette.gold),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Keep it safe on ${AppStrings.appName}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  'Never share personal details or pay outside the app.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One message, with the day printed above it the first time that day is seen.
class _ThreadEntry extends StatelessWidget {
  final Message message;
  final Message? previous;
  final bool isMine;
  final String correspondent;

  const _ThreadEntry({
    required this.message,
    required this.previous,
    required this.isMine,
    required this.correspondent,
  });

  bool get _startsNewDay {
    final earlier = previous;
    if (earlier == null) return true;
    return !AppUtils.isSameDay(earlier.createdAt, message.createdAt);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_startsNewDay) _DayDivider(date: message.createdAt),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment:
              isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            if (!isMine) ...[
              MemberInitials(name: correspondent, diameter: 30),
              const SizedBox(width: 9),
            ],
            Flexible(child: _Bubble(message: message, isMine: isMine)),
          ],
        ),
      ],
    );
  }
}

class _DayDivider extends StatelessWidget {
  final DateTime date;

  const _DayDivider({required this.date});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Expanded(child: Divider(color: palette.hairline)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              AppUtils.formatDayLabel(date),
              style: TextStyle(
                fontFamily: AppFonts.body,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: palette.muted,
              ),
            ),
          ),
          Expanded(child: Divider(color: palette.hairline)),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final Message message;
  final bool isMine;

  const _Bubble({required this.message, required this.isMine});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final background = isMine ? palette.raisedSurface : palette.surface;

    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.72,
      ),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 9),
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: palette.hairline),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(14),
          topRight: const Radius.circular(14),
          bottomLeft: Radius.circular(isMine ? 14 : 4),
          bottomRight: Radius.circular(isMine ? 4 : 14),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            message.content,
            style: TextStyle(
              fontFamily: AppFonts.body,
              fontSize: 14.5,
              height: 1.4,
              color: palette.onSurface,
            ),
          ),
          const SizedBox(height: 5),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AppUtils.formatTimeOfDay(message.createdAt),
                style: TextStyle(
                  fontFamily: AppFonts.body,
                  fontSize: 10.5,
                  color: palette.muted,
                ),
              ),
              if (isMine) ...[
                const SizedBox(width: 5),
                Icon(
                  message.isRead ? Icons.done_all : Icons.done,
                  size: 13,
                  color: message.isRead ? palette.gold : palette.muted,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyThread extends StatelessWidget {
  const _EmptyThread();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          'Ask the seller anything about the lot.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;

  const _Composer({required this.controller, required this.onSend});

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
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  textCapitalization: TextCapitalization.sentences,
                  onSubmitted: (_) => onSend(),
                  decoration: InputDecoration(
                    hintText: 'Type a message…',
                    filled: true,
                    fillColor: palette.surface,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    border: _pill(palette.hairline),
                    enabledBorder: _pill(palette.hairline),
                    focusedBorder: _pill(palette.amber),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Material(
                color: palette.amber,
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: onSend,
                  customBorder: const CircleBorder(),
                  child: SizedBox(
                    width: 46,
                    height: 46,
                    child: Icon(
                      Icons.send_rounded,
                      size: 20,
                      color: palette.onAmber,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  OutlineInputBorder _pill(Color color) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppTheme.pillRadius),
      borderSide: BorderSide(color: color),
    );
  }
}

/// Says who a member is actually writing to. A demo seller cannot answer a
/// question about the lot, and letting a member believe otherwise while they
/// wait for a reply is the dishonest part, not the demo data itself.
class _AutomatedAccountNotice extends StatelessWidget {
  const _AutomatedAccountNotice();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(color: palette.hairline),
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      ),
      child: Row(
        children: [
          Icon(Icons.smart_toy_outlined, size: 19, color: palette.muted),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Demo seller account',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  'Replies here are automatic and nobody reads what you send.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
