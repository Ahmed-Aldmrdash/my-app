import '../utils/json.dart';

/// A university course (مادة).
class Subject {
  const Subject({
    required this.id,
    required this.name,
    this.code = '',
    this.instructor = '',
    this.assistant = '',
    this.colorValue = 0xFF6C5CE7,
    this.totalMarks = 100,
    this.finalExamMarks = 60,
    this.creditHours = 3,
    this.absenceLimit = 0,
    this.notes = '',
  });

  final String id;
  final String name;
  final String code;

  /// The lecturer (الدكتور).
  final String instructor;

  /// The teaching assistant (المعيد).
  final String assistant;
  final int colorValue;

  /// The full mark of the course (e.g. 100 or 150).
  final double totalMarks;

  /// How much of [totalMarks] belongs to the final exam. The rest is
  /// coursework (أعمال السنة).
  final double finalExamMarks;

  /// Credit hours, used to weight the GPA.
  final int creditHours;

  /// Allowed absences before being barred (حرمان). 0 means not tracked.
  final int absenceLimit;
  final String notes;

  double get courseworkMarks =>
      (totalMarks - finalExamMarks).clamp(0, totalMarks).toDouble();

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'code': code,
    'instructor': instructor,
    'assistant': assistant,
    'color': colorValue,
    'totalMarks': totalMarks,
    'finalExamMarks': finalExamMarks,
    'creditHours': creditHours,
    'absenceLimit': absenceLimit,
    'notes': notes,
  };

  factory Subject.fromJson(Map<String, dynamic> j) => Subject(
    id: readString(j['id']),
    name: readString(j['name']),
    code: readString(j['code']),
    instructor: readString(j['instructor']),
    assistant: readString(j['assistant']),
    colorValue: readInt(j['color'], 0xFF6C5CE7),
    totalMarks: readDouble(j['totalMarks'], 100),
    finalExamMarks: readDouble(j['finalExamMarks'], 60),
    creditHours: readInt(j['creditHours'], 3),
    absenceLimit: readInt(j['absenceLimit']),
    notes: readString(j['notes']),
  );
}
