import 'dart:math';

import '../models/models.dart';

/// A named grade band (تقدير) and the minimum percentage to get it.
class GradeBand {
  const GradeBand(this.label, this.minPercent);
  final String label;
  final double minPercent;
}

/// The common Egyptian university scale, highest first.
const gradeBands = <GradeBand>[
  GradeBand('ممتاز', 85),
  GradeBand('جيد جداً', 75),
  GradeBand('جيد', 65),
  GradeBand('مقبول', 50),
];

String gradeLabel(double percent) {
  for (final band in gradeBands) {
    if (percent >= band.minPercent) return band.label;
  }
  return 'ضعيف';
}

class CategoryTotal {
  CategoryTotal(this.category);
  final GradeCategory category;
  double score = 0;
  double max = 0;
  int count = 0;
}

/// Everything about one subject's marks so far.
class SubjectGradeSummary {
  SubjectGradeSummary(this.subject, List<GradeEntry> entries)
    : entries = List.unmodifiable(entries) {
    for (final e in entries) {
      earned += e.score;
      if (e.isBonus) {
        bonus += e.score;
      } else {
        attemptedMax += e.maxScore;
        final c = byCategory.putIfAbsent(
          e.category,
          () => CategoryTotal(e.category),
        );
        c.score += e.score;
        c.max += e.maxScore;
        c.count++;
      }
    }
  }

  final Subject subject;
  final List<GradeEntry> entries;
  final Map<GradeCategory, CategoryTotal> byCategory = {};

  /// Everything earned, bonus included.
  double earned = 0;
  double bonus = 0;

  /// The sum of "out of" of every non-bonus mark recorded so far.
  double attemptedMax = 0;

  double get total => subject.totalMarks;
  bool get hasGrades => entries.isNotEmpty;

  /// How well it is going: earned out of what was attempted, in percent.
  double? get percentSoFar =>
      attemptedMax > 0 ? earned / attemptedMax * 100 : null;

  /// Marks not yet graded (usually the final exam plus the rest of the
  /// coursework).
  double get remaining => max(0, total - attemptedMax);

  /// Extra marks needed out of [remaining] to finish the course with at
  /// least [percent] of [total]. Zero or less means already secured.
  double neededFor(double percent) => percent / 100 * total - earned;

  bool canReach(double percent) => neededFor(percent) <= remaining + 1e-9;
}

/// Plain average of the subjects' current percentages.
double? overallPercent(Iterable<SubjectGradeSummary> summaries) {
  final values = summaries
      .map((s) => s.percentSoFar)
      .whereType<double>()
      .toList();
  if (values.isEmpty) return null;
  return values.reduce((a, b) => a + b) / values.length;
}
