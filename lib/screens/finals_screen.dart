import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/common.dart';
import 'export_screen.dart';
import 'final_exam_form.dart';

/// The finals timetable with countdowns, and the study plan until the last
/// exam.
class FinalsScreen extends StatefulWidget {
  const FinalsScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  State<FinalsScreen> createState() => _FinalsScreenState();
}

class _FinalsScreenState extends State<FinalsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(
    length: 2,
    vsync: this,
    initialIndex: widget.initialTab,
  )..addListener(() => setState(() {}));

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final onPlan = _tabs.index == 1;
    return Scaffold(
      appBar: AppBar(
        title: const Text('الفاينال'),
        actions: [
          IconButton(
            tooltip: 'صورة جدول الفاينال',
            icon: const Icon(Icons.image_outlined),
            onPressed: () =>
                pushPage(context, const TimetableExportScreen(finals: true)),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'الامتحانات'),
            Tab(text: 'خطة المذاكرة'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'finals-fab',
        onPressed: () => pushPage(
          context,
          onPlan ? const PlanEntryForm() : const FinalExamForm(),
        ),
        icon: const Icon(Icons.add_rounded),
        label: Text(onPlan ? 'مهمة في الخطة' : 'امتحان فاينال'),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          const _ExamsTab(),
          _PlanTab(onAddExam: () => _tabs.animateTo(0)),
        ],
      ),
    );
  }
}

class _ExamsTab extends StatelessWidget {
  const _ExamsTab();

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final exams = store.finalsSorted;
    if (exams.isEmpty) {
      return const EmptyState(
        icon: Icons.workspace_premium_rounded,
        title: 'ضيف جدول الفاينال',
        message:
            'سجل ميعاد كل امتحان ومكانه، وهعدّ لك الأيام الفاضلة '
            'وأعملك خطة مذاكرة لحد آخر امتحان',
      );
    }
    return NowBuilder(
      builder: (context, now) {
        final upcoming = exams.where((e) => !e.isOver(now)).toList();
        final past = exams.where((e) => e.isOver(now)).toList().reversed;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          children: [
            if (upcoming.isNotEmpty)
              _NextExamCard(exam: upcoming.first, now: now),
            if (upcoming.length > 1) ...[
              const SectionHeader('الجاية', icon: Icons.upcoming_rounded),
              for (final e in upcoming.skip(1)) _ExamTile(exam: e, now: now),
            ],
            if (past.isNotEmpty) ...[
              const SectionHeader('خلصت', icon: Icons.task_alt_rounded),
              for (final e in past) _ExamTile(exam: e, now: now, past: true),
            ],
          ],
        );
      },
    );
  }
}

/// The next exam, big, with a countdown.
class _NextExamCard extends StatelessWidget {
  const _NextExamCard({required this.exam, required this.now});

  final FinalExam exam;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    final subject = store.subjectById(exam.subjectId);
    final color = subject == null
        ? AppColors.primary
        : Color(subject.colorValue);
    final onColor = AppColors.onColor(color);
    final left = exam.start.difference(now);
    final days = left.inDays;
    final hours = left.inHours % 24;
    final details = [
      friendlyDateTime(exam.start, now),
      if (exam.place.isNotEmpty) exam.place,
      if (exam.seat.isNotEmpty) 'رقم الجلوس ${ltr(exam.seat)}',
    ].join(' • ');
    return AppCard(
      gradient: AppColors.gradientOf(color),
      onTap: () => pushPage(context, FinalExamForm(exam: exam)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'الامتحان الجاي',
            style: TextStyle(
              color: onColor.withValues(alpha: 0.85),
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            subject?.name ?? 'مادة اتمسحت',
            style: TextStyle(
              color: onColor,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _CountBox(value: days, label: 'يوم', color: onColor),
              const SizedBox(width: 10),
              _CountBox(value: hours, label: 'ساعة', color: onColor),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  left.isNegative
                      ? 'بدأ دلوقتي — ربنا معاك 🤲'
                      : countdownText(exam.start, now),
                  style: TextStyle(color: onColor, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            details,
            style: TextStyle(color: onColor.withValues(alpha: 0.9)),
          ),
        ],
      ),
    );
  }
}

class _CountBox extends StatelessWidget {
  const _CountBox({
    required this.value,
    required this.label,
    required this.color,
  });

