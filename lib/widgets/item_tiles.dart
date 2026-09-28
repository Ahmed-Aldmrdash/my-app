import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/models.dart';
import '../screens/assessment_form.dart';
import '../screens/grade_form.dart';
import '../screens/project_detail_screen.dart';
import '../screens/session_form.dart';
import '../screens/study_item_form.dart';
import '../screens/task_form.dart';
import '../utils/formatters.dart';
import '../utils/labels.dart';
import 'common.dart';

/// A timetable slot card.
class SessionTile extends StatelessWidget {
  const SessionTile({
    super.key,
    required this.session,
    this.showDay = false,
    this.highlight = false,
  });

  final ClassSession session;
  final bool showDay;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final subject = store.subjectById(session.subjectId);
    final color = subjectColor(subject, context);
    final theme = Theme.of(context);
    final details = [
      if (showDay) weekdayNames[session.weekday]!,
      if (session.location.isNotEmpty) session.location,
      if (session.instructor.isNotEmpty) session.instructor,
    ].join(' • ');
    return Card(
      shape: highlight
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: color, width: 2),
            )
          : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => pushPage(context, SessionForm(session: session)),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 76,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      formatMinuteOfDay(session.startMinute),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      formatMinuteOfDay(session.endMinute),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Container(
                width: 4,
                margin: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        subject?.name ?? 'مادة محذوفة',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Pill(
                            session.type.label,
                            color: color,
                            icon: session.type.icon,
                          ),
                          if (details.isNotEmpty)
                            Text(details, style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                tooltip: session.notify ? 'إيقاف الإشعار' : 'تشغيل الإشعار',
                icon: Icon(
                  session.notify
                      ? Icons.notifications_active
                      : Icons.notifications_off_outlined,
                  color: session.notify ? color : theme.disabledColor,
                ),
                onPressed: () => store.saveSession(
                  session.copyWith(notify: !session.notify),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A lecture/section in the study list with a quick "studied" toggle.
class StudyItemTile extends StatelessWidget {
  const StudyItemTile({
    super.key,
    required this.item,
    this.showSubject = false,
  });

  final StudyItem item;
  final bool showSubject;

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    final theme = Theme.of(context);
    final subject = store.subjectById(item.subjectId);
    final status = item.status;
    final subtitle = [
      if (showSubject && subject != null) subject.name,
      'نزلت ${friendlyDay(item.releaseDate, DateTime.now())}',
      if (item.notes.isNotEmpty) '📝',
    ].join(' • ');
    return ListTile(
      contentPadding: const EdgeInsetsDirectional.only(start: 8, end: 4),
      leading: IconButton(
        tooltip: status.isDone ? 'رجعها لسه' : 'اتذاكرت',
        icon: Icon(status.icon, color: status.color, size: 28),
        onPressed: () => store.setStudyStatus(
          item.id,
          status.isDone ? StudyStatus.notStarted : StudyStatus.studied,
        ),
      ),
      title: Text(
        item.title,
        style: status.isDone
            ? theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              )
            : null,
      ),
      subtitle: Text(subtitle),
      onTap: () => pushPage(context, StudyItemForm(item: item)),
      trailing: PopupMenuButton<StudyStatus>(
        tooltip: 'الحالة',
        initialValue: status,
        onSelected: (s) => store.setStudyStatus(item.id, s),
        itemBuilder: (_) => [
          for (final s in StudyStatus.values)
            PopupMenuItem(
              value: s,
              child: Row(
                children: [
                  Icon(s.icon, color: s.color),
                  const SizedBox(width: 10),
                  Text(s.label),
                ],
              ),
            ),
        ],
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Pill(status.label, color: status.color),
        ),
      ),
    );
  }
}

class TaskTile extends StatelessWidget {
  const TaskTile({super.key, required this.task, required this.now});

  final TaskItem task;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    final theme = Theme.of(context);
    final subject = store.subjectById(task.subjectId);
    final overdue = task.isOverdue(now);
    final subtitle = [
      if (task.dueDate != null) friendlyDateTime(task.dueDate!, now),
      ?subject?.name,
    ].join(' • ');
    return ListTile(
      contentPadding: const EdgeInsetsDirectional.only(start: 4, end: 12),
      leading: Checkbox(
        value: task.done,
        shape: const CircleBorder(),
        onChanged: (_) => store.toggleTask(task.id),
      ),
      title: Text(
        task.title,
        style: task.done
            ? TextStyle(
                decoration: TextDecoration.lineThrough,
                color: theme.colorScheme.onSurfaceVariant,
              )
            : null,
      ),
      subtitle: subtitle.isEmpty
          ? null
          : Text(
              subtitle,
              style: overdue ? TextStyle(color: theme.colorScheme.error) : null,
            ),
      trailing: task.done
          ? null
          : Icon(Icons.flag, color: task.priority.color, size: 20),
      onTap: () => pushPage(context, TaskForm(task: task)),
    );
  }
}

