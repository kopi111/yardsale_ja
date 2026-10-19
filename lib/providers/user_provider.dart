import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../data/models/user.dart';
import '../data/repositories/user_repository.dart';

class UserProvider with ChangeNotifier {
  final UserRepository _repo = UserRepository();
  User? _currentUser;
  bool _isLoading = true;

  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _currentUser != null;

  Future<void> init() async {
    try {
      _currentUser = await _repo.getCurrentUser();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clear() {
    _currentUser = null;
    _isLoading = false;
    notifyListeners();
  }

  Future<void> createProfile({
    required String name,
    required String email,
    required String phone,
    required String parish,
    String? avatarPath,
  }) async {
    final user = User(
      id: const Uuid().v4(),
      name: name,
      email: email,
      phone: phone,
      parish: parish,
      avatarPath: avatarPath,
      isCurrent: true,
    );
    await _repo.createUser(user);
    _currentUser = user;
    notifyListeners();
  }

  Future<void> updateProfile({
    String? name,
    String? email,
    String? phone,
    String? parish,
    String? avatarPath,
  }) async {
    if (_currentUser == null) return;
    final updated = _currentUser!.copyWith(
      name: name,
      email: email,
      phone: phone,
      parish: parish,
      avatarPath: avatarPath,
    );
    await _repo.updateUser(updated);
    _currentUser = updated;
    notifyListeners();
  }

  Future<User?> getUserById(String id) async {
    return _repo.getUserById(id);
  }

  // SECURITY (BUG-035): getUserById returns the full record including email and
  // phone. When showing another member's profile, callers must not expose that
  // PII. getPublicProfile strips contact fields so cross-user views leak only
  // public attributes (name, parish, avatar).
  Future<User?> getPublicProfile(String id) async {
    final user = await _repo.getUserById(id);
    if (user == null) return null;
    if (user.id == _currentUser?.id) return user;
    return user.copyWith(email: '', phone: '');
  }

  Future<int> getUserListingCount(String userId) async {
    return _repo.getUserListingCount(userId);
  }

  Future<double> getUserRating(String userId) async {
    return _repo.getUserRating(userId);
  }
}
