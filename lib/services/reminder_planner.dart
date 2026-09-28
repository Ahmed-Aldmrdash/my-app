import '../data/app_store.dart';
import '../models/models.dart';
import '../utils/formatters.dart';
import '../utils/labels.dart';

enum ReminderChannel { classes, deadlines, daily, focus }

/// Where tapping a notification should take the user.
class ReminderTarget {
  static const schedule = 'tab:1';
  static const study = 'tab:2';
  static const tasks = 'tab:3:0';
  static const quizzes = 'tab:3:1';
  static const assignments = 'tab:3:2';
  static const projects = 'tab:3:3';
  static const home = 'tab:0';
  static const focus = 'focus';
}

/// A notification the app wants shown at [when].
class PlannedReminder {
  const PlannedReminder({
    required this.when,
    required this.title,
    required this.body,
    required this.channel,
    required this.payload,
    this.weekly = false,
  });

  final DateTime when;
  final String title;
  final String body;
  final ReminderChannel channel;
  final String payload;

  /// Repeats every week on the same weekday and time.
  final bool weekly;

  @override
  String toString() => '$when ${weekly ? '(weekly) ' : ''}$title — $body';
}

/// The first moment after [now] that is [minutesBefore] before a weekly
/// slot starting at [minuteOfDay] on [weekday].
DateTime nextWeeklyReminder(
  DateTime now,
  int weekday,
  int minuteOfDay,
  int minutesBefore,
) {
  final dayDelta = (weekday - now.weekday) % 7;
  var start = DateTime(
    now.year,
    now.month,
    now.day + dayDelta,
    minuteOfDay ~/ 60,
    minuteOfDay % 60,
  );
  var fire = start.subtract(Duration(minutes: minutesBefore));
  while (!fire.isAfter(now)) {
    start = DateTime(
      start.year,
      start.month,
      start.day + 7,
      start.hour,
      start.minute,
    );
    fire = start.subtract(Duration(minutes: minutesBefore));
  }
  return fire;
}

