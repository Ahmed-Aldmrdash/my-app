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
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/labels.dart';
import 'common.dart';

/// A timetable slot card. When [attendanceDay] is given and the class has
/// started, it also offers "حضرت / غبت".
class SessionTile extends StatelessWidget {
  const SessionTile({
    super.key,
    required this.session,
    this.showDay = false,
    this.highlight = false,
    this.dimmed = false,
    this.attendanceDay,
  });

  final ClassSession session;
  final bool showDay;
  final bool highlight;
  final bool dimmed;
  final DateTime? attendanceDay;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final subject = store.subjectById(session.subjectId);
    final color = subjectColor(subject, context);
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final day = attendanceDay;
    final record = day == null ? null : store.attendanceFor(session.id, day);

    return Opacity(
      opacity: dimmed && record == null && day == null ? 0.55 : 1,
      child: AppCard(
        padding: EdgeInsets.zero,
        onTap: () => pushPage(context, SessionForm(session: session)),
        color: highlight ? color.withValues(alpha: 0.10) : null,
        child: Column(
          children: [
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 78,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          formatMinuteOfDay(session.startMinute),
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          formatMinuteOfDay(session.endMinute),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: muted,
                          ),
                        ),
                        if (showDay)
                          Text(
                            weekdayNames[session.weekday]!,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: color,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    width: 4,
                    margin: const EdgeInsets.symmetric(vertical: 14),
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
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  subject?.name ?? 'مادة محذوفة',
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleMedium,
                                ),
                              ),
                              if (highlight) ...[
                                const SizedBox(width: 6),
                                Pill('دلوقتي', color: color),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Pill(
                                session.type.label,
                                color: color,
                                icon: session.type.icon,
                              ),
                              if (session.location.isNotEmpty)
                                _Meta(Icons.place_rounded, session.location),
                              if (session.instructor.isNotEmpty)
                                _Meta(Icons.person_rounded, session.instructor),
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
                          ? Icons.notifications_active_rounded
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
            if (day != null)
              _AttendanceBar(
                record: record,
                color: color,
                onSet: (present) =>
                    store.setAttendance(session, day, present: present),
                onClear: record == null
                    ? null
                    : () => store.deleteAttendance(record.id),
              ),
          ],
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: muted),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: muted),
          ),
        ),
      ],
    );
  }
}

class _AttendanceBar extends StatelessWidget {
  const _AttendanceBar({
    required this.record,
    required this.color,
    required this.onSet,
    required this.onClear,
  });

  final AttendanceRecord? record;
  final Color color;
  final ValueChanged<bool> onSet;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = record;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
      ),
      child: r == null
          ? Row(
              children: [
                Expanded(
                  child: Text(
                    'حضرت؟',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _SmallButton(
                  label: 'حضرت',
                  icon: Icons.check_rounded,
                  color: AppColors.success,
                  onTap: () => onSet(true),
                ),
                const SizedBox(width: 8),
                _SmallButton(
                  label: 'غبت',
                  icon: Icons.close_rounded,
                  color: AppColors.danger,
                  onTap: () => onSet(false),
                ),
              ],
            )
          : Row(
              children: [
                Pill(
                  r.present ? 'حضرت ✓' : 'غبت',
                  color: r.present ? AppColors.success : AppColors.danger,
                  icon: r.present ? Icons.how_to_reg_rounded : Icons.close,
                ),
                const Spacer(),
                TextButton(onPressed: onClear, child: const Text('تغيير')),
              ],
            ),
    );
  }
}

