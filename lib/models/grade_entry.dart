import '../utils/json.dart';

enum GradeCategory {
  quiz,
  midterm,
  assignment,
  project,
  practical,
  oral,
  attendance,
  finalExam,
  other,
}

/// One mark earned in a subject: what it was for, the score, out of what,
/// when, and whether it is a bonus.
class GradeEntry {
  const GradeEntry({
    required this.id,
    required this.subjectId,
    required this.title,
    required this.score,
    required this.maxScore,
    required this.date,
    this.category = GradeCategory.quiz,
    this.isBonus = false,
    this.notes = '',
    this.assessmentId,
  });

  final String id;
  final String subjectId;
  final GradeCategory category;
  final String title;
  final double score;

  /// Out of how much. Bonus entries may have 0 here.
  final double maxScore;
  final DateTime date;

  /// Bonus marks add to the score without adding to the maximum.
  final bool isBonus;
  final String notes;

  /// The quiz/assignment this mark came from, if recorded from there.
  final String? assessmentId;

  double? get ratio => (!isBonus && maxScore > 0) ? score / maxScore : null;

  Map<String, dynamic> toJson() => {
    'id': id,
    'subjectId': subjectId,
    'category': category.name,
    'title': title,
    'score': score,
    'maxScore': maxScore,
    'date': writeDate(date),
    'isBonus': isBonus,
    'notes': notes,
    'assessmentId': assessmentId,
  };

  factory GradeEntry.fromJson(Map<String, dynamic> j) => GradeEntry(
    id: readString(j['id']),
    subjectId: readString(j['subjectId']),
    category: enumByName(
      GradeCategory.values,
      j['category'],
      GradeCategory.other,
    ),
    title: readString(j['title']),
    score: readDouble(j['score']),
    maxScore: readDouble(j['maxScore']),
    date: readDate(j['date']) ?? DateTime.now(),
    isBonus: readBool(j['isBonus']),
    notes: readString(j['notes']),
    assessmentId: readNullableString(j['assessmentId']),
  );
}
