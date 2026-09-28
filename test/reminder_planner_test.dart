import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:study_planner/data/app_store.dart';
import 'package:study_planner/data/storage.dart';
import 'package:study_planner/models/models.dart';
import 'package:study_planner/services/reminder_planner.dart';

void main() {
  setUpAll(() => initializeDateFormatting('ar'));

  group('nextWeeklyReminder', () {
    // Monday 28 Sep 2026, 10:00.
    final now = DateTime(2026, 9, 28, 10);

    test('later today', () {
      expect(
        nextWeeklyReminder(now, DateTime.monday, 12 * 60, 15),
        DateTime(2026, 9, 28, 11, 45),
      );
    });

    test('already passed today rolls to next week', () {
      expect(
        nextWeeklyReminder(now, DateTime.monday, 10 * 60 + 10, 15),
        DateTime(2026, 10, 5, 9, 55),
      );
    });

    test('at the start time exactly', () {
      expect(
        nextWeeklyReminder(now, DateTime.wednesday, 9 * 60, 0),
        DateTime(2026, 9, 30, 9),
      );
    });

    test('reminder that crosses midnight into the previous day', () {
      expect(
        nextWeeklyReminder(now, DateTime.tuesday, 30, 60),
        DateTime(2026, 9, 28, 23, 30),
      );
    });

    test('earlier weekday goes to the following week', () {
      expect(
        nextWeeklyReminder(now, DateTime.saturday, 9 * 60, 10),
        DateTime(2026, 10, 3, 8, 50),
      );
    });
  });

  group('planReminders', () {
    final now = DateTime(2026, 9, 28, 10);
    late AppStore store;

    setUp(() async {
      store = AppStore(MemoryStorage());
      await store.load();
      await store.updateSettings(const AppSettings(dailySummaryEnabled: false));
      await store.saveSubject(const Subject(id: 's1', name: 'برمجة'));
    });

    test('weekly class reminder with place and lead time', () async {
      await store.saveSession(
        const ClassSession(
          id: 'c1',
          subjectId: 's1',
          weekday: DateTime.tuesday,
          startMinute: 9 * 60,
          endMinute: 11 * 60,
          location: 'مدرج 1',
          reminderMinutes: 15,
        ),
      );
      final plan = planReminders(store, now);
      expect(plan, hasLength(1));
      expect(plan.single.weekly, isTrue);
      expect(plan.single.when, DateTime(2026, 9, 29, 8, 45));
      expect(plan.single.title, 'محاضرة: برمجة');
      expect(plan.single.body, contains('مدرج 1'));
      expect(plan.single.body, contains('ربع ساعة'));
    });

    test('muted classes and done deadlines are skipped', () async {
      await store.saveSession(
        const ClassSession(
          id: 'c1',
          subjectId: 's1',
          weekday: DateTime.tuesday,
          startMinute: 9 * 60,
          endMinute: 11 * 60,
          notify: false,
        ),
      );
      await store.saveAssessment(
        Assessment(
          id: 'a1',
          subjectId: 's1',
          title: 'كويز 1',
          dueDate: DateTime(2026, 10, 2, 9),
          done: true,
        ),
      );
      await store.saveTask(
        TaskItem(
          id: 't1',
          title: 'x',
          dueDate: DateTime(2026, 10, 2),
          done: true,
        ),
      );
      expect(planReminders(store, now), isEmpty);
    });

    test('only future offsets of a deadline are scheduled', () async {
      await store.saveAssessment(
        Assessment(
          id: 'a1',
          subjectId: 's1',
          title: 'كويز 2',
          // 3 hours from now: the 1-day reminder is already in the past.
          dueDate: DateTime(2026, 9, 28, 13),
          reminders: const [24 * 60, 60, 0],
        ),
      );
      final plan = planReminders(store, now);
      expect(plan.map((r) => r.when), [
        DateTime(2026, 9, 28, 12),
        DateTime(2026, 9, 28, 13),
      ]);
      expect(plan.first.title, contains('كويز 2'));
      expect(plan.first.body, contains('باقي ساعة'));
      expect(plan.last.body, contains('ميعاده دلوقتي'));
    });

    test(
      'assignments, tasks and projects are included in time order',
      () async {
        await store.saveAssessment(
          Assessment(
            id: 'a1',
            subjectId: 's1',
            type: AssessmentType.assignment,
            title: 'شيت 3',
            dueDate: DateTime(2026, 10, 3, 23, 59),
            reminders: const [24 * 60],
          ),
        );
        await store.saveTask(
          TaskItem(
            id: 't1',
            title: 'أطبع الملزمة',
            dueDate: DateTime(2026, 9, 29, 18),
            reminders: const [60],
          ),
        );
        await store.saveProject(
          Project(
            id: 'p1',
            title: 'مشروع',
            deadline: DateTime(2026, 10, 10),
            reminders: const [3 * 24 * 60],
          ),
        );
        final plan = planReminders(store, now);
        expect(plan.map((r) => r.when), [
          DateTime(2026, 9, 29, 17),
          DateTime(2026, 10, 2, 23, 59),
          DateTime(2026, 10, 7),
        ]);
        expect(plan[1].title, startsWith('📤 تسليم'));
      },
    );

    test('daily summaries for the coming week', () async {
      await store.updateSettings(
        store.settings.copyWith(
          dailySummaryEnabled: true,
          dailySummaryMinute: 8 * 60,
          studentName: 'أحمد',
        ),
      );
      final plan = planReminders(store, now);
      // Today's 8:00 already passed, so the next 6 mornings.
      expect(plan, hasLength(6));
      expect(plan.first.when, DateTime(2026, 9, 29, 8));
      expect(plan.first.title, contains('أحمد'));
      expect(plan.first.channel, ReminderChannel.daily);
    });

    test('nothing when notifications are off', () async {
      await store.saveSession(
        const ClassSession(
          id: 'c1',
          subjectId: 's1',
          weekday: DateTime.tuesday,
          startMinute: 9 * 60,
          endMinute: 11 * 60,
        ),
      );
      await store.updateSettings(
        store.settings.copyWith(notificationsEnabled: false),
      );
      expect(planReminders(store, now), isEmpty);
    });

    test('respects the limit, keeping weekly classes first', () async {
      for (var i = 0; i < 5; i++) {
        await store.saveSession(
          ClassSession(
            id: 'c$i',
            subjectId: 's1',
            weekday: DateTime.sunday,
            startMinute: (8 + i) * 60,
            endMinute: (9 + i) * 60,
          ),
        );
      }
      await store.saveTask(
        TaskItem(id: 't1', title: 'x', dueDate: DateTime(2026, 9, 28, 12)),
      );
      final plan = planReminders(store, now, limit: 5);
      expect(plan, hasLength(5));
      expect(plan.every((r) => r.weekly), isTrue);
    });
  });

  test('daily summary text lists the day', () async {
    final store = AppStore(MemoryStorage());
    await store.load();
    await store.saveSubject(const Subject(id: 's1', name: 'داتابيز'));
    final day = DateTime(2026, 9, 29, 8); // Tuesday
    await store.saveSession(
      const ClassSession(
        id: 'c1',
        subjectId: 's1',
        weekday: DateTime.tuesday,
        startMinute: 10 * 60,
        endMinute: 12 * 60,
      ),
    );
    await store.saveAssessment(
      Assessment(
        id: 'a1',
        subjectId: 's1',
        title: 'كويز',
        dueDate: DateTime(2026, 9, 29, 12),
      ),
    );
    await store.saveStudyItem(
      StudyItem(
        id: 'l1',
        subjectId: 's1',
        title: 'محاضرة 1',
        releaseDate: DateTime(2026, 9, 20),
      ),
    );
    final body = dailySummaryBody(store, day);
    expect(body, contains('عندك 1 في الجدول'));
    expect(body, contains('10:00\u00A0ص'));
    expect(body, contains('كويز داتابيز'));
    expect(body, contains('محاضرة لسه ماتذاكرتش'));
  });
}
