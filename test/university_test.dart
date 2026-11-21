import 'package:flutter_test/flutter_test.dart';
import 'package:study_planner/data/app_store.dart';
import 'package:study_planner/data/storage.dart';
import 'package:study_planner/models/models.dart';
import 'package:study_planner/services/reminder_planner.dart';
import 'package:study_planner/utils/academic.dart';
import 'package:study_planner/utils/study_plan.dart';

Future<AppStore> device() async {
  final s = AppStore(MemoryStorage());
  await s.load();
  return s;
}

StudyItem lecture(
  String id,
  String subjectId,
  int n, {
  StudyStatus status = StudyStatus.notStarted,
}) => StudyItem(
  id: id,
  subjectId: subjectId,
  title: 'محاضرة $n',
  number: n,
  releaseDate: DateTime(2026, 10, n),
  status: status,
);

void main() {
  group('study plan', () {
    final today = DateTime(2026, 12, 1, 10);
    var ids = 0;
    String makeId() => 'e${ids++}';

    test('everything is planned before its exam, with a final review', () {
      final exams = [
        FinalExam(id: 'x1', subjectId: 'a', start: DateTime(2026, 12, 5, 9)),
        FinalExam(id: 'x2', subjectId: 'b', start: DateTime(2026, 12, 9, 9)),
      ];
      final items = [
        for (var i = 1; i <= 4; i++) lecture('a$i', 'a', i),
        lecture('b1', 'b', 1, status: StudyStatus.studied),
        lecture('b2', 'b', 2),
      ];
      final plan = generateStudyPlan(
        today: today,
        exams: exams,
        studyItems: items,
        subjectName: (id) => id,
        perDay: 2,
        makeId: makeId,
      );
      for (final exam in exams) {
        final mine = plan.where((e) => e.examId == exam.id).toList();
        expect(mine.every((e) => e.day.isBefore(exam.day)), isTrue);
        expect(
          mine.every((e) => e.auto && e.subjectId == exam.subjectId),
          isTrue,
        );
        final last = mine.where((e) => e.kind == PlanKind.finalReview).single;
        expect(
          last.day,
          DateTime(exam.day.year, exam.day.month, exam.day.day - 1),
        );
      }
      // Every unstudied lecture is planned once.
      final studies = plan.where((e) => e.kind == PlanKind.study).toList();
      expect(studies.map((e) => e.studyItemId).toSet(), {
        'a1',
        'a2',
        'a3',
        'a4',
        'b2',
      });
      expect(plan.where((e) => e.kind == PlanKind.review), hasLength(1));
      expect(plan.first.day, DateTime(2026, 12, 1));
    });

    test('a subject without lectures still gets study sessions', () {
      final plan = generateStudyPlan(
        today: today,
        exams: [
          FinalExam(id: 'x', subjectId: 'a', start: DateTime(2026, 12, 8, 9)),
        ],
        studyItems: const [],
        subjectName: (_) => 'رياضة',
        makeId: makeId,
      );
      expect(plan.where((e) => e.kind == PlanKind.study), hasLength(3));
      expect(plan.where((e) => e.kind == PlanKind.practice), hasLength(1));
    });

    test('past exams and exams today are left out', () {
      final plan = generateStudyPlan(
        today: today,
        exams: [
          FinalExam(id: 'x', subjectId: 'a', start: DateTime(2026, 12, 1, 14)),
          FinalExam(id: 'y', subjectId: 'a', start: DateTime(2026, 11, 20)),
        ],
        studyItems: [lecture('a1', 'a', 1)],
        subjectName: (id) => id,
        makeId: makeId,
      );
      expect(plan, isEmpty);
    });

    test('regenerating keeps done and hand-made entries', () async {
      final s = await device();
      await s.saveSubject(const Subject(id: 'a', name: 'A'));
      await s.saveStudyItem(lecture('a1', 'a', 1));
      await s.saveStudyItem(lecture('a2', 'a', 2));
      final now = DateTime.now();
      await s.saveFinal(
        FinalExam(
          id: 'x',
          subjectId: 'a',
          start: DateTime(now.year, now.month, now.day + 6, 9),
        ),
      );
      final first = await s.regenerateStudyPlan(now);
      expect(first, greaterThan(0));
      final study = s.planEntries.firstWhere((e) => e.studyItemId == 'a1');
      await s.togglePlanEntry(study.id);
      // Ticking off "study lecture 1" marks the lecture studied.
      expect(
        s.studyItems.firstWhere((i) => i.id == 'a1').status,
        StudyStatus.studied,
      );
      await s.savePlanEntry(
        PlanEntry(
          id: 'mine',
          day: DateTime(now.year, now.month, now.day),
          title: 'x',
        ),
      );
      await s.regenerateStudyPlan(now);
      expect(s.planEntries.where((e) => e.id == study.id).single.done, isTrue);
      expect(s.planEntries.any((e) => e.id == 'mine'), isTrue);
      // Lecture 1 is studied now, so it comes back as a review only.
      expect(
        s.planEntries.where(
          (e) =>
              e.auto &&
              !e.done &&
              e.kind == PlanKind.study &&
              e.studyItemId == 'a1',
        ),
        isEmpty,
      );

      await s.deleteFinal('x');
      expect(s.planEntries.where((e) => e.auto && !e.done), isEmpty);
    });
  });

  group('flashcards', () {
    final created = DateTime(2026, 10, 1);
    final card = Flashcard(
      id: 'c',
      subjectId: 's',
      front: 'Q',
      back: 'A',
      createdAt: created,
    );
    final now = DateTime(2026, 11, 1, 20);

    test('new cards are due, and good answers push them further out', () {
      expect(card.isDue(now), isTrue);
      var c = card.answered(CardAnswer.good, now);
      expect(c.dueDate, DateTime(2026, 11, 2));
      expect(c.isDue(now), isFalse);
      c = c.answered(CardAnswer.good, DateTime(2026, 11, 2, 9));
      expect(c.dueDate, DateTime(2026, 11, 5));
      c = c.answered(CardAnswer.easy, DateTime(2026, 11, 5, 9));
      expect(c.dueDate, DateTime(2026, 11, 19));
    });

    test('forgetting starts over and counts a lapse', () {
      final learned = card
          .answered(CardAnswer.good, now)
          .answered(CardAnswer.good, DateTime(2026, 11, 2));
      final forgot = learned.answered(CardAnswer.again, DateTime(2026, 11, 5));
      expect(forgot.stage, 0);
      expect(forgot.lapses, 1);
      expect(forgot.isDue(DateTime(2026, 11, 5, 23)), isTrue);
    });

    test(
      'due cards: overdue first, then new; deleted subjects skipped',
      () async {
        final s = await device();
        await s.saveSubject(const Subject(id: 's', name: 'S'));
        await s.saveCard(card);
        await s.saveCard(
          Flashcard(
            id: 'old',
            subjectId: 's',
            front: 'q',
            back: 'a',
            createdAt: created,
            dueDate: DateTime(2026, 10, 20),
            stage: 2,
          ),
        );
        await s.saveCard(
          Flashcard(
            id: 'orphan',
            subjectId: 'gone',
            front: 'q',
            back: 'a',
            createdAt: created,
          ),
        );
        expect(s.dueCards(now).map((c) => c.id), ['old', 'c']);
        await s.answerCard('old', CardAnswer.good, now);
        expect(s.dueCards(now).map((c) => c.id), ['c']);
      },
    );
  });

  group('semesters and the study plan', () {
    test('cumulative averages are weighted by credit hours', () {
      const s1 = Semester(id: 's1', name: 'T1', order: 1);
      final record = AcademicRecord(
        semesters: [s1],
        courses: const [
          PlanCourse(
            id: 'a',
            name: 'A',
            creditHours: 3,
            semesterId: 's1',
            letter: 'A',
          ),
          PlanCourse(
            id: 'b',
            name: 'B',
            creditHours: 1,
            semesterId: 's1',
            percent: 62,
          ),
          PlanCourse(id: 'c', name: 'C', creditHours: 2),
        ],
      );
      // (4.0 * 3 + 2.0 * 1) / 4
      expect(record.gpa, closeTo(3.5, 1e-9));
      expect(record.passedHours, 4);
      expect(record.terms.single.courses, hasLength(2));
      expect(record.remaining.single.id, 'c');
    });

    test('prerequisites decide what can be taken next', () {
      final record = AcademicRecord(
        semesters: const [Semester(id: 's1', name: 'T1')],
        courses: const [
          PlanCourse(id: 'p1', name: 'P1', semesterId: 's1', letter: 'B'),
          PlanCourse(id: 'f', name: 'F', semesterId: 's1', letter: 'F'),
          PlanCourse(id: 'next', name: 'N', prerequisites: ['p1']),
          PlanCourse(id: 'blocked', name: 'X', prerequisites: ['p1', 'f']),
        ],
      );
      final next = record.courses.firstWhere((c) => c.id == 'next');
      final blocked = record.courses.firstWhere((c) => c.id == 'blocked');
      expect(record.prerequisitesMet(next), isTrue);
      expect(record.prerequisitesMet(blocked), isFalse);
      expect(record.missingPrerequisites(blocked).single.id, 'f');
    });

    test('closing a semester archives grades and clears its data', () async {
      final s = await device();
      await s.saveSubject(
        const Subject(id: 'm', name: 'ماث', code: 'MA1', creditHours: 4),
      );
      await s.saveSubject(
        const Subject(id: 'p', name: 'برمجة', creditHours: 3),
      );
      await s.saveStudyItem(lecture('l', 'm', 1));
      await s.saveNote(
        Note(
          id: 'n',
          subjectId: 'm',
          title: 't',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      );
      await s.saveTask(const TaskItem(id: 't', title: 't', subjectId: 'm'));
      // Already in the study plan under its code.
      await s.saveCourse(
        const PlanCourse(
          id: 'pc',
          name: 'Math 1',
          code: 'ma1',
          group: 'متطلبات كلية',
        ),
      );

      final semester = await s.closeSemester(
        name: 'الترم الأول',
        nextName: 'الترم التاني',
        results: {
          'm': (percent: 91, letter: null),
          'p': (percent: null, letter: 'B+'),
        },
      );

      expect(s.subjects, isEmpty);
      expect(s.studyItems, isEmpty);
      expect(s.notes, isEmpty);
      expect(s.tasks.single.subjectId, isNull);
      expect(s.settings.semesterName, 'الترم التاني');
      expect(s.semesters.single.name, 'الترم الأول');
      final math = s.planCourses.firstWhere((c) => c.id == 'pc');
      expect(math.semesterId, semester.id);
      expect(math.percent, 91);
      expect(math.creditHours, 4);
      expect(math.group, 'متطلبات كلية');
      final prog = s.planCourses.firstWhere((c) => c.name == 'برمجة');
      expect(prog.letter, 'B+');
      // (4.0 * 4 + 3.3 * 3) / 7
      expect(s.academicRecord.gpa, closeTo((16 + 9.9) / 7, 1e-9));

      await s.deleteSemester(semester.id);
      expect(s.planCourses.every((c) => !c.isFinished), isTrue);
    });

    test('deleting a course removes it from prerequisites', () async {
      final s = await device();
      await s.saveCourse(const PlanCourse(id: 'a', name: 'A'));
      await s.saveCourse(
        const PlanCourse(id: 'b', name: 'B', prerequisites: ['a']),
      );
      await s.deleteCourse('a');
      expect(s.planCourses.single.prerequisites, isEmpty);
    });
  });

  test('deleting a subject or a lecture cleans up the new lists', () async {
    final s = await device();
    final at = DateTime(2026, 11, 1);
    await s.saveSubject(const Subject(id: 'a', name: 'A'));
    await s.saveStudyItem(lecture('l', 'a', 1));
    await s.saveNote(
      Note(
        id: 'n',
        subjectId: 'a',
        studyItemId: 'l',
        title: 't',
        createdAt: at,
        updatedAt: at,
      ),
    );
    await s.saveCard(
      Flashcard(
        id: 'c',
        subjectId: 'a',
        studyItemId: 'l',
        front: 'q',
        back: 'a',
        createdAt: at,
      ),
    );
    await s.deleteStudyItem('l');
    expect(s.notes.single.studyItemId, isNull);
    expect(s.notes.single.subjectId, 'a');
    expect(s.flashcards.single.studyItemId, isNull);

    await s.saveFinal(FinalExam(id: 'x', subjectId: 'a', start: at));
    await s.saveCourse(const PlanCourse(id: 'pc', name: 'A', subjectId: 'a'));
    await s.deleteSubject('a');
    expect(s.notes, isEmpty);
    expect(s.flashcards, isEmpty);
    expect(s.finals, isEmpty);
    expect(s.planCourses.single.subjectId, isNull);
  });

  test('notes: pinned first, then the latest edit', () async {
    final s = await device();
    Note note(String id, int day, {bool pinned = false}) => Note(
      id: id,
      title: id,
      subjectId: 'a',
      pinned: pinned,
      createdAt: DateTime(2026, 11, day),
      updatedAt: DateTime(2026, 11, day),
    );
    await s.saveNote(note('old', 1));
    await s.saveNote(note('new', 5));
    await s.saveNote(note('pin', 2, pinned: true));
    expect(s.notesFor(subjectId: 'a').map((n) => n.id), ['pin', 'new', 'old']);
    expect(linkTypeOf('https://youtu.be/x'), LinkType.youtube);
    expect(linkTypeOf('drive.google.com/file/d/1'), LinkType.drive);
    expect(linkTypeOf('https://site.edu/ch3.PDF'), LinkType.pdf);
    expect(normalizeUrl('drive.google.com/x'), 'https://drive.google.com/x');
  });

  test('finals get reminders and show in the morning summary', () async {
    final s = await device();
    final now = DateTime(2026, 12, 1, 7);
    await s.saveSubject(const Subject(id: 'a', name: 'شبكات'));
    await s.saveFinal(
      FinalExam(
        id: 'x',
        subjectId: 'a',
        start: DateTime(2026, 12, 4, 9),
        place: 'مدرج 2',
      ),
    );
    await s.savePlanEntry(
      PlanEntry(id: 'p', day: DateTime(2026, 12, 1), title: 'ذاكر'),
    );
    final reminders = planReminders(
      s,
      now,
    ).where((r) => r.payload == ReminderTarget.finals).toList();
    expect(reminders, hasLength(2));
    expect(reminders.first.title, contains('شبكات'));
    expect(reminders.first.body, contains('مدرج 2'));

    final summary = dailySummaryBody(s, now);
    expect(summary, contains('فاضل 3 أيام على فاينال شبكات'));
    expect(summary, contains('مهمة'));
  });

  group('review fixes', () {
    test('any data at all makes the store non-empty', () async {
      final s = await device();
      expect(s.isEmpty, isTrue);
      await s.saveSemester(const Semester(id: 'x', name: 'T'));
      expect(s.isEmpty, isFalse);
    });

    test('closing without clearing never archives a subject twice', () async {
      final s = await device();
      await s.saveSubject(const Subject(id: 'a', name: 'A', creditHours: 3));
      await s.closeSemester(
        name: 'T1',
        clearData: false,
        results: {'a': (percent: 80, letter: null)},
      );
      expect(s.subjects, hasLength(1));
      expect(s.currentSubjects, isEmpty);
      await s.closeSemester(name: 'T2', clearData: false, results: const {});
      expect(s.planCourses, hasLength(1));
      expect(s.academicRecord.passedHours, 3);
    });

    test('a retaken failed course replaces the failure', () async {
      final s = await device();
      await s.saveSemester(const Semester(id: 's1', name: 'T1', order: 1));
      await s.saveCourse(
        const PlanCourse(
          id: 'x',
          name: 'X',
          code: 'CS1',
          semesterId: 's1',
          letter: 'F',
        ),
      );
      await s.saveCourse(
        const PlanCourse(id: 'y', name: 'Y', prerequisites: ['x']),
      );
      expect(s.academicRecord.prerequisitesMet(s.planCourses.last), isFalse);
      await s.saveSubject(
        const Subject(id: 'sx', name: 'X again', code: 'cs1'),
      );
      await s.closeSemester(
        name: 'T2',
        results: {'sx': (percent: null, letter: 'B')},
      );
      expect(s.planCourses, hasLength(2));
      final x = s.planCourses.firstWhere((c) => c.id == 'x');
      expect(x.letter, 'B');
      final y = s.planCourses.firstWhere((c) => c.id == 'y');
      expect(s.academicRecord.prerequisitesMet(y), isTrue);
    });

    test('two finals of one subject plan its lectures once', () {
      final plan = generateStudyPlan(
        today: DateTime(2026, 12, 1),
        exams: [
          FinalExam(id: 'w', subjectId: 'a', start: DateTime(2026, 12, 6)),
          FinalExam(id: 'p', subjectId: 'a', start: DateTime(2026, 12, 9)),
        ],
        studyItems: [lecture('l1', 'a', 1), lecture('l2', 'a', 2)],
        subjectName: (_) => 'A',
      );
      expect(plan.where((e) => e.studyItemId == 'l1'), hasLength(1));
      expect(plan.where((e) => e.kind == PlanKind.finalReview), hasLength(2));
      expect(plan.map((e) => e.id).toSet(), hasLength(plan.length));
    });

    test('planning again adds nothing that is already there or done', () async {
      final s = await device();
      await s.saveSubject(const Subject(id: 'a', name: 'A'));
      final now = DateTime.now();
      await s.saveFinal(
        FinalExam(
          id: 'x',
          subjectId: 'a',
          start: DateTime(now.year, now.month, now.day + 5, 9),
        ),
      );
      final first = await s.regenerateStudyPlan(now);
      final practice = s.planEntries.firstWhere(
        (e) => e.kind == PlanKind.practice,
      );
      await s.togglePlanEntry(practice.id);
      await s.regenerateStudyPlan(now);
      expect(s.planEntries, hasLength(first));
      expect(
        s.planEntries.where((e) => e.kind == PlanKind.practice),
        hasLength(1),
      );
    });
  });
}
