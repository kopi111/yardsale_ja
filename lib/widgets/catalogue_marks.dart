import 'dart:async';

import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../core/palette.dart';
import '../core/theme.dart';

/// The lot number every auction carries through the app.
class LotMark extends StatelessWidget {
  final String lotNumber;
  final bool onInk;

  const LotMark({super.key, required this.lotNumber, this.onInk = false});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = onInk ? palette.money : palette.gold;
    return Text('LOT $lotNumber', style: AppTheme.sectionLabel(color));
  }
}

/// The lot number as it sits on a photograph: an ink tablet with gold type.
class LotBadge extends StatelessWidget {
  final String lotNumber;

  const LotBadge({super.key, required this.lotNumber});

  @override
  Widget build(BuildContext context) {
    return _Tablet(
      background: AppColors.panel.withValues(alpha: 0.92),
      child: Text(
        'LOT $lotNumber',
        style: AppTheme.sectionLabel(AppColors.goldBright),
      ),
    );
  }
}

/// The live marker as a filled pill, for use over a photograph.
class LivePill extends StatelessWidget {
  final String label;

  const LivePill({super.key, this.label = 'LIVE'});

  @override
  Widget build(BuildContext context) {
    return _Tablet(
      background: AppColors.liveRed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _BreathingDot(color: AppColors.white, size: 6),
          const SizedBox(width: 5),
          Text(label, style: AppTheme.sectionLabel(AppColors.white)),
        ],
      ),
    );
  }
}

/// How long a lot has left, worn on the photograph itself.
class TimeChip extends StatelessWidget {
  final String label;

  const TimeChip({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return _Tablet(
      background: AppColors.liveRed,
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: AppFonts.body,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: AppColors.white,
        ),
      ),
    );
  }
}

/// The count of photographs in a lot's gallery.
class GalleryCounter extends StatelessWidget {
  final int position;
  final int total;

  const GalleryCounter({
    super.key,
    required this.position,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return _Tablet(
      background: AppColors.panel.withValues(alpha: 0.72),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.photo_outlined, size: 13, color: AppColors.white),
          const SizedBox(width: 6),
          Text(
            '$position / $total',
            style: const TextStyle(
              fontFamily: AppFonts.body,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: AppColors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _Tablet extends StatelessWidget {
  final Color background;
  final Widget child;

  const _Tablet({required this.background, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppTheme.markRadius),
      ),
      child: child,
    );
  }
}

/// A section heading ruled off the way a catalogue page is.
class SectionHeading extends StatelessWidget {
  final String label;
  final String title;
  final Widget? trailing;

  const SectionHeading({
    super.key,
    required this.label,
    required this.title,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTheme.sectionLabel(context.palette.gold)),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(title, style: theme.textTheme.headlineMedium),
              ),
              ?trailing,
            ],
          ),
        ],
      ),
    );
  }
}

/// The live marker. The dot breathes so an active auction never looks static.
class LiveMark extends StatelessWidget {
  final String label;
  final Color? color;

  const LiveMark({super.key, this.label = 'LIVE', this.color});

  @override
  Widget build(BuildContext context) {
    final tone = color ?? context.palette.live;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _BreathingDot(color: tone, size: 7),
        const SizedBox(width: 6),
        Text(label, style: AppTheme.sectionLabel(tone)),
      ],
    );
  }
}

class _BreathingDot extends StatefulWidget {
  final Color color;
  final double size;

  const _BreathingDot({required this.color, required this.size});

  @override
  State<_BreathingDot> createState() => _BreathingDotState();
}

class _BreathingDotState extends State<_BreathingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 1, end: 0.25).animate(_pulse),
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      ),
    );
  }
}

/// A stat in the auction-floor strip: a big number over a hairline label, with
/// room underneath for whatever qualifies it.
class FloorStat extends StatelessWidget {
  final String value;
  final String label;
  final Color valueColor;
  final Color? labelColor;
  final Widget? note;

  const FloorStat({
    super.key,
    required this.value,
    required this.label,
    this.valueColor = AppColors.paper,
    this.labelColor,
    this.note,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: AppTheme.money(22, valueColor)),
        ),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            label,
            maxLines: 1,
            style: AppTheme.sectionLabel(labelColor ?? palette.muted),
          ),
        ),
        if (note != null) ...[
          const SizedBox(height: 5),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: note!,
          ),
        ],
      ],
    );
  }
}

/// The line of small print that qualifies a [FloorStat].
class StatNote extends StatelessWidget {
  final String text;
  final Color? color;

  const StatNote(this.text, {super.key, this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontFamily: AppFonts.body,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: color ?? context.palette.panelMuted,
      ),
    );
  }
}

/// A bordered tile carrying one measurement of a member's standing.
class StatTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color? accent;

  const StatTile({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 19, color: accent ?? palette.gold),
        const SizedBox(height: 9),
        Text(
          value,
          style: AppTheme.money(20, accent ?? palette.onSurface),
        ),
        const SizedBox(height: 5),
        Text(
          label.toUpperCase(),
          textAlign: TextAlign.center,
          style: AppTheme.sectionLabel(palette.muted),
        ),
      ],
    );
  }
}

/// The bordered panel the mockups group everything into: a hairline box on the
/// canvas, never a shadow.
class RuledPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Color? background;
  final Color? border;

  const RuledPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
    this.background,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: background ?? palette.surface,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(color: border ?? palette.hairline),
      ),
      child: child,
    );
  }
}

/// A member's initials, used wherever a photograph is not held.
class MemberInitials extends StatelessWidget {
  final String name;
  final double diameter;
  final Color? background;
  final Color? foreground;

  const MemberInitials({
    super.key,
    required this.name,
    this.diameter = 44,
    this.background,
    this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      width: diameter,
      height: diameter,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background ?? palette.panel,
        shape: BoxShape.circle,
      ),
      child: Text(
        _initialsOf(name),
        style: AppTheme.money(
          diameter * 0.34,
          foreground ?? AppColors.goldBright,
        ),
      ),
    );
  }

  static String _initialsOf(String name) {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    if (words.isEmpty) return '—';
    final letters = words.take(2).map((w) => w[0].toUpperCase());
    return letters.join();
  }
}

/// Keeps a subtree rebuilding once a second so relative times stay honest.
class Ticking extends StatefulWidget {
  final WidgetBuilder builder;

  const Ticking({super.key, required this.builder});

  @override
  State<Ticking> createState() => _TickingState();
}

class _TickingState extends State<Ticking> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}
