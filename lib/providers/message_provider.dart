import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../data/models/conversation.dart';
import '../data/models/message.dart';
import '../data/models/user.dart';
import '../data/repositories/message_repository.dart';
import '../data/repositories/user_repository.dart';

class MessageProvider with ChangeNotifier {
  final MessageRepository _messageRepo = MessageRepository();
  final UserRepository _userRepo = UserRepository();
  List<Conversation> _conversations = [];
  List<Message> _messages = [];
  int _totalUnread = 0;
  bool _isLoading = true;
  String? _activeConversationId;
  bool _activeConversationIsAutomated = false;
  final Set<Timer> _pendingReplyTimers = {};

  List<Conversation> get conversations => _conversations;
  List<Message> get messages => _messages;
  int get totalUnread => _totalUnread;
  bool get isLoading => _isLoading;

  /// True when the other side of the open conversation is a demo account.
  /// The screen says so out loud: an automatic acknowledgement dressed up as
  /// a seller's reply would be a lie about who a member is talking to.
  bool get activeConversationIsAutomated => _activeConversationIsAutomated;

  /// Demo accounts are not people. They acknowledge once, in their own name,
  /// and say plainly that nobody is reading. Passing a random line from a
  /// hardcoded list off as a seller's answer is worse than no reply at all.
  static const String _automatedAcknowledgement =
      'Automated reply — this is a demo seller account, so nobody is reading '
      'this conversation. Bidding, settlement and reviews all work for real '
      'on this lot.';

  Future<void> loadConversations(String userId) async {
    _isLoading = true;
    notifyListeners();
    await _readConversations(userId);
    _isLoading = false;
    notifyListeners();
  }

  /// Re-reads the inbox without raising the loading flag. The Inbox tab is
  /// kept alive behind the floor, so its initState runs once at startup and
  /// never again: without this a conversation started afterwards leaves the
  /// member looking at "No messages yet" while their own message sits in it.
  Future<void> refreshConversations(String userId) async {
    await _readConversations(userId);
    notifyListeners();
  }

  Future<void> _readConversations(String userId) async {
    _conversations = await _messageRepo.getConversations(userId);
    _totalUnread = await _messageRepo.getTotalUnreadCount(userId);
  }

  Future<void> loadMessages(String conversationId, String currentUserId) async {
    _activeConversationId = conversationId;
    _activeConversationIsAutomated =
        await _isAutomatedCounterparty(conversationId, currentUserId);
    _messages = await _messageRepo.getMessages(conversationId);
    await _messageRepo.markMessagesAsRead(conversationId, currentUserId);
    _totalUnread = await _messageRepo.getTotalUnreadCount(currentUserId);
    notifyListeners();
  }

  void leaveConversation() {
    _activeConversationId = null;
    _activeConversationIsAutomated = false;
  }

  Future<bool> _isAutomatedCounterparty(
      String conversationId, String currentUserId) async {
    final counterparty =
        await _counterpartyOf(conversationId, currentUserId);
    return counterparty?.isDemo ?? false;
  }

  Future<User?> _counterpartyOf(
      String conversationId, String senderId) async {
    final conversation = await _messageRepo.getConversation(conversationId);
    if (conversation == null) return null;
    final otherUserId = conversation.buyerId == senderId
        ? conversation.sellerId
        : conversation.buyerId;
    return _userRepo.getUserById(otherUserId);
  }

  Future<Conversation> getOrCreateConversation({
    required String listingId,
    required String buyerId,
    required String sellerId,
  }) async {
    final existing =
        await _messageRepo.findConversation(listingId, buyerId, sellerId);
    if (existing != null) return existing;

    final conversation = Conversation(
      id: const Uuid().v4(),
      listingId: listingId,
      buyerId: buyerId,
      sellerId: sellerId,
    );
    await _messageRepo.insertConversation(conversation);
    return conversation;
  }

  Future<void> sendMessage({
    required String conversationId,
    required String senderId,
    required String content,
  }) async {
    final message = Message(
      id: const Uuid().v4(),
      conversationId: conversationId,
      senderId: senderId,
      content: content,
    );
    await _messageRepo.insertMessage(message);
    _messages = await _messageRepo.getMessages(conversationId);
    await _readConversations(senderId);
    notifyListeners();

    // A demo account acknowledges once, so the member knows straight away
    // that the seller they are writing to is not a person.
    final otherUser = await _counterpartyOf(conversationId, senderId);
    if (otherUser == null || !otherUser.isDemo) return;
    if (_messages.any((m) => m.senderId == otherUser.id)) return;
    _scheduleAcknowledgement(conversationId, otherUser.id, senderId);
  }

  void _scheduleAcknowledgement(
      String conversationId, String demoUserId, String recipientId) {
    late final Timer timer;
    timer = Timer(const Duration(seconds: 1), () async {
      _pendingReplyTimers.remove(timer);
      final message = Message(
        id: const Uuid().v4(),
        conversationId: conversationId,
        senderId: demoUserId,
        content: _automatedAcknowledgement,
      );
      await _messageRepo.insertMessage(message);
      if (_activeConversationId == conversationId) {
        await _messageRepo.markMessagesAsRead(conversationId, recipientId);
        _messages = await _messageRepo.getMessages(conversationId);
      }
      await _readConversations(recipientId);
      notifyListeners();
    });
    _pendingReplyTimers.add(timer);
  }

  void clear() {
    for (final timer in _pendingReplyTimers) {
      timer.cancel();
    }
    _pendingReplyTimers.clear();
    _conversations = [];
    _messages = [];
    _totalUnread = 0;
    _isLoading = false;
    _activeConversationId = null;
    _activeConversationIsAutomated = false;
    notifyListeners();
  }

  Future<void> refreshUnreadCount(String userId) async {
    _totalUnread = await _messageRepo.getTotalUnreadCount(userId);
    notifyListeners();
  }
}
