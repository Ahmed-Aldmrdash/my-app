import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:study_planner/data/app_store.dart';
import 'package:study_planner/data/storage.dart';
import 'package:study_planner/models/models.dart';
import 'package:study_planner/services/reminder_planner.dart';
import 'package:study_planner/utils/grade_calculator.dart';
import 'package:study_planner/utils/study_stats.dart';

void main() {
  setUpAll(() => initializeDateFormatting('ar'));

  late AppStore store;
  setUp(() async {
    store = AppStore(MemoryStorage());
    await store.load();
    await store.saveSubject(const Subject(id: 's1', name: 'برمجة'));
  });

  group('spaced review', () {
    final studied = DateTime(2026, 9, 1, 20);
    final item = StudyItem(
      id: 'l1',
      subjectId: 's1',
      title: 'محاضرة 1',
      releaseDate: DateTime(2026, 8, 30),
    ).withStatus(StudyStatus.studied, now: studied);

    test('first review the day after studying', () {
      expect(item.studiedAt, studied);
      expect(item.nextReviewDate, DateTime(2026, 9, 2));
      expect(item.isReviewDue(DateTime(2026, 9, 1, 23)), isFalse);
      expect(item.isReviewDue(DateTime(2026, 9, 2, 8)), isTrue);
    });

    test('each review pushes the next one further', () {
      var i = item.reviewed(now: DateTime(2026, 9, 2, 10));
      expect(i.status, StudyStatus.revised);
      expect(i.nextReviewDate, DateTime(2026, 9, 5)); // +3 days
      i = i.reviewed(now: DateTime(2026, 9, 5, 10));
      expect(i.nextReviewDate, DateTime(2026, 9, 12)); // +7 days
      i = i.reviewed(now: DateTime(2026, 9, 12));
      i = i.reviewed(now: DateTime(2026, 9, 26));
      expect(i.isMastered, isFalse);
      i = i.reviewed(now: DateTime(2026, 10, 26));
      expect(i.isMastered, isTrue);
      expect(i.nextReviewDate, isNull);
    });

    test('choosing "revised" counts as a review, "not started" resets', () {
      final r = item.withStatus(StudyStatus.revised, now: DateTime(2026, 9, 2));
      expect(r.reviewCount, 1);
      final reset = r.withStatus(StudyStatus.notStarted);
      expect(reset.reviewCount, 0);
      expect(reset.studiedAt, isNull);
      expect(reset.lastReviewedAt, isNull);
      expect(reset.nextReviewDate, isNull);
    });

    test('store lists due reviews and marks them', () async {
      await store.saveStudyItem(item);
      expect(store.dueReviews(DateTime(2026, 9, 2)).single.id, 'l1');
      await store.markReviewed('l1');
      expect(store.dueReviews(DateTime(2026, 9, 2)), isEmpty);
      expect(store.studyItems.single.reviewCount, 1);
    });
  });

  group('focus timer', () {
    final t0 = DateTime(2026, 9, 28, 18);

    test('pause and resume keep the remaining time', () async {
      await store.startFocus(
        phase: FocusPhase.focus,
        minutes: 25,
        subjectId: 's1',
        now: t0,
      );
      expect(store.focus!.remainingSeconds(t0), 25 * 60);
      await store.pauseFocus(t0.add(const Duration(minutes: 10)));
      final paused = store.focus!;
      expect(paused.isPaused, isTrue);
      expect(paused.remainingSeconds(DateTime(2030)), 15 * 60);
      await store.resumeFocus(t0.add(const Duration(minutes: 20)));
      expect(store.focus!.endsAt, t0.add(const Duration(minutes: 35)));
    });

    test('a finished focus phase is logged once', () async {
      await store.startFocus(
        phase: FocusPhase.focus,
        minutes: 25,
        subjectId: 's1',
        now: t0,
      );
      expect(
        await store.completeFocusIfDue(t0.add(const Duration(minutes: 10))),
        isNull,
      );
      final done = await store.completeFocusIfDue(
        t0.add(const Duration(minutes: 26)),
      );
      expect(done, FocusPhase.focus);
      expect(store.focus, isNull);
      expect(store.studySessions.single.minutes, 25);
      expect(store.studySessions.single.subjectId, 's1');
      expect(await store.completeFocusIfDue(t0), isNull);
      expect(store.studySessions, hasLength(1));
    });

    test(
      'stopping early logs the focused minutes; breaks log nothing',
      () async {
        await store.startFocus(phase: FocusPhase.focus, minutes: 25, now: t0);
        final logged = await store.stopFocus(
          t0.add(const Duration(minutes: 12)),
        );
        expect(logged!.minutes, 12);

        await store.startFocus(phase: FocusPhase.focus, minutes: 25, now: t0);
        expect(
          await store.stopFocus(t0.add(const Duration(seconds: 20))),
          isNull,
        );

        await store.startFocus(phase: FocusPhase.rest, minutes: 5, now: t0);
        expect(
          await store.completeFocusIfDue(t0.add(const Duration(minutes: 6))),
          FocusPhase.rest,
        );
        expect(store.studySessions, hasLength(1));
      },
    );

    test('studying a lecture moves it to "in progress"', () async {
      await store.saveStudyItem(
        StudyItem(
          id: 'l1',
          subjectId: 's1',
          title: 'x',
          releaseDate: DateTime(2026, 9, 1),
        ),
      );
      await store.startFocus(
        phase: FocusPhase.focus,
        minutes: 1,
        subjectId: 's1',
        studyItemId: 'l1',
        now: t0,
      );
      await store.completeFocusIfDue(t0.add(const Duration(minutes: 2)));
      expect(store.studyItems.single.status, StudyStatus.inProgress);
    });

    test('a running timer survives a restart', () async {
      final storage = MemoryStorage();
      final a = AppStore(storage);
      await a.load();
      await a.startFocus(phase: FocusPhase.focus, minutes: 50, now: t0);
      final b = AppStore(MemoryStorage(storage.data));
      await b.load();
      expect(b.focus!.endsAt, t0.add(const Duration(minutes: 50)));
      expect(b.focus!.plannedSeconds, 50 * 60);
    });

    test(
      'the end-of-session alarm is planned even with reminders off',
      () async {
        await store.updateSettings(
          store.settings.copyWith(notificationsEnabled: false),
        );
        await store.startFocus(phase: FocusPhase.focus, minutes: 25, now: t0);
        final plan = planReminders(store, t0);
        expect(plan, hasLength(1));
        expect(plan.single.channel, ReminderChannel.focus);
        expect(plan.single.when, t0.add(const Duration(minutes: 25)));
        await store.pauseFocus(t0.add(const Duration(minutes: 1)));
        expect(planReminders(store, t0), isEmpty);
      },
    );
  });

  group('study stats', () {
    final now = DateTime(2026, 9, 28, 12);
    StudySession s(int dayOffset, int minutes, [String? subject]) =>
        StudySession(
          id: '$dayOffset-$minutes',
          subjectId: subject,
          startedAt: DateTime(2026, 9, 28 + dayOffset, 20),
          minutes: minutes,
        );

    test('today, last days and streaks', () {
      final stats = StudyStats([
        s(0, 30),
        s(0, 20),
        s(-1, 120),
        s(-2, 60),
        s(-4, 90),
      ], now);
      expect(stats.today, 50);
      expect(stats.total, 320);
      final week = stats.lastDays(7);
      expect(week, hasLength(7));
      expect(week.last.$1, DateTime(2026, 9, 28));
      expect(week.last.$2, 50);
      expect(week.first.$1, DateTime(2026, 9, 22));
      expect(stats.lastSevenDays, 320);
      expect(stats.streak, 3);
      // Today is still below the goal, so it counts from yesterday.
      expect(stats.goalStreak(60), 2);
      expect(StudyStats([s(-1, 120), s(-2, 60)], now).goalStreak(60), 2);
    });

    test('streak is kept until the end of today', () {
      expect(StudyStats([s(-1, 10), s(-2, 10)], now).streak, 2);
      expect(StudyStats([s(-2, 10)], now).streak, 0);
    });

    test('minutes per subject since a date', () {
      final by = minutesBySubject([
        s(0, 30, 'a'),
        s(-1, 20, 'a'),
        s(-9, 60, 'a'),
        s(0, 15),
      ], DateTime(2026, 9, 22));
      expect(by['a'], 50);
      expect(by[null], 15);
    });
  });

  group('attendance', () {
    const session = ClassSession(
      id: 'c1',
      subjectId: 's1',
      weekday: DateTime.monday,
      startMinute: 9 * 60,
      endMinute: 11 * 60,
      type: SessionType.section,
    );

    test('one record per class per day, replaced on change', () async {
      final day = DateTime(2026, 9, 28, 11, 30);
      await store.setAttendance(session, day, present: true);
      await store.setAttendance(session, day, present: false);
      final r = store.attendanceFor('c1', DateTime(2026, 9, 28, 20))!;
      expect(r.present, isFalse);
      expect(r.type, SessionType.section);
      expect(r.date, DateTime(2026, 9, 28));
      expect(store.attendance, hasLength(1));

      await store.setAttendance(session, DateTime(2026, 10, 5), present: true);
      expect(store.attendanceOf('s1').first.date, DateTime(2026, 10, 5));
    });

    test('deleting the subject removes its attendance', () async {
      await store.setAttendance(session, DateTime(2026, 9, 28), present: true);
      await store.deleteSubject('s1');
      expect(store.attendance, isEmpty);
    });
  });

  group('GPA', () {
    test('letter grades', () {
      expect(gpaGradeFor(95).letter, 'A');
      expect(gpaGradeFor(84).letter, 'B+');
      expect(gpaGradeFor(62).letter, 'C');
      expect(gpaGradeFor(49).letter, 'F');
      expect(gradeText(80, GradingSystem.gpa), 'B+');
      expect(gradeText(80, GradingSystem.percentage), 'جيد جداً');
    });

    test('expected GPA is weighted by credit hours', () {
      GradeEntry g(String subject, double score) => GradeEntry(
        id: subject,
        subjectId: subject,
        title: 't',
        score: score,
        maxScore: 100,
        date: DateTime(2026),
      );
      final a = SubjectGradeSummary(
        const Subject(id: 'a', name: 'a', creditHours: 3),
        [g('a', 92)],
      );
      final b = SubjectGradeSummary(
        const Subject(id: 'b', name: 'b', creditHours: 1),
        [g('b', 61)],
      );
      // (4.0 * 3 + 2.0 * 1) / 4
      expect(expectedGpa([a, b]), closeTo(3.5, 1e-9));
      expect(
        expectedGpa([
          SubjectGradeSummary(const Subject(id: 'c', name: 'c'), []),
        ]),
        isNull,
      );
    });
  });

  test('daily summary mentions due reviews', () async {
    await store.saveStudyItem(
      StudyItem(
        id: 'l1',
        subjectId: 's1',
        title: 'محاضرة 1',
        releaseDate: DateTime(2026, 9, 20),
      ).withStatus(StudyStatus.studied, now: DateTime(2026, 9, 27, 20)),
    );
    expect(
      dailySummaryBody(store, DateTime(2026, 9, 28, 8)),
      contains('مراجعة مستنياك النهارده'),
    );
  });

  test('settings round trip keeps the new options', () {
    const s = AppSettings(
      gradingSystem: GradingSystem.gpa,
      dailyGoalMinutes: 180,
      focusMinutes: 50,
      breakMinutes: 10,
    );
    final back = AppSettings.fromJson(s.toJson());
    expect(back.gradingSystem, GradingSystem.gpa);
    expect(back.dailyGoalMinutes, 180);
    expect(back.focusMinutes, 50);
    expect(back.breakMinutes, 10);
  });
}
