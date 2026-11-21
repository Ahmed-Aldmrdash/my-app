import '../models/models.dart';
import 'labels.dart';

/// Builds a finals study plan from [today] until the last exam.
///
/// For every upcoming exam it lines up: the subject's lectures not studied
/// yet, a review of the ones already studied, and solving past exams; the
/// day before the exam is a final review. A subject with two finals
/// (written and practical) gets its lectures planned once, for the first.
/// Each day gets about [perDay] entries, giving more of them to the exams
/// with the most left to do per day remaining. Whatever doesn't fit lands
/// on the day before the exam.
///
/// The same thing to do always gets the same id, so planning again (here
/// or on another device) doesn't duplicate it. Tests may pass [makeId].
List<PlanEntry> generateStudyPlan({
  required DateTime today,
  required Iterable<FinalExam> exams,
  required Iterable<StudyItem> studyItems,
  required String Function(String subjectId) subjectName,
  int perDay = 4,
  String Function()? makeId,
}) {
  final start = DateTime(today.year, today.month, today.day);
  final upcoming = [
    for (final e in exams)
      if (e.day.isAfter(start)) e,
  ]..sort((a, b) => a.start.compareTo(b.start));
  if (upcoming.isEmpty) return const [];
  final capacity = perDay.clamp(1, 20);

  PlanEntry make(
    FinalExam exam,
    DateTime day,
    PlanKind kind,
    String title, [
    String? studyItemId,
  ]) => PlanEntry(
    id:
        makeId?.call() ??
        'auto-${exam.id}-${kind.name}-${studyItemId ?? _stableHash(title)}',
    day: day,
    title: title,
    kind: kind,
    subjectId: exam.subjectId,
    examId: exam.id,
    studyItemId: studyItemId,
    auto: true,
  );

  // What each exam needs, in order.
  final queues = <String, List<PlanEntry Function(DateTime day)>>{};
  final planned = <String>{};
  for (final exam in upcoming) {
    final queue = <PlanEntry Function(DateTime)>[];
    queues[exam.id] = queue;
    if (!planned.add(exam.subjectId)) continue;
    final name = subjectName(exam.subjectId);
    final items =
        studyItems.where((s) => s.subjectId == exam.subjectId).toList()
          ..sort((a, b) {
            final byDate = a.releaseDate.compareTo(b.releaseDate);
            return byDate != 0
                ? byDate
                : (a.number ?? 0).compareTo(b.number ?? 0);
          });
    void add(PlanKind kind, String title, [String? studyItemId]) =>
        queue.add((day) => make(exam, day, kind, title, studyItemId));

    for (final s in items.where((s) => !s.status.isDone)) {
      add(PlanKind.study, 'ذاكر ${_itemName(s)}', s.id);
    }
    final studied = items.where((s) => s.status.isDone).toList();
    // Reviews go in pairs so a subject with many lectures doesn't flood
    // the plan.
    for (var i = 0; i < studied.length; i += 2) {
      final pair = studied.skip(i).take(2).map(_itemName).join(' و');
      add(PlanKind.review, 'راجع $pair', studied[i].id);
    }
    if (items.isEmpty) {
      for (var part = 1; part <= 3; part++) {
        add(PlanKind.study, 'ذاكر $name (جزء $part)');
      }
    }
    add(PlanKind.practice, 'حل امتحانات سابقة في $name');
  }

  final out = <PlanEntry>[];
  final last = upcoming.last.day;
  for (
    var day = start;
    day.isBefore(last);
    day = DateTime(day.year, day.month, day.day + 1)
  ) {
    var free = capacity;
    // The day before an exam: what's left of it, then its final review.
    for (final exam in upcoming) {
      if (!_isDayBefore(day, exam.day)) continue;
      final queue = queues[exam.id]!;
      for (final makeEntry in queue) {
        out.add(makeEntry(day));
        free--;
      }
      queue.clear();
      out.add(
        make(
          exam,
          day,
          PlanKind.finalReview,
          'مراجعة نهائية ${subjectName(exam.subjectId)}',
        ),
      );
      free--;
    }
    while (free > 0) {
      FinalExam? pick;
      var pressure = 0.0;
      for (final exam in upcoming) {
        final left = queues[exam.id]!.length;
        if (left == 0 || !exam.day.isAfter(day)) continue;
        // Days to work on it, not counting the final-review day.
        final days = _daysBetween(day, exam.day) - 1;
        final p = left / (days < 1 ? 1 : days);
        if (p > pressure) {
          pressure = p;
          pick = exam;
        }
      }
      if (pick == null) break;
      out.add(queues[pick.id]!.removeAt(0)(day));
      free--;
    }
  }
  return out;
}

/// A hash of [s] that is the same on every platform and run (unlike
/// [String.hashCode]), for ids derived from text.
String _stableHash(String s) {
  var h = 0x811c9dc5;
  for (final unit in s.codeUnits) {
    h = (h ^ unit) & 0xffffffff;
    // h * 16777619 (the FNV prime, 2^24 + 403) in pieces that stay exact
    // in JavaScript numbers too.
    h = (((h & 0xff) << 24) + h * 403) & 0xffffffff;
  }
  return h.toRadixString(36);
}

/// Whole days from [a] to [b], unaffected by daylight-saving shifts.
int _daysBetween(DateTime a, DateTime b) => DateTime.utc(
  b.year,
  b.month,
  b.day,
).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

bool _isDayBefore(DateTime day, DateTime examDay) =>
    DateTime(examDay.year, examDay.month, examDay.day - 1) == day;

String _itemName(StudyItem s) {
  final label = s.number == null ? s.kind.label : '${s.kind.label} ${s.number}';
  final title = s.title.trim();
  return title.isEmpty || title == label ? label : '$label: $title';
}
