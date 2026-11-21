import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../sync/sync_doc.dart';
import '../utils/academic.dart';
import '../utils/grade_calculator.dart';
import '../utils/ids.dart';
import '../utils/study_plan.dart' as planner;
import '../utils/json.dart';
import 'storage.dart';

/// Every record of the sample semester has an id starting with this.
const demoIdPrefix = 'demo-';

/// Holds all of the student's data, persists it after every change and
/// notifies the UI.
///
/// Every change is also recorded in [SyncMeta] (when each record was last
/// edited or deleted) so the data can be merged with other devices.
class AppStore extends ChangeNotifier {
  AppStore(this._storage);

  static const dataVersion = 2;

  final Storage _storage;

  final _subjectRecords = _Records<Subject>(
    'subjects',
    Subject.fromJson,
    (e) => e.toJson(),
    (e) => e.id,
  );
  final _sessionRecords = _Records<ClassSession>(
    'sessions',
    ClassSession.fromJson,
    (e) => e.toJson(),
    (e) => e.id,
  );
  final _studyItemRecords = _Records<StudyItem>(
    'studyItems',
    StudyItem.fromJson,
    (e) => e.toJson(),
    (e) => e.id,
  );
  final _taskRecords = _Records<TaskItem>(
    'tasks',
    TaskItem.fromJson,
    (e) => e.toJson(),
    (e) => e.id,
  );
  final _assessmentRecords = _Records<Assessment>(
    'assessments',
    Assessment.fromJson,
    (e) => e.toJson(),
    (e) => e.id,
  );
  final _projectRecords = _Records<Project>(
    'projects',
    Project.fromJson,
    (e) => e.toJson(),
    (e) => e.id,
  );
  final _gradeRecords = _Records<GradeEntry>(
    'grades',
    GradeEntry.fromJson,
    (e) => e.toJson(),
    (e) => e.id,
  );
  final _studySessionRecords = _Records<StudySession>(
    'studySessions',
    StudySession.fromJson,
    (e) => e.toJson(),
    (e) => e.id,
  );
  final _attendanceRecords = _Records<AttendanceRecord>(
    'attendance',
    AttendanceRecord.fromJson,
    (e) => e.toJson(),
    (e) => e.id,
  );

  final _finalRecords = _Records<FinalExam>(
    'finals',
    FinalExam.fromJson,
    (e) => e.toJson(),
    (e) => e.id,
  );
  final _planRecords = _Records<PlanEntry>(
    'planEntries',
    PlanEntry.fromJson,
    (e) => e.toJson(),
    (e) => e.id,
  );
  final _noteRecords = _Records<Note>(
    'notes',
    Note.fromJson,
    (e) => e.toJson(),
    (e) => e.id,
  );
  final _cardRecords = _Records<Flashcard>(
    'flashcards',
    Flashcard.fromJson,
    (e) => e.toJson(),
    (e) => e.id,
  );
  final _semesterRecords = _Records<Semester>(
    'semesters',
    Semester.fromJson,
    (e) => e.toJson(),
    (e) => e.id,
  );
  final _courseRecords = _Records<PlanCourse>(
    'planCourses',
    PlanCourse.fromJson,
    (e) => e.toJson(),
    (e) => e.id,
  );

  /// Every synced list this app version knows, in [syncedCollections]
  /// order.
  late final List<_Records<Object?>> _records = [
    _subjectRecords,
    _sessionRecords,
    _studyItemRecords,
    _taskRecords,
    _assessmentRecords,
    _projectRecords,
    _gradeRecords,
    _studySessionRecords,
    _attendanceRecords,
    _finalRecords,
    _planRecords,
    _noteRecords,
    _cardRecords,
    _semesterRecords,
    _courseRecords,
  ];

  List<Subject> get _subjects => _subjectRecords.items;
  List<ClassSession> get _sessions => _sessionRecords.items;
  List<StudyItem> get _studyItems => _studyItemRecords.items;
  List<TaskItem> get _tasks => _taskRecords.items;
  List<Assessment> get _assessments => _assessmentRecords.items;
  List<Project> get _projects => _projectRecords.items;
  List<GradeEntry> get _grades => _gradeRecords.items;
  List<StudySession> get _studySessions => _studySessionRecords.items;
  List<AttendanceRecord> get _attendance => _attendanceRecords.items;
  List<FinalExam> get _finals => _finalRecords.items;
  List<PlanEntry> get _planEntries => _planRecords.items;
  List<Note> get _notes => _noteRecords.items;
  List<Flashcard> get _cards => _cardRecords.items;
  List<Semester> get _semesters => _semesterRecords.items;
  List<PlanCourse> get _courses => _courseRecords.items;

