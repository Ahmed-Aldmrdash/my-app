import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/ids.dart';
import '../utils/study_stats.dart';
import '../widgets/common.dart';
import '../widgets/subject_picker.dart';
import 'focus_screen.dart';

/// Study time: today vs. goal, streak, last 7 days and per subject.
class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  Future<void> _editGoal(BuildContext context, AppStore store) async {
    var goal = store.settings.dailyGoalMinutes;
    final result = await showModalBottomSheet<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('هدفك اليومي', style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                studyTimeText(goal),
                style: Theme.of(ctx).textTheme.headlineSmall?.copyWith(
                  color: Theme.of(ctx).colorScheme.primary,
                ),
              ),
              Slider(
                value: goal.toDouble(),
                min: 30,
                max: 600,
                divisions: 19,
                onChanged: (v) => setSheet(() => goal = v.round()),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx, goal),
                  child: const Text('حفظ'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (result != null) {
      await store.updateSettings(
        store.settings.copyWith(dailyGoalMinutes: result),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final theme = Theme.of(context);
    final now = DateTime.now();
    final stats = StudyStats(store.studySessions, now);
    final goal = store.settings.dailyGoalMinutes;
    final week = stats.lastDays(7);
    final weekStart = week.first.$1;
    final bySubject = minutesBySubject(
      store.studySessions,
      weekStart,
    ).entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final maxSubject = bySubject.isEmpty ? 1 : bySubject.first.value;
    final recent = [...store.studySessions]
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));

    return Scaffold(
      appBar: AppBar(
        title: const Text('إحصائيات المذاكرة'),
        actions: [
          IconButton(
            tooltip: 'سجل وقت مذاكرة',
            icon: const Icon(Icons.add_circle_outline_rounded),
            onPressed: () => showLogSessionSheet(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'stats-fab',
        onPressed: () => pushPage(context, const FocusScreen()),
        icon: const Icon(Icons.play_arrow_rounded),
        label: const Text('ابدأ جلسة'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
        children: [
          AppCard(
            gradient: AppColors.heroGradient,
            onTap: () => _editGoal(context, store),
            child: Row(
              children: [
                ProgressRing(
                  value: stats.today / goal,
                  size: 92,
                  stroke: 10,
                  color: Colors.white,
                  trackColor: Colors.white24,
                  child: Text(
                    '${(stats.today / goal * 100).clamp(0, 999).round()}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'النهارده',
                        style: TextStyle(color: Colors.white70),
                      ),
                      Text(
                        studyTimeText(stats.today),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        stats.today >= goal
                            ? 'حققت هدفك النهارده 🎉'
                            : 'فاضلك ${studyTimeText(goal - stats.today)} على هدفك',
                        style: const TextStyle(color: Colors.white),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'دوس هنا عشان تغير الهدف',
                        style: TextStyle(color: Colors.white60, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  value: '🔥 ${stats.streak}',
                  label: 'أيام ورا بعض',
                  icon: Icons.local_fire_department_rounded,
                  color: AppColors.coral,
                ),
              ),
              Expanded(
                child: StatTile(
                  value: hoursMinutes(stats.lastSevenDays),
                  label: 'ساعات الأسبوع',
                  icon: Icons.calendar_view_week_rounded,
                  color: AppColors.sky,
                ),
              ),
              Expanded(
                child: StatTile(
                  value: hoursMinutes(stats.total),
                  label: 'الإجمالي',
                  icon: Icons.timer_rounded,
                  color: AppColors.teal,
                ),
              ),
            ],
          ),
          const SectionHeader('آخر 7 أيام', icon: Icons.bar_chart_rounded),
          AppCard(
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 10),
            child: WeeklyBars(days: week, goal: goal, now: now),
          ),
          if (bySubject.isNotEmpty) ...[
            const SectionHeader(
              'ذاكرت إيه الأسبوع ده',
              icon: Icons.pie_chart_rounded,
            ),
            AppCard(
              child: Column(
                children: [
                  for (final e in bySubject)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: _SubjectBar(
                        subject: store.subjectById(e.key),
                        minutes: e.value,
                        max: maxSubject,
                      ),
                    ),
                ],
              ),
            ),
          ],
          SectionHeader(
            'آخر الجلسات',
            icon: Icons.history_rounded,
            trailing: SeeAllButton(
              'سجل يدوي',
              onPressed: () => showLogSessionSheet(context),
            ),
          ),
          if (recent.isEmpty)
            const EmptyState(
              icon: Icons.timer_outlined,
              title: 'لسه مفيش جلسات',
              message: 'ابدأ جلسة تركيز أو سجل وقت ذاكرته بنفسك',
            )
          else
            AppCard(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                children: [
                  for (final s in recent.take(30))
                    Dismissible(
                      key: ValueKey(s.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: theme.colorScheme.errorContainer,
                        alignment: AlignmentDirectional.centerEnd,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: const Icon(Icons.delete_outline_rounded),
                      ),
                      onDismissed: (_) {
                        store.deleteStudySession(s.id);
                        showSnack(
                          context,
                          'اتمسحت الجلسة',
                          onUndo: () => store.saveStudySession(s),
                        );
                      },
                      child: ListTile(
                        leading: IconBadge(
                          Icons.timer_rounded,
                          color: subjectColor(
                            store.subjectById(s.subjectId),
                            context,
                          ),
                          size: 40,
                        ),
                        title: Text(
                          store.subjectById(s.subjectId)?.name ?? 'مذاكرة عامة',
                        ),
                        subtitle: Text(
                          '${friendlyDay(s.startedAt, now)} • ${formatTime(s.startedAt)}'
                          '${s.note.isEmpty ? '' : ' • ${s.note}'}',
                        ),
                        trailing: Text(
                          studyTimeText(s.minutes),
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Minutes per day for the last week, with the daily goal as a dashed line.
/// Tap a bar to see its value; today's value is always shown.
class WeeklyBars extends StatefulWidget {
  const WeeklyBars({
    super.key,
    required this.days,
    required this.goal,
    required this.now,
    this.height = 160,
  });

  final List<(DateTime, int)> days;
  final int goal;
  final DateTime now;
  final double height;

  @override
  State<WeeklyBars> createState() => _WeeklyBarsState();
}

class _WeeklyBarsState extends State<WeeklyBars> {
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;
    final muted = theme.colorScheme.onSurfaceVariant;
    final maxValue = [
      widget.goal,
      ...widget.days.map((d) => d.$2),
    ].reduce((a, b) => a > b ? a : b).toDouble();
    final todayIndex = widget.days.length - 1;
    final shown = _selected ?? todayIndex;

    return SizedBox(
      height: widget.height + 44,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final plotHeight = widget.height;
          final goalY = plotHeight * (1 - widget.goal / maxValue);
          return Stack(
            children: [
              // Goal reference line.
              Positioned(
                top: 20 + goalY,
                left: 0,
                right: 0,
                child: CustomPaint(
                  size: Size(constraints.maxWidth, 1),
                  painter: _DashPainter(color: muted.withValues(alpha: 0.5)),
                ),
              ),
              PositionedDirectional(
                top: 20 + goalY - 16,
                start: 0,
                child: Text(
                  'الهدف',
                  style: theme.textTheme.labelSmall?.copyWith(color: muted),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < widget.days.length; i++)
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => setState(
                          () => _selected = _selected == i ? null : i,
                        ),
                        child: _Bar(
                          day: widget.days[i].$1,
                          minutes: widget.days[i].$2,
                          fraction: widget.days[i].$2 / maxValue,
                          plotHeight: plotHeight,
                          color: widget.days[i].$2 >= widget.goal
                              ? color
                              : color.withValues(alpha: 0.55),
                          showValue: i == shown,
                          isToday: i == todayIndex,
                          muted: muted,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.day,
    required this.minutes,
    required this.fraction,
    required this.plotHeight,
    required this.color,
    required this.showValue,
    required this.isToday,
    required this.muted,
  });

  final DateTime day;
  final int minutes;
  final double fraction;
  final double plotHeight;
  final Color color;
  final bool showValue;
  final bool isToday;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // The value sits right on top of its bar; the extra 20px above the
        // plot leaves room for it even on the tallest bar.
        SizedBox(
          height: plotHeight + 20,
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: fraction.clamp(0, 1)),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            builder: (context, f, _) => Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (showValue)
                  SizedBox(
                    height: 20,
                    child: FittedBox(
                      child: Text(
                        minutes == 0 ? '0' : hoursMinutes(minutes),
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                Container(
                  width: 18,
                  height: minutes == 0
                      ? 3
                      : (plotHeight * f).clamp(4, plotHeight),
                  decoration: BoxDecoration(
                    color: minutes == 0 ? muted.withValues(alpha: 0.2) : color,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 18,
          child: FittedBox(
            child: Text(
              weekdayShortNames[day.weekday]!,
              style: theme.textTheme.labelSmall?.copyWith(
                color: isToday ? theme.colorScheme.primary : muted,
                fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DashPainter extends CustomPainter {
  _DashPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5;
    const dash = 6.0;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(x + dash, 0), paint);
      x += dash * 2;
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => old.color != color;
}

class _SubjectBar extends StatelessWidget {
  const _SubjectBar({
    required this.subject,
    required this.minutes,
    required this.max,
  });

  final Subject? subject;
  final int minutes;
  final int max;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                subject?.name ?? 'مذاكرة عامة',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(studyTimeText(minutes), style: theme.textTheme.bodySmall),
          ],
        ),
        const SizedBox(height: 6),
        RoundedProgress(
          value: max == 0 ? 0 : minutes / max,
          color: subjectColor(subject, context),
          height: 10,
        ),
      ],
    );
  }
}

/// Bottom sheet to log study time done without the timer.
Future<void> showLogSessionSheet(
  BuildContext context, {
  String? subjectId,
}) async {
  final store = context.read<AppStore>();
  String? subject = subjectId;
  var minutes = 60;
  var day = DateTime.now();
  final note = TextEditingController();
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheet) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          20 + MediaQuery.viewInsetsOf(ctx).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('سجل وقت مذاكرة', style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 16),
            SubjectPicker(
              value: subject,
              required: false,
              onChanged: (v) => setSheet(() => subject = v),
            ),
            formGap,
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final m in const [15, 30, 45, 60, 90, 120, 180])
                  ChoiceChip(
                    label: Text(studyTimeText(m)),
                    selected: minutes == m,
                    showCheckmark: false,
                    onSelected: (_) => setSheet(() => minutes = m),
                  ),
              ],
            ),
            formGap,
            DateTimeField(
              label: 'إمتى',
              value: day,
              onChanged: (d) => setSheet(() => day = d ?? day),
            ),
            formGap,
            TextField(
              controller: note,
              decoration: const InputDecoration(
                labelText: 'ملاحظة (اختياري)',
                prefixIcon: Icon(Icons.notes_rounded),
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.check_rounded),
              label: const Text('حفظ'),
            ),
          ],
        ),
      ),
    ),
  );
  final text = note.text.trim();
  note.dispose();
  if (saved != true) return;
  await store.saveStudySession(
    StudySession(
      id: newId(),
      subjectId: subject,
      startedAt: day,
      minutes: minutes,
      note: text,
    ),
  );
  if (context.mounted) {
    showSnack(context, 'اتسجل ${studyTimeText(minutes)} مذاكرة 👏');
  }
}
