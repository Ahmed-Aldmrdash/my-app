import '../models/models.dart';
import 'grade_calculator.dart';

/// Whether [c] is the course [s] is about: the same code, or the same name
/// when either has no code.
bool courseMatchesSubject(PlanCourse c, Subject s) {
  final a = c.code.trim().toLowerCase();
  final b = s.code.trim().toLowerCase();
  if (a.isNotEmpty && b.isNotEmpty) return a == b;
  return c.name.trim() == s.name.trim();
}

/// Grade points of a finished course: from its letter, else its percent.
double? coursePoints(PlanCourse c) {
  final letter = c.letter;
  if (letter != null) {
    for (final g in gpaScale) {
      if (g.letter == letter) return g.points;
    }
  }
  final p = c.percent;
  return p == null ? null : gpaGradeFor(p).points;
}

/// Whether a finished course counts as passed. Without a recorded grade it
/// is assumed passed.
bool coursePassed(PlanCourse c) {
  if (!c.isFinished) return false;
  final letter = c.letter;
  if (letter != null) return letter != 'F';
  final p = c.percent;
  return p == null || p >= 50;
}

/// Grade text of a finished course in the chosen [system].
String? courseGradeText(PlanCourse c, GradingSystem system) {
  final p = c.percent;
  if (system == GradingSystem.gpa) {
    return c.letter ?? (p == null ? null : gpaGradeFor(p).letter);
  }
  if (p != null) return gradeLabel(p);
  return c.letter;
}

/// One archived semester with its courses and averages.
class TermResult {
  TermResult(this.semester, this.courses)
    : gpa = _gpa(courses),
      percent = _percent(courses),
      hours = courses.fold(0, (sum, c) => sum + c.creditHours);

  /// Null for courses whose semester is missing (deleted on another device).
  final Semester? semester;
  final List<PlanCourse> courses;
  final double? gpa;
  final double? percent;
  final int hours;
}

double? _gpa(Iterable<PlanCourse> courses) {
  var points = 0.0;
  var hours = 0;
  for (final c in courses) {
    final p = coursePoints(c);
    if (p == null || c.creditHours <= 0) continue;
    points += p * c.creditHours;
    hours += c.creditHours;
  }
  return hours == 0 ? null : points / hours;
}

double? _percent(Iterable<PlanCourse> courses) {
  var sum = 0.0;
  var hours = 0;
  for (final c in courses) {
    final p = c.percent;
    if (p == null || c.creditHours <= 0) continue;
    sum += p * c.creditHours;
    hours += c.creditHours;
  }
  return hours == 0 ? null : sum / hours;
}

/// The student's whole record: archived semesters, cumulative averages and
/// progress towards graduation.
class AcademicRecord {
  AcademicRecord({
    required List<Semester> semesters,
    required List<PlanCourse> courses,
  }) : courses = List.unmodifiable(courses) {
    final finished = courses.where((c) => c.isFinished).toList();
    final byId = {for (final s in semesters) s.id: s};
    final grouped = <String?, List<PlanCourse>>{};
    for (final c in finished) {
      final key = byId.containsKey(c.semesterId) ? c.semesterId : null;
      grouped.putIfAbsent(key, () => []).add(c);
    }
    final ordered = [...semesters]..sort((a, b) => b.order.compareTo(a.order));
    terms = [
      for (final s in ordered) TermResult(s, grouped[s.id] ?? const []),
      if (grouped[null] != null) TermResult(null, grouped[null]!),
    ];
    gpa = _gpa(finished);
    percent = _percent(finished);
    passedHours = finished
        .where(coursePassed)
        .fold(0, (sum, c) => sum + c.creditHours);
  }

  final List<PlanCourse> courses;

  /// Newest first.
  late final List<TermResult> terms;
  late final double? gpa;
  late final double? percent;
  late final int passedHours;

  /// Cumulative GPA including the current semester's expected grades.
  double? projectedGpa(Iterable<SubjectGradeSummary> current) {
    var points = (gpa ?? 0) * _gradedHours((c) => coursePoints(c) != null);
    var hours = _gradedHours((c) => coursePoints(c) != null);
    for (final s in current) {
      final p = s.percentSoFar;
      final h = s.subject.creditHours;
      if (p == null || h <= 0) continue;
      points += gpaGradeFor(p).points * h;
      hours += h;
    }
    return hours == 0 ? null : points / hours;
  }

  /// Cumulative percentage including the current semester's marks so far.
  double? projectedPercent(Iterable<SubjectGradeSummary> current) {
    var sum = (percent ?? 0) * _gradedHours((c) => c.percent != null);
    var hours = _gradedHours((c) => c.percent != null);
    for (final s in current) {
      final p = s.percentSoFar;
      final h = s.subject.creditHours;
      if (p == null || h <= 0) continue;
      sum += p * h;
      hours += h;
    }
    return hours == 0 ? null : sum / hours;
  }

  int _gradedHours(bool Function(PlanCourse) graded) => courses
      .where((c) => c.isFinished && c.creditHours > 0 && graded(c))
      .fold(0, (sum, c) => sum + c.creditHours);

  /// Courses not finished yet.
  List<PlanCourse> get remaining =>
      courses.where((c) => !c.isFinished).toList();

  /// Whether every prerequisite of [c] is passed.
  bool prerequisitesMet(PlanCourse c) => missingPrerequisites(c).isEmpty;

  /// The prerequisites of [c] that are not passed yet. A prerequisite that
  /// was deleted no longer blocks anything, and one passed under another
  /// entry with the same code (a retake) counts as passed.
  List<PlanCourse> missingPrerequisites(PlanCourse c) {
    final byId = {for (final x in courses) x.id: x};
    final passedCodes = {
      for (final x in courses)
        if (coursePassed(x) && x.code.trim().isNotEmpty)
          x.code.trim().toLowerCase(),
    };
    bool passed(PlanCourse p) =>
        coursePassed(p) || passedCodes.contains(p.code.trim().toLowerCase());
    return [
      for (final id in c.prerequisites)
        if (byId[id] != null && !passed(byId[id]!)) byId[id]!,
    ];
  }
}
