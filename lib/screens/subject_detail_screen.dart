import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/models.dart';
import '../utils/formatters.dart';
import '../utils/grade_calculator.dart';
import '../utils/labels.dart';
import '../widgets/common.dart';
import '../widgets/item_tiles.dart';
import 'assessment_form.dart';
import 'grade_form.dart';
import 'session_form.dart';
import 'study_item_form.dart';
import 'subject_form.dart';

/// Everything about one subject: marks, lectures, deadlines, timetable.
class SubjectDetailScreen extends StatefulWidget {
  const SubjectDetailScreen({super.key, required this.subjectId});

  final String subjectId;

  @override
  State<SubjectDetailScreen> createState() => _SubjectDetailScreenState();
}

class _SubjectDetailScreenState extends State<SubjectDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 4, vsync: this)
    ..addListener(() => setState(() {}));

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _delete(AppStore store, Subject s) async {
    final ok = await confirmDelete(
      context,
      'تمسح مادة "${s.name}"؟',
      message: 'هيتمسح معاها جدولها ومحاضراتها وكويزاتها ودرجاتها. التاسكات والمشاريع هتفضل.',
    );
    if (!ok || !mounted) return;
    Navigator.pop(context);
    await store.deleteSubject(s.id);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final subject = store.subjectById(widget.subjectId);
    if (subject == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(
          icon: Icons.delete_outline,
          title: 'المادة دي اتمسحت',
        ),
      );
    }
    final color = Color(subject.colorValue);
    final onColor =
        ThemeData.estimateBrightnessForColor(color) == Brightness.dark
        ? Colors.white
        : Colors.black87;

    final fab = switch (_tabs.index) {
      0 => (
        'درجة جديدة',
        () => pushPage(context, GradeForm(initialSubjectId: subject.id)),
      ),
      1 => (
        'محاضرة نزلت',
        () => pushPage(context, StudyItemForm(initialSubjectId: subject.id)),
      ),
      2 => (
        'كويز / أسايمنت',
        () => pushPage(context, AssessmentForm(initialSubjectId: subject.id)),
      ),
      _ => (
        'ميعاد في الجدول',
        () => pushPage(context, SessionForm(initialSubjectId: subject.id)),
      ),
    };

    return Scaffold(
      appBar: AppBar(
        backgroundColor: color,
        foregroundColor: onColor,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(subject.name),
            if (subject.instructor.isNotEmpty || subject.code.isNotEmpty)
              Text(
                [
                  if (subject.code.isNotEmpty) subject.code,
                  if (subject.instructor.isNotEmpty) subject.instructor,
                  if (subject.assistant.isNotEmpty) subject.assistant,
                ].join(' • '),
                style: TextStyle(
                  fontSize: 12,
                  color: onColor.withValues(alpha: 0.85),
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'تعديل',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => pushPage(context, SubjectForm(subject: subject)),
          ),
          IconButton(
            tooltip: 'حذف',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _delete(store, subject),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: onColor,
          unselectedLabelColor: onColor.withValues(alpha: 0.7),
          indicatorColor: onColor,
          tabs: const [
            Tab(text: 'الدرجات'),
            Tab(text: 'المذاكرة'),
            Tab(text: 'المواعيد'),
            Tab(text: 'الجدول'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'subject-fab',
        onPressed: fab.$2,
        icon: const Icon(Icons.add),
        label: Text(fab.$1),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _GradesTab(subject: subject),
          _StudyTab(subject: subject),
          _DeadlinesTab(subject: subject),
          _ScheduleTab(subject: subject),
        ],
      ),
    );
  }
}

class _GradesTab extends StatelessWidget {
  const _GradesTab({required this.subject});

  final Subject subject;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final summary = store.gradeSummary(subject);
    final theme = Theme.of(context);
    final color = Color(subject.colorValue);
    final percent = summary.percentSoFar;

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: formatNumber(summary.earned),
                              style: theme.textTheme.displaySmall?.copyWith(
                                color: color,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextSpan(
                              text:
                                  '  من ${formatNumber(summary.attemptedMax)}',
                              style: theme.textTheme.titleMedium,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (percent != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            formatPercent(percent),
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(gradeLabel(percent)),
                        ],
                      ),
                  ],
                ),
                if (summary.bonus > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Pill(
                      'منهم ${formatNumber(summary.bonus)} بونص',
                      color: const Color(0xFF8E24AA),
                      icon: Icons.star,
                    ),
                  ),
                const SizedBox(height: 14),
                RoundedProgress(
                  value: summary.total == 0
                      ? 0
                      : summary.earned / summary.total,
                  color: color,
                  height: 10,
                ),
                const SizedBox(height: 6),
                Text(
                  'ضامن ${formatNumber(summary.earned)} من ${formatNumber(summary.total)} '
                  '• فاضل ${formatNumber(summary.remaining)} درجة لسه متسجلتش',
                  style: theme.textTheme.bodySmall,
                ),
                Text(
                  'الفاينل ${formatNumber(subject.finalExamMarks)} '
                  '• أعمال السنة ${formatNumber(subject.courseworkMarks)}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
        if (summary.byCategory.isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in summary.byCategory.values)
                    Chip(
                      avatar: Icon(c.category.icon, size: 18),
                      label: Text(
                        '${c.category.label}: ${fraction(c.score, c.max)}',
                      ),
                    ),
                ],
              ),
            ),
          ),
        _NeededCard(summary: summary),
        SectionHeader(
          'كل الدرجات (${summary.entries.length})',
          padding: const EdgeInsetsDirectional.fromSTEB(4, 16, 4, 6),
        ),
        if (summary.entries.isEmpty)
          const EmptyState(
            icon: Icons.emoji_events_outlined,
            title: 'لسه مفيش درجات',
            message: 'سجل كل درجة تاخدها: كويز، ميدترم، أسايمنت، حضور أو بونص، وهحسبلك مجموعك وتقديرك',
          )
        else
          Card(
            child: Column(
              children: [for (final g in summary.entries) GradeTile(grade: g)],
            ),
          ),
      ],
    );
  }
}

