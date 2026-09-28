import 'package:flutter_test/flutter_test.dart';
import 'package:study_planner/models/models.dart';
import 'package:study_planner/utils/grade_calculator.dart';

GradeEntry _g(
  double score,
  double max, {
  bool bonus = false,
  GradeCategory category = GradeCategory.quiz,
}) => GradeEntry(
  id: '$score/$max/$bonus',
  subjectId: 's',
  title: 't',
  score: score,
  maxScore: max,
  date: DateTime(2026, 9, 1),
  isBonus: bonus,
  category: category,
);

void main() {
  const subject = Subject(
    id: 's',
    name: 'برمجة',
    totalMarks: 100,
    finalExamMarks: 60,
  );

  test('empty subject', () {
    final s = SubjectGradeSummary(subject, const []);
    expect(s.hasGrades, isFalse);
    expect(s.percentSoFar, isNull);
    expect(s.remaining, 100);
    expect(s.neededFor(50), 50);
  });

  test('sums scores, keeps bonus out of the maximum', () {
    final s = SubjectGradeSummary(subject, [
      _g(8, 10),
      _g(15, 20, category: GradeCategory.midterm),
      _g(2, 0, bonus: true),
    ]);
    expect(s.earned, 25);
    expect(s.bonus, 2);
    expect(s.attemptedMax, 30);
    expect(s.percentSoFar, closeTo(83.33, 0.01));
    expect(s.remaining, 70);
    expect(s.byCategory[GradeCategory.quiz]!.score, 8);
    expect(s.byCategory[GradeCategory.midterm]!.max, 20);
    expect(s.byCategory.containsKey(GradeCategory.attendance), isFalse);
  });

  test('marks needed for each band', () {
    final s = SubjectGradeSummary(subject, [_g(30, 40)]);
    expect(s.neededFor(50), 20);
    expect(s.neededFor(85), 55);
    expect(s.canReach(85), isTrue);
    expect(s.remaining, 60);

    final weak = SubjectGradeSummary(subject, [_g(5, 40)]);
    expect(weak.neededFor(85), 80);
    expect(weak.canReach(85), isFalse);
    expect(weak.canReach(65), isTrue);
  });

  test('already secured band', () {
    final s = SubjectGradeSummary(subject, [
      _g(38, 40),
      _g(20, 0, bonus: true),
    ]);
    expect(s.neededFor(50), lessThanOrEqualTo(0));
  });

  test('grade labels use the Egyptian scale', () {
    expect(gradeLabel(90), 'ممتاز');
    expect(gradeLabel(85), 'ممتاز');
    expect(gradeLabel(80), 'جيد جداً');
    expect(gradeLabel(70), 'جيد');
    expect(gradeLabel(55), 'مقبول');
    expect(gradeLabel(40), 'ضعيف');
  });

  test('overall percent averages subjects with grades only', () {
    final a = SubjectGradeSummary(subject, [_g(9, 10)]);
    final b = SubjectGradeSummary(subject, [_g(7, 10)]);
    final c = SubjectGradeSummary(subject, const []);
    expect(overallPercent([a, b, c]), closeTo(80, 0.001));
    expect(overallPercent([c]), isNull);
  });
}