  /// Lists added by newer app versions, kept as they are so that syncing
  /// from this device never deletes them.
  final Map<String, List<Object?>> _otherCollections = {};

  /// The shared settings as last loaded or saved (without this device's own
  /// keys), and what this version made of them then. An edit only writes the
  /// settings it changed over them, so values only a newer app version
  /// understands survive.
  Map<String, dynamic> _settingsRaw = {};
  Map<String, dynamic> _settingsBase = {};

  /// The focus timer as last loaded or saved, kept for the same reason.
  Object? _focusRaw;
  FocusState? _focusLoaded;

  /// The oldest app format still allowed to save (see [minWriterFormat]).
  int _minFormat = minWriterFormat;
  FocusState? _focus;
  AppSettings _settings = const AppSettings();
  Map<String, Subject> _subjectIndex = {};

  SyncMeta _meta = SyncMeta();

  /// The last saved state of every record, to find what a change touched.
  final Map<String, Map<String, String>> _snapshot = {};
  String _settingsSnapshot = '';
  String _focusSnapshot = '';
  int _lastStamp = 0;
  final _localChanges = StreamController<void>.broadcast();

  /// Fires after a change made on this device (not one merged from sync).
  Stream<void> get localChanges => _localChanges.stream;

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
  UnmodifiableListView<StudySession> get studySessions =>
      UnmodifiableListView(_studySessions);
  UnmodifiableListView<AttendanceRecord> get attendance =>
      UnmodifiableListView(_attendance);
  UnmodifiableListView<FinalExam> get finals => UnmodifiableListView(_finals);
  UnmodifiableListView<PlanEntry> get planEntries =>
      UnmodifiableListView(_planEntries);
  UnmodifiableListView<Note> get notes => UnmodifiableListView(_notes);
  UnmodifiableListView<Flashcard> get flashcards =>
      UnmodifiableListView(_cards);
  UnmodifiableListView<Semester> get semesters =>
      UnmodifiableListView(_semesters);
  UnmodifiableListView<PlanCourse> get planCourses =>
      UnmodifiableListView(_courses);

  /// The focus timer, when one is running or paused.
  FocusState? get focus => _focus;
  AppSettings get settings => _settings;

  /// Whether there is no data at all, so replacing it loses nothing.
  bool get isEmpty =>
      _records.every((r) => r.items.isEmpty) &&
      _otherCollections.values.every((l) => l.isEmpty) &&
      _focus == null;

