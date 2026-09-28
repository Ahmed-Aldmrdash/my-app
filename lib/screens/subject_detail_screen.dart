import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/grade_calculator.dart';
import '../utils/ids.dart';
import '../utils/labels.dart';
import '../utils/study_stats.dart';
import '../widgets/common.dart';
import '../widgets/item_tiles.dart';
import 'assessment_form.dart';
import 'focus_screen.dart';
import 'grade_form.dart';
import 'session_form.dart';
import 'study_item_form.dart';
import 'subject_form.dart';

/// Everything about one subject: marks, lectures, deadlines, attendance.
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
      message:
          'هيتمسح معاها جدولها ومحاضراتها وكويزاتها ودرجاتها وحضورها. '
          'التاسكات والمشاريع هتفضل.',
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
          icon: Icons.delete_outline_rounded,
          title: 'المادة دي اتمسحت',
        ),
      );
    }
    final color = Color(subject.colorValue);
    final onColor = AppColors.onColor(color);
    final system = store.settings.gradingSystem;
    final summary = store.gradeSummary(subject);
    final lectures = store.studyItemsFor(subject.id);
    final studied = lectures.where((l) => l.status.isDone).length;
    final attendance = store.attendanceOf(subject.id);
    final absent = attendance.where((a) => !a.present).length;
    final percent = summary.percentSoFar;

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
      _ => ('سجل حضور', () => showAttendanceSheet(context, subject)),
    };

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'subject-fab',
        onPressed: fab.$2,
        icon: const Icon(Icons.add_rounded),
        label: Text(fab.$1),
      ),
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverAppBar(
            pinned: true,
            expandedHeight: 250,
            backgroundColor: color,
            foregroundColor: onColor,
            title: Text(subject.name, style: TextStyle(color: onColor)),
            actions: [
              IconButton(
                tooltip: 'ذاكر المادة دي',
                icon: const Icon(Icons.play_circle_fill_rounded),
                onPressed: () =>
                    pushPage(context, FocusScreen(subjectId: subject.id)),
              ),
              IconButton(
                tooltip: 'تعديل',
                icon: const Icon(Icons.edit_rounded),
                onPressed: () =>
                    pushPage(context, SubjectForm(subject: subject)),
              ),
              IconButton(
                tooltip: 'حذف',
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: () => _delete(store, subject),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: AppColors.gradientOf(color),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 60, 20, 60),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          [
                            if (subject.code.isNotEmpty) subject.code,
                            if (subject.instructor.isNotEmpty)
                              subject.instructor,
                            if (subject.assistant.isNotEmpty) subject.assistant,
                          ].join(' • '),
                          style: TextStyle(
                            color: onColor.withValues(alpha: 0.85),
                          ),
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            _HeaderStat(
                              label: 'الدرجات',
                              value: percent == null
                                  ? '—'
                                  : '${formatPercent(percent)} ${system == GradingSystem.gpa ? gpaGradeFor(percent).letter : ''}',
                              color: onColor,
                            ),
                            _HeaderStat(
                              label: 'المذاكرة',
                              value: lectures.isEmpty
                                  ? '—'
                                  : ltr('$studied/${lectures.length}'),
                              color: onColor,
                            ),
                            _HeaderStat(
                              label: 'الغياب',
                              value: subject.absenceLimit > 0
                                  ? ltr('$absent/${subject.absenceLimit}')
                                  : '$absent',
                              color: onColor,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            bottom: TabBar(
              controller: _tabs,
              labelColor: onColor,
              unselectedLabelColor: onColor.withValues(alpha: 0.7),
              indicatorColor: onColor,
              indicatorWeight: 3,
              tabs: const [
                Tab(text: 'الدرجات'),
                Tab(text: 'المذاكرة'),
                Tab(text: 'المواعيد'),
                Tab(text: 'الحضور'),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabs,
          children: [
            _GradesTab(subject: subject),
            _StudyTab(subject: subject),
            _DeadlinesTab(subject: subject),
            _AttendanceTab(subject: subject),
          ],
        ),
      ),
    );
  }
}

