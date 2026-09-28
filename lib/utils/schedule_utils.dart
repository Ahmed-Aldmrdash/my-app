import '../models/models.dart';

/// A concrete occurrence of a weekly [ClassSession].
class ClassOccurrence {
  const ClassOccurrence(this.session, this.start, this.end);

  final ClassSession session;
  final DateTime start;
  final DateTime end;

  bool isOngoing(DateTime now) => !now.isBefore(start) && now.isBefore(end);
}

/// The class that is running now, or the next one to start.
ClassOccurrence? findNextClass(Iterable<ClassSession> sessions, DateTime now) {
  ClassOccurrence? best;
  for (final s in sessions) {
    final dayDelta = (s.weekday - now.weekday) % 7;
    DateTime at(int extraDays, int minute) => DateTime(
      now.year,
      now.month,
      now.day + dayDelta + extraDays,
      minute ~/ 60,
      minute % 60,
    );
    var start = at(0, s.startMinute);
    var end = at(0, s.endMinute);
    if (!end.isAfter(now)) {
      start = at(7, s.startMinute);
      end = at(7, s.endMinute);
    }
    if (best == null || start.isBefore(best.start)) {
      best = ClassOccurrence(s, start, end);
    }
  }
  return best;
}
