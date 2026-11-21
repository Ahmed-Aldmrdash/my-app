import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:study_planner/data/app_store.dart';
import 'package:study_planner/data/demo_data.dart';
import 'package:study_planner/data/storage.dart';
import 'package:study_planner/models/models.dart';
import 'package:study_planner/screens/career_screen.dart';
import 'package:study_planner/services/reminder_planner.dart';
import 'package:study_planner/utils/schedule_utils.dart';

Future<AppStore> device() async {
  final s = AppStore(MemoryStorage());
  await s.load();
  return s;
}

void main() {
  setUpAll(() => initializeDateFormatting('ar'));

  group('holidays', () {
    // Sunday 6 December 2026, 8 in the morning.
    final now = DateTime(2026, 12, 6, 8);

    Future<AppStore> withMondayClass() async {
      final s = await device();
      await s.saveSubject(const Subject(id: 'a', name: 'شبكات'));
      await s.saveSession(
        const ClassSession(
          id: 'c',
          subjectId: 'a',
          weekday: DateTime.monday,
          startMinute: 10 * 60,
          endMinute: 12 * 60,
        ),
      );
      return s;
    }

    test('a day off covers its whole period', () {
      final e = CalendarEvent(
        id: 'h',
        title: 'إجازة',
        start: DateTime(2026, 12, 7),
        end: DateTime(2026, 12, 9),
        noClasses: true,
      );
      expect(e.covers(DateTime(2026, 12, 7, 23)), isTrue);
      expect(e.covers(DateTime(2026, 12, 9, 10)), isTrue);
      expect(e.covers(DateTime(2026, 12, 10)), isFalse);
      expect(e.isOver(DateTime(2026, 12, 10)), isTrue);
    });

    test('the next class skips a holiday', () async {
      final s = await withMondayClass();
      await s.saveEvent(
        CalendarEvent(
          id: 'h',
          title: 'إجازة',
          start: DateTime(2026, 12, 7),
          noClasses: true,
        ),
      );
      final next = findNextClass(
        s.sessions,
        now,
        isOff: (d) => s.dayOff(d) != null,
      );
      expect(next!.start, DateTime(2026, 12, 14, 10));
    });

    test('class reminders skip the holiday and stop repeating', () async {
      final s = await withMondayClass();
      List<PlannedReminder> classes() => planReminders(
        s,
        now,
      ).where((r) => r.payload == ReminderTarget.schedule).toList();
      expect(classes().single.weekly, isTrue);

      await s.saveEvent(
        CalendarEvent(
          id: 'h',
          title: 'إجازة',
          start: DateTime(2026, 12, 14),
          noClasses: true,
        ),
      );
      final planned = classes();
      expect(planned.every((r) => !r.weekly), isTrue);
      expect(planned.map((r) => r.when.day), [7, 21, 28]);
      expect(dailySummaryBody(s, DateTime(2026, 12, 14, 8)), contains('إجازة'));
    });
  });

  test('deleting a contact takes them out of groups', () async {
    final s = await device();
    await s.saveContact(const Contact(id: 'p', name: 'يوسف'));
    await s.saveGroup(
      const StudyGroup(id: 'g', name: 'فريق', memberIds: ['p']),
    );
    await s.deleteContact('p');
    expect(s.groups.single.memberIds, isEmpty);
  });

  test('deleting a subject detaches contacts, groups and expenses', () async {
    final s = await device();
    await s.saveSubject(const Subject(id: 'a', name: 'A'));
    await s.saveContact(
      const Contact(id: 'p', name: 'د. س', subjectIds: ['a', 'b']),
    );
    await s.saveGroup(const StudyGroup(id: 'g', name: 'G', subjectId: 'a'));
    await s.saveExpense(
      Expense(id: 'e', amount: 50, date: DateTime(2026, 12), subjectId: 'a'),
    );
    await s.deleteSubject('a');
    expect(s.contacts.single.subjectIds, ['b']);
    expect(s.groups.single.subjectId, isNull);
    expect(s.expenses.single.subjectId, isNull);
  });

  test('expenses by month, newest first', () async {
    final s = await device();
    for (final (id, day) in [('a', 3), ('b', 20), ('c', 40)]) {
      await s.saveExpense(
        Expense(id: id, amount: 10, date: DateTime(2026, 11, day)),
      );
    }
    expect(s.expensesIn(DateTime(2026, 11)).map((e) => e.id), ['b', 'a']);
    expect(s.expensesIn(DateTime(2026, 12)).single.id, 'c');
  });

  test('applications: open ones by deadline first, with reminders', () async {
    final s = await device();
    final now = DateTime(2026, 12, 1, 9);
    await s.saveApplication(
      Application(id: 'late', title: 'B', deadline: DateTime(2026, 12, 20)),
    );
    await s.saveApplication(
      Application(id: 'soon', title: 'A', deadline: DateTime(2026, 12, 10)),
    );
    await s.saveApplication(
      const Application(
        id: 'sent',
        title: 'C',
        status: ApplicationStatus.applied,
      ),
    );
    expect(s.applicationsSorted.map((a) => a.id), ['soon', 'late', 'sent']);
    final reminders = planReminders(
      s,
      now,
    ).where((r) => r.payload == ReminderTarget.applications);
    expect(reminders, hasLength(4));
  });

  test('the CV summary lists the record and the achievements', () async {
    final s = await device();
    await loadDemoData(s, DateTime(2026, 10, 5, 9));
    final text = cvText(s);
    expect(text, contains('Flutter من الصفر'));
    expect(text, contains('الأنشطة'));
    expect(text, contains('التقدير التراكمي'));
    expect(normalizeUrl('tel:0100'), 'tel:0100');
    expect(normalizeUrl('mailto:a@b.c'), 'mailto:a@b.c');
  });
}
