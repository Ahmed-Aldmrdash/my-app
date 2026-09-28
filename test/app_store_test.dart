import 'package:flutter_test/flutter_test.dart';
import 'package:study_planner/data/app_store.dart';
import 'package:study_planner/data/demo_data.dart';
import 'package:study_planner/data/storage.dart';
import 'package:study_planner/models/models.dart';

void main() {
  late MemoryStorage storage;
  late AppStore store;

  setUp(() async {
    storage = MemoryStorage();
    store = AppStore(storage);
    await store.load();
  });

  test('everything survives a save and reload', () async {
    await loadDemoData(store, DateTime(2026, 9, 28, 10));
    await store.updateSettings(store.settings.copyWith(studentName: 'أحمد'));

    final reloaded = AppStore(MemoryStorage(storage.data));
    await reloaded.load();
    expect(reloaded.toJson(), store.toJson());
    expect(reloaded.subjects, hasLength(4));
    expect(reloaded.settings.studentName, 'أحمد');
    expect(reloaded.projects.first.steps, isNotEmpty);
  });

  test('corrupted data does not crash loading', () async {
    final broken = AppStore(MemoryStorage('{not json'));
    await broken.load();
    expect(broken.subjects, isEmpty);

    final partly = AppStore(
      MemoryStorage(
        '{"subjects":[{"id":"a","name":"x"},"oops",{"id":"b","name":"y","color":"bad"}]}',
      ),
    );
    await partly.load();
    expect(partly.subjects.map((s) => s.id), ['a', 'b']);
  });

  test('deleting a subject cascades but keeps tasks and projects', () async {
    await store.saveSubject(const Subject(id: 's1', name: 'x'));
    await store.saveSession(
      const ClassSession(
        id: 'c',
        subjectId: 's1',
        weekday: 1,
        startMinute: 0,
        endMinute: 60,
      ),
    );
    await store.saveStudyItem(
      StudyItem(
        id: 'l',
        subjectId: 's1',
        title: 'l',
        releaseDate: DateTime(2026),
      ),
    );
    await store.saveGrade(
      GradeEntry(
        id: 'g',
        subjectId: 's1',
        title: 'g',
        score: 1,
        maxScore: 2,
        date: DateTime(2026),
      ),
    );
    await store.saveTask(const TaskItem(id: 't', title: 't', subjectId: 's1'));
    await store.saveProject(
      const Project(id: 'p', title: 'p', subjectId: 's1'),
    );

    await store.deleteSubject('s1');

    expect(store.subjects, isEmpty);
    expect(store.sessions, isEmpty);
    expect(store.studyItems, isEmpty);
    expect(store.grades, isEmpty);
    expect(store.tasks.single.subjectId, isNull);
    expect(store.projects.single.subjectId, isNull);
  });

  test('completing an assessment with a mark records a grade', () async {
    await store.saveSubject(const Subject(id: 's1', name: 'x'));
    await store.saveAssessment(
      Assessment(
        id: 'a',
        subjectId: 's1',
        title: 'كويز 1',
        dueDate: DateTime(2026, 9, 1),
      ),
    );
    await store.completeAssessment(
      'a',
      done: true,
      score: 7,
      maxScore: 10,
      category: GradeCategory.quiz,
    );
    final a = store.assessments.single;
    expect(a.done, isTrue);
    expect(a.completedAt, isNotNull);
    final g = store.grades.single;
    expect(a.gradeId, g.id);
    expect(g.score, 7);
    expect(g.assessmentId, 'a');

    // Editing the mark updates the same grade instead of adding another.
    await store.completeAssessment('a', done: true, score: 9, maxScore: 10);
    expect(store.grades.single.score, 9);

    await store.deleteGrade(g.id);
    expect(store.assessments.single.gradeId, isNull);
  });

  test('study status and next lecture number', () async {
    await store.saveSubject(const Subject(id: 's1', name: 'x'));
    await store.saveStudyItem(
      StudyItem(
        id: 'l1',
        subjectId: 's1',
        title: 'محاضرة 1',
        number: 1,
        releaseDate: DateTime(2026, 9, 1),
      ),
    );
    expect(store.nextStudyNumber('s1', StudyKind.lecture), 2);
    expect(store.nextStudyNumber('s1', StudyKind.section), 1);

    await store.setStudyStatus('l1', StudyStatus.studied);
    expect(store.studyItems.single.studiedAt, isNotNull);
    await store.setStudyStatus('l1', StudyStatus.notStarted);
    expect(store.studyItems.single.studiedAt, isNull);
  });

  test('import rejects text that is not a backup', () async {
    expect(() => store.importJson('hello'), throwsFormatException);
    expect(() => store.importJson('[1,2]'), throwsFormatException);
  });

  test('project progress uses steps, falls back to manual', () {
    const p = Project(id: 'p', title: 'p', manualProgress: 40);
    expect(p.progress, 0.4);
    final withSteps = p.copyWith(
      steps: const [
        ProjectStep(id: '1', title: 'a', done: true),
        ProjectStep(id: '2', title: 'b'),
      ],
    );
    expect(withSteps.progress, 0.5);
    expect(withSteps.copyWith(submitted: true).progress, 1);
  });
}
