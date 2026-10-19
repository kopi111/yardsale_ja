import 'package:flutter/material.dart';
import '../data/models/app_notification.dart';
import '../data/repositories/notification_repository.dart';

class NotificationProvider with ChangeNotifier {
  final NotificationRepository _repo = NotificationRepository();
  List<AppNotification> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = true;

  List<AppNotification> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;

  Future<void> load(String userId) async {
    _isLoading = true;
    notifyListeners();
    try {
      _notifications = await _repo.getNotifications(userId);
      _unreadCount = await _repo.getUnreadCount(userId);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshUnreadCount(String userId) async {
    _unreadCount = await _repo.getUnreadCount(userId);
    notifyListeners();
  }

  Future<void> markAllRead(String userId) async {
    await _repo.markAllRead(userId);
    await load(userId);
  }

  void clear() {
    _notifications = [];
    _unreadCount = 0;
    _isLoading = false;
    notifyListeners();
  }
}
