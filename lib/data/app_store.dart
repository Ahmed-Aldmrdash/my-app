import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../utils/grade_calculator.dart';
import '../utils/ids.dart';
import '../utils/json.dart';
import 'storage.dart';

/// Holds all of the student's data, persists it after every change and
/// notifies the UI.
class AppStore extends ChangeNotifier {
  AppStore(this._storage);

  static const dataVersion = 1;

  final Storage _storage;

  final List<Subject> _subjects = [];
  final List<ClassSession> _sessions = [];
  final List<StudyItem> _studyItems = [];
  final List<TaskItem> _tasks = [];
  final List<Assessment> _assessments = [];
  final List<Project> _projects = [];
  final List<GradeEntry> _grades = [];
  AppSettings _settings = const AppSettings();
  Map<String, Subject> _subjectIndex = {};

  UnmodifiableListView<Subject> get subjects => UnmodifiableListView(_subjects);
  UnmodifiableListView<ClassSession> get sessions =>
      UnmodifiableListView(_sessions);
  UnmodifiableListView<StudyItem> get studyItems =>
      UnmodifiableListView(_studyItems);
  UnmodifiableListView<TaskItem> get tasks => UnmodifiableListView(_tasks);
  UnmodifiableListView<Assessment> get assessments =>
      UnmodifiableListView(_assessments);
  UnmodifiableListView<Project> get projects => UnmodifiableListView(_projects);
  UnmodifiableListView<GradeEntry> get grades => UnmodifiableListView(_grades);
  AppSettings get settings => _settings;

  bool get isEmpty =>
      _subjects.isEmpty &&
      _tasks.isEmpty &&
      _projects.isEmpty &&
      _sessions.isEmpty;

  // ---------------------------------------------------------------------------
  // Persistence

  Future<void> load() async {
    String? raw;
    try {
      raw = await _storage.read();
    } catch (e) {
      debugPrint('Could not read saved data: $e');
    }
    if (raw != null && raw.isNotEmpty) {
      try {
        _applyJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (e) {
        debugPrint('Saved data is unreadable, starting fresh: $e');
      }
    }
    _reindex();
    notifyListeners();
  }

  Map<String, dynamic> toJson() => {
    'version': dataVersion,
    'subjects': _subjects.map((e) => e.toJson()).toList(),
    'sessions': _sessions.map((e) => e.toJson()).toList(),
    'studyItems': _studyItems.map((e) => e.toJson()).toList(),
    'tasks': _tasks.map((e) => e.toJson()).toList(),
    'assessments': _assessments.map((e) => e.toJson()).toList(),
    'projects': _projects.map((e) => e.toJson()).toList(),
    'grades': _grades.map((e) => e.toJson()).toList(),
    'settings': _settings.toJson(),
  };

  String exportJson() => const JsonEncoder.withIndent(' ').convert(toJson());

  /// Replaces everything with a previously exported backup.
  /// Throws [FormatException] when [raw] is not a backup.
  Future<void> importJson(String raw) async {
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      throw const FormatException('النص ده مش نسخة احتياطية صحيحة');
    }
    if (decoded is! Map<String, dynamic> || !decoded.containsKey('subjects')) {
      throw const FormatException('النص ده مش نسخة احتياطية صحيحة');
    }
    _applyJson(decoded);
    await _changed();
  }

  void _applyJson(Map<String, dynamic> j) {
    _subjects
      ..clear()
      ..addAll(readList(j['subjects'], Subject.fromJson));
    _sessions
      ..clear()
      ..addAll(readList(j['sessions'], ClassSession.fromJson));
    _studyItems
      ..clear()
      ..addAll(readList(j['studyItems'], StudyItem.fromJson));
    _tasks
      ..clear()
      ..addAll(readList(j['tasks'], TaskItem.fromJson));
    _assessments
      ..clear()
      ..addAll(readList(j['assessments'], Assessment.fromJson));
    _projects
      ..clear()
      ..addAll(readList(j['projects'], Project.fromJson));
    _grades
      ..clear()
      ..addAll(readList(j['grades'], GradeEntry.fromJson));
    final s = j['settings'];
    _settings = s is Map
        ? AppSettings.fromJson(Map<String, dynamic>.from(s))
        : const AppSettings();
    _reindex();
  }

  void _reindex() {
    _subjectIndex = {for (final s in _subjects) s.id: s};
  }