  /// Whether everything here is the sample semester, or was added on top of
  /// it (like a grade for a sample subject): the student was only trying
  /// the app out.
  bool get onlyDemoData {
    var any = false;
    for (final items in _collectionsJson().values) {
      for (final item in items) {
        any = true;
        final demo = item.values.any(
          (v) => v is String && v.startsWith(demoIdPrefix),
        );
        if (!demo) return false;
      }
    }
    return any;
  }

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
        final j = jsonDecode(raw) as Map<String, dynamic>;
        _applyJson(j);
        _meta = SyncMeta.fromJson(j['meta']);
      } catch (e) {
        debugPrint('Saved data is unreadable, starting fresh: $e');
      }
    }
    _reindex();
    _takeSnapshot();
    notifyListeners();
  }

  /// The names of the synced lists this app version knows.
  @visibleForTesting
  List<String> get collectionNames => [for (final r in _records) r.name];

  Map<String, List<Map<String, dynamic>>> _collectionsJson() => {
    for (final r in _records) r.name: r.toJson(),
    for (final e in _otherCollections.entries)
      e.key: [
        for (final item in e.value)
          if (item is Map) Map<String, dynamic>.from(item),
      ],
  };

  Map<String, dynamic> toJson() {
    final own = _settings.toJson();
    return {
      'version': dataVersion,
      'minFormat': _minFormat,
      ..._collectionsJson(),
      'focus': _focusJson(),
      'settings': {
        ..._syncedSettingsJson(),
        for (final k in AppSettings.localOnlyKeys) k: own[k],
      },
      'meta': _meta.toJson(),
    };
  }

  /// The data shared between devices: everything except settings that only
  /// make sense on this device.
  Map<String, dynamic> syncDoc() => {
    'v': syncFormat,
    'minFormat': _minFormat,
    ..._collectionsJson(),
    'focus': _focusJson(),
    'settings': _syncedSettingsJson(),
    'meta': _meta.toJson(),
  };

  /// The shared settings: as loaded or last saved, with only what was
  /// changed here since then written over it.
  Map<String, dynamic> _syncedSettingsJson() {
    final own = _settings.toSyncJson();
    if (_settingsRaw.isEmpty) return own;
    return overlayChanges(_settingsRaw, _settingsBase, own);
  }

  /// The focus timer, the same way.
  Object? _focusJson() {
    final raw = _focusRaw;
    if (identical(_focus, _focusLoaded)) {
      return raw is Map ? Map<String, dynamic>.from(raw) : _focus?.toJson();
    }
    final now = _focus?.toJson();
    final before = _focusLoaded?.toJson();
    if (now == null || raw is! Map || before == null) return now;
    return overlayChanges(Map<String, dynamic>.from(raw), before, now);
  }

  /// Remembers the settings just loaded from [raw] (see [_settingsRaw]).
  void _rememberSettings(Object? raw) {
    _settingsRaw = {
      if (raw is Map)
        for (final e in raw.entries)
          if (e.key is String && !AppSettings.localOnlyKeys.contains(e.key))
            e.key as String: e.value,
    };
    _settingsBase = _settings.toSyncJson();
  }

  /// After saving a change made here: what was saved becomes the base the
  /// next edit is compared with.
  void _rebase() {
    for (final r in _records) {
      r.rebase();
    }
    _settingsRaw = _syncedSettingsJson();
    _settingsBase = _settings.toSyncJson();
    _focusRaw = _focusJson();
    _focusLoaded = _focus;
  }

  /// Replaces the data with [doc], usually the result of merging with the
  /// server. Unlike local edits, this does not count as a new change.
  Future<void> applySyncDoc(Map<String, dynamic> doc) {
    final local = _settings;
    _applyJson(doc);
    final s = doc['settings'];
    _settings = s is Map
        ? local.withSynced(Map<String, dynamic>.from(s))
        : local;
    _rememberSettings(s);
    _meta = SyncMeta.fromJson(doc['meta']);
    return _changed(fromSync: true);
  }

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
    // A restored backup counts as editing everything that differs, so the
    // meta of this device is kept and the differences get stamped.
    final meta = _meta;
    _applyJson(decoded);
    _meta = meta;
    await _changed();
  }

  void _applyJson(Map<String, dynamic> j) {
    for (final r in _records) {
      r.load(j[r.name]);
    }
    final known = {for (final r in _records) r.name};
    _otherCollections
      ..clear()
      ..addAll({
        for (final e in j.entries)
          if (e.value is List &&
              !known.contains(e.key) &&
              !_notCollections.contains(e.key))
            e.key: List<Object?>.of(e.value as List),
      });
    _focusRaw = j['focus'];
    _focus = _focusLoaded = FocusState.fromJson(_focusRaw);
    final s = j['settings'];
    _settings = s is Map
        ? AppSettings.fromJson(Map<String, dynamic>.from(s))
        : const AppSettings();
    _rememberSettings(s);
    _minFormat = math.max(minWriterFormat, readInt(j['minFormat'], 1));
    _reindex();
  }

  /// Keys of the saved document that are not lists of records.
  static const _notCollections = {
    'version',
    'v',
    'minFormat',
    'focus',
    'settings',
    'meta',
  };

  void _reindex() {
    _subjectIndex = {for (final s in _subjects) s.id: s};
  }

  Future<void> _changed({bool fromSync = false}) async {
    _reindex();
    if (fromSync) {
      _takeSnapshot();
    } else {
      if (_stampChanges()) _localChanges.add(null);
      _rebase();
    }
    notifyListeners();
    try {
      await _storage.write(jsonEncode(toJson()));
    } catch (e) {
      debugPrint('Could not save data: $e');
    }
  }

  int _nextStamp() {
    final now = DateTime.now().millisecondsSinceEpoch;
    _lastStamp = now > _lastStamp ? now : _lastStamp + 1;
    return _lastStamp;
  }

  void _takeSnapshot() {
    for (final e in _collectionsJson().entries) {
      _snapshot[e.key] = {
        for (final item in e.value) readString(item['id']): jsonEncode(item),
      };
    }
    _settingsSnapshot = jsonEncode(_syncedSettingsJson());
    _focusSnapshot = jsonEncode(_focusJson());
  }

  /// Compares with the last snapshot and stamps every record that was
  /// added, edited or removed. Returns whether anything synced changed.
  bool _stampChanges() {
    var changed = false;
    int? stamp;
    int now() => stamp ??= _nextStamp();
    final collections = _collectionsJson();
    // Lists that disappeared entirely (unknown ones on "delete all") count
    // as deleting each of their records.
    for (final col in {...collections.keys, ..._snapshot.keys}) {
      final current = {
        for (final item in collections[col] ?? const <Map<String, dynamic>>[])
          readString(item['id']): jsonEncode(item),
      };
      final before = _snapshot[col] ?? const <String, String>{};
      final stamps = _meta.stamps.putIfAbsent(col, () => {});
      final tombs = _meta.tombs.putIfAbsent(col, () => {});
      current.forEach((id, encoded) {
        if (before[id] == encoded) return;
        stamps[id] = now();
        tombs.remove(id);
        changed = true;
      });
      for (final id in before.keys) {
        if (current.containsKey(id)) continue;
        tombs[id] = now();
        stamps.remove(id);
        changed = true;
      }
      _snapshot[col] = current;
    }
    final settings = jsonEncode(_syncedSettingsJson());
    if (settings != _settingsSnapshot) {
      _settingsSnapshot = settings;
      _meta.settingsAt = now();
      changed = true;
    }
    final focus = jsonEncode(_focusJson());
    if (focus != _focusSnapshot) {
      _focusSnapshot = focus;
      _meta.focusAt = now();
      changed = true;
    }
    return changed;
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

  /// Deletes the subject with its timetable, lectures, quizzes, grades,
  /// finals, notes and cards. Tasks and projects are kept but detached.
  Future<void> deleteSubject(String id) {
    _removeSubject(id);
    return _changed();
  }

  void _removeSubject(String id) {
    _subjects.removeWhere((e) => e.id == id);
    _sessions.removeWhere((e) => e.subjectId == id);
    _studyItems.removeWhere((e) => e.subjectId == id);
    _assessments.removeWhere((e) => e.subjectId == id);
    _grades.removeWhere((e) => e.subjectId == id);
    _attendance.removeWhere((e) => e.subjectId == id);
    _finals.removeWhere((e) => e.subjectId == id);
    _planEntries.removeWhere((e) => e.subjectId == id);
    _notes.removeWhere((e) => e.subjectId == id);
    _cards.removeWhere((e) => e.subjectId == id);
    for (var i = 0; i < _courses.length; i++) {
      if (_courses[i].subjectId == id) {
        _courses[i] = _courses[i].copyWith(clearSubject: true);
      }
    }
    for (var i = 0; i < _studySessions.length; i++) {
      final s = _studySessions[i];
      if (s.subjectId == id) {
        _studySessions[i] = StudySession(
          id: s.id,
          startedAt: s.startedAt,
          minutes: s.minutes,
          note: s.note,
        );
      }
    }
    if (_focus?.subjectId == id) _focus = null;
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

  /// Records one more spaced review of a lecture.
  Future<void> markReviewed(String id) {
    final i = _studyItems.indexWhere((e) => e.id == id);
    if (i < 0) return Future.value();
    _studyItems[i] = _studyItems[i].reviewed();
    return _changed();
  }

  /// Lectures whose next spaced review is due today or earlier.
  List<StudyItem> dueReviews(DateTime now) =>
      _studyItems.where((s) => s.isReviewDue(now)).toList()
        ..sort((a, b) => a.nextReviewDate!.compareTo(b.nextReviewDate!));

  /// Deletes a lecture. Its notes, cards and plan entries stay with the
  /// subject.
  Future<void> deleteStudyItem(String id) {
    _studyItems.removeWhere((e) => e.id == id);
    for (var i = 0; i < _notes.length; i++) {
      if (_notes[i].studyItemId == id) {
        _notes[i] = _notes[i].copyWith(clearStudyItem: true);
      }
    }
    for (var i = 0; i < _cards.length; i++) {
      if (_cards[i].studyItemId == id) {
        _cards[i] = _cards[i].withoutStudyItem();
      }
    }
    for (var i = 0; i < _planEntries.length; i++) {
      if (_planEntries[i].studyItemId == id) {
        _planEntries[i] = _planEntries[i].withoutStudyItem();
      }
    }
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
  // Study time & focus timer

  Future<void> saveStudySession(StudySession s) {
    _upsert(_studySessions, s, (e) => e.id);
    return _changed();
  }

  Future<void> deleteStudySession(String id) {
    _studySessions.removeWhere((e) => e.id == id);
    return _changed();
  }

  Future<void> startFocus({
    required FocusPhase phase,
    required int minutes,
    String? subjectId,
    String? studyItemId,
    DateTime? now,
  }) {
    final at = now ?? DateTime.now();
    final seconds = minutes * 60;
    _focus = FocusState(
      phase: phase,
      subjectId: subjectId,
      studyItemId: studyItemId,
      plannedSeconds: seconds,
      startedAt: at,
      endsAt: at.add(Duration(seconds: seconds)),
    );
    return _changed();
  }

  Future<void> pauseFocus([DateTime? now]) {
    final f = _focus;
    if (f == null || !f.isRunning) return Future.value();
    _focus = f.paused(now ?? DateTime.now());
    return _changed();
  }

  Future<void> resumeFocus([DateTime? now]) {
    final f = _focus;
    if (f == null || f.isRunning) return Future.value();
    _focus = f.resumed(now ?? DateTime.now());
    return _changed();
  }

  /// Stops the timer early. Focused time of a minute or more is logged.
  Future<StudySession?> stopFocus([DateTime? now]) async {
    final f = _focus;
    if (f == null) return null;
    _focus = null;
    StudySession? logged;
    if (f.phase == FocusPhase.focus) {
      final minutes = (f.elapsedSeconds(now ?? DateTime.now()) / 60).round();
      if (minutes >= 1) logged = _logFocus(f, minutes);
    }
    await _changed();
    return logged;
  }

  /// Finishes the running phase if its time is up and returns which phase
  /// finished. A finished focus phase is logged as study time.
  Future<FocusPhase?> completeFocusIfDue([DateTime? now]) async {
    final f = _focus;
    if (f == null || !f.isFinished(now ?? DateTime.now())) return null;
    _focus = null;
    if (f.phase == FocusPhase.focus) {
      _logFocus(f, (f.plannedSeconds / 60).round());
    }
    await _changed();
    return f.phase;
  }

  StudySession _logFocus(FocusState f, int minutes) {
    final session = StudySession(
      // Derived from the timer, so if two synced devices both finish the
      // same session it is still logged once.
      id: 'focus-${f.startedAt.millisecondsSinceEpoch}',
      subjectId: f.subjectId,
      studyItemId: f.studyItemId,
      startedAt: f.startedAt,
      minutes: minutes,
    );
    _studySessions.add(session);
    // Studying a lecture that was "not started" moves it to "in progress".
    final i = _studyItems.indexWhere((e) => e.id == f.studyItemId);
    if (i >= 0 && _studyItems[i].status == StudyStatus.notStarted) {
      _studyItems[i] = _studyItems[i].withStatus(StudyStatus.inProgress);
    }
    return session;
  }

  // ---------------------------------------------------------------------------
  // Attendance

  /// The attendance recorded for [sessionId] on [day], if any.
  AttendanceRecord? attendanceFor(String sessionId, DateTime day) {
    for (final a in _attendance) {
      if (a.sessionId == sessionId && _sameDay(a.date, day)) return a;
    }
    return null;
  }

  List<AttendanceRecord> attendanceOf(String subjectId) =>
      _attendance.where((a) => a.subjectId == subjectId).toList()
        ..sort((a, b) => b.date.compareTo(a.date));

  /// Marks a timetable slot on [day] as attended or missed, replacing any
  /// earlier record for it.
  Future<void> setAttendance(
    ClassSession session,
    DateTime day, {
    required bool present,
  }) {
    final existing = attendanceFor(session.id, day);
    _upsert(
      _attendance,
      AttendanceRecord(
        id: existing?.id ?? newId(),
        subjectId: session.subjectId,
        sessionId: session.id,
        type: session.type,
        date: DateTime(day.year, day.month, day.day),
        present: present,
      ),
      (e) => e.id,
    );
    return _changed();
  }

  Future<void> saveAttendance(AttendanceRecord a) {
    _upsert(_attendance, a, (e) => e.id);
    return _changed();
  }

  Future<void> deleteAttendance(String id) {
    _attendance.removeWhere((e) => e.id == id);
    return _changed();
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  // ---------------------------------------------------------------------------
  // Finals & study plan

  /// Every final exam, soonest first.
  List<FinalExam> get finalsSorted =>
      [..._finals]..sort((a, b) => a.start.compareTo(b.start));

  /// Finals not over yet, soonest first.
  List<FinalExam> upcomingFinals(DateTime now) =>
      finalsSorted.where((e) => !e.isOver(now)).toList();

  List<FinalExam> finalsFor(String subjectId) =>
      finalsSorted.where((e) => e.subjectId == subjectId).toList();

  Future<void> saveFinal(FinalExam e) {
    _upsert(_finals, e, (x) => x.id);
    return _changed();
  }

  /// Deletes an exam and the planner's unfinished entries for it.
  Future<void> deleteFinal(String id) {
    _finals.removeWhere((e) => e.id == id);
    _planEntries.removeWhere((e) => e.examId == id && e.auto && !e.done);
    return _changed();
  }

  /// The plan entries of [day], in the order they were planned.
  List<PlanEntry> planOn(DateTime day) =>
      _planEntries.where((e) => _sameDay(e.day, day)).toList();

  Future<void> savePlanEntry(PlanEntry e) {
    _upsert(_planEntries, e, (x) => x.id);
    return _changed();
  }

  Future<void> deletePlanEntry(String id) {
    _planEntries.removeWhere((e) => e.id == id);
    return _changed();
  }

  /// Ticks an entry off (or back on). Ticking off "study this lecture" also
  /// marks the lecture as studied.
  Future<void> togglePlanEntry(String id, {DateTime? now}) {
    final i = _planEntries.indexWhere((e) => e.id == id);
    if (i < 0) return Future.value();
    final entry = _planEntries[i].copyWith(done: !_planEntries[i].done);
    _planEntries[i] = entry;
    if (entry.done && entry.kind == PlanKind.study) {
      final j = _studyItems.indexWhere((s) => s.id == entry.studyItemId);
      if (j >= 0 && !_studyItems[j].status.isDone) {
        _studyItems[j] = _studyItems[j].withStatus(
          StudyStatus.studied,
          now: now,
        );
      }
    }
    return _changed();
  }

  /// Moves [entries] to [day] (e.g. the missed ones to today).
  Future<void> movePlanEntries(Iterable<PlanEntry> entries, DateTime day) {
    final ids = {for (final e in entries) e.id};
    for (var i = 0; i < _planEntries.length; i++) {
      if (ids.contains(_planEntries[i].id)) {
        _planEntries[i] = _planEntries[i].copyWith(
          day: DateTime(day.year, day.month, day.day),
        );
      }
    }
    return _changed();
  }

  /// Replaces the planner's unfinished entries with a fresh plan from
  /// today. Entries done or written by hand stay. Returns how many entries
  /// were planned.
  Future<int> regenerateStudyPlan(DateTime now) async {
    _planEntries.removeWhere((e) => e.auto && !e.done);
    // Entries already done keep their place; the same id means the same
    // thing to do, so it isn't planned again.
    final kept = {for (final e in _planEntries) e.id};
    final fresh = planner
        .generateStudyPlan(
          today: now,
          exams: _finals,
          studyItems: _studyItems,
          subjectName: (id) => subjectById(id)?.name ?? '',
          perDay: _settings.planPerDay,
        )
        .where((e) => !kept.contains(e.id))
        .toList();
    _planEntries.addAll(fresh);
    await _changed();
    return fresh.length;
  }

  // ---------------------------------------------------------------------------
  // Notes & links

  /// Notes of a subject or a lecture (or all of them), pinned first, then
  /// the most recently edited.
  List<Note> notesFor({String? subjectId, String? studyItemId}) =>
      _notes
          .where(
            (n) =>
                (subjectId == null || n.subjectId == subjectId) &&
                (studyItemId == null || n.studyItemId == studyItemId),
          )
          .toList()
        ..sort((a, b) {
          if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
          return b.updatedAt.compareTo(a.updatedAt);
        });

  Future<void> saveNote(Note n) {
    _upsert(_notes, n, (x) => x.id);
    return _changed();
  }

  Future<void> deleteNote(String id) {
    _notes.removeWhere((e) => e.id == id);
    return _changed();
  }

  // ---------------------------------------------------------------------------
  // Flashcards

  /// A subject's cards (or a lecture's), oldest first.
  List<Flashcard> cardsFor(String subjectId, {String? studyItemId}) =>
      _cards
          .where(
            (c) =>
                c.subjectId == subjectId &&
                (studyItemId == null || c.studyItemId == studyItemId),
          )
          .toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  /// Cards to review today: overdue ones first, then new ones.
  List<Flashcard> dueCards(DateTime now, {String? subjectId}) =>
      _cards
          .where(
            (c) =>
                c.isDue(now) &&
                (subjectId == null || c.subjectId == subjectId) &&
                subjectById(c.subjectId) != null,
          )
          .toList()
        ..sort((a, b) {
          if (a.isNew != b.isNew) return a.isNew ? 1 : -1;
          final byDue = (a.dueDate ?? a.createdAt).compareTo(
            b.dueDate ?? b.createdAt,
          );
          return byDue != 0 ? byDue : a.createdAt.compareTo(b.createdAt);
        });

  Future<void> saveCard(Flashcard c) {
    _upsert(_cards, c, (x) => x.id);
    return _changed();
  }

  Future<void> deleteCard(String id) {
    _cards.removeWhere((e) => e.id == id);
    return _changed();
  }

  Future<void> answerCard(String id, CardAnswer answer, DateTime now) {
    final i = _cards.indexWhere((e) => e.id == id);
    if (i < 0) return Future.value();
    _cards[i] = _cards[i].answered(answer, now);
    return _changed();
  }

  // ---------------------------------------------------------------------------
  // Semesters & study plan

  /// The archive, cumulative averages and graduation progress.
  AcademicRecord get academicRecord =>
      AcademicRecord(semesters: _semesters, courses: _courses);

  /// Subjects of the current semester: those not archived yet (a semester
  /// closed without clearing its data keeps its subjects).
  List<Subject> get currentSubjects {
    final archived = {
      for (final c in _courses)
        if (c.isFinished && c.subjectId != null) c.subjectId,
    };
    return _subjects.where((s) => !archived.contains(s.id)).toList();
  }

  Semester? semesterById(String? id) {
    for (final s in _semesters) {
      if (s.id == id) return s;
    }
    return null;
  }

  Future<void> saveSemester(Semester s) {
    _upsert(_semesters, s, (x) => x.id);
    return _changed();
  }

  /// Deletes a semester. Its courses stay in the study plan without their
  /// grades.
  Future<void> deleteSemester(String id) {
    _semesters.removeWhere((e) => e.id == id);
    for (var i = 0; i < _courses.length; i++) {
      if (_courses[i].semesterId == id) {
        _courses[i] = _courses[i].copyWith(clearResult: true);
      }
    }
    return _changed();
  }

  Future<void> saveCourse(PlanCourse c) {
    _upsert(_courses, c, (x) => x.id);
    return _changed();
  }

  /// Deletes a course and removes it from other courses' prerequisites.
  Future<void> deleteCourse(String id) {
    _courses.removeWhere((e) => e.id == id);
    for (var i = 0; i < _courses.length; i++) {
      final c = _courses[i];
      if (c.prerequisites.contains(id)) {
        _courses[i] = c.copyWith(
          prerequisites: [...c.prerequisites]..remove(id),
        );
      }
    }
    return _changed();
  }

  /// Archives the current semester as [name]: every subject becomes a
  /// finished course of the study plan with its final [results], matched to
  /// an existing course by link, code or name. With [clearData] the
  /// semester's subjects and everything about them are then removed.
  Future<Semester> closeSemester({
    required String name,
    required Map<String, ({double? percent, String? letter})> results,
    bool clearData = true,
    String nextName = '',
  }) async {
    final order = _semesters.fold(0, (m, s) => s.order > m ? s.order : m) + 1;
    final semester = Semester(
      id: newId(),
      name: name.trim().isEmpty ? 'ترم ${_semesters.length + 1}' : name.trim(),
      order: order,
    );
    _semesters.add(semester);
    final closing = currentSubjects;
    for (final subject in closing) {
      final r = results[subject.id];
      // The course it already is in the plan: linked to it, or the same
      // code or name and not passed yet (a failed course being retaken).
      var i = _courses.indexWhere(
        (c) => c.subjectId == subject.id && !c.isFinished,
      );
      if (i < 0) {
        i = _courses.indexWhere(
          (c) =>
              (!c.isFinished || !coursePassed(c)) &&
              courseMatchesSubject(c, subject),
        );
      }
      final base = i >= 0 ? _courses[i] : null;
      final course = PlanCourse(
        id: base?.id ?? newId(),
        name: subject.name,
        code: subject.code.isNotEmpty ? subject.code : (base?.code ?? ''),
        creditHours: subject.creditHours,
        group: base?.group ?? '',
        level: base?.level ?? 0,
        prerequisites: base?.prerequisites ?? const [],
        semesterId: semester.id,
        percent: r?.percent,
        letter: r?.letter,
        // Kept so the subject counts as archived if its data stays.
        subjectId: subject.id,
        notes: base?.notes ?? '',
      );
      if (i >= 0) {
        _courses[i] = course;
      } else {
        _courses.add(course);
      }
    }
    if (clearData) {
      for (final subject in closing) {
        _removeSubject(subject.id);
      }
    }
    _settings = _settings.copyWith(semesterName: nextName.trim());
    await _changed();
    return semester;
  }

  // ---------------------------------------------------------------------------
  // Settings & data

  Future<void> updateSettings(AppSettings s) {
    _settings = s;
    return _changed();
  }

  /// Deletes all data but keeps the settings.
  Future<void> clearAll() {
    for (final r in _records) {
      r.items.clear();
    }
    // Empty rather than gone, so the document still names every list its
    // deletions are recorded for.
    _otherCollections.updateAll((_, _) => []);
    _focus = _focusLoaded = null;
    _focusRaw = null;
    return _changed();
  }

  @override
  void dispose() {
    _localChanges.close();
    super.dispose();
  }
}

/// One synced list of records.
///
/// A record this device didn't edit is saved back exactly as it was loaded,
/// with any fields or values only a newer app version understands (an
/// unknown status, a field inside a project step…). An edited record keeps
/// the fields this version doesn't know, under the ones it wrote.
class _Records<T> {
  _Records(this.name, this.parse, this.encode, this.idOf);

  final String name;
  final T Function(Map<String, dynamic>) parse;
  final Map<String, dynamic> Function(T) encode;
  final String Function(T) idOf;
  final List<T> items = [];

  /// Record id -> the record as last loaded or saved, the map it was saved
  /// as, and what this version made of it. Kept after a record is deleted,
  /// so undoing the deletion restores it whole.
  final Map<
    String,
    ({T item, Map<String, dynamic> raw, Map<String, dynamic> base})
  >
  _loaded = {};

  /// Replaces the records with the saved list [raw]. A malformed record is
  /// skipped rather than losing everything.
  void load(Object? raw) {
    items.clear();
    if (raw is! List) return;
    for (final e in raw) {
      if (e is! Map) continue;
      final map = Map<String, dynamic>.from(e);
      final T item;
      try {
        item = parse(map);
      } catch (_) {
        continue;
      }
      items.add(item);
      _loaded[idOf(item)] = (item: item, raw: map, base: encode(item));
    }
  }

  /// Makes what would be saved now the base for the next edit.
  void rebase() {
    for (final item in items) {
      final loaded = _loaded[idOf(item)];
      if (loaded != null && identical(loaded.item, item)) continue;
      _loaded[idOf(item)] = (item: item, raw: _json(item), base: encode(item));
    }
  }

  List<Map<String, dynamic>> toJson() => [
    for (final item in items) _json(item),
  ];

  Map<String, dynamic> _json(T item) {
    final loaded = _loaded[idOf(item)];
    if (loaded == null) return encode(item);
    if (identical(loaded.item, item)) return Map.of(loaded.raw);
    return overlayChanges(loaded.raw, loaded.base, encode(item));
  }
}
