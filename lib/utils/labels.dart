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
    SessionType.lecture => Icons.school_rounded,
    SessionType.section => Icons.groups_rounded,
    SessionType.lab => Icons.computer_rounded,
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
    StudyStatus.notStarted => Icons.radio_button_unchecked_rounded,
    StudyStatus.inProgress => Icons.timelapse_rounded,
    StudyStatus.studied => Icons.check_circle_rounded,
    StudyStatus.revised => Icons.verified_rounded,
  };

  Color get color => switch (this) {
    StudyStatus.notStarted => const Color(0xFF9A98B0),
    StudyStatus.inProgress => const Color(0xFFF39C12),
    StudyStatus.studied => const Color(0xFF00B894),
    StudyStatus.revised => const Color(0xFF6C5CE7),
  };
}

extension PriorityLabel on Priority {
  String get label => switch (this) {
    Priority.low => 'عادية',
    Priority.medium => 'متوسطة',
    Priority.high => 'مهمة جداً',
  };

  Color get color => switch (this) {
    Priority.low => const Color(0xFF74B9FF),
    Priority.medium => const Color(0xFFF39C12),
    Priority.high => const Color(0xFFE74C3C),
  };
}

extension AssessmentTypeLabel on AssessmentType {
  String get label => switch (this) {
    AssessmentType.quiz => 'كويز',
    AssessmentType.exam => 'امتحان',
    AssessmentType.assignment => 'أسايمنت',
  };

  IconData get icon => switch (this) {
    AssessmentType.quiz => Icons.quiz_rounded,
    AssessmentType.exam => Icons.edit_note_rounded,
    AssessmentType.assignment => Icons.assignment_rounded,
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
    GradeCategory.quiz => Icons.quiz_rounded,
    GradeCategory.midterm => Icons.edit_note_rounded,
    GradeCategory.assignment => Icons.assignment_rounded,
    GradeCategory.project => Icons.rocket_launch_rounded,
    GradeCategory.practical => Icons.science_rounded,
    GradeCategory.oral => Icons.record_voice_over_rounded,
    GradeCategory.attendance => Icons.how_to_reg_rounded,
    GradeCategory.finalExam => Icons.workspace_premium_rounded,
    GradeCategory.other => Icons.star_rounded,
  };
}

/// Colors offered for subjects.
const subjectPalette = <int>[
  0xFF6C5CE7, // violet
  0xFF0984E3, // blue
  0xFF00B894, // teal
  0xFF00A8B5, // cyan
  0xFFE17055, // terracotta
  0xFFFF7675, // coral
  0xFFE84393, // magenta
  0xFFF39C12, // orange
  0xFF27AE60, // green
  0xFF8E44AD, // purple
  0xFF2C3E91, // navy
  0xFF6D4C41, // brown
  0xFF636E72, // grey
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
