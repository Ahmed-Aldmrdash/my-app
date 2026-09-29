import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

Color subjectColor(Subject? s, BuildContext context) =>
    s == null ? Theme.of(context).colorScheme.primary : Color(s.colorValue);

/// Screens at least this wide get the desktop layout.
const wideLayoutWidth = 840.0;

/// Content never gets wider than this on big screens.
const maxContentWidth = 880.0;

Future<T?> pushPage<T>(BuildContext context, Widget page) => Navigator.of(
  context,
).push<T>(MaterialPageRoute(builder: (_) => ReadableWidth(child: page)));

/// Centers [child] with a comfortable width on computer screens.
class ReadableWidth extends StatelessWidget {
  const ReadableWidth({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).width <= maxContentWidth) return child;
    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: maxContentWidth),
          child: child,
        ),
      ),
    );
  }
}

void showSnack(BuildContext context, String message, {VoidCallback? onUndo}) {
  final messenger = ScaffoldMessenger.of(context);
  final wide = MediaQuery.sizeOf(context).width >= wideLayoutWidth;
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      // A phone-wide bar looks lost across a computer screen.
      width: wide ? 520 : null,
      content: Text(message),
      action: onUndo == null
          ? null
          : SnackBarAction(label: 'تراجع', onPressed: onUndo),
    ),
  );
}

Future<bool> confirmDelete(
  BuildContext context,
  String title, {
  String? message,
  String confirmLabel = 'حذف',
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: Icon(
        Icons.delete_outline_rounded,
        color: Theme.of(ctx).colorScheme.error,
      ),
      title: Text(title, textAlign: TextAlign.center),
      content: message == null
          ? null
          : Text(message, textAlign: TextAlign.center),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: const Size(100, 44),
            backgroundColor: Theme.of(ctx).colorScheme.error,
            foregroundColor: Theme.of(ctx).colorScheme.onError,
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// Parses numbers typed with Arabic or Latin digits ("٨٫٥", "8,5", "8.5").
double? parseNumber(String input) {
  const arabic = '٠١٢٣٤٥٦٧٨٩';
  final buf = StringBuffer();
  for (final ch in input.trim().split('')) {
    final i = arabic.indexOf(ch);
    if (i >= 0) {
      buf.write(i);
    } else if (ch == '٫' || ch == ',' || ch == '،') {
      buf.write('.');
    } else {
      buf.write(ch);
    }
  }
  return double.tryParse(buf.toString());
}

/// Rebuilds its child every [interval] so countdowns stay fresh.
class NowBuilder extends StatefulWidget {
  const NowBuilder({
    super.key,
    required this.builder,
    this.interval = const Duration(seconds: 30),
  });

  final Widget Function(BuildContext context, DateTime now) builder;
  final Duration interval;

  @override
  State<NowBuilder> createState() => _NowBuilderState();
}

class _NowBuilderState extends State<NowBuilder> {
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(widget.interval, (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, DateTime.now());
}

/// The app's card: rounded, white (or dark) with a soft violet shadow.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = const EdgeInsets.symmetric(vertical: 6),
    this.onTap,
    this.color,
    this.gradient,
    this.radius = 22,
    this.clip = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;
  final Color? color;
  final Gradient? gradient;
  final double radius;

  /// Clip children to the rounded shape (for edge-to-edge content).
  final bool clip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final shape = BorderRadius.circular(radius);
    final shadowColor = gradient != null
        ? (gradient!.colors.first).withValues(alpha: dark ? 0.25 : 0.32)
        : AppColors.primary.withValues(alpha: dark ? 0 : 0.07);
    return Padding(
      padding: margin,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: gradient == null
              ? (color ?? theme.colorScheme.surfaceContainerLowest)
              : null,
          gradient: gradient,
          borderRadius: shape,
          border: dark && gradient == null && color == null
              ? Border.all(color: Colors.white.withValues(alpha: 0.05))
              : null,
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              blurRadius: gradient != null ? 22 : 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: shape,
          clipBehavior: clip || onTap != null ? Clip.antiAlias : Clip.none,
          child: InkWell(
            onTap: onTap,
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}

/// A rounded tinted square holding an icon.
class IconBadge extends StatelessWidget {
  const IconBadge(
    this.icon, {
    super.key,
    required this.color,
    this.size = 44,
    this.filled = false,
  });

  final IconData icon;
  final Color color;
  final double size;

  /// Solid background with a white icon instead of a light tint.
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: filled ? color : color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Icon(
        icon,
        color: filled ? Colors.white : color,
        size: size * 0.52,
      ),
    );
  }
}

/// Circular progress with round caps and optional centre content.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.value,
    this.size = 64,
    this.stroke = 7,
    this.color,
    this.trackColor,
    this.child,
  });

  final double value;
  final double size;
  final double stroke;
  final Color? color;
  final Color? trackColor;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: value.clamp(0, 1).toDouble()),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        builder: (context, v, _) => CustomPaint(
          painter: _RingPainter(
            value: v,
            stroke: stroke,
            color: c,
            track: trackColor ?? c.withValues(alpha: 0.15),
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.value,
    required this.stroke,
    required this.color,
    required this.track,
  });

  final double value;
  final double stroke;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(stroke / 2);
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;
    canvas.drawArc(arcRect, 0, math.pi * 2, false, trackPaint);
    if (value <= 0) return;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(arcRect, -math.pi / 2, math.pi * 2 * value, false, paint);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.color != color || old.track != track;
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
    this.color,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = color ?? theme.colorScheme.primary;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c.withValues(alpha: 0.08),
              ),
              alignment: Alignment.center,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      c.withValues(alpha: 0.22),
                      c.withValues(alpha: 0.10),
                    ],
                  ),
                ),
                child: Icon(icon, size: 40, color: c),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(
                message!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[const SizedBox(height: 18), action!],
          ],
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(
    this.title, {
    super.key,
    this.trailing,
    this.padding,
    this.icon,
  });

  final String title;
  final Widget? trailing;
  final EdgeInsetsGeometry? padding;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: padding ?? const EdgeInsetsDirectional.fromSTEB(4, 22, 0, 6),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// A "see all" style link used next to section titles.
