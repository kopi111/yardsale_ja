import 'dart:async';

import 'package:flutter/material.dart';
import '../core/palette.dart';
import '../core/theme.dart';
import '../core/utils.dart';

/// A countdown that ticks every second, so an auction visibly runs out of time
/// instead of freezing at whatever the clock read when the screen was built.
class LiveCountdown extends StatefulWidget {
  final DateTime endTime;
  final double size;
  final bool onInk;

  const LiveCountdown({
    super.key,
    required this.endTime,
    this.size = 15,
    this.onInk = false,
  });

  @override
  State<LiveCountdown> createState() => _LiveCountdownState();
}

class _LiveCountdownState extends State<LiveCountdown> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), _onTick);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _onTick(Timer timer) {
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final parts = AppUtils.timeRemainingParts(widget.endTime);
    if (parts.isEmpty) return _endedLabel();

    final palette = context.palette;
    final urgent = AppUtils.isClosingSoon(widget.endTime);
    final color = urgent
        ? palette.live
        : (widget.onInk ? palette.onPanel : palette.onSurface);

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        for (final part in parts)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Text(
              part,
              style: AppTheme.money(widget.size, color),
            ),
          ),
      ],
    );
  }

  Widget _endedLabel() {
    return Text(
      'CLOSED',
      style: AppTheme.sectionLabel(
        widget.onInk ? context.palette.panelMuted : context.palette.muted,
      ),
    );
  }
}
