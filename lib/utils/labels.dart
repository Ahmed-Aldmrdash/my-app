import 'package:flutter/material.dart';

import '../models/models.dart';

extension SessionTypeLabel on SessionType {
  String get label => switch (this) {
    SessionType.lecture => 'محاضرة',
    SessionType.section => 'سكشن',
    SessionType.lab => 'لاب',
  };

  /// "المحاضرة الجاية" / "السكشن الجاي" / "اللاب الجاي"
  String get nextLabel => switch (this) {
    SessionType.lecture => 'المحاضرة الجاية',
    SessionType.section => 'السكشن الجاي',
    SessionType.lab => 'اللاب الجاي',
  };

  IconData get icon => switch (this) {
    SessionType.lecture => Icons.school_outlined,
    SessionType.section => Icons.groups_outlined,
    SessionType.lab => Icons.computer_outlined,
  };
}

extension StudyKindLabel on StudyKind {
  String get label => switch (this) {
    StudyKind.lecture => 'محاضرة',
    StudyKind.section => 'سكشن',
    StudyKind.lab => 'لاب',
    StudyKind.chapter => 'شابتر',
    StudyKind.other => 'أخرى',
  };
}

extension StudyStatusLabel on StudyStatus {
  String get label => switch (this) {
    StudyStatus.notStarted => 'لسه',
    StudyStatus.inProgress => 'بذاكرها',
    StudyStatus.studied => 'اتذاكرت',
    StudyStatus.revised => 'راجعتها',
  };

  IconData get icon => switch (this) {
    StudyStatus.notStarted => Icons.radio_button_unchecked,
    StudyStatus.inProgress => Icons.timelapse,
    StudyStatus.studied => Icons.check_circle,
    StudyStatus.revised => Icons.verified,
  };

  Color get color => switch (this) {
    StudyStatus.notStarted => const Color(0xFF9E9E9E),
    StudyStatus.inProgress => const Color(0xFFF59E0B),
    StudyStatus.studied => const Color(0xFF22A45D),
    StudyStatus.revised => const Color(0xFF2E7DD7),
  };
}

extension PriorityLabel on Priority {
  String get label => switch (this) {
    Priority.low => 'عادية',
    Priority.medium => 'متوسطة',
    Priority.high => 'مهمة جداً',
  };

  Color get color => switch (this) {
    Priority.low => const Color(0xFF78909C),
    Priority.medium => const Color(0xFFF59E0B),
    Priority.high => const Color(0xFFE53935),
  };
}

extension AssessmentTypeLabel on AssessmentType {
  String get label => switch (this) {
    AssessmentType.quiz => 'كويز',
    AssessmentType.exam => 'امتحان',
    AssessmentType.assignment => 'أسايمنت',
  };

  IconData get icon => switch (this) {
    AssessmentType.quiz => Icons.quiz_outlined,
    AssessmentType.exam => Icons.edit_note,
    AssessmentType.assignment => Icons.assignment_outlined,
  };

  /// What "done" means for this type.
  String get doneLabel => switch (this) {
    AssessmentType.assignment => 'اتسلّم',
    _ => 'خلص',
  };

  GradeCategory get gradeCategory => switch (this) {
    AssessmentType.quiz => GradeCategory.quiz,
    AssessmentType.exam => GradeCategory.midterm,
    AssessmentType.assignment => GradeCategory.assignment,
  };
}

extension GradeCategoryLabel on GradeCategory {
  String get label => switch (this) {
    GradeCategory.quiz => 'كويز',
    GradeCategory.midterm => 'ميدترم',
    GradeCategory.assignment => 'أسايمنت',
    GradeCategory.project => 'مشروع',
    GradeCategory.practical => 'عملي',
    GradeCategory.oral => 'شفوي',
    GradeCategory.attendance => 'حضور ومشاركة',
    GradeCategory.finalExam => 'فاينل',
    GradeCategory.other => 'أخرى',
  };

  IconData get icon => switch (this) {
    GradeCategory.quiz => Icons.quiz_outlined,
    GradeCategory.midterm => Icons.edit_note,
    GradeCategory.assignment => Icons.assignment_outlined,
    GradeCategory.project => Icons.rocket_launch_outlined,
    GradeCategory.practical => Icons.science_outlined,
    GradeCategory.oral => Icons.record_voice_over_outlined,
    GradeCategory.attendance => Icons.how_to_reg_outlined,
    GradeCategory.finalExam => Icons.workspace_premium_outlined,
    GradeCategory.other => Icons.star_outline,
  };
}

/// Colors offered for subjects.
const subjectPalette = <int>[
  0xFF3F51B5,
  0xFF1E88E5,
  0xFF00897B,
  0xFF43A047,
  0xFF7CB342,
  0xFFF4511E,
  0xFFFB8C00,
  0xFFE53935,
  0xFFD81B60,
  0xFF8E24AA,
  0xFF5E35B1,
  0xFF6D4C41,
  0xFF546E7A,
];

/// Reminder choices for deadlines (minutes before).
const deadlineReminderOptions = <int>[
  0,
  15,
  60,
  3 * 60,
  24 * 60,
  2 * 24 * 60,
  3 * 24 * 60,
  7 * 24 * 60,
];

/// Reminder choices for timetable slots (minutes before).
const classReminderOptions = <int>[0, 5, 10, 15, 30, 60];
