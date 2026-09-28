import '../utils/json.dart';

enum AssessmentType { quiz, exam, assignment }

/// A dated deliverable for a subject: a quiz, an exam (midterm, practical,
/// final…) or an assignment.
class Assessment {
  const Assessment({
    required this.id,
    required this.subjectId,
    required this.title,
    required this.dueDate,
    this.type = AssessmentType.quiz,
    this.location = '',
    this.notes = '',
    this.done = false,
    this.completedAt,
    this.reminders = const [24 * 60, 60],
    this.gradeId,
  });

  final String id;
  final String subjectId;
  final AssessmentType type;
  final String title;

  /// Quiz/exam time, or assignment deadline.
  final DateTime dueDate;
  final String location;
  final String notes;

  /// Taken (quiz/exam) or submitted (assignment).
  final bool done;
  final DateTime? completedAt;

  /// Minutes before [dueDate] to remind.
  final List<int> reminders;

  /// The [GradeEntry] recorded for this assessment, if any.
  final String? gradeId;

  bool isOverdue(DateTime now) => !done && dueDate.isBefore(now);

  Assessment copyWith({bool? done, String? gradeId}) {
    final nextDone = done ?? this.done;
    return Assessment(
      id: id,
      subjectId: subjectId,
      type: type,
      title: title,
      dueDate: dueDate,
      location: location,
      notes: notes,
      done: nextDone,
      completedAt: nextDone ? (completedAt ?? DateTime.now()) : null,
      reminders: reminders,
      gradeId: gradeId ?? this.gradeId,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'subjectId': subjectId,
    'type': type.name,
    'title': title,
    'dueDate': writeDate(dueDate),
    'location': location,
    'notes': notes,
    'done': done,
    'completedAt': writeDate(completedAt),
    'reminders': reminders,
    'gradeId': gradeId,
  };

  factory Assessment.fromJson(Map<String, dynamic> j) => Assessment(
    id: readString(j['id']),
    subjectId: readString(j['subjectId']),
    type: enumByName(AssessmentType.values, j['type'], AssessmentType.quiz),
    title: readString(j['title']),
    dueDate: readDate(j['dueDate']) ?? DateTime.now(),
    location: readString(j['location']),
    notes: readString(j['notes']),
    done: readBool(j['done']),
    completedAt: readDate(j['completedAt']),
    reminders: readIntList(j['reminders'], const [24 * 60, 60]),
    gradeId: readNullableString(j['gradeId']),
  );
}