  Future<void> _changed() async {
    _reindex();
    notifyListeners();
    try {
      await _storage.write(jsonEncode(toJson()));
    } catch (e) {
      debugPrint('Could not save data: $e');
    }
  }

  void _upsert<T>(List<T> list, T item, String Function(T) idOf) {
    final i = list.indexWhere((e) => idOf(e) == idOf(item));
    if (i >= 0) {
      list[i] = item;
    } else {
      list.add(item);
    }
  }

  // ---------------------------------------------------------------------------
  // Queries

  Subject? subjectById(String? id) => id == null ? null : _subjectIndex[id];

  List<ClassSession> sessionsOn(int weekday) =>
      _sessions.where((s) => s.weekday == weekday).toList()
        ..sort((a, b) => a.startMinute.compareTo(b.startMinute));

  List<ClassSession> sessionsFor(String subjectId) =>
      _sessions.where((s) => s.subjectId == subjectId).toList()..sort(
        (a, b) => a.weekday == b.weekday
            ? a.startMinute.compareTo(b.startMinute)
            : _weekIndex(a.weekday).compareTo(_weekIndex(b.weekday)),
      );

  static int _weekIndex(int weekday) => (weekday - DateTime.saturday) % 7;

  List<StudyItem> studyItemsFor(String subjectId) =>
      _studyItems.where((s) => s.subjectId == subjectId).toList()
        ..sort(compareStudyItems);

  static int compareStudyItems(StudyItem a, StudyItem b) {
    final byDate = a.releaseDate.compareTo(b.releaseDate);
    if (byDate != 0) return byDate;
    return (a.number ?? 0).compareTo(b.number ?? 0);
  }

  List<GradeEntry> gradesFor(String subjectId) =>
      _grades.where((g) => g.subjectId == subjectId).toList()
        ..sort((a, b) => b.date.compareTo(a.date));

  SubjectGradeSummary gradeSummary(Subject subject) =>
      SubjectGradeSummary(subject, gradesFor(subject.id));

  List<Assessment> assessmentsFor(String subjectId) =>
      _assessments.where((a) => a.subjectId == subjectId).toList()
        ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

  List<Project> projectsFor(String subjectId) =>
      _projects.where((p) => p.subjectId == subjectId).toList();

  GradeEntry? gradeById(String? id) {
    if (id == null) return null;
    for (final g in _grades) {
      if (g.id == id) return g;
    }
    return null;
  }