class _HeaderStat extends StatelessWidget {
  const _HeaderStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsetsDirectional.only(end: 8),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            FittedBox(
              child: Text(
                value.trim(),
                style: TextStyle(
                  color: color,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: color.withValues(alpha: 0.85),
                fontSize: 12,
              ),
            ),
          ],
        ),
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
    final system = store.settings.gradingSystem;
    final theme = Theme.of(context);
    final color = Color(subject.colorValue);
    final percent = summary.percentSoFar;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'مجموعك لحد دلوقتي',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: formatNumber(summary.earned),
                                style: theme.textTheme.displaySmall?.copyWith(
                                  color: color,
                                  fontWeight: FontWeight.w800,
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
                        if (summary.bonus > 0)
                          Pill(
                            'منهم ${formatNumber(summary.bonus)} بونص',
                            color: AppColors.bonus,
                            icon: Icons.star_rounded,
                          ),
                      ],
                    ),
                  ),
                  if (percent != null)
                    ProgressRing(
                      value: percent / 100,
                      size: 86,
                      stroke: 9,
                      color: color,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            formatPercent(percent),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              height: 1.1,
                            ),
                          ),
                          Text(
                            gradeText(percent, system),
                            style: theme.textTheme.labelSmall,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              RoundedProgress(
                value: summary.total == 0 ? 0 : summary.earned / summary.total,
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
                '• أعمال السنة ${formatNumber(subject.courseworkMarks)}'
                '${system == GradingSystem.gpa ? ' • ${subject.creditHours} ساعات' : ''}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (summary.byCategory.isNotEmpty)
          AppCard(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in summary.byCategory.values)
                  Pill(
                    '${c.category.label}: ${fraction(c.score, c.max)}',
                    color: gradeColor(c.max == 0 ? null : c.score / c.max),
                    icon: c.category.icon,
                  ),
              ],
            ),
          ),
        _NeededCard(summary: summary, system: system),
        SectionHeader(
          'كل الدرجات (${summary.entries.length})',
          icon: Icons.format_list_numbered_rounded,
        ),
        if (summary.entries.isEmpty)
          const EmptyState(
            icon: Icons.emoji_events_rounded,
            title: 'لسه مفيش درجات',
            message:
                'سجل كل درجة تاخدها: كويز، ميدترم، أسايمنت، حضور أو بونص، '
                'وهحسبلك مجموعك وتقديرك',
          )
        else
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 6),
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
  const _NeededCard({required this.summary, required this.system});

  final SubjectGradeSummary summary;
  final GradingSystem system;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconBadge(
                Icons.flag_circle_rounded,
                color: AppColors.primary,
                size: 36,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'محتاج كام عشان تجيب…',
                  style: theme.textTheme.titleSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'من الـ ${formatNumber(summary.remaining)} درجة اللي لسه باقية (الفاينل وأي حاجة متسجلتش)',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          for (final band in targetBands(system))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 112,
                    child: Text(
                      '${band.label} (${band.minPercent.round()}%)',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: _neededText(context, band)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _neededText(BuildContext context, GradeBand band) {
    final needed = summary.neededFor(band.minPercent);
    final Widget pill;
    if (needed <= 0) {
      pill = const Pill(
        'ضامنه ✓',
        color: AppColors.success,
        icon: Icons.verified_rounded,
      );
    } else if (!summary.canReach(band.minPercent)) {
      pill = const Pill('مش هينفع يتجاب', color: Color(0xFF9A98B0));
    } else {
      final share = summary.remaining == 0 ? 0 : needed / summary.remaining;
      final color = share > 0.85
          ? AppColors.danger
          : share > 0.6
          ? AppColors.orange
          : Theme.of(context).colorScheme.primary;
      pill = Pill(
        'محتاج ${formatNumber((needed * 100).ceil() / 100)} من ${formatNumber(summary.remaining)}',
        color: color,
      );
    }
    return Align(alignment: AlignmentDirectional.centerStart, child: pill);
  }
}

class _StudyTab extends StatelessWidget {
  const _StudyTab({required this.subject});

  final Subject subject;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final items = store.studyItemsFor(subject.id);
    final now = DateTime.now();
    final week = minutesBySubject(
      store.studySessions,
      DateTime(now.year, now.month, now.day - 6),
    )[subject.id];
    final total = store.studySessions
        .where((s) => s.subjectId == subject.id)
        .fold<int>(0, (sum, s) => sum + s.minutes);
    final done = items.where((i) => i.status.isDone).length;
    final color = Color(subject.colorValue);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        AppCard(
          child: Row(
            children: [
              ProgressRing(
                value: items.isEmpty ? 0 : done / items.length,
                size: 70,
                stroke: 8,
                color: color,
                child: Text(
                  items.isEmpty
                      ? '—'
                      : '${(done / items.length * 100).round()}%',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ذاكرت $done من ${items.length}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      'وقت المذاكرة: ${studyTimeText(week ?? 0)} الأسبوع ده • '
                      '${studyTimeText(total)} إجمالي',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (items.isEmpty)
          const EmptyState(
            icon: Icons.menu_book_rounded,
            title: 'لسه مفيش محاضرات متسجلة',
            message: 'كل ما محاضرة أو سكشن ينزل سجله هنا وعلّم عليه لما تذاكره',
          )
        else
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
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
        icon: Icons.event_note_rounded,
        title: 'مفيش كويزات ولا تسليمات',
        message: 'ضيف الكويزات والامتحانات والأسايمنتات بتاعة المادة دي',
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      children: [
        if (pending.isNotEmpty) ...[
          const SectionHeader('الجاية', icon: Icons.upcoming_rounded),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                for (final a in pending)
                  AssessmentTile(assessment: a, now: now, showSubject: false),
              ],
            ),
          ),
        ],
        if (projects.isNotEmpty) ...[
          const SectionHeader('المشاريع', icon: Icons.rocket_launch_rounded),
          for (final p in projects) ProjectCard(project: p, now: now),
        ],
        if (done.isNotEmpty) ...[
          const SectionHeader('خلصت', icon: Icons.task_alt_rounded),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 6),
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

class _AttendanceTab extends StatelessWidget {
  const _AttendanceTab({required this.subject});

  final Subject subject;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final theme = Theme.of(context);
    final records = store.attendanceOf(subject.id);
    final sessions = store.sessionsFor(subject.id);
    final present = records.where((r) => r.present).length;
    final absent = records.length - present;
    final limit = subject.absenceLimit;
    final rate = records.isEmpty ? null : present / records.length;

    final String status;
    final Color statusColor;
    if (limit > 0 && absent >= limit) {
      status = '⚠️ وصلت لحد الغياب المسموح — خلي بالك من الحرمان';
      statusColor = AppColors.danger;
    } else if (limit > 0 && absent == limit - 1) {
      status = 'فاضلك غياب واحد بس قبل الحرمان';
      statusColor = AppColors.orange;
    } else if (limit > 0) {
      status = 'فاضلك ${limit - absent} غياب قبل الحرمان';
      statusColor = AppColors.success;
    } else {
      status = 'حدد عدد الغياب المسموح من تعديل المادة عشان أنبهك';
      statusColor = theme.colorScheme.onSurfaceVariant;
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ProgressRing(
                    value: rate ?? 0,
                    size: 76,
                    stroke: 8,
                    color: AppColors.success,
                    child: Text(
                      rate == null ? '—' : '${(rate * 100).round()}%',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('نسبة حضورك', style: theme.textTheme.titleMedium),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            Pill(
                              'حضور $present',
                              color: AppColors.success,
                              icon: Icons.how_to_reg_rounded,
                            ),
                            Pill(
                              limit > 0
                                  ? 'غياب ${ltr('$absent/$limit')}'
                                  : 'غياب $absent',
                              color: AppColors.danger,
                              icon: Icons.event_busy_rounded,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                status,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        SectionHeader(
          'مواعيدها في الجدول',
          icon: Icons.calendar_month_rounded,
          trailing: SeeAllButton(
            'إضافة',
            onPressed: () =>
                pushPage(context, SessionForm(initialSubjectId: subject.id)),
          ),
        ),
        if (sessions.isEmpty)
          AppCard(
            child: Text(
              'المادة دي مش في الجدول — ضيف مواعيدها وهفكرك قبل كل واحدة',
              style: theme.textTheme.bodyMedium,
            ),
          )
        else
          for (final s in sessions) SessionTile(session: s, showDay: true),
        SectionHeader(
          'سجل الحضور (${records.length})',
          icon: Icons.fact_check_rounded,
        ),
        if (records.isEmpty)
          AppCard(
            child: Text(
              'بعد كل محاضرة هتلاقي في الرئيسية "حضرت؟" — أو سجل من زرار "سجل حضور"',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            clip: true,
            child: Column(
              children: [
                for (final r in records)
                  Dismissible(
                    key: ValueKey(r.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      color: theme.colorScheme.errorContainer,
                      alignment: AlignmentDirectional.centerEnd,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: const Icon(Icons.delete_outline_rounded),
                    ),
                    onDismissed: (_) {
                      store.deleteAttendance(r.id);
                      showSnack(
                        context,
                        'اتمسح',
                        onUndo: () => store.saveAttendance(r),
                      );
                    },
                    child: ListTile(
                      leading: IconBadge(
                        r.present
                            ? Icons.how_to_reg_rounded
                            : Icons.event_busy_rounded,
                        color: r.present ? AppColors.success : AppColors.danger,
                        size: 40,
                      ),
                      title: Text(
                        '${r.type.label} • ${formatLongDate(r.date)}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: r.note.isEmpty ? null : Text(r.note),
                      trailing: Pill(
                        r.present ? 'حضرت' : 'غبت',
                        color: r.present ? AppColors.success : AppColors.danger,
                      ),
                      onTap: () => store.saveAttendance(
                        AttendanceRecord(
                          id: r.id,
                          subjectId: r.subjectId,
                          sessionId: r.sessionId,
                          type: r.type,
                          date: r.date,
                          present: !r.present,
                          note: r.note,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        if (records.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              'دوس على اليوم عشان تبدّل حضرت/غبت، واسحبه عشان تمسحه',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}

/// Records attendance for a day that is not (or not only) in the timetable.
Future<void> showAttendanceSheet(BuildContext context, Subject subject) async {
  final store = context.read<AppStore>();
  var day = DateTime.now();
  var type = SessionType.lecture;
  bool? present;
  await showModalBottomSheet<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheet) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'سجل حضور ${subject.name}',
              style: Theme.of(ctx).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            DateTimeField(
              label: 'اليوم',
              value: day,
              withTime: false,
              onChanged: (d) => setSheet(() => day = d ?? day),
            ),
            formGap,
            SegmentedButton<SessionType>(
              segments: [
                for (final t in SessionType.values)
                  ButtonSegment(value: t, label: Text(t.label)),
              ],
              selected: {type},
              onSelectionChanged: (s) => setSheet(() => type = s.first),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.success,
                    ),
                    onPressed: () {
                      present = true;
                      Navigator.pop(ctx);
                    },
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('حضرت'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.danger,
                    ),
                    onPressed: () {
                      present = false;
                      Navigator.pop(ctx);
                    },
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('غبت'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  if (present == null) return;
  await store.saveAttendance(
    AttendanceRecord(
      id: newId(),
      subjectId: subject.id,
      type: type,
      date: DateTime(day.year, day.month, day.day),
      present: present!,
    ),
  );
}