/// Works out every notification that should currently be pending: weekly
/// class reminders first (they matter most), then one-off deadline and
/// daily-summary reminders in time order, capped at [limit] (iOS only keeps
/// 64 pending notifications per app).
List<PlannedReminder> planReminders(
  AppStore store,
  DateTime now, {
  int limit = 60,
}) {
  final settings = store.settings;

  // The focus timer alarm always goes out, even with reminders turned off:
  // the student started it on purpose.
  final focusAlarm = <PlannedReminder>[];
  final focus = store.focus;
  if (focus != null && focus.isRunning && focus.endsAt!.isAfter(now)) {
    final subject = store.subjectById(focus.subjectId);
    final isFocus = focus.phase == FocusPhase.focus;
    focusAlarm.add(
      PlannedReminder(
        when: focus.endsAt!,
        title: isFocus ? '🎉 برافو! خلصت جلسة المذاكرة' : '⏰ البريك خلص',
        body: isFocus
            ? 'ذاكرت ${durationText(Duration(seconds: focus.plannedSeconds))}'
                  '${subject == null ? '' : ' ${subject.name}'} — خد بريك صغير وارجع'
            : 'يلا نرجع نذاكر 💪',
        channel: ReminderChannel.focus,
        payload: ReminderTarget.focus,
      ),
    );
  }
  if (!settings.notificationsEnabled) return focusAlarm;

  final weekly = <PlannedReminder>[];
  for (final session in store.sessions) {
    if (!session.notify) continue;
    final subject = store.subjectById(session.subjectId);
    if (subject == null) continue;
    final place = session.location.isEmpty ? '' : ' • ${session.location}';
    final start = formatMinuteOfDay(session.startMinute);
    final body = session.reminderMinutes <= 0
        ? 'بتبدأ دلوقتي ($start)$place'
        : 'هتبدأ بعد ${durationText(Duration(minutes: session.reminderMinutes))} '
              '(الساعة $start)$place';
    weekly.add(
      PlannedReminder(
        when: nextWeeklyReminder(
          now,
          session.weekday,
          session.startMinute,
          session.reminderMinutes,
        ),
        title: '${session.type.label}: ${subject.name}',
        body: body,
        channel: ReminderChannel.classes,
        payload: ReminderTarget.schedule,
        weekly: true,
      ),
    );
  }
  weekly.sort((a, b) => a.when.compareTo(b.when));

  final oneOff = <PlannedReminder>[];
  void addDeadline({
    required DateTime due,
    required List<int> offsets,
    required String title,
    required String context,
    required String payload,
  }) {
    for (final offset in offsets.toSet()) {
      final when = due.subtract(Duration(minutes: offset));
      if (!when.isAfter(now)) continue;
      final lead = offset <= 0
          ? 'ميعاده دلوقتي'
          : 'باقي ${durationText(Duration(minutes: offset))}';
      final prefix = context.isEmpty ? '' : '$context • ';
      oneOff.add(
        PlannedReminder(
          when: when,
          title: title,
          body: '$prefix$lead (${friendlyDateTime(due, when)})',
          channel: ReminderChannel.deadlines,
          payload: payload,
        ),
      );
    }
  }

  for (final a in store.assessments) {
    if (a.done) continue;
    final subject = store.subjectById(a.subjectId);
    final isAssignment = a.type == AssessmentType.assignment;
    addDeadline(
      due: a.dueDate,
      offsets: a.reminders,
      title: isAssignment
          ? '📤 تسليم ${a.type.label}: ${a.title}'
          : '📝 ${a.type.label}: ${a.title}',
      context: [
        ?subject?.name,
        if (a.location.isNotEmpty) a.location,
      ].join(' • '),
      payload: isAssignment
          ? ReminderTarget.assignments
          : ReminderTarget.quizzes,
    );
  }

  for (final t in store.tasks) {
    if (t.done || t.dueDate == null) continue;
    addDeadline(
      due: t.dueDate!,
      offsets: t.reminders,
      title: '✅ تاسك: ${t.title}',
      context: store.subjectById(t.subjectId)?.name ?? '',
      payload: ReminderTarget.tasks,
    );
  }

  for (final p in store.projects) {
    if (p.submitted || p.deadline == null) continue;
    addDeadline(
      due: p.deadline!,
      offsets: p.reminders,
      title: '🚀 مشروع: ${p.title}',
      context: 'خلصت ${(p.progress * 100).round()}%',
      payload: ReminderTarget.projects,
    );
  }

  if (settings.dailySummaryEnabled) {
    final today = dateOnly(now);
    for (var d = 0; d < 7; d++) {
      final when = DateTime(
        today.year,
        today.month,
        today.day + d,
        settings.dailySummaryMinute ~/ 60,
        settings.dailySummaryMinute % 60,
      );
      if (!when.isAfter(now)) continue;
      final name = settings.studentName.trim();
      oneOff.add(
        PlannedReminder(
          when: when,
          title:
              'صباح الخير${name.isEmpty ? '' : ' يا $name'} ☀️ خطة ${weekdayNames[when.weekday]}',
          body: dailySummaryBody(store, when),
          channel: ReminderChannel.daily,
          payload: ReminderTarget.home,
        ),
      );
    }
  }

  oneOff.sort((a, b) => a.when.compareTo(b.when));
  return [...focusAlarm, ...weekly, ...oneOff].take(limit).toList();
}

/// The text of the morning summary for [day].
String dailySummaryBody(AppStore store, DateTime day) {
  final lines = <String>[];

  final sessions = store.sessionsOn(day.weekday);
  if (sessions.isNotEmpty) {
    final first = sessions.first;
    final firstName = store.subjectById(first.subjectId)?.name ?? '';
    lines.add(
      '📅 عندك ${sessions.length} في الجدول، أولها $firstName '
      '${formatMinuteOfDay(first.startMinute)}',
    );
  }

  final dueToday = store.assessments
      .where((a) => !a.done && isSameDay(a.dueDate, day))
      .map((a) {
        final subject = store.subjectById(a.subjectId)?.name;
        return '${a.type.label} ${subject ?? a.title}';
      })
      .toList();
  if (dueToday.isNotEmpty) lines.add('📝 النهارده: ${dueToday.join('، ')}');

  final tasksToday = store.tasks
      .where((t) => !t.done && t.dueDate != null && isSameDay(t.dueDate!, day))
      .length;
  if (tasksToday > 0) {
    lines.add(
      '✅ ${countText(tasksToday, 'تاسك', 'تاسكين', 'تاسكات', 'تاسك')} لازم يخلصوا',
    );
  }

  final reviews = store.dueReviews(day).length;
  if (reviews > 0) {
    lines.add(
      '🔁 ${countText(reviews, 'مراجعة', 'مراجعتين', 'مراجعات', 'مراجعة')} مستنياك النهارده',
    );
  }

  final notStudied = store.studyItems.where((s) => !s.status.isDone).length;
  if (notStudied > 0) {
    lines.add(
      '📚 ${countText(notStudied, 'محاضرة', 'محاضرتين', 'محاضرات', 'محاضرة')} لسه ماتذاكرتش',
    );
  }

  if (lines.isEmpty) return 'يومك فاضي — فرصة حلوة تذاكر وتخلص اللي وراك 💪';
  return lines.join('\n');
}
