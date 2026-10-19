import 'dart:async';

import 'package:flutter/foundation.dart';
import '../data/repositories/listing_repository.dart';

/// Closes auctions whose time is up, whether or not anybody is looking.
///
/// Settlement used to run only where a screen happened to call it, so a lot
/// could finish at 3am and stay "active" with its winner unsettled until
/// somebody opened Browse. The house closes its own lots.
class AuctionCloser {
  static const Duration defaultInterval = Duration(seconds: 30);

  final ListingRepository _repo;
  final Duration _interval;
  final VoidCallback? _onLotsClosed;
  Timer? _timer;

  AuctionCloser({
    ListingRepository? repository,
    Duration interval = defaultInterval,
    VoidCallback? onLotsClosed,
  })  : _repo = repository ?? ListingRepository(),
        _interval = interval,
        _onLotsClosed = onLotsClosed;

  bool get isRunning => _timer != null;

  /// Sweeps once immediately — the app may have been shut while lots ran out —
  /// and then on every tick.
  void start() {
    if (_timer != null) return;
    unawaited(sweep());
    _timer = Timer.periodic(_interval, (_) => sweep());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Closes and settles everything past its close time, and says so when it
  /// did. A member sitting on their notices should not have to leave the
  /// screen and come back to learn they just won a lot. A failed sweep is
  /// logged and left for the next tick rather than taking the app down.
  Future<void> sweep() async {
    try {
      final closed = await _repo.endExpiredAuctions();
      if (closed > 0) _onLotsClosed?.call();
    } catch (error) {
      debugPrint('Auction sweep failed: $error');
    }
  }
}
