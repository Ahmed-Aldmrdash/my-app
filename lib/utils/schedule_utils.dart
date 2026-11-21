import '../models/models.dart';

/// A concrete occurrence of a weekly [ClassSession].
class ClassOccurrence {
  const ClassOccurrence(this.session, this.start, this.end);

  final ClassSession session;
  final DateTime start;
  final DateTime end;

  bool isOngoing(DateTime now) => !now.isBefore(start) && now.isBefore(end);
}

/// The class that is running now, or the next one to start, skipping the
/// days [isOff] says have no classes (holidays).
ClassOccurrence? findNextClass(
  Iterable<ClassSession> sessions,
  DateTime now, {
  bool Function(DateTime day)? isOff,
}) {
  ClassOccurrence? best;
  for (final s in sessions) {
    final dayDelta = (s.weekday - now.weekday) % 7;
    // A long holiday can skip a few weeks; give up after ten.
    for (var week = 0; week < 10; week++) {
      DateTime at(int minute) => DateTime(
        now.year,
        now.month,
        now.day + dayDelta + 7 * week,
        minute ~/ 60,
        minute % 60,
      );
      final start = at(s.startMinute);
      final end = at(s.endMinute);
      if (!end.isAfter(now) || (isOff?.call(start) ?? false)) continue;
      if (best == null || start.isBefore(best.start)) {
        best = ClassOccurrence(s, start, end);
      }
      break;
    }
  }
  return best;
}
