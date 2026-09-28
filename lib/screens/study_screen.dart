import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/labels.dart';
import '../utils/study_stats.dart';
import '../widgets/common.dart';
import '../widgets/item_tiles.dart';
import 'focus_screen.dart';
import 'stats_screen.dart';
import 'study_item_form.dart';

enum StudyFilter { pending, done, all }

/// Focus timer entry, due reviews, and released lectures across subjects.
class StudyScreen extends StatefulWidget {
  const StudyScreen({super.key});

  @override
  State<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends State<StudyScreen> {
  StudyFilter _filter = StudyFilter.pending;
  String? _subjectId;

  bool _matches(StudyItem item) => switch (_filter) {
    StudyFilter.pending => !item.status.isDone,
    StudyFilter.done => item.status.isDone,
    StudyFilter.all => true,
  };

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final theme = Theme.of(context);
    final now = DateTime.now();
    final all = store.studyItems
        .where((s) => _subjectId == null || s.subjectId == _subjectId)
        .toList();
    final doneCount = all.where((s) => s.status.isDone).length;
    final counts = {
      for (final s in StudyStatus.values)
        s: all.where((i) => i.status == s).length,
    };
    final subjects = store.subjects
        .where((s) => _subjectId == null || s.id == _subjectId)
        .toList();
    final selectedSubject = store.subjectById(_subjectId);
    final reviews = store
        .dueReviews(now)
        .where((i) => _subjectId == null || i.subjectId == _subjectId)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('المذاكرة'),
        actions: [
          IconButton(
            tooltip: 'الإحصائيات',
            icon: const Icon(Icons.insights_rounded),
            onPressed: () => pushPage(context, const StatsScreen()),
          ),
          PopupMenuButton<String?>(
            tooltip: 'فلتر بالمادة',
            icon: Icon(
              _subjectId == null
                  ? Icons.filter_list_rounded
                  : Icons.filter_alt_rounded,
            ),
            onSelected: (v) => setState(() => _subjectId = v == '' ? null : v),
            itemBuilder: (_) => [
              const PopupMenuItem(value: '', child: Text('كل المواد')),
              for (final s in store.subjects)
                PopupMenuItem(
                  value: s.id,
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 6,
                        backgroundColor: Color(s.colorValue),
                      ),
                      const SizedBox(width: 10),
                      Text(s.name),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'study-fab',
        onPressed: () =>
            pushPage(context, StudyItemForm(initialSubjectId: _subjectId)),
        icon: const Icon(Icons.add_rounded),
        label: const Text('محاضرة نزلت'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
        children: [
          _FocusCard(subjectId: _subjectId),
          AppCard(
            child: Row(
              children: [
                ProgressRing(
                  value: all.isEmpty ? 0 : doneCount / all.length,
                  size: 76,
                  stroke: 8,
                  child: Text(
                    all.isEmpty
                        ? '—'
                        : '${(doneCount / all.length * 100).round()}%',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selectedSubject?.name ?? 'كل المواد',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        'ذاكرت $doneCount من ${all.length}',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          for (final s in StudyStatus.values)
                            if (counts[s]! > 0)
                              Pill('${s.label} ${counts[s]}', color: s.color),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (reviews.isNotEmpty) ...[
            SectionHeader(
              'مراجعات النهارده (${reviews.length})',
              icon: Icons.replay_circle_filled_rounded,
            ),
            AppCard(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                children: [for (final i in reviews) ReviewTile(item: i)],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                'بعد ما تذاكر محاضرة هفكرك تراجعها بعد يوم، 3 أيام، أسبوع، '
                'أسبوعين وشهر عشان تثبت 🧠',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          SegmentedButton<StudyFilter>(
            segments: const [
              ButtonSegment(
                value: StudyFilter.pending,
                label: Text('لسه'),
                icon: Icon(Icons.pending_actions_rounded),
              ),
              ButtonSegment(
                value: StudyFilter.done,
                label: Text('خلصتها'),
                icon: Icon(Icons.task_alt_rounded),
              ),
              ButtonSegment(value: StudyFilter.all, label: Text('الكل')),
            ],
            selected: {_filter},
            onSelectionChanged: (s) => setState(() => _filter = s.first),
          ),
          ..._buildGroups(context, store, subjects),
        ],
      ),
    );
  }

  List<Widget> _buildGroups(
    BuildContext context,
    AppStore store,
    List<Subject> subjects,
  ) {
    if (store.subjects.isEmpty) {
      return const [
        EmptyState(
          icon: Icons.menu_book_rounded,
          title: 'لسه مفيش مواد',
          message: 'ضيف موادك من تاب "المواد"، وبعدين سجل كل محاضرة بتنزل هنا',
        ),
      ];
    }
    final widgets = <Widget>[];
    for (final subject in subjects) {
      final items = store.studyItemsFor(subject.id);
      final visible = items.where(_matches).toList();
      if (visible.isEmpty) continue;
      final done = items.where((i) => i.status.isDone).length;
      final color = Color(subject.colorValue);
      widgets.add(
        SectionHeader(
          subject.name,
          trailing: Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 64,
                  child: RoundedProgress(
                    value: items.isEmpty ? 0 : done / items.length,
                    color: color,
                    height: 7,
                  ),
                ),
                const SizedBox(width: 8),
                Text(ltr('$done/${items.length}')),
              ],
            ),
          ),
        ),
      );
      widgets.add(
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [for (final i in visible) StudyItemTile(item: i)],
          ),
        ),
      );
    }
    if (widgets.isEmpty) {
      widgets.add(
        EmptyState(
          icon: _filter == StudyFilter.pending
              ? Icons.celebration_rounded
              : Icons.menu_book_rounded,
          color: _filter == StudyFilter.pending ? AppColors.success : null,
          title: switch (_filter) {
            StudyFilter.pending => 'مفيش حاجة متأخرة عليك 🎉',
            StudyFilter.done => 'لسه مخلصتش حاجة',
            StudyFilter.all => 'لسه مفيش محاضرات',
          },
          message: 'كل ما محاضرة تنزل دوس "محاضرة نزلت" وسجلها',
        ),
      );
    }
    return widgets;
  }
}

/// Entry point to the focus timer with today's progress.
class _FocusCard extends StatelessWidget {
  const _FocusCard({this.subjectId});

  final String? subjectId;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final now = DateTime.now();
    final stats = StudyStats(store.studySessions, now);
    final goal = store.settings.dailyGoalMinutes;
    final focus = store.focus;
    const white = Colors.white;
    final left = focus?.remainingSeconds(now) ?? 0;
    return AppCard(
      gradient: AppColors.focusGradient,
      onTap: () => pushPage(context, FocusScreen(subjectId: subjectId)),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: const BoxDecoration(
              color: white,
              shape: BoxShape.circle,
            ),
            child: Icon(
              focus == null ? Icons.play_arrow_rounded : Icons.timer_rounded,
              color: AppColors.coral,
              size: 36,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  focus == null ? 'ابدأ جلسة تركيز' : 'فيه جلسة شغالة',
                  style: const TextStyle(
                    color: white,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  focus == null
                      ? 'ذاكرت النهارده ${studyTimeText(stats.today)} من ${studyTimeText(goal)}'
                      : 'فاضل ${durationText(Duration(seconds: left < 60 ? 60 : left))}',
                  style: TextStyle(color: white.withValues(alpha: 0.9)),
                ),
                const SizedBox(height: 8),
                RoundedProgress(
                  value: stats.today / goal,
                  color: white,
                  height: 6,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
