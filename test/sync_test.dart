import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:study_planner/data/app_store.dart';
import 'package:study_planner/data/demo_data.dart';
import 'package:study_planner/data/storage.dart';
import 'package:study_planner/models/models.dart';
import 'package:study_planner/sync/sync_doc.dart';
import 'package:study_planner/sync/sync_engine.dart';

/// An in-memory server with optimistic versioning, like the real table.
class FakeRemote implements SyncRemote {
  Map<String, dynamic>? doc;
  int version = 0;
  int writes = 0;

  /// Runs once before the next write, to simulate another device racing.
  Future<void> Function()? beforeNextWrite;

  Future<void> _race() async {
    final f = beforeNextWrite;
    beforeNextWrite = null;
    if (f != null) await f();
  }

  @override
  Future<RemoteDoc?> fetch() async => doc == null
      ? null
      // Round-trip through JSON like the network does.
      : RemoteDoc(jsonDecode(jsonEncode(doc)) as Map<String, dynamic>, version);

  @override
  Future<int?> create(Map<String, dynamic> d) async {
    await _race();
    if (doc != null) return null;
    doc = jsonDecode(jsonEncode(d)) as Map<String, dynamic>;
    writes++;
    return version = 1;
  }

  @override
  Future<int?> replace(Map<String, dynamic> d, int expected) async {
    await _race();
    if (version != expected) return null;
    doc = jsonDecode(jsonEncode(d)) as Map<String, dynamic>;
    writes++;
    return ++version;
  }
}

Future<AppStore> device() async {
  final s = AppStore(MemoryStorage());
  await s.load();
  return s;
}

