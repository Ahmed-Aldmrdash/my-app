import '../utils/json.dart';

/// A final exam (امتحان فاينال) of a subject.
class FinalExam {
  const FinalExam({
    required this.id,
    required this.subjectId,
    required this.start,
    this.durationMinutes = 120,
    this.place = '',
    this.seat = '',
    this.notes = '',
    this.reminders = const [24 * 60, 3 * 60],
  });

  final String id;
  final String subjectId;

  /// When the exam starts.
  final DateTime start;
  final int durationMinutes;

  /// The hall or building (اللجنة / المدرج).
  final String place;

  /// Seat number (رقم الجلوس).
  final String seat;
  final String notes;

  /// Minutes before [start] to remind.
  final List<int> reminders;

  DateTime get end => start.add(Duration(minutes: durationMinutes));

  /// The calendar day of the exam.
  DateTime get day => DateTime(start.year, start.month, start.day);

  bool isOver(DateTime now) => !end.isAfter(now);

  Map<String, dynamic> toJson() => {
    'id': id,
    'subjectId': subjectId,
    'start': writeDate(start),
    'durationMinutes': durationMinutes,
    'place': place,
    'seat': seat,
    'notes': notes,
    'reminders': reminders,
  };

  factory FinalExam.fromJson(Map<String, dynamic> j) => FinalExam(
    id: readString(j['id']),
    subjectId: readString(j['subjectId']),
    start: readDate(j['start']) ?? DateTime.now(),
    durationMinutes: readInt(j['durationMinutes'], 120).clamp(0, 24 * 60),
    place: readString(j['place']),
    seat: readString(j['seat']),
    notes: readString(j['notes']),
    reminders: readIntList(j['reminders'], const [24 * 60, 3 * 60]),
  );
}
