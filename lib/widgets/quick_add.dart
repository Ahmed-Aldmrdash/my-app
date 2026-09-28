import 'package:flutter/material.dart';

import '../models/models.dart';
import '../screens/assessment_form.dart';
import '../screens/focus_screen.dart';
import '../screens/grade_form.dart';
import '../screens/project_form.dart';
import '../screens/session_form.dart';
import '../screens/stats_screen.dart';
import '../screens/study_item_form.dart';
import '../screens/task_form.dart';
import '../theme/app_theme.dart';
import 'common.dart';

class _Action {
  const _Action(this.label, this.icon, this.color, this.open);
  final String label;
  final IconData icon;
  final Color color;
  final void Function(BuildContext context) open;
}

final _actions = <_Action>[
  _Action(
    'جلسة مذاكرة',
    Icons.play_circle_fill_rounded,
    AppColors.coral,
    (c) => pushPage(c, const FocusScreen()),
  ),
  _Action(
    'محاضرة نزلت',
    Icons.menu_book_rounded,
    AppColors.primary,
    (c) => pushPage(c, const StudyItemForm()),
  ),
  _Action(
    'تاسك',
    Icons.task_alt_rounded,
    AppColors.sky,
    (c) => pushPage(c, const TaskForm()),
  ),
  _Action(
    'كويز / امتحان',
    Icons.quiz_rounded,
    AppColors.orange,
    (c) => pushPage(c, const AssessmentForm()),
  ),
  _Action(
    'أسايمنت',
    Icons.assignment_rounded,
    AppColors.pink,
    (c) => pushPage(
      c,
      const AssessmentForm(initialType: AssessmentType.assignment),
    ),
  ),
  _Action(
    'درجة',
    Icons.emoji_events_rounded,
    AppColors.teal,
    (c) => pushPage(c, const GradeForm()),
  ),
  _Action(
    'ميعاد في الجدول',
    Icons.calendar_month_rounded,
    AppColors.cyan,
    (c) => pushPage(c, const SessionForm()),
  ),
  _Action(
    'مشروع',
    Icons.rocket_launch_rounded,
    AppColors.bonus,
    (c) => pushPage(c, const ProjectForm()),
  ),
  _Action(
    'وقت ذاكرته',
    Icons.more_time_rounded,
    AppColors.success,
    (c) => showLogSessionSheet(c),
  ),
];

/// A grid of everything the student can add, one tap away.
Future<void> showQuickAddSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('عايز تضيف إيه؟', style: Theme.of(sheet).textTheme.titleLarge),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.05,
              children: [
                for (final a in _actions)
                  Material(
                    color: a.color.withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(20),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () {
                        Navigator.pop(sheet);
                        a.open(context);
                      },
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconBadge(a.icon, color: a.color, filled: true),
                          const SizedBox(height: 8),
                          Text(
                            a.label,
                            textAlign: TextAlign.center,
                            style: Theme.of(sheet).textTheme.labelLarge,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
