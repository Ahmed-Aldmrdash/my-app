import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../data/demo_data.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/grade_calculator.dart';
import '../utils/labels.dart';
import '../utils/quotes.dart';
import '../utils/schedule_utils.dart';
import '../utils/study_stats.dart';
import '../widgets/common.dart';
import '../widgets/item_tiles.dart';
import '../widgets/quick_add.dart';
import 'focus_screen.dart';
import 'grade_form.dart';
import 'project_detail_screen.dart';
import 'settings_screen.dart';
import 'stats_screen.dart';
import 'study_item_form.dart';
import 'subject_form.dart';
import 'task_form.dart';

typedef Navigate = void Function(int tab, [int? subTab]);

/// Today at a glance: next class, deadlines, tasks and progress.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required this.onNavigate});

  final Navigate onNavigate;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        heroTag: 'home-fab',
        tooltip: 'إضافة',
        onPressed: () => showQuickAddSheet(context),
        child: const Icon(Icons.add_rounded, size: 30),
      ),
      body: NowBuilder(
        builder: (context, now) =>
            _DashboardBody(now: now, onNavigate: onNavigate),
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({required this.now, required this.onNavigate});

  final DateTime now;
  final Navigate onNavigate;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    return ListView(
      padding: const EdgeInsets.only(bottom: 100),
      children: [
        _Hero(now: now, onNavigate: onNavigate),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (store.focus != null) _FocusBanner(now: now),
              if (store.subjects.isEmpty) const _Onboarding(),
              const SizedBox(height: 4),
              const _QuickActions(),
              _NextClassCard(now: now, onNavigate: onNavigate),
              _TodaySchedule(now: now, onNavigate: onNavigate),
              _ReviewsDue(now: now, onNavigate: onNavigate),
              _UpcomingDeadlines(now: now, onNavigate: onNavigate),
              _TasksPreview(now: now, onNavigate: onNavigate),
              _StudyProgress(onNavigate: onNavigate),
              _ProjectsPreview(now: now, onNavigate: onNavigate),
            ],
          ),
        ),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.now, required this.onNavigate});

  final DateTime now;
  final Navigate onNavigate;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final name = store.settings.studentName.trim();
    final greeting = now.hour < 12 ? 'صباح الخير' : 'مساء الخير';
    final stats = StudyStats(store.studySessions, now);
    final goal = store.settings.dailyGoalMinutes;
    final system = store.settings.gradingSystem;
    final summaries = store.subjects.map(store.gradeSummary).toList();
    final overall = overallPercent(summaries);
    final gpa = expectedGpa(summaries);
    final level = system == GradingSystem.gpa
        ? (gpa == null ? '—' : gpa.toStringAsFixed(2))
        : formatPercent(overall);
    const white = Colors.white;

    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 12, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          formatLongDate(now),
                          style: TextStyle(
                            color: white.withValues(alpha: 0.8),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '$greeting${name.isEmpty ? '' : ' يا $name'} 👋',
                          style: const TextStyle(
                            color: white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'الإحصائيات',
                    style: IconButton.styleFrom(
                      backgroundColor: white.withValues(alpha: 0.16),
                    ),
                    icon: const Icon(Icons.insights_rounded, color: white),
                    onPressed: () => pushPage(context, const StatsScreen()),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    tooltip: 'الإعدادات',
                    style: IconButton.styleFrom(
                      backgroundColor: white.withValues(alpha: 0.16),
                    ),
                    icon: const Icon(Icons.settings_rounded, color: white),
                    onPressed: () => pushPage(context, const SettingsScreen()),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Text('💡'),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          quoteOfTheDay(now),
                          style: const TextStyle(
                            color: white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
                child: Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: _GlassTile(
                        onTap: () => pushPage(context, const StatsScreen()),
                        child: Row(
                          children: [
                            ProgressRing(
                              value: stats.today / goal,
                              size: 48,
                              stroke: 5,
                              color: AppColors.amber,
                              trackColor: white.withValues(alpha: 0.22),
                              child: const Text(
                                '🎯',
                                style: TextStyle(fontSize: 16),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  FittedBox(
                                    child: Text(
                                      '${hoursMinutes(stats.today)} من ${hoursMinutes(goal)}',
                                      style: const TextStyle(
                                        color: white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    'مذاكرة النهارده',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: white.withValues(alpha: 0.8),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: _GlassTile(
                        onTap: () => pushPage(context, const StatsScreen()),
                        child: _GlassValue(
                          value: '🔥 ${stats.streak}',
                          label: 'أيام متتالية',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: _GlassTile(
                        onTap: () => onNavigate(4),
                        child: _GlassValue(
                          value: level,
                          label: system == GradingSystem.gpa
                              ? 'GPA متوقع'
                              : 'مستواك',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassTile extends StatelessWidget {
  const _GlassTile({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: SizedBox(
          height: 72,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}

class _GlassValue extends StatelessWidget {
  const _GlassValue({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _FocusBanner extends StatelessWidget {
  const _FocusBanner({required this.now});

  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final focus = store.focus!;
    final left = focus.remainingSeconds(now);
    final subject = store.subjectById(focus.subjectId);
    final resting = focus.phase == FocusPhase.rest;
    return AppCard(
      margin: const EdgeInsets.only(top: 14),
      gradient: resting ? AppColors.tealGradient : AppColors.focusGradient,
      onTap: () => pushPage(context, const FocusScreen()),
      child: Row(
        children: [
          const Icon(Icons.timer_rounded, color: Colors.white, size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              [
                if (focus.isPaused)
                  'الجلسة متوقفة'
                else if (resting)
                  'بريك شغال'
                else
                  'جلسة مذاكرة شغالة',
                ?subject?.name,
              ].join(' • '),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            'فاضل ${durationText(Duration(seconds: left < 60 ? 60 : left))}',
            style: const TextStyle(color: Colors.white),
          ),
          const Icon(Icons.chevron_left_rounded, color: Colors.white),
        ],
      ),
    );
  }
}

class _Onboarding extends StatelessWidget {
  const _Onboarding();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      margin: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text('🎓', style: TextStyle(fontSize: 30)),
              const SizedBox(width: 10),
              Text('أهلاً بيك!', style: theme.textTheme.titleLarge),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'ابدأ بإضافة موادك، وبعدين ضيف الجدول والمحاضرات والكويزات '
            'والدرجات — وأنا هفكرك بكل حاجة في معادها وأساعدك تذاكر أول بأول.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: () => pushPage(context, const SubjectForm()),
            icon: const Icon(Icons.add_rounded),
            label: const Text('ضيف أول مادة'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () async {
              await loadDemoData(context.read<AppStore>(), DateTime.now());
              if (context.mounted) {
                showSnack(
                  context,
                  'اتضافت بيانات تجريبية — تقدر تمسحها من الإعدادات',
                );
              }
            },
            icon: const Icon(Icons.auto_awesome_rounded),
            label: const Text('جرّب ببيانات تجريبية'),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    final actions = [
      (
        'ذاكر',
        Icons.play_arrow_rounded,
        AppColors.coral,
        () => pushPage(context, const FocusScreen()),
      ),
      (
        'محاضرة',
        Icons.menu_book_rounded,
        AppColors.primary,
        () => pushPage(context, const StudyItemForm()),
      ),
      (
        'تاسك',
        Icons.task_alt_rounded,
        AppColors.sky,
        () => pushPage(context, const TaskForm()),
      ),
      (
        'درجة',
        Icons.emoji_events_rounded,
        AppColors.teal,
        () => pushPage(context, const GradeForm()),
      ),
      (
        'المزيد',
        Icons.apps_rounded,
        AppColors.orange,
        () => showQuickAddSheet(context),
      ),
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 4),
      child: Row(
        children: [
          for (final a in actions)
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: a.$4,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    children: [
                      IconBadge(a.$2, color: a.$3, size: 54, filled: true),
                      const SizedBox(height: 6),
                      FittedBox(
                        child: Text(
                          a.$1,
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _NextClassCard extends StatelessWidget {
  const _NextClassCard({required this.now, required this.onNavigate});

  final DateTime now;
  final Navigate onNavigate;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final next = findNextClass(store.sessions, now);
    if (next == null) return const SizedBox.shrink();
    final subject = store.subjectById(next.session.subjectId);
    final color = subjectColor(subject, context);
    final onColor = AppColors.onColor(color);
    final ongoing = next.isOngoing(now);
    final s = next.session;
    return AppCard(
      margin: const EdgeInsets.only(top: 14),
      gradient: AppColors.gradientOf(color),
      onTap: () => onNavigate(1),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: onColor.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(s.type.icon, color: onColor, size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ongoing ? '${s.type.label} شغالة دلوقتي' : s.type.nextLabel,
                  style: TextStyle(
                    color: onColor.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subject?.name ?? '',
                  style: TextStyle(
                    color: onColor,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  [
                    '${friendlyDay(next.start, now)} ${formatMinuteOfDay(s.startMinute)}',
                    if (s.location.isNotEmpty) s.location,
                  ].join(' • '),
                  style: TextStyle(color: onColor),
                ),
              ],
            ),
          ),
          if (!ongoing)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: onColor.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  Text(
                    'بعد',
                    style: TextStyle(
                      color: onColor.withValues(alpha: 0.85),
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    durationText(next.start.difference(now)),
                    style: TextStyle(
                      color: onColor,
                      fontWeight: FontWeight.w800,
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

class _TodaySchedule extends StatelessWidget {
  const _TodaySchedule({required this.now, required this.onNavigate});

  final DateTime now;
  final Navigate onNavigate;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    if (store.sessions.isEmpty) return const SizedBox.shrink();
    final today = store.sessionsOn(now.weekday);
    final nowMinute = now.hour * 60 + now.minute;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          'جدول النهارده',
          icon: Icons.today_rounded,
          trailing: SeeAllButton('الجدول كله', onPressed: () => onNavigate(1)),
        ),
        if (today.isEmpty)
          const AppCard(
            child: Row(
              children: [
                Text('🎉', style: TextStyle(fontSize: 24)),
                SizedBox(width: 12),
                Expanded(
                  child: Text('مفيش محاضرات النهارده — استغله في المذاكرة'),
                ),
              ],
            ),
          )
        else
          for (final s in today)
            SessionTile(
              session: s,
              highlight: s.startMinute <= nowMinute && nowMinute < s.endMinute,
              attendanceDay: s.startMinute <= nowMinute ? now : null,
            ),
      ],
    );
  }
}

class _ReviewsDue extends StatelessWidget {
  const _ReviewsDue({required this.now, required this.onNavigate});

  final DateTime now;
  final Navigate onNavigate;

  @override
  Widget build(BuildContext context) {
    final due = context.watch<AppStore>().dueReviews(now);
    if (due.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          'مراجعات النهارده (${due.length})',
          icon: Icons.replay_circle_filled_rounded,
          trailing: due.length > 3
              ? SeeAllButton('الكل', onPressed: () => onNavigate(2))
              : null,
        ),
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: [for (final i in due.take(3)) ReviewTile(item: i)],
          ),
        ),
      ],
    );
  }
}

class _UpcomingDeadlines extends StatelessWidget {
  const _UpcomingDeadlines({required this.now, required this.onNavigate});

  final DateTime now;
  final Navigate onNavigate;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    if (store.subjects.isEmpty) return const SizedBox.shrink();
    final horizon = now.add(const Duration(days: 14));
    final items = <({DateTime due, Widget tile})>[];
    for (final a in store.assessments) {
      if (a.done || a.dueDate.isAfter(horizon)) continue;
      items.add((
        due: a.dueDate,
        tile: AssessmentTile(assessment: a, now: now),
      ));
    }
    for (final p in store.projects) {
      final deadline = p.deadline;
      if (p.submitted || deadline == null || deadline.isAfter(horizon)) {
        continue;
      }
      final color = subjectColor(store.subjectById(p.subjectId), context);
      items.add((
        due: deadline,
        tile: ListTile(
          contentPadding: const EdgeInsetsDirectional.only(start: 14, end: 12),
          leading: IconBadge(Icons.rocket_launch_rounded, color: color),
          title: Text(
            'مشروع: ${p.title}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            'خلصت ${(p.progress * 100).round()}% • ${friendlyDateTime(deadline, now)}',
          ),
          trailing: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 124),
            child: CountdownPill(due: deadline, now: now),
          ),
          onTap: () => pushPage(context, ProjectDetailScreen(projectId: p.id)),
        ),
      ));
    }
    items.sort((a, b) => a.due.compareTo(b.due));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          'كويزات وتسليمات قريبة',
          icon: Icons.event_note_rounded,
          trailing: SeeAllButton('الكل', onPressed: () => onNavigate(3, 1)),
        ),
        if (items.isEmpty)
          const AppCard(
            child: Row(
              children: [
                Text('🏖️', style: TextStyle(fontSize: 24)),
                SizedBox(width: 12),
                Expanded(child: Text('مفيش حاجة في الأسبوعين الجايين')),
              ],
            ),
          )
        else
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(children: [for (final i in items.take(5)) i.tile]),
          ),
      ],
    );
  }
}

class _TasksPreview extends StatelessWidget {
  const _TasksPreview({required this.now, required this.onNavigate});

  final DateTime now;
  final Navigate onNavigate;

  @override
  Widget build(BuildContext context) {
    final tasks = context
        .watch<AppStore>()
        .tasks
        .where((t) => !t.done)
        .toList();
    if (tasks.isEmpty) return const SizedBox.shrink();
    tasks.sort((a, b) {
      if (a.dueDate != null && b.dueDate != null) {
        return a.dueDate!.compareTo(b.dueDate!);
      }
      if (a.dueDate != null) return -1;
      if (b.dueDate != null) return 1;
      return b.priority.index.compareTo(a.priority.index);
    });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          'تاسكات عليك (${tasks.length})',
          icon: Icons.checklist_rounded,
          trailing: SeeAllButton('الكل', onPressed: () => onNavigate(3, 0)),
        ),
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: [
              for (final t in tasks.take(4)) TaskTile(task: t, now: now),
            ],
          ),
        ),
      ],
    );
  }
}

class _StudyProgress extends StatelessWidget {
  const _StudyProgress({required this.onNavigate});

  final Navigate onNavigate;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final theme = Theme.of(context);
    final rows = <Widget>[];
    for (final s in store.subjects) {
      final items = store.studyItemsFor(s.id);
      if (items.isEmpty) continue;
      final done = items.where((i) => i.status.isDone).length;
      rows.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      s.name,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    done == items.length
                        ? 'خلصتها كلها ✓'
                        : 'فاضل ${items.length - done} من ${items.length}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              RoundedProgress(
                value: done / items.length,
                color: Color(s.colorValue),
                height: 9,
              ),
            ],
          ),
        ),
      );
    }
    if (rows.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          'المذاكرة وصلت لحد فين',
          icon: Icons.auto_stories_rounded,
          trailing: SeeAllButton('التفاصيل', onPressed: () => onNavigate(2)),
        ),
        AppCard(child: Column(children: rows)),
      ],
    );
  }
}

class _ProjectsPreview extends StatelessWidget {
  const _ProjectsPreview({required this.now, required this.onNavigate});

  final DateTime now;
  final Navigate onNavigate;

  @override
  Widget build(BuildContext context) {
    final projects = context
        .watch<AppStore>()
        .projects
        .where((p) => !p.submitted)
        .toList();
    if (projects.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          'المشاريع',
          icon: Icons.rocket_launch_rounded,
          trailing: SeeAllButton('الكل', onPressed: () => onNavigate(3, 3)),
        ),
        for (final p in projects.take(3)) ProjectCard(project: p, now: now),
      ],
    );
  }
}