void main() {
  group('change tracking', () {
    test('edits, deletions and settings are stamped', () async {
      final s = await device();
      var events = 0;
      s.localChanges.listen((_) => events++);

      await s.saveSubject(const Subject(id: 'a', name: 'x'));
      final meta1 = SyncMeta.fromJson(s.syncDoc()['meta']);
      expect(meta1.stamps['subjects']!['a'], greaterThan(0));

      await s.saveSubject(const Subject(id: 'a', name: 'x'));
      expect(
        SyncMeta.fromJson(s.syncDoc()['meta']).stamps['subjects']!['a'],
        meta1.stamps['subjects']!['a'],
        reason: 'saving identical data is not a change',
      );

      await s.deleteSubject('a');
      final meta2 = SyncMeta.fromJson(s.syncDoc()['meta']);
      expect(meta2.stamps['subjects'], isNot(contains('a')));
      expect(meta2.tombs['subjects']!['a'], greaterThan(0));

      await s.updateSettings(s.settings.copyWith(studentName: 'أحمد'));
      expect(SyncMeta.fromJson(s.syncDoc()['meta']).settingsAt, greaterThan(0));
      await Future<void>.delayed(Duration.zero);
      expect(events, 3);
    });

    test('theme is per device and not synced', () async {
      final s = await device();
      await s.updateSettings(s.settings.copyWith(themeMode: AppThemeMode.dark));
      expect(SyncMeta.fromJson(s.syncDoc()['meta']).settingsAt, 0);
      expect(s.syncDoc()['settings'], isNot(contains('themeMode')));
    });

    test('meta survives a restart', () async {
      final storage = MemoryStorage();
      final a = AppStore(storage);
      await a.load();
      await a.saveTask(const TaskItem(id: 't', title: 'x'));
      await a.deleteTask('t');
      final b = AppStore(MemoryStorage(storage.data));
      await b.load();
      expect(
        SyncMeta.fromJson(b.syncDoc()['meta']).tombs['tasks'],
        contains('t'),
      );
      // Loading is not an edit.
      await b.saveTask(const TaskItem(id: 'u', title: 'y'));
      expect(
        SyncMeta.fromJson(b.syncDoc()['meta']).tombs['tasks'],
        contains('t'),
      );
    });
  });

  test('only sample data is recognised, even with additions', () async {
    final s = await device();
    expect(s.onlyDemoData, isFalse, reason: 'nothing at all');

    await loadDemoData(s, DateTime(2026, 9, 29));
    expect(s.onlyDemoData, isTrue);

    // A grade for a sample subject is still just trying the app out.
    await s.saveGrade(
      GradeEntry(
        id: 'g',
        subjectId: 'demo-prog',
        title: 'كويز',
        score: 8,
        maxScore: 10,
        date: DateTime(2026, 9, 29),
      ),
    );
    expect(s.onlyDemoData, isTrue);

    await s.saveSubject(const Subject(id: 'real', name: 'فيزياء'));
    expect(s.onlyDemoData, isFalse);
  });

  group('merge', () {
    Map<String, dynamic> doc(
      List<Map<String, dynamic>> tasks,
      Map<String, int> stamps, [
      Map<String, int> tombs = const {},
    ]) => {
      'tasks': tasks,
      'meta': {
        'stamps': {'tasks': stamps},
        'tombs': {'tasks': tombs},
      },
    };

    test('newer edit wins, both sides agree', () {
      final a = doc(
        [
          {'id': '1', 'title': 'old'},
        ],
        {'1': 10},
      );
      final b = doc(
        [
          {'id': '1', 'title': 'new'},
        ],
        {'1': 20},
      );
      final ab = mergeSyncDocs(a, b);
      final ba = mergeSyncDocs(b, a);
      expect((ab['tasks'] as List).single['title'], 'new');
      expect(sameSyncDoc(ab, ba), isTrue);
    });

    test('deletion wins over older edits only', () {
      final edited = doc(
        [
          {'id': '1', 'title': 'x'},
        ],
        {'1': 10},
      );
      final deleted = doc([], {}, {'1': 15});
      expect(mergeSyncDocs(edited, deleted)['tasks'], isEmpty);

      final editedLater = doc(
        [
          {'id': '1', 'title': 'x'},
        ],
        {'1': 20},
      );
      final m = mergeSyncDocs(editedLater, deleted);
      expect(m['tasks'], hasLength(1));
      expect(SyncMeta.fromJson(m['meta']).tombs['tasks'], isEmpty);
    });

    test('ties resolve the same way on both sides', () {
      final a = doc([
        {'id': '1', 'title': 'a'},
      ], {});
      final b = doc([
        {'id': '1', 'title': 'b'},
      ], {});
      expect(
        canonicalJson(mergeSyncDocs(a, b)),
        canonicalJson(mergeSyncDocs(b, a)),
      );
    });

    test('merging is idempotent', () {
      final a = doc(
        [
          {'id': '1', 'title': 'a'},
          {'id': '3', 'title': 'c'},
        ],
        {'1': 5, '3': 7},
        {'2': 9},
      );
      final b = doc(
        [
          {'id': '2', 'title': 'b'},
          {'id': '1', 'title': 'a2'},
        ],
        {'2': 3, '1': 6},
      );
      final m = mergeSyncDocs(a, b);
      expect(sameSyncDoc(mergeSyncDocs(m, b), m), isTrue);
      expect(sameSyncDoc(mergeSyncDocs(m, a), m), isTrue);
      expect((m['tasks'] as List).map((t) => t['id']), ['1', '3']);
    });
  });

  group('two devices', () {
    test('changes flow both ways and converge', () async {
      final server = FakeRemote();
      final phone = await device();
      final pc = await device();
      final phoneSync = SyncEngine(phone, server);
      final pcSync = SyncEngine(pc, server);

      await phone.saveSubject(const Subject(id: 's1', name: 'برمجة'));
      await phone.saveTask(const TaskItem(id: 't1', title: 'from phone'));
      expect(await phoneSync.syncOnce(), SyncOutcome.pushed);

      expect(await pcSync.syncOnce(), SyncOutcome.pulled);
      expect(pc.subjects.single.name, 'برمجة');
      expect(pc.tasks.single.title, 'from phone');

      // Different edits on each side.
      await pc.saveTask(const TaskItem(id: 't2', title: 'from pc'));
      await phone.toggleTask('t1');
      await pcSync.syncOnce();
      await phoneSync.syncOnce();
      await pcSync.syncOnce();

      for (final d in [phone, pc]) {
        expect(d.tasks.map((t) => t.id).toSet(), {'t1', 't2'});
        expect(d.tasks.firstWhere((t) => t.id == 't1').done, isTrue);
      }
      expect(sameSyncDoc(phone.syncDoc(), pc.syncDoc()), isTrue);

      // Nothing new: nothing is written.
      final writes = server.writes;
      expect(await phoneSync.syncOnce(), SyncOutcome.upToDate);
      expect(await pcSync.syncOnce(), SyncOutcome.upToDate);
      expect(server.writes, writes);
    });

    test('a deletion on one device removes it on the other', () async {
      final server = FakeRemote();
      final phone = await device();
      final pc = await device();
      await phone.saveTask(const TaskItem(id: 't1', title: 'x'));
      await SyncEngine(phone, server).syncOnce();
      await SyncEngine(pc, server).syncOnce();
      expect(pc.tasks, hasLength(1));

      await pc.deleteTask('t1');
      await SyncEngine(pc, server).syncOnce();
      await SyncEngine(phone, server).syncOnce();
      expect(phone.tasks, isEmpty);
    });

    test('a racing write is merged instead of overwritten', () async {
      final server = FakeRemote();
      final phone = await device();
      final pc = await device();
      await phone.saveTask(const TaskItem(id: 'base', title: 'x'));
      await SyncEngine(phone, server).syncOnce();
      await SyncEngine(pc, server).syncOnce();

      await phone.saveTask(const TaskItem(id: 'p', title: 'phone'));
      await pc.saveTask(const TaskItem(id: 'c', title: 'pc'));
      // The PC saves just before the phone's write lands.
      server.beforeNextWrite = () => SyncEngine(pc, server).syncOnce();
      await SyncEngine(phone, server).syncOnce();
      await SyncEngine(pc, server).syncOnce();

      final ids = {'base', 'p', 'c'};
      expect(phone.tasks.map((t) => t.id).toSet(), ids);
      expect(pc.tasks.map((t) => t.id).toSet(), ids);
    });

    test('an edit made while syncing is kept', () async {
      final server = FakeRemote();
      final phone = await device();
      final pc = await device();
      await pc.saveTask(const TaskItem(id: 'pc', title: 'x'));
      await SyncEngine(pc, server).syncOnce();

      // The phone edits while its sync is waiting for the server.
      final engine = SyncEngine(phone, server);
      final running = engine.syncOnce();
      await phone.saveTask(const TaskItem(id: 'mine', title: 'y'));
      await running;
      await engine.syncOnce();
      expect(phone.tasks.map((t) => t.id).toSet(), {'pc', 'mine'});
      expect((server.doc!['tasks'] as List).map((t) => t['id']).toSet(), {
        'pc',
        'mine',
      });
    });

    test('settings sync but the theme stays per device', () async {
      final server = FakeRemote();
      final phone = await device();
      final pc = await device();
      await pc.updateSettings(
        pc.settings.copyWith(themeMode: AppThemeMode.dark),
      );
      await phone.updateSettings(
        phone.settings.copyWith(studentName: 'أحمد', dailyGoalMinutes: 180),
      );
      await SyncEngine(phone, server).syncOnce();
      await SyncEngine(pc, server).syncOnce();
      expect(pc.settings.studentName, 'أحمد');
      expect(pc.settings.dailyGoalMinutes, 180);
      expect(pc.settings.themeMode, AppThemeMode.dark);
      expect(phone.settings.themeMode, AppThemeMode.system);
    });

    test('the same finished focus session is counted once', () async {
      final server = FakeRemote();
      final phone = await device();
      final pc = await device();
      final t0 = DateTime(2026, 9, 29, 18);
      await phone.startFocus(phase: FocusPhase.focus, minutes: 25, now: t0);
      await SyncEngine(phone, server).syncOnce();
      await SyncEngine(pc, server).syncOnce();
      expect(pc.focus, isNotNull);

      final end = t0.add(const Duration(minutes: 26));
      await phone.completeFocusIfDue(end);
      await pc.completeFocusIfDue(end);
      await SyncEngine(phone, server).syncOnce();
      await SyncEngine(pc, server).syncOnce();
      await SyncEngine(phone, server).syncOnce();
      expect(phone.studySessions, hasLength(1));
      expect(pc.studySessions, hasLength(1));
      expect(pc.focus, isNull);
    });
  });
}
