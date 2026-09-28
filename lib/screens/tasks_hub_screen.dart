import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/models.dart';
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
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'تاسكات'),
            Tab(text: 'كويزات'),
            Tab(text: 'أسايمنتات'),
            Tab(text: 'مشاريع'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'tasks-fab',
        onPressed: _add,
        icon: const Icon(Icons.add),
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
      padding: const EdgeInsets.only(bottom: 96),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
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
            icon: Icons.task_alt,
            title: 'مفيش تاسكات عليك 👌',
            message: 'ضيف أي حاجة عايز تعملها وحدد لها معاد لو حابب يفكرك',
          ),
        if (_showDone && done.isEmpty)
          const EmptyState(
            icon: Icons.inbox_outlined,
            title: 'لسه مخلصتش تاسكات',
          ),
        if (!_showDone)
          for (final entry in groups.entries)
            if (entry.value.isNotEmpty) ...[
              SectionHeader('${entry.key} (${entry.value.length})'),
              for (final t in entry.value) _dismissible(context, store, t, now),
            ],
        if (_showDone) ...[
          const SizedBox(height: 8),
          for (final t in done) _dismissible(context, store, t, now),
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
        child: const Icon(Icons.delete_outline),
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
            icon: isAssignments
                ? Icons.assignment_outlined
                : Icons.quiz_outlined,
            title: isAssignments
                ? 'مفيش أسايمنتات'
                : 'مفيش كويزات ولا امتحانات',
            message: 'ضيفها بمعادها وهفكرك قبلها، ولما تخلص سجل درجتك',
          );
        }
        return ListView(
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            if (overdue.isNotEmpty) ...[
              SectionHeader(
                isAssignments ? 'فات معادها — سلمتها؟' : 'فات معادها — خلصت؟',
              ),
              for (final a in overdue) AssessmentTile(assessment: a, now: now),
            ],
            if (upcoming.isNotEmpty) ...[
              SectionHeader('الجاية (${upcoming.length})'),
              for (final a in upcoming) AssessmentTile(assessment: a, now: now),
            ],
            if (done.isNotEmpty) ...[
              SectionHeader(isAssignments ? 'اتسلمت' : 'خلصت'),
              for (final a in done) AssessmentTile(assessment: a, now: now),
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
        icon: Icons.rocket_launch_outlined,
        title: 'مفيش مشاريع',
        message: 'ضيف مشروعك وقسمه لمراحل، وتابع وصلت لحد فين',
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 96),
      children: [
        if (active.isNotEmpty) ...[
          const SectionHeader('شغال عليها'),
          for (final p in active) ProjectCard(project: p, now: now),
        ],
        if (submitted.isNotEmpty) ...[
          const SectionHeader('اتسلمت'),
          for (final p in submitted) ProjectCard(project: p, now: now),
        ],
      ],
    );
  }
}