  final int value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            '${value < 0 ? 0 : value}',
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          Text(label, style: TextStyle(color: color, fontSize: 12)),
        ],
      ),
    );
  }
}

class _ExamTile extends StatelessWidget {
  const _ExamTile({required this.exam, required this.now, this.past = false});

  final FinalExam exam;
  final DateTime now;
  final bool past;

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    final subject = store.subjectById(exam.subjectId);
    final theme = Theme.of(context);
    final color = subject == null
        ? theme.colorScheme.outline
        : Color(subject.colorValue);
    return Opacity(
      opacity: past ? 0.6 : 1,
      child: AppCard(
        onTap: () => pushPage(context, FinalExamForm(exam: exam)),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            IconBadge(Icons.workspace_premium_rounded, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    subject?.name ?? 'مادة اتمسحت',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    [
                      '${formatLongDate(exam.start)} • ${formatTime(exam.start)}',
                      if (exam.place.isNotEmpty) exam.place,
                    ].join(' • '),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            if (!past) CountdownPill(due: exam.start, now: now),
          ],
        ),
      ),
    );
  }
}

class _PlanTab extends StatelessWidget {
  const _PlanTab({required this.onAddExam});

  final VoidCallback onAddExam;

  Future<void> _generate(BuildContext context) async {
    final store = context.read<AppStore>();
    final now = DateTime.now();
    if (store.upcomingFinals(now).isEmpty) {
      showSnack(context, 'ضيف امتحاناتك الأول عشان أعرف أخطط لحد إمتى');
      onAddExam();
      return;
    }
    final hasAuto = store.planEntries.any((e) => e.auto && !e.done);
    if (hasAuto) {
      final ok = await confirmDelete(
        context,
        'أعيد ترتيب الخطة؟',
        message:
            'المهام اللي عملها التطبيق ولسه ماخلصتش هتترتب من جديد. '
            'اللي خلصتها واللي عدلتها أو ضفتها بإيدك هيفضلوا زي ما هم.',
        confirmLabel: 'رتّب',
      );
      if (!ok || !context.mounted) return;
    }
    final count = await store.regenerateStudyPlan(now);
    if (!context.mounted) return;
    showSnack(
      context,
      count == 0
          ? 'مفيش حاجة جديدة أضيفها — الخطة متظبطة'
          : 'ضفت للخطة ${countText(count, 'مهمة', 'مهمتين', 'مهام', 'مهمة')} 💪',
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final now = DateTime.now();
    final today = dateOnly(now);
    final theme = Theme.of(context);
    final entries = store.planEntries;
    final exams = store.finalsSorted;
    // Unfinished entries of past days, unless their exam is already over.
    final over = {
      for (final x in exams)
        if (x.isOver(now)) x.id,
    };
    final missed = entries
        .where(
          (e) => !e.done && e.day.isBefore(today) && !over.contains(e.examId),
        )
        .toList();
    final done = entries.where((e) => e.done).length;

    // Every day from today that has entries or an exam.
    final days = <DateTime>{
      for (final e in entries)
        if (!e.day.isBefore(today)) e.day,
      for (final x in exams)
        if (!x.day.isBefore(today)) x.day,
    }.toList()..sort();

    final perDay = store.settings.planPerDay;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  ProgressRing(
                    value: entries.isEmpty ? 0 : done / entries.length,
                    size: 60,
                    stroke: 7,
                    child: Text(
                      entries.isEmpty
                          ? '—'
                          : '${(done / entries.length * 100).round()}%',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entries.isEmpty
                              ? 'لسه مفيش خطة'
                              : 'خلصت $done من ${entries.length}',
                          style: theme.textTheme.titleMedium,
                        ),
                        Text(
                          'هوزّع المحاضرات اللي لسه والمراجعة على الأيام '
                          'لحد كل امتحان، وتقدر تعدّل أي حاجة بإيدك',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'مهام في اليوم',
                      style: theme.textTheme.labelLarge,
                    ),
                  ),
                  IconButton.filledTonal(
                    tooltip: 'أقل',
                    onPressed: perDay <= 1
                        ? null
                        : () => store.updateSettings(
                            store.settings.copyWith(planPerDay: perDay - 1),
                          ),
                    icon: const Icon(Icons.remove_rounded),
                  ),
                  SizedBox(
                    width: 36,
                    child: Text(
                      '$perDay',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  IconButton.filledTonal(
                    tooltip: 'أكتر',
                    onPressed: perDay >= 12
                        ? null
                        : () => store.updateSettings(
                            store.settings.copyWith(planPerDay: perDay + 1),
                          ),
                    icon: const Icon(Icons.add_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: () => _generate(context),
                icon: const Icon(Icons.auto_awesome_rounded),
                label: Text(
                  entries.any((e) => e.auto)
                      ? 'رتّب الخطة من جديد'
                      : 'اعمل الخطة أوتوماتيك',
                ),
              ),
            ],
          ),
        ),
        if (missed.isNotEmpty) ...[
          SectionHeader(
            'فاتتك',
            icon: Icons.history_rounded,
            trailing: SeeAllButton(
              'انقلهم للنهارده',
              onPressed: () => store.movePlanEntries(missed, today),
            ),
          ),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [for (final e in missed) _PlanTile(entry: e)],
            ),
          ),
        ],
        if (days.isEmpty && missed.isEmpty)
          const EmptyState(
            icon: Icons.event_note_rounded,
            title: 'الخطة فاضية',
            message: 'ضيف امتحاناتك ودوس "اعمل الخطة أوتوماتيك"',
          ),
        for (final day in days) ...[
          SectionHeader(
            _dayTitle(day, now),
            icon: day == today
                ? Icons.today_rounded
                : Icons.calendar_today_rounded,
            trailing: IconButton(
              tooltip: 'ضيف مهمة في اليوم ده',
              icon: const Icon(Icons.add_circle_outline_rounded),
              onPressed: () =>
                  pushPage(context, PlanEntryForm(initialDay: day)),
            ),
          ),
          for (final x in exams.where((x) => x.day == day))
            _ExamDayBanner(exam: x),
          if (entries.any((e) => e.day == day))
            AppCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  for (final e in entries.where((e) => e.day == day))
                    _PlanTile(entry: e),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

class _ExamDayBanner extends StatelessWidget {
  const _ExamDayBanner({required this.exam});

  final FinalExam exam;

  @override
  Widget build(BuildContext context) {
    final subject = context.read<AppStore>().subjectById(exam.subjectId);
    final color = subject == null
        ? AppColors.primary
        : Color(subject.colorValue);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Pill(
        'امتحان ${subject?.name ?? ''} الساعة ${formatTime(exam.start)} — بالتوفيق 🤲',
        color: color,
        icon: Icons.workspace_premium_rounded,
      ),
    );
  }
}

class _PlanTile extends StatelessWidget {
  const _PlanTile({required this.entry});

