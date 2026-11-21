import '../utils/json.dart';

/// A finished semester (ترم) kept in the archive.
class Semester {
  const Semester({
    required this.id,
    required this.name,
    this.order = 0,
    this.notes = '',
  });

  final String id;

  /// e.g. "الترم الأول 2025/2026".
  final String name;

  /// Position in time; higher is more recent.
  final int order;
  final String notes;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'order': order,
    'notes': notes,
  };

  factory Semester.fromJson(Map<String, dynamic> j) => Semester(
    id: readString(j['id']),
    name: readString(j['name']),
    order: readInt(j['order']),
    notes: readString(j['notes']),
  );
}

/// Suggested groups for the courses of a study plan.
const courseGroups = <String>[
  'متطلبات جامعة',
  'متطلبات كلية',
  'متطلبات قسم',
  'اختياري',
];

/// A course of the degree's study plan (الخطة الدراسية): still to take,
/// being taken now, or finished with a grade in some semester.
class PlanCourse {
  const PlanCourse({
    required this.id,
    required this.name,
    this.code = '',
    this.creditHours = 3,
    this.group = '',
    this.level = 0,
    this.prerequisites = const [],
    this.semesterId,
    this.percent,
    this.letter,
    this.subjectId,
    this.notes = '',
  });

  final String id;
  final String name;
  final String code;
  final int creditHours;

  /// e.g. "متطلبات كلية" (see [courseGroups]); empty when not set.
  final String group;

  /// The year it belongs to (الفرقة 1-5); 0 when not set.
  final int level;

  /// Ids of the courses that must be passed first.
  final List<String> prerequisites;

  /// The semester it was finished in; null while not finished.
  final String? semesterId;

  /// The final mark in percent, if known.
  final double? percent;

  /// The letter grade (A, B+, …) in the credit-hour system, if known.
  final String? letter;

  /// The subject that is this course in the current semester.
  final String? subjectId;
  final String notes;

  bool get isFinished => semesterId != null;

  PlanCourse copyWith({
    String? name,
    String? code,
    int? creditHours,
    List<String>? prerequisites,
    String? semesterId,
    bool clearResult = false,
    double? percent,
    String? letter,
    String? subjectId,
    bool clearSubject = false,
  }) => PlanCourse(
    id: id,
    name: name ?? this.name,
    code: code ?? this.code,
    creditHours: creditHours ?? this.creditHours,
    group: group,
    level: level,
    prerequisites: prerequisites ?? this.prerequisites,
    semesterId: clearResult ? null : (semesterId ?? this.semesterId),
    percent: clearResult ? null : (percent ?? this.percent),
    letter: clearResult ? null : (letter ?? this.letter),
    subjectId: clearSubject ? null : (subjectId ?? this.subjectId),
    notes: notes,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'code': code,
    'creditHours': creditHours,
    'group': group,
    'level': level,
    'prerequisites': prerequisites,
    'semesterId': semesterId,
    'percent': percent,
    'letter': letter,
    'subjectId': subjectId,
    'notes': notes,
  };

  factory PlanCourse.fromJson(Map<String, dynamic> j) => PlanCourse(
    id: readString(j['id']),
    name: readString(j['name']),
    code: readString(j['code']),
    creditHours: readInt(j['creditHours'], 3).clamp(0, 30),
    group: readString(j['group']),
    level: readInt(j['level']).clamp(0, 7),
    prerequisites: j['prerequisites'] is List
        ? (j['prerequisites'] as List).whereType<String>().toList()
        : const [],
    semesterId: readNullableString(j['semesterId']),
    percent: j['percent'] is num ? (j['percent'] as num).toDouble() : null,
    letter: readNullableString(j['letter']),
    subjectId: readNullableString(j['subjectId']),
    notes: readString(j['notes']),
  );
}
