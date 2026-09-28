import '../utils/json.dart';

enum StudyKind { lecture, section, lab, chapter, other }

enum StudyStatus { notStarted, inProgress, studied, revised }

extension StudyStatusX on StudyStatus {
  bool get isDone => this == StudyStatus.studied || this == StudyStatus.revised;
}

/// Something released that needs studying: a lecture, a section, a chapter…
class StudyItem {
  const StudyItem({
    required this.id,
    required this.subjectId,
    required this.title,
    required this.releaseDate,
    this.kind = StudyKind.lecture,
    this.number,
    this.status = StudyStatus.notStarted,
    this.notes = '',
    this.studiedAt,
  });

  final String id;
  final String subjectId;
  final StudyKind kind;
  final String title;
  final int? number;

  /// When the lecture was released / given (نزلت إمتى).
  final DateTime releaseDate;
  final StudyStatus status;
  final String notes;
  final DateTime? studiedAt;

  StudyItem withStatus(StudyStatus next) => StudyItem(
    id: id,
    subjectId: subjectId,
    kind: kind,
    title: title,
    number: number,
    releaseDate: releaseDate,
    status: next,
    notes: notes,
    studiedAt: next.isDone ? (studiedAt ?? DateTime.now()) : null,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'subjectId': subjectId,
    'kind': kind.name,
    'title': title,
    'number': number,
    'releaseDate': writeDate(releaseDate),
    'status': status.name,
    'notes': notes,
    'studiedAt': writeDate(studiedAt),
  };

  factory StudyItem.fromJson(Map<String, dynamic> j) => StudyItem(
    id: readString(j['id']),
    subjectId: readString(j['subjectId']),
    kind: enumByName(StudyKind.values, j['kind'], StudyKind.lecture),
    title: readString(j['title']),
    number: j['number'] is num ? (j['number'] as num).toInt() : null,
    releaseDate: readDate(j['releaseDate']) ?? DateTime.now(),
    status: enumByName(StudyStatus.values, j['status'], StudyStatus.notStarted),
    notes: readString(j['notes']),
    studiedAt: readDate(j['studiedAt']),
  );
}