  Project? projectById(String id) {
    for (final p in _projects) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// Next number to suggest for a new lecture of [kind] in [subjectId].
  int nextStudyNumber(String subjectId, StudyKind kind) {
    var maxNumber = 0;
    for (final s in _studyItems) {
      if (s.subjectId == subjectId && s.kind == kind && s.number != null) {
        if (s.number! > maxNumber) maxNumber = s.number!;
      }
    }
    return maxNumber + 1;
  }

  // ---------------------------------------------------------------------------
  // Subjects

  Future<void> saveSubject(Subject s) {
    _upsert(_subjects, s, (e) => e.id);
    return _changed();
  }

  /// Deletes the subject with its timetable, lectures, quizzes and grades.
  /// Tasks and projects are kept but detached from it.
  Future<void> deleteSubject(String id) {
    _subjects.removeWhere((e) => e.id == id);
    _sessions.removeWhere((e) => e.subjectId == id);
    _studyItems.removeWhere((e) => e.subjectId == id);
    _assessments.removeWhere((e) => e.subjectId == id);
    _grades.removeWhere((e) => e.subjectId == id);
    for (var i = 0; i < _tasks.length; i++) {
      final t = _tasks[i];
      if (t.subjectId == id) {
        _tasks[i] = TaskItem(
          id: t.id,
          title: t.title,
          notes: t.notes,
          dueDate: t.dueDate,
          priority: t.priority,
          done: t.done,
          completedAt: t.completedAt,
          reminders: t.reminders,
        );
      }
    }
    for (var i = 0; i < _projects.length; i++) {
      final p = _projects[i];
      if (p.subjectId == id) {
        _projects[i] = Project(
          id: p.id,
          title: p.title,
          description: p.description,
          team: p.team,
          deadline: p.deadline,
          steps: p.steps,
          manualProgress: p.manualProgress,
          submitted: p.submitted,
          reminders: p.reminders,
        );
      }
    }
    return _changed();
  }

  // ---------------------------------------------------------------------------
  // Timetable

  Future<void> saveSession(ClassSession s) {
    _upsert(_sessions, s, (e) => e.id);
    return _changed();
  }

  Future<void> deleteSession(String id) {
    _sessions.removeWhere((e) => e.id == id);
    return _changed();
  }

  // ---------------------------------------------------------------------------
  // Study

  Future<void> saveStudyItem(StudyItem s) {
    _upsert(_studyItems, s, (e) => e.id);
    return _changed();
  }

  Future<void> setStudyStatus(String id, StudyStatus status) {
    final i = _studyItems.indexWhere((e) => e.id == id);
    if (i < 0) return Future.value();
    _studyItems[i] = _studyItems[i].withStatus(status);
    return _changed();
  }

  Future<void> deleteStudyItem(String id) {
    _studyItems.removeWhere((e) => e.id == id);
    return _changed();
  }

  // ---------------------------------------------------------------------------
  // Tasks

  Future<void> saveTask(TaskItem t) {
    _upsert(_tasks, t, (e) => e.id);
    return _changed();
  }

  Future<void> toggleTask(String id) {
    final i = _tasks.indexWhere((e) => e.id == id);
    if (i < 0) return Future.value();
    _tasks[i] = _tasks[i].toggled();
    return _changed();
  }

  Future<void> deleteTask(String id) {
    _tasks.removeWhere((e) => e.id == id);
    return _changed();
  }

  // ---------------------------------------------------------------------------
  // Quizzes, exams & assignments

  Future<void> saveAssessment(Assessment a) {
    _upsert(_assessments, a, (e) => e.id);
    return _changed();
  }

  /// Marks an assessment done (or not), optionally recording its mark in
  /// the subject's grades.
  Future<void> completeAssessment(
    String id, {
    required bool done,
    double? score,
    double? maxScore,
    GradeCategory? category,
  }) {
    final i = _assessments.indexWhere((e) => e.id == id);
    if (i < 0) return Future.value();
    var a = _assessments[i].copyWith(done: done);
    if (done && score != null && maxScore != null) {
      final existing = gradeById(a.gradeId);
      final grade = GradeEntry(
        id: existing?.id ?? newId(),
        subjectId: a.subjectId,
        category: category ?? existing?.category ?? GradeCategory.quiz,
        title: a.title,
        score: score,
        maxScore: maxScore,
        date: existing?.date ?? DateTime.now(),
        notes: existing?.notes ?? '',
        assessmentId: a.id,
      );
      _upsert(_grades, grade, (e) => e.id);
      a = a.copyWith(gradeId: grade.id);
    }
    _assessments[i] = a;
    return _changed();
  }

  Future<void> deleteAssessment(String id) {
    _assessments.removeWhere((e) => e.id == id);
    return _changed();
  }

  // ---------------------------------------------------------------------------
  // Projects

  Future<void> saveProject(Project p) {
    _upsert(_projects, p, (e) => e.id);
    return _changed();
  }

  Future<void> deleteProject(String id) {
    _projects.removeWhere((e) => e.id == id);
    return _changed();
  }

  Future<void> updateProjectSteps(String projectId, List<ProjectStep> steps) {
    final i = _projects.indexWhere((e) => e.id == projectId);
    if (i < 0) return Future.value();
    _projects[i] = _projects[i].copyWith(steps: steps);
    return _changed();
  }

  // ---------------------------------------------------------------------------
  // Grades

  Future<void> saveGrade(GradeEntry g) {
    _upsert(_grades, g, (e) => e.id);
    return _changed();
  }

  Future<void> deleteGrade(String id) {
    _grades.removeWhere((e) => e.id == id);
    for (var i = 0; i < _assessments.length; i++) {
      final a = _assessments[i];
      if (a.gradeId == id) {
        _assessments[i] = Assessment(
          id: a.id,
          subjectId: a.subjectId,
          type: a.type,
          title: a.title,
          dueDate: a.dueDate,
          location: a.location,
          notes: a.notes,
          done: a.done,
          completedAt: a.completedAt,
          reminders: a.reminders,
        );
      }
    }
    return _changed();
  }

  // ---------------------------------------------------------------------------
  // Settings & data

  Future<void> updateSettings(AppSettings s) {
    _settings = s;
    return _changed();
  }

  /// Deletes all data but keeps the settings.
  Future<void> clearAll() {
    _subjects.clear();
    _sessions.clear();
    _studyItems.clear();
    _tasks.clear();
    _assessments.clear();
    _projects.clear();
    _grades.clear();
    return _changed();
  }
}