class SeeAllButton extends StatelessWidget {
  const SeeAllButton(this.label, {super.key, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          const SizedBox(width: 2),
          const Icon(Icons.chevron_left_rounded, size: 20),
        ],
      ),
    );
  }
}

/// A small pill showing the subject's colour and name.
class SubjectChip extends StatelessWidget {
  const SubjectChip(this.subject, {super.key});

  final Subject? subject;

  @override
  Widget build(BuildContext context) {
    if (subject == null) return const SizedBox.shrink();
    final color = Color(subject!.colorValue);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(radius: 4, backgroundColor: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              subject!.name,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// A coloured pill with a short text, e.g. a countdown or a status.
class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, required this.color, this.icon});

  final String text;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Countdown pill coloured by urgency.
class CountdownPill extends StatelessWidget {
  const CountdownPill({super.key, required this.due, required this.now});

  final DateTime due;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final diff = due.difference(now);
    final Color color;
    if (diff.isNegative) {
      color = AppColors.danger;
    } else if (diff.inHours < 24) {
      color = AppColors.coral;
    } else if (diff.inDays < 3) {
      color = AppColors.orange;
    } else {
      color = Theme.of(context).colorScheme.primary;
    }
    return Pill(
      countdownText(due, now),
      color: color,
      icon: diff.isNegative
          ? Icons.warning_amber_rounded
          : Icons.hourglass_bottom_rounded,
    );
  }
}

class RoundedProgress extends StatelessWidget {
  const RoundedProgress({
    super.key,
    required this.value,
    this.color,
    this.height = 8,
  });

  final double value;
  final Color? color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value.clamp(0, 1).toDouble()),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => ClipRRect(
        borderRadius: BorderRadius.circular(height),
        child: LinearProgressIndicator(
          value: v,
          minHeight: height,
          color: c,
          backgroundColor: c.withValues(alpha: 0.14),
        ),
      ),
    );
  }
}

/// A compact number + label tile.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
    this.onTap,
  });

  final String value;
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      margin: const EdgeInsets.all(4),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      onTap: onTap,
      child: Column(
        children: [
          IconBadge(icon, color: color, size: 38),
          const SizedBox(height: 6),
          FittedBox(
            child: Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                height: 1.1,
              ),
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// A titled group of form fields on a card.
class FormSection extends StatelessWidget {
  const FormSection({super.key, required this.children, this.title, this.icon});

  final String? title;
  final IconData? icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      margin: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                ],
                Text(
                  title!,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          ...children,
        ],
      ),
    );
  }
}

/// Multi-select chips for "remind me before".
class ReminderChips extends StatelessWidget {
  const ReminderChips({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final List<int> options;
  final List<int> selected;
  final ValueChanged<List<int>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        for (final m in options)
          FilterChip(
            label: Text(reminderText(m)),
            selected: selected.contains(m),
            onSelected: (on) {
              final next = [...selected];
              on ? next.add(m) : next.remove(m);
              next.sort();
              onChanged(next);
            },
          ),
      ],
    );
  }
}

/// A field that shows a date+time and opens pickers on tap.
class DateTimeField extends StatelessWidget {
  const DateTimeField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.withTime = true,
    this.clearable = false,
    this.icon = Icons.event_rounded,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final bool withTime;
  final bool clearable;
  final IconData icon;

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final initial = value ?? DateTime(now.year, now.month, now.day, 9);
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );
    if (date == null) return;
    if (!withTime) {
      onChanged(DateTime(date.year, date.month, date.day));
      return;
    }
    if (!context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return;
    onChanged(
      DateTime(date.year, date.month, date.day, time.hour, time.minute),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = value == null
        ? 'اختار'
        : withTime
        ? '${formatLongDate(value!)} • ${formatTime(value!)}'
        : formatLongDate(value!);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _pick(context),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          suffixIcon: clearable && value != null
              ? IconButton(
                  tooltip: 'مسح',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => onChanged(null),
                )
              : null,
        ),
        child: Text(text),
      ),
    );
  }
}

/// A tappable field that opens the time picker.
class TimeField extends StatelessWidget {
  const TimeField({
    super.key,
    required this.label,
    required this.minuteOfDay,
    required this.onChanged,
  });

  final String label;
  final int minuteOfDay;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () async {
        final t = await showTimePicker(
          context: context,
          initialTime: TimeOfDay(
            hour: minuteOfDay ~/ 60,
            minute: minuteOfDay % 60,
          ),
        );
        if (t != null) onChanged(t.hour * 60 + t.minute);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.access_time_rounded),
        ),
        child: Text(formatMinuteOfDay(minuteOfDay)),
      ),
    );
  }
}

/// Space between form fields.
const formGap = SizedBox(height: 14);
