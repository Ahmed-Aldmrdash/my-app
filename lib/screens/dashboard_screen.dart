import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../data/demo_data.dart';
import '../models/models.dart';
import '../utils/formatters.dart';
import '../utils/grade_calculator.dart';
import '../utils/labels.dart';
import '../utils/schedule_utils.dart';
import '../widgets/common.dart';
import '../widgets/item_tiles.dart';
import 'assessment_form.dart';
import 'project_detail_screen.dart';
import 'settings_screen.dart';
import 'subject_form.dart';

typedef Navigate = void Function(int tab, [int? subTab]);

/// Today at a glance: next class, deadlines, tasks and progress.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required this.onNavigate});

  final Navigate onNavigate;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('منظم دراستي'),
        actions: [
          IconButton(
            tooltip: 'الإعدادات',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => pushPage(context, const SettingsScreen()),
          ),
        ],
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
    final theme = Theme.of(context);
    final name = store.settings.studentName.trim();
    final greeting = now.hour < 12 ? 'صباح الخير' : 'مساء الخير';

    final notStudied = store.studyItems.where((s) => !s.status.isDone).length;
    final pendingTasks = store.tasks.where((t) => !t.done).toList();
    final weekEnd = now.add(const Duration(days: 7));
    final dueThisWeek = store.assessments
        .where(
          (a) =>
              !a.done && a.dueDate.isAfter(now) && a.dueDate.isBefore(weekEnd),
        )
        .length;
    final overall = overallPercent(store.subjects.map(store.gradeSummary));

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$greeting${name.isEmpty ? '' : ' يا $name'} 👋',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                formatLongDate(now),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (store.subjects.isEmpty) const _Onboarding(),
        Row(
          children: [
            _StatTile(
              value: '$notStudied',
              label: 'محاضرات لسه',
              icon: Icons.menu_book,
              color: const Color(0xFFF59E0B),
              onTap: () => onNavigate(2),
            ),
            _StatTile(
              value: '${pendingTasks.length}',
              label: 'تاسكات',
              icon: Icons.task_alt,
              color: const Color(0xFF2E7DD7),
              onTap: () => onNavigate(3, 0),
            ),
            _StatTile(
              value: '$dueThisWeek',
              label: 'مواعيد الأسبوع',
              icon: Icons.event_note,
              color: const Color(0xFFE53935),
              onTap: () => onNavigate(3, 1),
            ),
            _StatTile(
              value: formatPercent(overall),
              label: 'درجاتك',
              icon: Icons.emoji_events_outlined,
              color: const Color(0xFF22A45D),
              onTap: () => onNavigate(4),
            ),
          ],
        ),
        _NextClassCard(now: now, onNavigate: onNavigate),
        _TodaySchedule(now: now, onNavigate: onNavigate),
        _UpcomingDeadlines(now: now, onNavigate: onNavigate),
        _TasksPreview(now: now, tasks: pendingTasks, onNavigate: onNavigate),
        _StudyProgress(onNavigate: onNavigate),
        _ProjectsPreview(now: now, onNavigate: onNavigate),
      ],
    );
  }
}

