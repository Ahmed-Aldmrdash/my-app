import '../utils/json.dart';

enum StudyKind { lecture, section, lab, chapter, other }

enum StudyStatus { notStarted, inProgress, studied, revised }

extension StudyStatusX on StudyStatus {
  bool get isDone => this == StudyStatus.studied || this == StudyStatus.revised;
}

/// Days after studying (and after each review) when a lecture should be
/// revised again — a simple spaced-repetition schedule.
const reviewIntervalsDays = <int>[1, 3, 7, 14, 30];

/// Something released that needs studying: a lecture, a section, a chapter…
class StudyItem {
  const StudyItem({
    required this.id,
    required this.subjectId,
    required this.title,
    required this.releaseDate,
    this.kind = StudyKind.lecture,
    this.number,
    this.status = StudyStatus.notStarted,
    this.notes = '',
    this.studiedAt,
    this.reviewCount = 0,
    this.lastReviewedAt,
  });

  final String id;
  final String subjectId;
  final StudyKind kind;
  final String title;
  final int? number;

  /// When the lecture was released / given (نزلت إمتى).
  final DateTime releaseDate;
  final StudyStatus status;
  final String notes;
  final DateTime? studiedAt;

  /// How many spaced reviews were done since it was studied.
  final int reviewCount;
  final DateTime? lastReviewedAt;

  /// The day the next review is due, or null when not studied yet or all
  /// reviews are done.
  DateTime? get nextReviewDate {
    if (!status.isDone) return null;
    final base = lastReviewedAt ?? studiedAt;
    if (base == null || reviewCount >= reviewIntervalsDays.length) return null;
    return DateTime(
      base.year,
      base.month,
      base.day + reviewIntervalsDays[reviewCount],
    );
  }

  bool isReviewDue(DateTime now) {
    final next = nextReviewDate;
    return next != null &&
        !next.isAfter(DateTime(now.year, now.month, now.day));
  }

  /// All planned reviews were done.
  bool get isMastered =>
      status.isDone && reviewCount >= reviewIntervalsDays.length;

  StudyItem withStatus(StudyStatus next, {DateTime? now}) {
    final at = now ?? DateTime.now();
    if (!next.isDone) {
      return _copy(status: next, studiedAt: null, reviewCount: 0);
    }
    // Picking "راجعتها" counts as a review.
    final reviewed =
        next == StudyStatus.revised && status != StudyStatus.revised;
    return _copy(
      status: next,
      studiedAt: studiedAt ?? at,
      reviewCount: reviewed ? reviewCount + 1 : reviewCount,
      lastReviewedAt: reviewed ? at : lastReviewedAt,
    );
  }

  /// Records one more spaced review.
  StudyItem reviewed({DateTime? now}) {
    final at = now ?? DateTime.now();
    return _copy(
      status: StudyStatus.revised,
      studiedAt: studiedAt ?? at,
      reviewCount: reviewCount + 1,
      lastReviewedAt: at,
    );
  }

  StudyItem _copy({
    required StudyStatus status,
    required DateTime? studiedAt,
    required int reviewCount,
    DateTime? lastReviewedAt,
  }) => StudyItem(
    id: id,
    subjectId: subjectId,
    kind: kind,
    title: title,
    number: number,
    releaseDate: releaseDate,
    status: status,
    notes: notes,
    studiedAt: studiedAt,
    reviewCount: reviewCount,
    lastReviewedAt: status.isDone ? lastReviewedAt : null,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'subjectId': subjectId,
    'kind': kind.name,
    'title': title,
    'number': number,
    'releaseDate': writeDate(releaseDate),
    'status': status.name,
    'notes': notes,
    'studiedAt': writeDate(studiedAt),
    'reviewCount': reviewCount,
    'lastReviewedAt': writeDate(lastReviewedAt),
  };

  factory StudyItem.fromJson(Map<String, dynamic> j) => StudyItem(
    id: readString(j['id']),
    subjectId: readString(j['subjectId']),
    kind: enumByName(StudyKind.values, j['kind'], StudyKind.lecture),
    title: readString(j['title']),
    number: j['number'] is num ? (j['number'] as num).toInt() : null,
    releaseDate: readDate(j['releaseDate']) ?? DateTime.now(),
    status: enumByName(StudyStatus.values, j['status'], StudyStatus.notStarted),
    notes: readString(j['notes']),
    studiedAt: readDate(j['studiedAt']),
    reviewCount: readInt(j['reviewCount']),
    lastReviewedAt: readDate(j['lastReviewedAt']),
  );
}
