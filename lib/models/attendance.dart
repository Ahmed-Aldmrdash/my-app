import '../utils/json.dart';
import 'class_session.dart';

/// Whether the student attended one occurrence of a class (حضور / غياب).
class AttendanceRecord {
  const AttendanceRecord({
    required this.id,
    required this.subjectId,
    required this.date,
    required this.present,
    this.sessionId,
    this.type = SessionType.lecture,
    this.note = '',
  });

  final String id;
  final String subjectId;

  /// The timetable slot, when recorded from the timetable.
  final String? sessionId;
  final SessionType type;

  /// The day of the class (time part is ignored).
  final DateTime date;
  final bool present;
  final String note;

  Map<String, dynamic> toJson() => {
    'id': id,
    'subjectId': subjectId,
    'sessionId': sessionId,
    'type': type.name,
    'date': writeDate(date),
    'present': present,
    'note': note,
  };

  factory AttendanceRecord.fromJson(Map<String, dynamic> j) => AttendanceRecord(
    id: readString(j['id']),
    subjectId: readString(j['subjectId']),
    sessionId: readNullableString(j['sessionId']),
    type: enumByName(SessionType.values, j['type'], SessionType.lecture),
    date: readDate(j['date']) ?? DateTime.now(),
    present: readBool(j['present'], true),
    note: readString(j['note']),
  );
}
