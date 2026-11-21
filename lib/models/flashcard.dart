import '../utils/json.dart';
import 'study_item.dart';

/// How well the student remembered a card.
enum CardAnswer { again, hard, good, easy }

/// Days between reviews of a card. Starts like the lectures' spaced review
/// ([reviewIntervalsDays]) and keeps growing for cards that stick.
const cardIntervalsDays = <int>[...reviewIntervalsDays, 60, 120];

/// A question/answer card for spaced review.
class Flashcard {
  const Flashcard({
    required this.id,
    required this.subjectId,
    required this.front,
    required this.back,
    required this.createdAt,
    this.studyItemId,
    this.stage = 0,
    this.dueDate,
    this.lastReviewedAt,
    this.reviews = 0,
    this.lapses = 0,
  });

  final String id;
  final String subjectId;

  /// The lecture it is about, if any.
  final String? studyItemId;
  final String front;
  final String back;

  /// How far along [cardIntervalsDays] the card is.
  final int stage;

  /// The day it should be reviewed next; null for a card never reviewed.
  final DateTime? dueDate;
  final DateTime? lastReviewedAt;
  final int reviews;

  /// How many times it was forgotten.
  final int lapses;
  final DateTime createdAt;

  bool get isNew => dueDate == null;

  bool isDue(DateTime now) =>
      dueDate == null ||
      !dueDate!.isAfter(DateTime(now.year, now.month, now.day));

  /// Days until the next review if answered with [a].
  int intervalFor(CardAnswer a) => switch (a) {
    CardAnswer.again => 0,
    CardAnswer.hard => 1,
    CardAnswer.good => cardIntervalsDays[_clamp(stage)],
    CardAnswer.easy => cardIntervalsDays[_clamp(stage + 1)],
  };

  static int _clamp(int s) => s.clamp(0, cardIntervalsDays.length - 1);

  /// The card after being reviewed at [now].
  Flashcard answered(CardAnswer a, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final days = intervalFor(a);
    return Flashcard(
      id: id,
      subjectId: subjectId,
      studyItemId: studyItemId,
      front: front,
      back: back,
      createdAt: createdAt,
      stage: switch (a) {
        CardAnswer.again => 0,
        CardAnswer.hard => stage,
        CardAnswer.good => _clamp(stage + 1),
        CardAnswer.easy => _clamp(stage + 2),
      },
      dueDate: DateTime(today.year, today.month, today.day + days),
      lastReviewedAt: now,
      reviews: reviews + 1,
      lapses: a == CardAnswer.again && !isNew ? lapses + 1 : lapses,
    );
  }

  Flashcard edited({
    required String subjectId,
    required String? studyItemId,
    required String front,
    required String back,
  }) => Flashcard(
    id: id,
    subjectId: subjectId,
    studyItemId: studyItemId,
    front: front,
    back: back,
    createdAt: createdAt,
    stage: stage,
    dueDate: dueDate,
    lastReviewedAt: lastReviewedAt,
    reviews: reviews,
    lapses: lapses,
  );

  /// The same card without a link to a deleted lecture.
  Flashcard withoutStudyItem() =>
      edited(subjectId: subjectId, studyItemId: null, front: front, back: back);

  Map<String, dynamic> toJson() => {
    'id': id,
    'subjectId': subjectId,
    'studyItemId': studyItemId,
    'front': front,
    'back': back,
    'stage': stage,
    'dueDate': writeDate(dueDate),
    'lastReviewedAt': writeDate(lastReviewedAt),
    'reviews': reviews,
    'lapses': lapses,
    'createdAt': writeDate(createdAt),
  };

  factory Flashcard.fromJson(Map<String, dynamic> j) => Flashcard(
    id: readString(j['id']),
    subjectId: readString(j['subjectId']),
    studyItemId: readNullableString(j['studyItemId']),
    front: readString(j['front']),
    back: readString(j['back']),
    stage: readInt(j['stage']).clamp(0, cardIntervalsDays.length - 1),
    dueDate: readDate(j['dueDate']),
    lastReviewedAt: readDate(j['lastReviewedAt']),
    reviews: readInt(j['reviews']),
    lapses: readInt(j['lapses']),
    createdAt: readDate(j['createdAt']) ?? DateTime.now(),
  );
}