/// Opens a dialog to mark a quiz/assignment done and optionally record the
/// mark it got.
Future<void> showCompleteAssessmentDialog(
  BuildContext context,
  Assessment a,
) async {
  final store = context.read<AppStore>();
  final existing = store.gradeById(a.gradeId);
  final score = TextEditingController(
    text: existing == null ? '' : formatNumber(existing.score),
  );
  final max = TextEditingController(
    text: existing == null ? '' : formatNumber(existing.maxScore),
  );
  String? error;
  final result = await showDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text('${a.title} ${a.type.doneLabel} ✓'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('لو عرفت درجتك سجلها هنا وهتتحسب في درجات المادة:'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: score,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'درجتك'),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('من'),
                ),
                Expanded(
                  child: TextField(
                    controller: max,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'الدرجة النهائية',
                    ),
                  ),
                ),
              ],
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  error!,
                  style: TextStyle(color: Theme.of(ctx).colorScheme.error),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'no-grade'),
            child: const Text('من غير درجة'),
          ),
          FilledButton(
            onPressed: () {
              final s = parseNumber(score.text);
              final m = parseNumber(max.text);
              if (s == null || m == null || m <= 0 || s < 0) {
                setState(() => error = 'اكتب الدرجة والنهاية العظمى صح');
                return;
              }
              Navigator.pop(ctx, 'grade');
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    ),
  );
  final scoreValue = parseNumber(score.text);
  final maxValue = parseNumber(max.text);
  score.dispose();
  max.dispose();
  if (result == null) return;
  if (result == 'grade') {
    await store.completeAssessment(
      a.id,
      done: true,
      score: scoreValue,
      maxScore: maxValue,
      category: a.type.gradeCategory,
    );
  } else {
    await store.completeAssessment(a.id, done: true);
  }
}

class AssessmentTile extends StatelessWidget {
  const AssessmentTile({
    super.key,
    required this.assessment,
    required this.now,
    this.showSubject = true,
  });

  final Assessment assessment;
  final DateTime now;
  final bool showSubject;

  @override
  Widget build(BuildContext context) {
    final a = assessment;
    final store = context.read<AppStore>();
    final subject = store.subjectById(a.subjectId);
    final color = subjectColor(subject, context);
    final grade = store.gradeById(a.gradeId);
    final subtitle = [
      if (showSubject) ?subject?.name,
      friendlyDateTime(a.dueDate, now),
      if (a.location.isNotEmpty) a.location,
    ].join(' • ');

    final Widget trailing;
    if (!a.done) {
      trailing = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          CountdownPill(due: a.dueDate, now: now),
          const SizedBox(height: 2),
          InkWell(
            onTap: () => showCompleteAssessmentDialog(context, a),
            child: Text(
              '${a.type.doneLabel}؟',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      );
    } else if (grade != null) {
      trailing = InkWell(
        onTap: () => pushPage(context, GradeForm(grade: grade)),
        child: Pill(
          fraction(grade.score, grade.maxScore),
          color: const Color(0xFF22A45D),
          icon: Icons.emoji_events_outlined,
        ),
      );
    } else {
      trailing = TextButton(
        onPressed: () => showCompleteAssessmentDialog(context, a),
        child: const Text('سجل الدرجة'),
      );
    }

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.15),
        child: Icon(a.done ? Icons.check : a.type.icon, color: color),
      ),
      title: Text('${a.type.label}: ${a.title}'),
      subtitle: Text(subtitle),
      trailing: trailing,
      onTap: () => pushPage(context, AssessmentForm(assessment: a)),
    );
  }
}

class ProjectCard extends StatelessWidget {
  const ProjectCard({super.key, required this.project, required this.now});

  final Project project;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final p = project;
    final store = context.read<AppStore>();
    final subject = store.subjectById(p.subjectId);
    final color = subject == null
        ? Theme.of(context).colorScheme.primary
        : Color(subject.colorValue);
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => pushPage(context, ProjectDetailScreen(projectId: p.id)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.rocket_launch_outlined, color: color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(p.title, style: theme.textTheme.titleMedium),
                  ),
                  if (p.submitted)
                    const Pill(
                      'اتسلّم',
                      color: Color(0xFF22A45D),
                      icon: Icons.check,
                    )
                  else if (p.deadline != null)
                    CountdownPill(due: p.deadline!, now: now),
                ],
              ),
              if (subject != null) ...[
                const SizedBox(height: 6),
                SubjectChip(subject),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: RoundedProgress(value: p.progress, color: color),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${(p.progress * 100).round()}%',
                    style: theme.textTheme.titleSmall,
                  ),
                ],
              ),
              if (p.steps.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'خلصت ${p.doneSteps} من ${p.steps.length} مراحل',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class GradeTile extends StatelessWidget {
  const GradeTile({super.key, required this.grade});

  final GradeEntry grade;

  @override
  Widget build(BuildContext context) {
    final g = grade;
    final theme = Theme.of(context);
    final ratio = g.ratio;
    final Color color;
    if (g.isBonus) {
      color = const Color(0xFF8E24AA);
    } else if (ratio == null) {
      color = theme.colorScheme.outline;
    } else if (ratio >= 0.85) {
      color = const Color(0xFF22A45D);
    } else if (ratio >= 0.65) {
      color = const Color(0xFF2E7DD7);
    } else if (ratio >= 0.5) {
      color = const Color(0xFFF59E0B);
    } else {
      color = const Color(0xFFE53935);
    }
    final subtitle = [
      g.category.label,
      'اتاخدت ${formatShortDate(g.date)}',
      if (g.notes.isNotEmpty) g.notes,
    ].join(' • ');
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.14),
        child: Icon(g.category.icon, color: color),
      ),
      title: Text(g.title),
      subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: g.isBonus
          ? Pill(
              '${ltr('+${formatNumber(g.score)}')} بونص',
              color: color,
              icon: Icons.star,
            )
          : Text(
              fraction(g.score, g.maxScore),
              style: theme.textTheme.titleMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
      onTap: () => pushPage(context, GradeForm(grade: g)),
    );
  }
}
