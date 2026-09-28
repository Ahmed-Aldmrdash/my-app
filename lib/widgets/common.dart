import 'dart:async';

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../utils/formatters.dart';

Color subjectColor(Subject? s, BuildContext context) =>
    s == null ? Theme.of(context).colorScheme.outline : Color(s.colorValue);

Future<T?> pushPage<T>(BuildContext context, Widget page) =>
    Navigator.of(context).push<T>(MaterialPageRoute(builder: (_) => page));

void showSnack(BuildContext context, String message, {VoidCallback? onUndo}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
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
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: message == null ? null : Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(ctx).colorScheme.error,
            foregroundColor: Theme.of(ctx).colorScheme.onError,
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('حذف'),
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

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 56,
              color: theme.colorScheme.primary.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 12),
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
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing, this.padding});

  final String title;
  final Widget? trailing;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? const EdgeInsetsDirectional.fromSTEB(16, 20, 8, 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          ?trailing,
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
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
              style: Theme.of(context).textTheme.labelSmall,
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
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
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: color, fontWeight: FontWeight.w600),
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
      color = const Color(0xFFE53935);
    } else if (diff.inHours < 24) {
      color = const Color(0xFFF4511E);
    } else if (diff.inDays < 3) {
      color = const Color(0xFFF59E0B);
    } else {
      color = Theme.of(context).colorScheme.primary;
    }
    return Pill(
      countdownText(due, now),
      color: color,
      icon: diff.isNegative ? Icons.warning_amber_rounded : Icons.schedule,
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: LinearProgressIndicator(
        value: value.clamp(0, 1),
        minHeight: height,
        color: color,
        backgroundColor: (color ?? Theme.of(context).colorScheme.primary)
            .withValues(alpha: 0.15),
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
      runSpacing: 4,
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
    this.icon = Icons.event,
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
      borderRadius: BorderRadius.circular(12),
      onTap: () => _pick(context),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          suffixIcon: clearable && value != null
              ? IconButton(
                  tooltip: 'مسح',
                  icon: const Icon(Icons.close),
                  onPressed: () => onChanged(null),
                )
              : null,
        ),
        child: Text(text),
      ),
    );
  }
}

/// A tappable card-like field that opens the time picker.
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
      borderRadius: BorderRadius.circular(12),
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
          prefixIcon: const Icon(Icons.access_time),
        ),
        child: Text(formatMinuteOfDay(minuteOfDay)),
      ),
    );
  }
}

/// Space between form fields.
const formGap = SizedBox(height: 14);
