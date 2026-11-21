import '../utils/json.dart';

enum CalendarKind { holiday, registration, addDrop, exams, semester, other }

/// A date on the academic calendar: a holiday, the registration period,
/// the start of exams…
class CalendarEvent {
  const CalendarEvent({
    required this.id,
    required this.title,
    required this.start,
    this.end,
    this.kind = CalendarKind.other,
    this.noClasses = false,
    this.reminders = const [24 * 60],
    this.notes = '',
  });

  final String id;
  final String title;
  final CalendarKind kind;

  /// The first day (time ignored).
  final DateTime start;

  /// The last day, for periods; null for a single day.
  final DateTime? end;

  /// No lectures on these days: the timetable and its reminders skip them.
  final bool noClasses;

  /// Minutes before [start] to remind.
  final List<int> reminders;
  final String notes;

  DateTime get firstDay => DateTime(start.year, start.month, start.day);

  DateTime get lastDay {
    final e = end ?? start;
    final d = DateTime(e.year, e.month, e.day);
    return d.isBefore(firstDay) ? firstDay : d;
  }

  /// Whether [day] falls within the event.
  bool covers(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    return !d.isBefore(firstDay) && !d.isAfter(lastDay);
  }

  bool isOver(DateTime now) =>
      DateTime(now.year, now.month, now.day).isAfter(lastDay);

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'kind': kind.name,
    'start': writeDate(firstDay),
    'end': end == null ? null : writeDate(lastDay),
    'noClasses': noClasses,
    'reminders': reminders,
    'notes': notes,
  };

  factory CalendarEvent.fromJson(Map<String, dynamic> j) => CalendarEvent(
    id: readString(j['id']),
    title: readString(j['title']),
    kind: enumByName(CalendarKind.values, j['kind'], CalendarKind.other),
    start: readDate(j['start']) ?? DateTime.now(),
    end: readDate(j['end']),
    noClasses: readBool(j['noClasses']),
    reminders: readIntList(j['reminders'], const [24 * 60]),
    notes: readString(j['notes']),
  );
}
