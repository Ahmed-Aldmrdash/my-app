import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/common.dart';
import '../widgets/item_tiles.dart';
import 'assessment_form.dart';
import 'project_form.dart';
import 'task_form.dart';

/// Everything that has to get done: tasks, quizzes & exams, assignments
/// and projects.
class TasksHubScreen extends StatefulWidget {
  const TasksHubScreen({super.key, required this.requestedTab});

  /// Lets notifications and the home screen open a specific sub-tab.
  final ValueNotifier<int> requestedTab;

  @override
  State<TasksHubScreen> createState() => _TasksHubScreenState();
}

class _TasksHubScreenState extends State<TasksHubScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(
    length: 4,
    vsync: this,
    initialIndex: widget.requestedTab.value,
  );

  @override
  void initState() {
    super.initState();
    _tabs.addListener(_onTab);
    widget.requestedTab.addListener(_onRequested);
  }

  void _onTab() {
    // Keep the shared notifier in sync so a later request for the same
    // sub-tab still counts as a change.
    if (!_tabs.indexIsChanging) widget.requestedTab.value = _tabs.index;
    setState(() {});
  }

  void _onRequested() {
    final requested = widget.requestedTab.value;
    if (_tabs.index != requested) _tabs.animateTo(requested);
  }

  @override
  void dispose() {
    widget.requestedTab.removeListener(_onRequested);
    _tabs.dispose();
    super.dispose();
  }

  void _add() {
    switch (_tabs.index) {
      case 0:
        pushPage(context, const TaskForm());
      case 1:
        pushPage(context, const AssessmentForm());
      case 2:
        pushPage(
          context,
          const AssessmentForm(initialType: AssessmentType.assignment),
        );
      default:
        pushPage(context, const ProjectForm());
    }
  }

  @override
  Widget build(BuildContext context) {
    final labels = ['تاسك جديد', 'كويز / امتحان', 'أسايمنت جديد', 'مشروع جديد'];
    return Scaffold(
      appBar: AppBar(
        title: const Text('المهام والتسليمات'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            height: 48,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: TabBar(
              controller: _tabs,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              labelColor: Theme.of(context).colorScheme.onPrimary,
              labelPadding: EdgeInsets.zero,
              tabs: [
                for (final label in const [
                  'تاسكات',
                  'كويزات',
                  'أسايمنتات',
                  'مشاريع',
                ])
                  Tab(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: FittedBox(child: Text(label)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'tasks-fab',
        onPressed: _add,
        icon: const Icon(Icons.add_rounded),
        label: Text(labels[_tabs.index]),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _TasksTab(),
          _AssessmentsTab(types: {AssessmentType.quiz, AssessmentType.exam}),
          _AssessmentsTab(types: {AssessmentType.assignment}),
          _ProjectsTab(),
        ],
      ),
    );
  }
}

class _TasksTab extends StatefulWidget {
  const _TasksTab();

  @override
  State<_TasksTab> createState() => _TasksTabState();
}

class _TasksTabState extends State<_TasksTab> {
  bool _showDone = false;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final now = DateTime.now();
    final pending = store.tasks.where((t) => !t.done).toList();
    final done = store.tasks.where((t) => t.done).toList()
      ..sort((a, b) => (b.completedAt ?? now).compareTo(a.completedAt ?? now));

    final groups = <String, List<TaskItem>>{
      'متأخرة': [],
      'النهارده': [],
      'بكرة': [],
      'الأيام الجاية': [],
      'من غير معاد': [],
    };
    for (final t in pending) {
      final due = t.dueDate;
      if (due == null) {
        groups['من غير معاد']!.add(t);
      } else if (due.isBefore(now)) {
        groups['متأخرة']!.add(t);
      } else if (isSameDay(due, now)) {
        groups['النهارده']!.add(t);
      } else if (isSameDay(due, now.add(const Duration(days: 1)))) {
        groups['بكرة']!.add(t);
      } else {
        groups['الأيام الجاية']!.add(t);
      }
    }
    int byDueThenPriority(TaskItem a, TaskItem b) {
      if (a.dueDate != null && b.dueDate != null) {
        final c = a.dueDate!.compareTo(b.dueDate!);
        if (c != 0) return c;
      }
      return b.priority.index.compareTo(a.priority.index);
    }

    for (final g in groups.values) {
      g.sort(byDueThenPriority);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: SegmentedButton<bool>(
            segments: [
              ButtonSegment(
                value: false,
                label: Text('لسه (${pending.length})'),
              ),
              ButtonSegment(value: true, label: Text('خلصت (${done.length})')),
            ],
            selected: {_showDone},
            onSelectionChanged: (s) => setState(() => _showDone = s.first),
          ),
        ),
        if (!_showDone && pending.isEmpty)
          const EmptyState(
            icon: Icons.task_alt_rounded,
            color: AppColors.success,
            title: 'مفيش تاسكات عليك 👌',
            message: 'ضيف أي حاجة عايز تعملها وحدد لها معاد لو حابب يفكرك',
          ),
        if (_showDone && done.isEmpty)
          const EmptyState(
            icon: Icons.inbox_rounded,
            title: 'لسه مخلصتش تاسكات',
          ),
        if (!_showDone)
          for (final entry in groups.entries)
            if (entry.value.isNotEmpty) ...[
              SectionHeader('${entry.key} (${entry.value.length})'),
              AppCard(
                padding: const EdgeInsets.symmetric(vertical: 4),
                clip: true,
                color: entry.key == 'متأخرة'
                    ? AppColors.danger.withValues(alpha: 0.06)
                    : null,
                child: Column(
                  children: [
                    for (final t in entry.value)
                      _dismissible(context, store, t, now),
                  ],
                ),
              ),
            ],
        if (_showDone && done.isNotEmpty) ...[
          const SizedBox(height: 8),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            clip: true,
            child: Column(
              children: [
                for (final t in done) _dismissible(context, store, t, now),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _dismissible(
    BuildContext context,
    AppStore store,
    TaskItem t,
    DateTime now,
  ) {
    return Dismissible(
      key: ValueKey(t.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Theme.of(context).colorScheme.errorContainer,
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Icon(Icons.delete_outline_rounded),
      ),
      onDismissed: (_) {
        store.deleteTask(t.id);
        showSnack(
          context,
          'اتمسح "${t.title}"',
          onUndo: () => store.saveTask(t),
        );
      },
      child: TaskTile(task: t, now: now),
    );
  }
}

class _AssessmentsTab extends StatelessWidget {
  const _AssessmentsTab({required this.types});

  final Set<AssessmentType> types;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final isAssignments = types.contains(AssessmentType.assignment);
    return NowBuilder(
      builder: (context, now) {
        final items = store.assessments
            .where((a) => types.contains(a.type))
            .toList();
        final overdue = items.where((a) => a.isOverdue(now)).toList()
          ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
        final upcoming =
            items.where((a) => !a.done && !a.isOverdue(now)).toList()
              ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
        final done = items.where((a) => a.done).toList()
          ..sort((a, b) => b.dueDate.compareTo(a.dueDate));

        if (items.isEmpty) {
          return EmptyState(
            icon: isAssignments ? Icons.assignment_rounded : Icons.quiz_rounded,
            title: isAssignments
                ? 'مفيش أسايمنتات'
                : 'مفيش كويزات ولا امتحانات',
            message: 'ضيفها بمعادها وهفكرك قبلها، ولما تخلص سجل درجتك',
          );
        }
        Widget group(List<Assessment> list, {Color? color}) => AppCard(
          padding: const EdgeInsets.symmetric(vertical: 6),
          color: color,
          child: Column(
            children: [
              for (final a in list) AssessmentTile(assessment: a, now: now),
            ],
          ),
        );
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
          children: [
            if (overdue.isNotEmpty) ...[
              SectionHeader(
                isAssignments ? 'فات معادها — سلمتها؟' : 'فات معادها — خلصت؟',
                icon: Icons.warning_amber_rounded,
              ),
              group(overdue, color: AppColors.danger.withValues(alpha: 0.06)),
            ],
            if (upcoming.isNotEmpty) ...[
              SectionHeader(
                'الجاية (${upcoming.length})',
                icon: Icons.upcoming_rounded,
              ),
              group(upcoming),
            ],
            if (done.isNotEmpty) ...[
              SectionHeader(
                isAssignments ? 'اتسلمت' : 'خلصت',
                icon: Icons.task_alt_rounded,
              ),
              group(done),
            ],
          ],
        );
      },
    );
  }
}

class _ProjectsTab extends StatelessWidget {
  const _ProjectsTab();

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final now = DateTime.now();
    final active = store.projects.where((p) => !p.submitted).toList()
      ..sort((a, b) {
        if (a.deadline == null) return 1;
        if (b.deadline == null) return -1;
        return a.deadline!.compareTo(b.deadline!);
      });
    final submitted = store.projects.where((p) => p.submitted).toList();
    if (store.projects.isEmpty) {
      return const EmptyState(
        icon: Icons.rocket_launch_rounded,
        title: 'مفيش مشاريع',
        message: 'ضيف مشروعك وقسمه لمراحل، وتابع وصلت لحد فين',
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      children: [
        if (active.isNotEmpty) ...[
          const SectionHeader('شغال عليها', icon: Icons.construction_rounded),
          for (final p in active) ProjectCard(project: p, now: now),
        ],
        if (submitted.isNotEmpty) ...[
          const SectionHeader('اتسلمت', icon: Icons.task_alt_rounded),
          for (final p in submitted) ProjectCard(project: p, now: now),
        ],
      ],
    );
  }
}
