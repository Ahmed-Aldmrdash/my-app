import '../utils/json.dart';

/// A university course (مادة).
class Subject {
  const Subject({
    required this.id,
    required this.name,
    this.code = '',
    this.instructor = '',
    this.assistant = '',
    this.colorValue = 0xFF3F51B5,
    this.totalMarks = 100,
    this.finalExamMarks = 60,
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
  final String notes;

  double get courseworkMarks =>
      (totalMarks - finalExamMarks).clamp(0, totalMarks).toDouble();

  Subject copyWith({
    String? name,
    String? code,
    String? instructor,
    String? assistant,
    int? colorValue,
    double? totalMarks,
    double? finalExamMarks,
    String? notes,
  }) {
    return Subject(
      id: id,
      name: name ?? this.name,
      code: code ?? this.code,
      instructor: instructor ?? this.instructor,
      assistant: assistant ?? this.assistant,
      colorValue: colorValue ?? this.colorValue,
      totalMarks: totalMarks ?? this.totalMarks,
      finalExamMarks: finalExamMarks ?? this.finalExamMarks,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'code': code,
    'instructor': instructor,
    'assistant': assistant,
    'color': colorValue,
    'totalMarks': totalMarks,
    'finalExamMarks': finalExamMarks,
    'notes': notes,
  };

  factory Subject.fromJson(Map<String, dynamic> j) => Subject(
    id: readString(j['id']),
    name: readString(j['name']),
    code: readString(j['code']),
    instructor: readString(j['instructor']),
    assistant: readString(j['assistant']),
    colorValue: readInt(j['color'], 0xFF3F51B5),
    totalMarks: readDouble(j['totalMarks'], 100),
    finalExamMarks: readDouble(j['finalExamMarks'], 60),
    notes: readString(j['notes']),
  );
}
