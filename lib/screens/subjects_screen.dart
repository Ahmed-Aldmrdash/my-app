import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/grade_calculator.dart';
import '../utils/labels.dart';
import '../widgets/common.dart';
import 'subject_detail_screen.dart';
import 'subject_form.dart';

/// All subjects with their marks, study progress and attendance at a glance.
class SubjectsScreen extends StatelessWidget {
  const SubjectsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final summaries = [for (final s in store.subjects) store.gradeSummary(s)];
    final system = store.settings.gradingSystem;
    final overall = overallPercent(summaries);
    final gpa = expectedGpa(summaries);
    final now = DateTime.now();
    const white = Colors.white;

    return Scaffold(
      appBar: AppBar(title: const Text('المواد والدرجات')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'subjects-fab',
        onPressed: () => pushPage(context, const SubjectForm()),
        icon: const Icon(Icons.add_rounded),
        label: const Text('مادة جديدة'),
      ),
      body: store.subjects.isEmpty
          ? const EmptyState(
              icon: Icons.school_rounded,
              title: 'ابدأ بإضافة موادك',
              message:
                  'كل مادة ليها درجاتها ومحاضراتها وكويزاتها وحضورها وجدولها، '
                  'وتقدر تتابعها أول بأول',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
              children: [
                if (overall != null)
                  AppCard(
                    gradient: AppColors.heroGradient,
                    child: Row(
                      children: [
                        ProgressRing(
                          value: system == GradingSystem.gpa
                              ? (gpa ?? 0) / 4
                              : overall / 100,
                          size: 84,
                          stroke: 9,
                          color: white,
                          trackColor: white.withValues(alpha: 0.22),
                          child: Text(
                            system == GradingSystem.gpa
                                ? (gpa?.toStringAsFixed(2) ?? '—')
                                : formatPercent(overall),
                            style: const TextStyle(
                              color: white,
                              fontSize: 18,
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
                                system == GradingSystem.gpa
                                    ? 'المعدل التراكمي المتوقع'
                                    : 'مستواك لحد دلوقتي',
                                style: TextStyle(
                                  color: white.withValues(alpha: 0.85),
                                ),
                              ),
                              Text(
                                gradeText(overall, system),
                                style: const TextStyle(
                                  color: white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                system == GradingSystem.gpa
                                    ? 'محسوب من درجاتك بالساعات المعتمدة (تقريبي)'
                                    : 'متوسط نسبتك في المواد من الدرجات اللي اتسجلت',
                                style: TextStyle(
                                  color: white.withValues(alpha: 0.85),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                for (final summary in summaries)
                  _SubjectCard(summary: summary, now: now, system: system),
              ],
            ),
    );
  }
}

class _SubjectCard extends StatelessWidget {
  const _SubjectCard({
    required this.summary,
    required this.now,
    required this.system,
  });

  final SubjectGradeSummary summary;
  final DateTime now;
  final GradingSystem system;

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    final theme = Theme.of(context);
    final subject = summary.subject;
    final color = Color(subject.colorValue);
    final lectures = store.studyItemsFor(subject.id);
    final studied = lectures.where((l) => l.status.isDone).length;
    final next = store
        .assessmentsFor(subject.id)
        .where((a) => !a.done && a.dueDate.isAfter(now))
        .firstOrNull;
    final absences = store
        .attendanceOf(subject.id)
        .where((a) => !a.present)
        .length;
    final percent = summary.percentSoFar;

    return AppCard(
      padding: EdgeInsets.zero,
      onTap: () =>
          pushPage(context, SubjectDetailScreen(subjectId: subject.id)),
      child: Container(
        decoration: BoxDecoration(
          border: BorderDirectional(start: BorderSide(color: color, width: 6)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconBadge(Icons.menu_book_rounded, color: color, filled: true),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(subject.name, style: theme.textTheme.titleMedium),
                      if (subject.code.isNotEmpty ||
                          subject.instructor.isNotEmpty)
                        Text(
                          [
                            if (subject.code.isNotEmpty) subject.code,
                            if (subject.instructor.isNotEmpty)
                              subject.instructor,
                          ].join(' • '),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                if (percent != null)
                  ProgressRing(
                    value: percent / 100,
                    size: 56,
                    stroke: 6,
                    color: color,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          system == GradingSystem.gpa
                              ? gpaGradeFor(percent).letter
                              : formatPercent(percent),
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                Pill(
                  summary.hasGrades
                      ? '${formatNumber(summary.earned)} من ${formatNumber(summary.attemptedMax)}'
                            '${percent == null ? '' : ' • ${gradeText(percent, system)}'}'
                      : 'مفيش درجات لسه',
                  color: color,
                  icon: Icons.emoji_events_rounded,
                ),
                if (lectures.isNotEmpty)
                  Pill(
                    'ذاكرت ${ltr('$studied/${lectures.length}')}',
                    color: studied == lectures.length
                        ? AppColors.success
                        : AppColors.orange,
                    icon: Icons.auto_stories_rounded,
                  ),
                if (subject.absenceLimit > 0 || absences > 0)
                  Pill(
                    subject.absenceLimit > 0
                        ? 'غياب ${ltr('$absences/${subject.absenceLimit}')}'
                        : 'غياب $absences',
                    color:
                        subject.absenceLimit > 0 &&
                            absences >= subject.absenceLimit - 1
                        ? AppColors.danger
                        : AppColors.sky,
                    icon: Icons.event_busy_rounded,
                  ),
                if (next != null)
                  Pill(
                    '${next.type.label} ${friendlyDay(next.dueDate, now)}',
                    color: AppColors.coral,
                    icon: next.type.icon,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
