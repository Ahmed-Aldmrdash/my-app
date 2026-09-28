import '../utils/json.dart';

/// Time spent studying, from the focus timer or logged by hand.
class StudySession {
  const StudySession({
    required this.id,
    required this.startedAt,
    required this.minutes,
    this.subjectId,
    this.studyItemId,
    this.note = '',
  });

  final String id;
  final String? subjectId;
  final String? studyItemId;
  final DateTime startedAt;
  final int minutes;
  final String note;

  Map<String, dynamic> toJson() => {
    'id': id,
    'subjectId': subjectId,
    'studyItemId': studyItemId,
    'startedAt': writeDate(startedAt),
    'minutes': minutes,
    'note': note,
  };

  factory StudySession.fromJson(Map<String, dynamic> j) => StudySession(
    id: readString(j['id']),
    subjectId: readNullableString(j['subjectId']),
    studyItemId: readNullableString(j['studyItemId']),
    startedAt: readDate(j['startedAt']) ?? DateTime.now(),
    minutes: readInt(j['minutes']),
    note: readString(j['note']),
  );
}

enum FocusPhase { focus, rest }

/// The running (or paused) focus timer. Kept in the saved data so the
/// timer survives the app being closed.
class FocusState {
  const FocusState({
    required this.phase,
    required this.plannedSeconds,
    required this.startedAt,
    this.subjectId,
    this.studyItemId,
    this.endsAt,
    this.pausedRemaining,
  });

  final FocusPhase phase;
  final String? subjectId;
  final String? studyItemId;
  final int plannedSeconds;
  final DateTime startedAt;

  /// Set while running.
  final DateTime? endsAt;

  /// Set while paused.
  final int? pausedRemaining;

  bool get isRunning => endsAt != null;
  bool get isPaused => endsAt == null;

  int remainingSeconds(DateTime now) {
    if (endsAt != null) {
      final left = endsAt!.difference(now).inMilliseconds / 1000;
      return left <= 0 ? 0 : left.ceil();
    }
    return pausedRemaining ?? plannedSeconds;
  }

  int elapsedSeconds(DateTime now) =>
      (plannedSeconds - remainingSeconds(now)).clamp(0, plannedSeconds);

  bool isFinished(DateTime now) => isRunning && remainingSeconds(now) == 0;

  FocusState paused(DateTime now) => FocusState(
    phase: phase,
    subjectId: subjectId,
    studyItemId: studyItemId,
    plannedSeconds: plannedSeconds,
    startedAt: startedAt,
    pausedRemaining: remainingSeconds(now),
  );

  FocusState resumed(DateTime now) => FocusState(
    phase: phase,
    subjectId: subjectId,
    studyItemId: studyItemId,
    plannedSeconds: plannedSeconds,
    startedAt: startedAt,
    endsAt: now.add(Duration(seconds: remainingSeconds(now))),
  );

  Map<String, dynamic> toJson() => {
    'phase': phase.name,
    'subjectId': subjectId,
    'studyItemId': studyItemId,
    'plannedSeconds': plannedSeconds,
    'startedAt': writeDate(startedAt),
    'endsAt': writeDate(endsAt),
    'pausedRemaining': pausedRemaining,
  };

  static FocusState? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final j = Map<String, dynamic>.from(raw);
    final started = readDate(j['startedAt']);
    if (started == null) return null;
    return FocusState(
      phase: enumByName(FocusPhase.values, j['phase'], FocusPhase.focus),
      subjectId: readNullableString(j['subjectId']),
      studyItemId: readNullableString(j['studyItemId']),
      plannedSeconds: readInt(j['plannedSeconds'], 25 * 60),
      startedAt: started,
      endsAt: readDate(j['endsAt']),
      pausedRemaining: j['pausedRemaining'] is num
          ? (j['pausedRemaining'] as num).toInt()
          : null,
    );
  }
}
