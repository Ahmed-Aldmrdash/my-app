import 'dart:convert';

import '../models/models.dart';
import 'app_store.dart';

/// Fills the app with a realistic sample semester so the student can try
/// every screen before entering their own data. Keeps the current settings.
Future<void> loadDemoData(AppStore store, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  DateTime day(int offset, [int hour = 0, int minute = 0]) =>
      DateTime(today.year, today.month, today.day + offset, hour, minute);

  const prog = Subject(
    id: 'demo-prog',
    name: 'برمجة 2',
    code: 'CS201',
    instructor: 'د. محمد علي',
    assistant: 'م. سارة',
    colorValue: 0xFF1E88E5,
    totalMarks: 100,
    finalExamMarks: 60,
  );
  const db = Subject(
    id: 'demo-db',
    name: 'قواعد البيانات',
    code: 'IS211',
    instructor: 'د. هبة حسن',
    colorValue: 0xFF00897B,
    totalMarks: 100,
    finalExamMarks: 50,
  );
  const math = Subject(
    id: 'demo-math',
    name: 'رياضيات 3',
    code: 'MA203',
    instructor: 'د. أحمد سمير',
    colorValue: 0xFFF4511E,
    totalMarks: 150,
    finalExamMarks: 100,
  );
  const se = Subject(
    id: 'demo-se',
    name: 'هندسة البرمجيات',
    code: 'CS251',
    instructor: 'د. منى إبراهيم',
    colorValue: 0xFF8E24AA,
    totalMarks: 100,
    finalExamMarks: 60,
  );
  final subjects = [prog, db, math, se];

  int m(int h, [int min = 0]) => h * 60 + min;
  final sessions = [
    ClassSession(
      id: 'demo-s1',
      subjectId: prog.id,
      weekday: DateTime.saturday,
      startMinute: m(9),
      endMinute: m(11),
      location: 'مدرج 1',
    ),
    ClassSession(
      id: 'demo-s2',
      subjectId: prog.id,
      weekday: DateTime.monday,
      startMinute: m(12),
      endMinute: m(14),
      type: SessionType.lab,
      location: 'لاب 3',
    ),
    ClassSession(
      id: 'demo-s3',
      subjectId: db.id,
      weekday: DateTime.sunday,
      startMinute: m(10),
      endMinute: m(12),
      location: 'مدرج 2',
    ),
    ClassSession(
      id: 'demo-s4',
      subjectId: db.id,
      weekday: DateTime.tuesday,
      startMinute: m(13),
      endMinute: m(14, 30),
      type: SessionType.section,
      location: 'قاعة 105',
    ),
    ClassSession(
      id: 'demo-s5',
      subjectId: math.id,
      weekday: DateTime.saturday,
      startMinute: m(12),
      endMinute: m(14),
      location: 'مدرج 3',
    ),
    ClassSession(
      id: 'demo-s6',
      subjectId: math.id,
      weekday: DateTime.wednesday,
      startMinute: m(9),
      endMinute: m(10, 30),
      type: SessionType.section,
      location: 'قاعة 201',
    ),
    ClassSession(
      id: 'demo-s7',
      subjectId: se.id,
      weekday: DateTime.monday,
      startMinute: m(9),
      endMinute: m(11),
      location: 'مدرج 1',
    ),
    ClassSession(
      id: 'demo-s8',
      subjectId: se.id,
      weekday: now.weekday,
      startMinute: m(15),
      endMinute: m(16, 30),
      type: SessionType.section,
      location: 'قاعة 110',
    ),
  ];

  final studyItems = <StudyItem>[];
  void lectures(Subject s, List<StudyStatus> statuses) {
    for (var i = 0; i < statuses.length; i++) {
      studyItems.add(
        StudyItem(
          id: 'demo-l-${s.id}-$i',
          subjectId: s.id,
          title: 'محاضرة ${i + 1}',
          number: i + 1,
          releaseDate: day(-7 * (statuses.length - i)),
          status: statuses[i],
        ),
      );
    }
  }

  const done = StudyStatus.studied;
  const revised = StudyStatus.revised;
  const todo = StudyStatus.notStarted;
  const doing = StudyStatus.inProgress;
  lectures(prog, [revised, done, done, doing, todo]);
  lectures(db, [done, done, todo, todo]);
  lectures(math, [done, doing, todo, todo, todo]);
  lectures(se, [revised, revised, done]);
  studyItems.add(
    StudyItem(
      id: 'demo-sec-1',
      subjectId: db.id,
      kind: StudyKind.section,
      title: 'سكشن SQL Joins',
      number: 3,
      releaseDate: day(-2),
    ),
  );

  final assessments = [
    Assessment(
      id: 'demo-a1',
      subjectId: prog.id,
      title: 'كويز 2',
      dueDate: day(2, 9),
      location: 'مدرج 1',
    ),
    Assessment(
      id: 'demo-a2',
      subjectId: db.id,
      type: AssessmentType.assignment,
      title: 'ERD لمكتبة',
      dueDate: day(4, 23, 59),
    ),
    Assessment(
      id: 'demo-a3',
      subjectId: math.id,
      type: AssessmentType.exam,
      title: 'ميدترم',
      dueDate: day(12, 10),
      location: 'مدرج 3',
    ),
    Assessment(
      id: 'demo-a4',
      subjectId: prog.id,
      title: 'كويز 1',
      dueDate: day(-12, 9),
      done: true,
      completedAt: day(-12, 10),
      gradeId: 'demo-g1',
    ),
    Assessment(
      id: 'demo-a5',
      subjectId: se.id,
      type: AssessmentType.assignment,
      title: 'SRS Document',
      dueDate: day(-1, 23, 59),
    ),
  ];

  final grades = [
    GradeEntry(
      id: 'demo-g1',
      subjectId: prog.id,
      title: 'كويز 1',
      category: GradeCategory.quiz,
      score: 8.5,
      maxScore: 10,
      date: day(-12),
      assessmentId: 'demo-a4',
    ),
    GradeEntry(
      id: 'demo-g2',
      subjectId: prog.id,
      title: 'أسايمنت 1',
      category: GradeCategory.assignment,
      score: 5,
      maxScore: 5,
      date: day(-9),
    ),
    GradeEntry(
      id: 'demo-g3',
      subjectId: prog.id,
      title: 'حل سؤال في المحاضرة',
      category: GradeCategory.attendance,
      score: 1,
      maxScore: 0,
      date: day(-5),
      isBonus: true,
    ),
    GradeEntry(
      id: 'demo-g4',
      subjectId: db.id,
      title: 'كويز 1',
      category: GradeCategory.quiz,
      score: 6,
      maxScore: 10,
      date: day(-10),
    ),
    GradeEntry(
      id: 'demo-g5',
      subjectId: db.id,
      title: 'حضور السكاشن',
      category: GradeCategory.attendance,
      score: 4,
      maxScore: 5,
      date: day(-3),
    ),
    GradeEntry(
      id: 'demo-g6',
      subjectId: math.id,
      title: 'كويز 1',
      category: GradeCategory.quiz,
      score: 12,
      maxScore: 15,
      date: day(-8),
    ),
    GradeEntry(
      id: 'demo-g7',
      subjectId: se.id,
      title: 'برزنتيشن',
      category: GradeCategory.oral,
      score: 9,
      maxScore: 10,
      date: day(-6),
    ),
  ];

  final tasks = [
    TaskItem(
      id: 'demo-t1',
      title: 'أطبع ملزمة الرياضيات',
      dueDate: day(1, 18),
      priority: Priority.medium,
      subjectId: math.id,
    ),
    TaskItem(
      id: 'demo-t2',
      title: 'أحل شيت 3 برمجة',
      dueDate: day(0, 22),
      priority: Priority.high,
      subjectId: prog.id,
    ),
    TaskItem(
      id: 'demo-t3',
      title: 'أسجل في الكورس الصيفي',
      priority: Priority.low,
    ),
    TaskItem(
      id: 'demo-t4',
      title: 'أبعت الأسايمنت للمعيد',
      done: true,
      completedAt: day(-1),
      priority: Priority.high,
    ),
  ];

  final projects = [
    Project(
      id: 'demo-p1',
      title: 'مشروع إدارة مكتبة',
      subjectId: se.id,
      description: 'تطبيق موبايل لإدارة استعارة الكتب',
      team: 'أنا، محمود، ندى',
      deadline: day(20, 23, 59),
      steps: const [
        ProjectStep(id: 'demo-ps1', title: 'تحديد المتطلبات', done: true),
        ProjectStep(id: 'demo-ps2', title: 'تصميم الـ UI', done: true),
        ProjectStep(id: 'demo-ps3', title: 'الداتابيز'),
        ProjectStep(id: 'demo-ps4', title: 'البرمجة'),
        ProjectStep(id: 'demo-ps5', title: 'التيست والتسليم'),
      ],
    ),
    Project(
      id: 'demo-p2',
      title: 'بروجكت SQL',
      subjectId: db.id,
      deadline: day(9, 23, 59),
      manualProgress: 30,
    ),
  ];

  final data = {
    'version': AppStore.dataVersion,
    'subjects': subjects.map((e) => e.toJson()).toList(),
    'sessions': sessions.map((e) => e.toJson()).toList(),
    'studyItems': studyItems.map((e) => e.toJson()).toList(),
    'tasks': tasks.map((e) => e.toJson()).toList(),
    'assessments': assessments.map((e) => e.toJson()).toList(),
    'projects': projects.map((e) => e.toJson()).toList(),
    'grades': grades.map((e) => e.toJson()).toList(),
    'settings': store.settings.toJson(),
  };
  return store.importJson(jsonEncode(data));
}