  final PlanEntry entry;

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    final subject = store.subjectById(entry.subjectId);
    final theme = Theme.of(context);
    final icon = switch (entry.kind) {
      PlanKind.study => Icons.menu_book_rounded,
      PlanKind.review => Icons.replay_rounded,
      PlanKind.practice => Icons.quiz_rounded,
      PlanKind.finalReview => Icons.flag_rounded,
      PlanKind.custom => Icons.edit_note_rounded,
    };
    return ListTile(
      onTap: () => pushPage(context, PlanEntryForm(entry: entry)),
      leading: Checkbox(
        value: entry.done,
        onChanged: (_) => store.togglePlanEntry(entry.id),
      ),
      title: Text(
        entry.title,
        style: TextStyle(
          decoration: entry.done ? TextDecoration.lineThrough : null,
          color: entry.done ? theme.colorScheme.onSurfaceVariant : null,
        ),
      ),
      subtitle: subject == null
          ? null
          : Align(
              alignment: AlignmentDirectional.centerStart,
              child: SubjectChip(subject),
            ),
      trailing: Icon(icon, color: theme.colorScheme.onSurfaceVariant),
    );
  }
}

/// "النهارده • 3 ديسمبر", "بكرة • 4 ديسمبر", or "الثلاثاء 15 ديسمبر" further
/// away.
String _dayTitle(DateTime day, DateTime now) {
  final friendly = friendlyDay(day, now);
  final date = formatShortDate(day);
  return friendly == date ? formatLongDate(day) : '$friendly • $date';
}