class _Onboarding extends StatelessWidget {
  const _Onboarding();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'أهلاً بيك! 🎓',
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'ابدأ بإضافة موادك، وبعدين ضيف الجدول والمحاضرات اللي بتنزل والكويزات '
              'والأسايمنتات والمشاريع والدرجات — وأنا هفكرك بكل حاجة في معادها.',
              style: TextStyle(color: theme.colorScheme.onPrimaryContainer),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: () => pushPage(context, const SubjectForm()),
                  icon: const Icon(Icons.add),
                  label: const Text('ضيف أول مادة'),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    await loadDemoData(
                      context.read<AppStore>(),
                      DateTime.now(),
                    );
                    if (context.mounted) {
                      showSnack(
                        context,
                        'اتضافت بيانات تجريبية — تقدر تمسحها من الإعدادات',
                      );
                    }
                  },
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('جرّب ببيانات تجريبية'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String value;
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
            child: Column(
              children: [
                Icon(icon, color: color),
                const SizedBox(height: 4),
                FittedBox(
                  child: Text(
                    value,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall,
                ),
              ],
            ),
          ),
        ),
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
    final onColor =
        ThemeData.estimateBrightnessForColor(color) == Brightness.dark
        ? Colors.white
        : Colors.black87;
    final ongoing = next.isOngoing(now);
    final s = next.session;
    return Card(
      color: color,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => onNavigate(1),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(s.type.icon, color: onColor, size: 40),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ongoing
                          ? '${s.type.label} شغالة دلوقتي'
                          : s.type.nextLabel,
                      style: TextStyle(color: onColor.withValues(alpha: 0.85)),
                    ),
                    Text(
                      subject?.name ?? '',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: onColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      [
                        '${friendlyDay(next.start, now)} ${formatMinuteOfDay(s.startMinute)} - ${formatMinuteOfDay(s.endMinute)}',
                        if (s.location.isNotEmpty) s.location,
                      ].join(' • '),
                      style: TextStyle(color: onColor),
                    ),
                  ],
                ),
              ),
              if (!ongoing)
                Column(
                  children: [
                    Text(
                      'بعد',
                      style: TextStyle(color: onColor.withValues(alpha: 0.85)),
                    ),
                    Text(
                      durationText(next.start.difference(now)),
                      style: TextStyle(
                        color: onColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
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
          trailing: TextButton(
            onPressed: () => onNavigate(1),
            child: const Text('الجدول كله'),
          ),
        ),
        if (today.isEmpty)
          const Card(
            child: ListTile(
              leading: Icon(Icons.free_breakfast_outlined),
              title: Text('مفيش محاضرات النهارده 🎉'),
            ),
          )
        else
          for (final s in today)
            Opacity(
              opacity: s.endMinute <= nowMinute ? 0.5 : 1,
              child: SessionTile(
                session: s,
                highlight:
                    s.startMinute <= nowMinute && nowMinute < s.endMinute,
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
      final subject = store.subjectById(p.subjectId);
      final color = subjectColor(subject, context);
      items.add((
        due: deadline,
        tile: ListTile(
          leading: CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.15),
            child: Icon(Icons.rocket_launch_outlined, color: color),
          ),
          title: Text('مشروع: ${p.title}'),
          subtitle: Text(
            'خلصت ${(p.progress * 100).round()}% • ${friendlyDateTime(deadline, now)}',
          ),
          trailing: CountdownPill(due: deadline, now: now),
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
          trailing: TextButton(
            onPressed: () => pushPage(context, const AssessmentForm()),
            child: const Text('إضافة'),
          ),
        ),
        if (items.isEmpty)
          const Card(
            child: ListTile(
              leading: Icon(Icons.beach_access_outlined),
              title: Text('مفيش حاجة في الأسبوعين الجايين'),
            ),
          )
        else
          Card(
            child: Column(children: [for (final i in items.take(6)) i.tile]),
          ),
      ],
    );
  }
}

class _TasksPreview extends StatelessWidget {
  const _TasksPreview({
    required this.now,
    required this.tasks,
    required this.onNavigate,
  });

  final DateTime now;
  final List<TaskItem> tasks;
  final Navigate onNavigate;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) return const SizedBox.shrink();
    final sorted = [...tasks]
      ..sort((a, b) {
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
          'تاسكات عليك',
          trailing: TextButton(
            onPressed: () => onNavigate(3, 0),
            child: Text('الكل (${tasks.length})'),
          ),
        ),
        Card(
          child: Column(
            children: [
              for (final t in sorted.take(5)) TaskTile(task: t, now: now),
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
    final rows = <Widget>[];
    for (final s in store.subjects) {
      final items = store.studyItemsFor(s.id);
      if (items.isEmpty) continue;
      final done = items.where((i) => i.status.isDone).length;
      final color = Color(s.colorValue);
      rows.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              SizedBox(
                width: 110,
                child: Text(s.name, overflow: TextOverflow.ellipsis),
              ),
              Expanded(
                child: RoundedProgress(
                  value: done / items.length,
                  color: color,
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 64,
                child: Text(
                  done == items.length
                      ? 'خلصت ✓'
                      : 'فاضل ${items.length - done}',
                  textAlign: TextAlign.end,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
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
          'المذاكرة',
          trailing: TextButton(
            onPressed: () => onNavigate(2),
            child: const Text('التفاصيل'),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(children: rows),
          ),
        ),
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
          trailing: TextButton(
            onPressed: () => onNavigate(3, 3),
            child: const Text('الكل'),
          ),
        ),
        for (final p in projects.take(3)) ProjectCard(project: p, now: now),
      ],
    );
  }
}
