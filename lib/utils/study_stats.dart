import '../models/models.dart';
import 'formatters.dart';

/// Totals and streaks computed from the logged study sessions.
class StudyStats {
  StudyStats(Iterable<StudySession> sessions, this.now) {
    for (final s in sessions) {
      final day = dateOnly(s.startedAt);
      _byDay[day] = (_byDay[day] ?? 0) + s.minutes;
      total += s.minutes;
    }
  }

  final DateTime now;
  final Map<DateTime, int> _byDay = {};
  int total = 0;

  int minutesOn(DateTime day) => _byDay[dateOnly(day)] ?? 0;

  int get today => minutesOn(now);

  /// The last [days] days ending today, oldest first.
  List<(DateTime, int)> lastDays(int days) {
    final today = dateOnly(now);
    return [
      for (var i = days - 1; i >= 0; i--)
        () {
          final d = DateTime(today.year, today.month, today.day - i);
          return (d, minutesOn(d));
        }(),
    ];
  }

  int get lastSevenDays => lastDays(7).fold(0, (sum, e) => sum + e.$2);

  /// Consecutive days with some study, ending today (or yesterday, so the
  /// streak is not lost before today's first session).
  int get streak {
    var day = dateOnly(now);
    if (minutesOn(day) == 0) day = DateTime(day.year, day.month, day.day - 1);
    var count = 0;
    while (minutesOn(day) > 0) {
      count++;
      day = DateTime(day.year, day.month, day.day - 1);
    }
    return count;
  }

  /// Days in a row the daily [goal] was reached, same rule as [streak].
  int goalStreak(int goal) {
    var day = dateOnly(now);
    if (minutesOn(day) < goal) day = DateTime(day.year, day.month, day.day - 1);
    var count = 0;
    while (minutesOn(day) >= goal) {
      count++;
      day = DateTime(day.year, day.month, day.day - 1);
    }
    return count;
  }
}

/// Minutes studied per subject id (null = no subject) since [since].
Map<String?, int> minutesBySubject(
  Iterable<StudySession> sessions,
  DateTime since,
) {
  final out = <String?, int>{};
  for (final s in sessions) {
    if (s.startedAt.isBefore(since)) continue;
    out[s.subjectId] = (out[s.subjectId] ?? 0) + s.minutes;
  }
  return out;
}

/// "ساعتين و10 دقايق" style text for a number of minutes; "0 دقيقة" for 0.
String studyTimeText(int minutes) {
  if (minutes <= 0) return '0 دقيقة';
  return durationText(Duration(minutes: minutes));
}

/// Compact study time: "45د", "2س", "8س 20د".
String hoursMinutes(int minutes) {
  if (minutes < 60) return '$minutes د';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '$h س' : '$h س $m د';
}
