import '../utils/json.dart';

/// What a study-plan entry asks for.
enum PlanKind {
  /// Study a lecture (or a part of a subject) for the first time.
  study,

  /// Revise something already studied.
  review,

  /// Solve past exams or exercises.
  practice,

  /// The last revision the day before an exam.
  finalReview,

  /// Anything the student wrote themselves.
  custom,
}

/// One thing to do on one day of the finals study plan.
class PlanEntry {
  const PlanEntry({
    required this.id,
    required this.day,
    required this.title,
    this.kind = PlanKind.custom,
    this.subjectId,
    this.examId,
    this.studyItemId,
    this.done = false,
    this.auto = false,
  });

  final String id;

  /// The day it is planned for (time is ignored).
  final DateTime day;
  final String title;
  final PlanKind kind;
  final String? subjectId;

  /// The final exam it prepares for.
  final String? examId;

  /// The lecture it is about, if any.
  final String? studyItemId;
  final bool done;

  /// Made by the automatic planner. Regenerating the plan replaces the
  /// automatic entries that are not done; editing one by hand makes it manual.
  final bool auto;

  PlanEntry copyWith({
    DateTime? day,
    String? title,
    PlanKind? kind,
    String? subjectId,
    bool clearSubject = false,
    bool? done,
    bool? auto,
  }) => PlanEntry(
    id: id,
    day: day ?? this.day,
    title: title ?? this.title,
    kind: kind ?? this.kind,
    subjectId: clearSubject ? null : (subjectId ?? this.subjectId),
    examId: examId,
    studyItemId: studyItemId,
    done: done ?? this.done,
    auto: auto ?? this.auto,
  );

  /// The same entry without links to a deleted lecture.
  PlanEntry withoutStudyItem() => PlanEntry(
    id: id,
    day: day,
    title: title,
    kind: kind,
    subjectId: subjectId,
    examId: examId,
    done: done,
    auto: auto,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'day': writeDate(DateTime(day.year, day.month, day.day)),
    'title': title,
    'kind': kind.name,
    'subjectId': subjectId,
    'examId': examId,
    'studyItemId': studyItemId,
    'done': done,
    'auto': auto,
  };

  factory PlanEntry.fromJson(Map<String, dynamic> j) {
    final d = readDate(j['day']) ?? DateTime.now();
    return PlanEntry(
      id: readString(j['id']),
      day: DateTime(d.year, d.month, d.day),
      title: readString(j['title']),
      kind: enumByName(PlanKind.values, j['kind'], PlanKind.custom),
      subjectId: readNullableString(j['subjectId']),
      examId: readNullableString(j['examId']),
      studyItemId: readNullableString(j['studyItemId']),
      done: readBool(j['done']),
      auto: readBool(j['auto']),
    );
  }
}
