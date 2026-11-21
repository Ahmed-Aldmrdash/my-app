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
    creditHours: 3,
    absenceLimit: 4,
  );
  const db = Subject(
    id: 'demo-db',
    name: 'قواعد البيانات',
    code: 'IS211',
    instructor: 'د. هبة حسن',
    colorValue: 0xFF00897B,
    totalMarks: 100,
    finalExamMarks: 50,
    creditHours: 3,
    absenceLimit: 3,
  );
  const math = Subject(
    id: 'demo-math',
    name: 'رياضيات 3',
    code: 'MA203',
    instructor: 'د. أحمد سمير',
    colorValue: 0xFFF4511E,
    totalMarks: 150,
    finalExamMarks: 100,
    creditHours: 4,
    absenceLimit: 5,
  );
  const se = Subject(
    id: 'demo-se',
    name: 'هندسة البرمجيات',
    code: 'CS251',
    instructor: 'د. منى إبراهيم',
    colorValue: 0xFF8E24AA,
    totalMarks: 100,
    finalExamMarks: 60,
    creditHours: 2,
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
      final released = day(-7 * (statuses.length - i));
      final status = statuses[i];
      final isLatestDone =
          status.isDone &&
          (i + 1 == statuses.length || !statuses[i + 1].isDone);
      // Older lectures already had some reviews; the most recently studied
      // one is due for its first review today.
      studyItems.add(
        StudyItem(
          id: 'demo-l-${s.id}-$i',
          subjectId: s.id,
          title: 'محاضرة ${i + 1}',
          number: i + 1,
          releaseDate: released,
          status: status,
          studiedAt: status.isDone
              ? (isLatestDone
                    ? day(-1, 20)
                    : released.add(const Duration(days: 1)))
              : null,
          reviewCount: !status.isDone || isLatestDone
              ? 0
              : (status == StudyStatus.revised ? 3 : 2),
          lastReviewedAt: !status.isDone || isLatestDone ? null : day(-2, 21),
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

  final studySessions = <StudySession>[];
  void studied(int dayOffset, Subject? s, int minutes, [int hour = 19]) {
    studySessions.add(
      StudySession(
        id: 'demo-ss-${studySessions.length}',
        subjectId: s?.id,
        startedAt: day(dayOffset, hour),
        minutes: minutes,
      ),
    );
  }

  studied(-6, prog, 60);
  studied(-5, db, 45);
  studied(-5, math, 30, 21);
  studied(-3, se, 90);
  studied(-2, prog, 50);
  studied(-2, db, 25, 21);
  studied(-1, math, 120);
  studied(-1, null, 30, 22);
  studied(0, prog, 50, 8);

  final attendance = <AttendanceRecord>[
    for (final w in [-14, -7])
      for (final session in sessions)
        AttendanceRecord(
          id: 'demo-at-${session.id}$w',
          subjectId: session.subjectId,
          sessionId: session.id,
          type: session.type,
          date: day(w + (session.weekday - now.weekday)),
          // One missed database section.
          present: !(session.id == 'demo-s4' && w == -7),
        ),
  ];

  final finals = [
    FinalExam(
      id: 'demo-fx-prog',
      subjectId: prog.id,
      start: day(24, 9),
      place: 'مدرج 3',
      seat: '1042',
    ),
    FinalExam(
      id: 'demo-fx-db',
      subjectId: db.id,
      start: day(27, 9),
      place: 'مدرج 1',
      seat: '1042',
    ),
    FinalExam(
      id: 'demo-fx-math',
      subjectId: math.id,
      start: day(31, 12),
      durationMinutes: 180,
      place: 'الصالة المغطاة',
      seat: '1042',
    ),
    FinalExam(
      id: 'demo-fx-se',
      subjectId: se.id,
      start: day(34, 9),
      place: 'مدرج 2',
      seat: '1042',
    ),
  ];

  final notes = [
    Note(
      id: 'demo-n-1',
      subjectId: db.id,
      title: 'ملخص الـ Normalization',
      body:
          '1NF: كل خانة فيها قيمة واحدة ومفيش أعمدة متكررة\n'
          '2NF: كل عمود معتمد على المفتاح كله مش جزء منه\n'
          '3NF: مفيش عمود معتمد على عمود تاني غير المفتاح',
      pinned: true,
      createdAt: day(-4, 20),
      updatedAt: day(-4, 20),
    ),
    Note(
      id: 'demo-n-2',
      kind: NoteKind.link,
      subjectId: prog.id,
      title: 'شرح الـ Recursion بالعربي',
      url: 'https://www.youtube.com/results?search_query=recursion+شرح',
      createdAt: day(-3, 18),
      updatedAt: day(-3, 18),
    ),
    Note(
      id: 'demo-n-3',
      kind: NoteKind.link,
      subjectId: math.id,
      title: 'شيتات السكشن على الدرايف',
      url: 'https://drive.google.com/',
      body: 'الدكتور قال الامتحان هيبقى شبه شيت 4 و5',
      createdAt: day(-2, 15),
      updatedAt: day(-2, 15),
    ),
  ];

  final cards = [
    for (final (i, subject, front, back) in [
      (
        1,
        prog,
        'إيه الفرق بين Stack و Queue؟',
        'Stack: آخر حاجة دخلت أول حاجة تطلع (LIFO)\n'
            'Queue: أول حاجة دخلت أول حاجة تطلع (FIFO)',
      ),
      (
        2,
        prog,
        'يعني إيه Big-O؟',
        'طريقة نوصف بيها الوقت اللي الخوارزمية بتاخده لما حجم الدخل يكبر',
      ),
      (
        3,
        db,
        'يعني إيه Primary Key؟',
        'عمود (أو أكتر) قيمته مش بتتكرر وبيميّز كل صف في الجدول',
      ),
      (
        4,
        db,
        'إمتى نستخدم LEFT JOIN؟',
        'لما تكون عايز كل صفوف الجدول الشمال حتى لو مالهاش مقابل في اليمين',
      ),
      (5, math, 'مشتقة sin(x)؟', 'cos(x)'),
    ])
      Flashcard(
        id: 'demo-fc-$i',
        subjectId: subject.id,
        front: front,
        back: back,
        createdAt: day(-5),
        // One was already reviewed and is due again today.
        dueDate: i == 3 ? day(0) : null,
        stage: i == 3 ? 1 : 0,
        reviews: i == 3 ? 1 : 0,
      ),
  ];

  const sem1 = Semester(
    id: 'demo-sem-1',
    name: 'الترم الأول 2025/2026',
    order: 1,
  );
  const sem2 = Semester(
    id: 'demo-sem-2',
    name: 'الترم التاني 2025/2026',
    order: 2,
  );
  PlanCourse course(
    String id,
    String name,
    String code,
    int hours,
    String group,
    int level, {
    Semester? done,
    double? percent,
    String? letter,
    List<String> prereqs = const [],
    Subject? current,
  }) => PlanCourse(
    id: 'demo-c-$id',
    name: name,
    code: code,
    creditHours: hours,
    group: group,
    level: level,
    semesterId: done?.id,
    percent: percent,
    letter: letter,
    prerequisites: [for (final p in prereqs) 'demo-c-$p'],
    subjectId: current?.id,
  );
  final courses = [
    course(
      'prog1',
      'برمجة 1',
      'CS101',
      3,
      'متطلبات كلية',
      1,
      done: sem1,
      percent: 88,
      letter: 'A-',
    ),
    course(
      'math1',
      'رياضيات 1',
      'MA101',
      3,
      'متطلبات كلية',
      1,
      done: sem1,
      percent: 79,
      letter: 'B',
    ),
    course(
      'eng',
      'لغة إنجليزية',
      'HU101',
      2,
      'متطلبات جامعة',
      1,
      done: sem1,
      percent: 92,
      letter: 'A',
    ),
    course(
      'ds',
      'هياكل البيانات',
      'CS102',
      3,
      'متطلبات قسم',
      1,
      done: sem2,
      percent: 84,
      letter: 'B+',
      prereqs: ['prog1'],
    ),
    course(
      'math2',
      'رياضيات 2',
      'MA102',
      3,
      'متطلبات كلية',
      1,
      done: sem2,
      percent: 71,
      letter: 'B-',
      prereqs: ['math1'],
    ),
    course(
      'prog2',
      'برمجة 2',
      'CS201',
      3,
      'متطلبات قسم',
      2,
      prereqs: ['prog1'],
      current: prog,
    ),
    course(
      'net',
      'شبكات الحاسب',
      'CS311',
      3,
      'متطلبات قسم',
      3,
      prereqs: ['ds'],
    ),
    course(
      'algo',
      'الخوارزميات',
      'CS301',
      3,
      'متطلبات قسم',
      3,
      prereqs: ['prog2', 'ds'],
    ),
    course(
      'ai',
      'الذكاء الاصطناعي',
      'CS401',
      3,
      'اختياري',
      4,
      prereqs: ['algo'],
    ),
  ];

  final contacts = [
    Contact(
      id: 'demo-ct-1',
      name: 'د. محمد علي',
      subjectIds: [prog.id],
      email: 'm.ali@university.edu.eg',
      office: 'مبنى B — دور 2 — مكتب 214',
      officeHours: const [
        WeeklySlot(weekday: DateTime.sunday, startMinute: 600, endMinute: 720),
        WeeklySlot(weekday: DateTime.tuesday, startMinute: 780, endMinute: 840),
      ],
    ),
    Contact(
      id: 'demo-ct-2',
      name: 'م. سارة',
      role: ContactRole.assistant,
      subjectIds: [prog.id],
      office: 'معمل 3',
    ),
    Contact(
      id: 'demo-ct-3',
      name: 'د. هبة حسن',
      subjectIds: [db.id],
      office: 'مبنى A — مكتب 105',
      officeHours: const [
        WeeklySlot(weekday: DateTime.monday, startMinute: 660, endMinute: 780),
      ],
    ),
    const Contact(
      id: 'demo-ct-4',
      name: 'يوسف',
      role: ContactRole.classmate,
      phone: '01000000000',
    ),
    const Contact(id: 'demo-ct-5', name: 'مريم', role: ContactRole.classmate),
  ];
  final groups = [
    StudyGroup(
      id: 'demo-gr-1',
      name: 'فريق مشروع المكتبة',
      subjectId: db.id,
      memberIds: const ['demo-ct-4', 'demo-ct-5'],
      notes: 'يوسف: الـ ERD • مريم: الـ SQL • أنا: الواجهة',
    ),
  ];

  final calendar = [
    CalendarEvent(
      id: 'demo-cal-1',
      title: 'إجازة عيد',
      kind: CalendarKind.holiday,
      start: day(10),
      end: day(12),
      noClasses: true,
    ),
    CalendarEvent(
      id: 'demo-cal-2',
      title: 'آخر يوم حذف وإضافة',
      kind: CalendarKind.addDrop,
      start: day(5),
    ),
    CalendarEvent(
      id: 'demo-cal-3',
      title: 'بداية امتحانات الفاينال',
      kind: CalendarKind.exams,
      start: day(24),
    ),
  ];

  final achievements = [
    Achievement(
      id: 'demo-ach-1',
      title: 'Flutter من الصفر',
      organization: 'منصة كورسات أونلاين',
      start: day(-90),
      end: day(-30),
      description: 'عملت تطبيق مهام كامل',
    ),
    Achievement(
      id: 'demo-ach-2',
      kind: AchievementKind.activity,
      title: 'عضو في فريق IEEE بالكلية',
      start: day(-200),
      ongoing: true,
    ),
    const Achievement(
      id: 'demo-ach-3',
      kind: AchievementKind.skill,
      title: 'Dart و Flutter و SQL',
    ),
  ];

  final applications = [
    Application(
      id: 'demo-app-1',
      title: 'تدريب صيفي في شركة برمجيات',
      kind: ApplicationKind.internship,
      deadline: day(15, 23, 59),
      requirements: const [
        ProjectStep(id: 'demo-rq-1', title: 'CV', done: true),
        ProjectStep(id: 'demo-rq-2', title: 'كشف درجات'),
        ProjectStep(id: 'demo-rq-3', title: 'جواب توصية'),
      ],
    ),
  ];

  final expenses = [
    for (final (i, d, amount, category, title) in [
      (1, 0, 40.0, ExpenseCategory.transport, 'مواصلات الكلية'),
      (2, -1, 120.0, ExpenseCategory.books, 'مذكرة رياضيات'),
      (3, -1, 75.0, ExpenseCategory.food, ''),
      (4, -3, 40.0, ExpenseCategory.transport, ''),
      (5, -6, 200.0, ExpenseCategory.phone, 'باقة النت'),
    ])
      Expense(
        id: 'demo-ex-$i',
        amount: amount,
        category: category,
        title: title,
        date: day(d),
        subjectId: category == ExpenseCategory.books ? math.id : null,
      ),
  ];

  // The current settings as saved (with any a newer app version added),
  // plus a sample semester name and graduation hours if none are set.
  final settings = {
    ...store.toJson()['settings'] as Map<String, dynamic>,
    if (store.settings.semesterName.isEmpty)
      'semesterName': 'الترم الأول 2026/2027',
    if (store.settings.graduationHours == 0) 'graduationHours': 140,
  };

  final data = {
    'version': AppStore.dataVersion,
    'subjects': subjects.map((e) => e.toJson()).toList(),
    'sessions': sessions.map((e) => e.toJson()).toList(),
    'studyItems': studyItems.map((e) => e.toJson()).toList(),
    'tasks': tasks.map((e) => e.toJson()).toList(),
    'assessments': assessments.map((e) => e.toJson()).toList(),
    'projects': projects.map((e) => e.toJson()).toList(),
    'grades': grades.map((e) => e.toJson()).toList(),
    'studySessions': studySessions.map((e) => e.toJson()).toList(),
    'attendance': attendance.map((e) => e.toJson()).toList(),
    'finals': finals.map((e) => e.toJson()).toList(),
    'notes': notes.map((e) => e.toJson()).toList(),
    'flashcards': cards.map((e) => e.toJson()).toList(),
    'semesters': [sem1.toJson(), sem2.toJson()],
    'planCourses': courses.map((e) => e.toJson()).toList(),
    'contacts': contacts.map((e) => e.toJson()).toList(),
    'groups': groups.map((e) => e.toJson()).toList(),
    'calendar': calendar.map((e) => e.toJson()).toList(),
    'achievements': achievements.map((e) => e.toJson()).toList(),
    'applications': applications.map((e) => e.toJson()).toList(),
    'expenses': expenses.map((e) => e.toJson()).toList(),
    'settings': settings,
  };
  return store.importJson(jsonEncode(data));
}
