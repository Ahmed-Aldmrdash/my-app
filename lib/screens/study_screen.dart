import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/models.dart';
import '../utils/formatters.dart';
import '../utils/labels.dart';
import '../widgets/common.dart';
import '../widgets/item_tiles.dart';
import 'study_item_form.dart';

enum StudyFilter { pending, done, all }

/// Released lectures across all subjects and whether they were studied.
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('المذاكرة'),
        actions: [
          PopupMenuButton<String?>(
            tooltip: 'فلتر بالمادة',
            icon: Icon(
              _subjectId == null ? Icons.filter_list : Icons.filter_list_alt,
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
        icon: const Icon(Icons.add),
        label: const Text('محاضرة نزلت'),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          Card(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  SizedBox(
                    width: 72,
                    height: 72,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CircularProgressIndicator(
                          value: all.isEmpty ? 0 : doneCount / all.length,
                          strokeWidth: 8,
                          strokeCap: StrokeCap.round,
                          backgroundColor: theme.colorScheme.primary.withValues(
                            alpha: 0.15,
                          ),
                        ),
                        Center(
                          child: Text(
                            all.isEmpty
                                ? '—'
                                : '${(doneCount / all.length * 100).round()}%',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selectedSubject?.name ?? 'كل المواد',
                          style: theme.textTheme.labelLarge,
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
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SegmentedButton<StudyFilter>(
              segments: const [
                ButtonSegment(
                  value: StudyFilter.pending,
                  label: Text('لسه'),
                  icon: Icon(Icons.pending_actions),
                ),
                ButtonSegment(
                  value: StudyFilter.done,
                  label: Text('خلصتها'),
                  icon: Icon(Icons.task_alt),
                ),
                ButtonSegment(value: StudyFilter.all, label: Text('الكل')),
              ],
              selected: {_filter},
              onSelectionChanged: (s) => setState(() => _filter = s.first),
            ),
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
          icon: Icons.menu_book_outlined,
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
                  width: 60,
                  child: RoundedProgress(
                    value: items.isEmpty ? 0 : done / items.length,
                    color: color,
                    height: 6,
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
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 12),
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
              ? Icons.celebration_outlined
              : Icons.menu_book_outlined,
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