class _SmallButton extends StatelessWidget {
  const _SmallButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(color: color, fontWeight: FontWeight.w700),
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
    final now = DateTime.now();
    final next = item.nextReviewDate;
    final subtitle = [
      if (showSubject && subject != null) subject.name,
      'نزلت ${friendlyDay(item.releaseDate, now)}',
      if (item.isMastered)
        'ثبتت 💯'
      else if (next != null && !item.isReviewDue(now))
        'المراجعة ${friendlyDay(next, now)}',
      if (item.notes.isNotEmpty) '📝',
    ].join(' • ');
    return ListTile(
      contentPadding: const EdgeInsetsDirectional.only(start: 6, end: 4),
      leading: IconButton(
        tooltip: status.isDone ? 'رجعها لسه' : 'اتذاكرت',
        icon: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
          child: Icon(
            status.icon,
            key: ValueKey(status),
            color: status.color,
            size: 30,
          ),
        ),
        onPressed: () => store.setStudyStatus(
          item.id,
          status.isDone ? StudyStatus.notStarted : StudyStatus.studied,
        ),
      ),
      title: Text(
        item.title,
        style: theme.textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: status.isDone ? theme.colorScheme.onSurfaceVariant : null,
        ),
      ),
      subtitle: Text(subtitle),
      onTap: () => pushPage(context, StudyItemForm(item: item)),
      trailing: item.isReviewDue(now)
          ? Pill('راجعها', color: AppColors.primary, icon: Icons.replay_rounded)
          : PopupMenuButton<StudyStatus>(
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

/// A lecture whose spaced review is due, with a one-tap "done".
class ReviewTile extends StatelessWidget {
  const ReviewTile({super.key, required this.item});

  final StudyItem item;

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    final subject = store.subjectById(item.subjectId);
    final color = subjectColor(subject, context);
    return ListTile(
      leading: IconBadge(Icons.replay_rounded, color: color, size: 42),
      title: Text(
        item.title,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        '${subject?.name ?? ''} • مراجعة ${item.reviewCount + 1} من ${reviewIntervalsDays.length}',
      ),
      trailing: FilledButton.tonal(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 38),
          padding: const EdgeInsets.symmetric(horizontal: 14),
        ),
        onPressed: () {
          store.markReviewed(item.id);
          showSnack(context, 'عاش! راجعت "${item.title}" ✓');
        },
        child: const Text('راجعتها'),
      ),
      onTap: () => pushPage(context, StudyItemForm(item: item)),
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
    final color = task.priority.color;
    return ListTile(
      contentPadding: const EdgeInsetsDirectional.only(start: 6, end: 14),
      leading: IconButton(
        tooltip: task.done ? 'لسه' : 'خلصت',
        onPressed: () => store.toggleTask(task.id),
        icon: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: task.done ? AppColors.success : Colors.transparent,
            border: Border.all(
              color: task.done ? AppColors.success : color,
              width: 2.4,
            ),
          ),
          child: task.done
              ? const Icon(Icons.check_rounded, size: 18, color: Colors.white)
              : null,
        ),
      ),
      title: Text(
        task.title,
        style: theme.textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w600,
          decoration: task.done ? TextDecoration.lineThrough : null,
          color: task.done ? theme.colorScheme.onSurfaceVariant : null,
        ),
      ),
      subtitle: subtitle.isEmpty
          ? null
          : Text(
              subtitle,
              style: overdue ? const TextStyle(color: AppColors.danger) : null,
            ),
      trailing: task.done || task.priority == Priority.low
          ? null
          : Icon(Icons.flag_rounded, color: color, size: 20),
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
        icon: const Text('🎉', style: TextStyle(fontSize: 36)),
        title: Text(
          '${a.title} ${a.type.doneLabel}',
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'لو عرفت درجتك سجلها هنا وهتتحسب في درجات المادة:',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
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
                    decoration: const InputDecoration(labelText: 'من كام'),
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
            style: FilledButton.styleFrom(minimumSize: const Size(80, 44)),
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
          const SizedBox(height: 4),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => showCompleteAssessmentDialog(context, a),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Text(
                '${a.type.doneLabel}؟',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      );
    } else if (grade != null) {
      trailing = InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => pushPage(context, GradeForm(grade: grade)),
        child: Pill(
          fraction(grade.score, grade.maxScore),
          color: AppColors.success,
          icon: Icons.emoji_events_rounded,
        ),
      );
    } else {
      trailing = TextButton(
        onPressed: () => showCompleteAssessmentDialog(context, a),
        child: const Text('سجل الدرجة'),
      );
    }

    return ListTile(
      contentPadding: const EdgeInsetsDirectional.only(start: 14, end: 12),
      leading: IconBadge(
        a.done ? Icons.check_rounded : a.type.icon,
        color: a.done ? AppColors.success : color,
      ),
      title: Text(
        '${a.type.label}: ${a.title}',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(subtitle),
      trailing: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 124),
        child: trailing,
      ),
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
    final percent = (p.progress * 100).round();
    return AppCard(
      onTap: () => pushPage(context, ProjectDetailScreen(projectId: p.id)),
      child: Row(
        children: [
          ProgressRing(
            value: p.progress,
            size: 58,
            stroke: 6,
            color: p.submitted ? AppColors.success : color,
            child: p.submitted
                ? const Icon(Icons.check_rounded, color: AppColors.success)
                : Text(
                    '$percent%',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.title, style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (subject != null) SubjectChip(subject),
                    if (p.submitted)
                      const Pill(
                        'اتسلّم',
                        color: AppColors.success,
                        icon: Icons.check_rounded,
                      )
                    else if (p.deadline != null)
                      CountdownPill(due: p.deadline!, now: now),
                  ],
                ),
                if (p.steps.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'خلصت ${p.doneSteps} من ${p.steps.length} مراحل',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Colour for a mark by how good it is.
Color gradeColor(double? ratio, {bool bonus = false}) {
  if (bonus) return AppColors.bonus;
  if (ratio == null) return const Color(0xFF9A98B0);
  if (ratio >= 0.85) return AppColors.success;
  if (ratio >= 0.65) return AppColors.sky;
  if (ratio >= 0.5) return AppColors.orange;
  return AppColors.danger;
}

class GradeTile extends StatelessWidget {
  const GradeTile({super.key, required this.grade});

  final GradeEntry grade;

  @override
  Widget build(BuildContext context) {
    final g = grade;
    final theme = Theme.of(context);
    final color = gradeColor(g.ratio, bonus: g.isBonus);
    final subtitle = [
      g.category.label,
      formatShortDate(g.date),
      if (g.notes.isNotEmpty) g.notes,
    ].join(' • ');
    return ListTile(
      contentPadding: const EdgeInsetsDirectional.only(start: 14, end: 16),
      leading: IconBadge(g.category.icon, color: color),
      title: Text(g.title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: g.isBonus
          ? Pill(
              '${ltr('+${formatNumber(g.score)}')} بونص',
              color: color,
              icon: Icons.star_rounded,
            )
          : Text(
              fraction(g.score, g.maxScore),
              style: theme.textTheme.titleMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
      onTap: () => pushPage(context, GradeForm(grade: g)),
    );
  }
}
