import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/models.dart';
import '../utils/formatters.dart';
import '../utils/grade_calculator.dart';
import '../utils/labels.dart';
import '../widgets/common.dart';
import 'subject_detail_screen.dart';
import 'subject_form.dart';

/// All subjects with their marks and study progress at a glance.
class SubjectsScreen extends StatelessWidget {
  const SubjectsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final theme = Theme.of(context);
    final summaries = [for (final s in store.subjects) store.gradeSummary(s)];
    final overall = overallPercent(summaries);
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(title: const Text('المواد والدرجات')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'subjects-fab',
        onPressed: () => pushPage(context, const SubjectForm()),
        icon: const Icon(Icons.add),
        label: const Text('مادة جديدة'),
      ),
      body: store.subjects.isEmpty
          ? const EmptyState(
              icon: Icons.menu_book_outlined,
              title: 'ابدأ بإضافة موادك',
              message: 'كل مادة ليها درجاتها ومحاضراتها وكويزاتها وجدولها، وتقدر تتابعها أول بأول',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
              children: [
                if (overall != null)
                  Card(
                    color: theme.colorScheme.primaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(
                            Icons.insights,
                            size: 36,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'مستواك لحد دلوقتي',
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    color: theme.colorScheme.onPrimaryContainer,
                                  ),
                                ),
                                Text(
                                  '${formatPercent(overall)} — ${gradeLabel(overall)}',
                                  style: theme.textTheme.headlineSmall
                                      ?.copyWith(
                                        color: theme
                                            .colorScheme
                                            .onPrimaryContainer,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                Text(
                                  'متوسط نسبتك في المواد من الدرجات اللي اتسجلت',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onPrimaryContainer,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                for (final summary in summaries)
                  _SubjectCard(summary: summary, now: now),
              ],
            ),
    );
  }
}

class _SubjectCard extends StatelessWidget {
  const _SubjectCard({required this.summary, required this.now});

  final SubjectGradeSummary summary;
  final DateTime now;

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
    final percent = summary.percentSoFar;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () =>
            pushPage(context, SubjectDetailScreen(subjectId: subject.id)),
        child: Container(
          decoration: BoxDecoration(
            border: BorderDirectional(
              start: BorderSide(color: color, width: 6),
            ),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
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
                            style: theme.textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                  if (percent != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          formatPercent(percent),
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: color,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          gradeLabel(percent),
                          style: theme.textTheme.labelSmall,
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  Pill(
                    summary.hasGrades
                        ? '${formatNumber(summary.earned)} من ${formatNumber(summary.attemptedMax)}'
                        : 'مفيش درجات لسه',
                    color: color,
                    icon: Icons.emoji_events_outlined,
                  ),
                  if (lectures.isNotEmpty)
                    Pill(
                      'ذاكرت ${ltr('$studied/${lectures.length}')}',
                      color: studied == lectures.length
                          ? const Color(0xFF22A45D)
                          : const Color(0xFFF59E0B),
                      icon: Icons.menu_book,
                    ),
                  if (next != null)
                    Pill(
                      '${next.type.label} ${friendlyDay(next.dueDate, now)}',
                      color: theme.colorScheme.error,
                      icon: next.type.icon,
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