/// "How much do I still need for each grade band?"
class _NeededCard extends StatelessWidget {
  const _NeededCard({required this.summary});

  final SubjectGradeSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('محتاج كام عشان تجيب…', style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              'من الـ ${formatNumber(summary.remaining)} درجة اللي لسه باقية (الفاينل وأي حاجة متسجلتش)',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            for (final band in gradeBands.reversed)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 112,
                      child: Text(
                        '${band.label} (${band.minPercent.round()}%)',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: _neededText(context, band)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _neededText(BuildContext context, GradeBand band) {
    final needed = summary.neededFor(band.minPercent);
    if (needed <= 0) {
      return const Pill('ضامنه ✓', color: Color(0xFF22A45D));
    }
    if (!summary.canReach(band.minPercent)) {
      return const Pill('مش هينفع يتجاب', color: Color(0xFF9E9E9E));
    }
    final share = summary.remaining == 0 ? 0 : needed / summary.remaining;
    final color = share > 0.85
        ? const Color(0xFFE53935)
        : share > 0.6
        ? const Color(0xFFF59E0B)
        : Theme.of(context).colorScheme.primary;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Pill(
        'محتاج ${formatNumber((needed * 100).ceil() / 100)} من ${formatNumber(summary.remaining)}',
        color: color,
      ),
    );
  }
}

class _StudyTab extends StatelessWidget {
  const _StudyTab({required this.subject});

  final Subject subject;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final items = store.studyItemsFor(subject.id);
    if (items.isEmpty) {
      return const EmptyState(
        icon: Icons.menu_book_outlined,
        title: 'لسه مفيش محاضرات متسجلة',
        message: 'كل ما محاضرة أو سكشن ينزل سجله هنا وعلّم عليه لما تذاكره',
      );
    }
    final done = items.where((i) => i.status.isDone).length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ذاكرت $done من ${items.length}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                RoundedProgress(
                  value: done / items.length,
                  color: Color(subject.colorValue),
                ),
              ],
            ),
          ),
        ),
        Card(
          child: Column(
            children: [for (final i in items) StudyItemTile(item: i)],
          ),
        ),
      ],
    );
  }
}

class _DeadlinesTab extends StatelessWidget {
  const _DeadlinesTab({required this.subject});

  final Subject subject;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final now = DateTime.now();
    final assessments = store.assessmentsFor(subject.id);
    final pending = assessments.where((a) => !a.done).toList();
    final done = assessments.where((a) => a.done).toList().reversed.toList();
    final projects = store.projectsFor(subject.id);
    if (assessments.isEmpty && projects.isEmpty) {
      return const EmptyState(
        icon: Icons.event_note_outlined,
        title: 'مفيش كويزات ولا تسليمات',
        message: 'ضيف الكويزات والامتحانات والأسايمنتات بتاعة المادة دي',
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 96),
      children: [
        if (pending.isNotEmpty) ...[
          const SectionHeader('الجاية'),
          Card(
            child: Column(
              children: [
                for (final a in pending)
                  AssessmentTile(assessment: a, now: now, showSubject: false),
              ],
            ),
          ),
        ],
        if (projects.isNotEmpty) ...[
          const SectionHeader('المشاريع'),
          for (final p in projects) ProjectCard(project: p, now: now),
        ],
        if (done.isNotEmpty) ...[
          const SectionHeader('خلصت'),
          Card(
            child: Column(
              children: [
                for (final a in done)
                  AssessmentTile(assessment: a, now: now, showSubject: false),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _ScheduleTab extends StatelessWidget {
  const _ScheduleTab({required this.subject});

  final Subject subject;

  @override
  Widget build(BuildContext context) {
    final sessions = context.watch<AppStore>().sessionsFor(subject.id);
    if (sessions.isEmpty) {
      return const EmptyState(
        icon: Icons.calendar_month_outlined,
        title: 'المادة دي مش في الجدول',
        message: 'ضيف مواعيد المحاضرات والسكاشن وهفكرك قبل كل واحدة',
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
      children: [
        for (final s in sessions) SessionTile(session: s, showDay: true),
      ],
    );
  }
}
