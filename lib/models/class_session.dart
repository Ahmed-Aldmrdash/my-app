import '../utils/json.dart';

enum SessionType { lecture, section, lab }

/// A weekly recurring slot in the timetable (محاضرة / سكشن / لاب).
class ClassSession {
  const ClassSession({
    required this.id,
    required this.subjectId,
    required this.weekday,
    required this.startMinute,
    required this.endMinute,
    this.type = SessionType.lecture,
    this.location = '',
    this.instructor = '',
    this.notify = true,
    this.reminderMinutes = 15,
  });

  final String id;
  final String subjectId;
  final SessionType type;

  /// [DateTime.monday] .. [DateTime.sunday].
  final int weekday;

  /// Minutes since midnight.
  final int startMinute;
  final int endMinute;
  final String location;
  final String instructor;
  final bool notify;

  /// How long before the start to remind. 0 means at the start time.
  final int reminderMinutes;

  ClassSession copyWith({bool? notify, int? reminderMinutes}) => ClassSession(
    id: id,
    subjectId: subjectId,
    weekday: weekday,
    startMinute: startMinute,
    endMinute: endMinute,
    type: type,
    location: location,
    instructor: instructor,
    notify: notify ?? this.notify,
    reminderMinutes: reminderMinutes ?? this.reminderMinutes,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'subjectId': subjectId,
    'type': type.name,
    'weekday': weekday,
    'start': startMinute,
    'end': endMinute,
    'location': location,
    'instructor': instructor,
    'notify': notify,
    'reminder': reminderMinutes,
  };

  factory ClassSession.fromJson(Map<String, dynamic> j) => ClassSession(
    id: readString(j['id']),
    subjectId: readString(j['subjectId']),
    type: enumByName(SessionType.values, j['type'], SessionType.lecture),
    weekday: readInt(j['weekday'], DateTime.saturday).clamp(1, 7),
    startMinute: readInt(j['start']).clamp(0, 24 * 60 - 1),
    endMinute: readInt(j['end']).clamp(0, 24 * 60 - 1),
    location: readString(j['location']),
    instructor: readString(j['instructor']),
    notify: readBool(j['notify'], true),
    reminderMinutes: readInt(j['reminder'], 15),
  );
}
