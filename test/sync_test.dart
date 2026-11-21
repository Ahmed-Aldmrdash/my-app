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
  int versionChecks = 0;

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
  Future<int?> fetchVersion() async {
    versionChecks++;
    return doc == null ? null : version;
  }

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
    test('checking for news only downloads the version', () async {
      final server = FakeRemote();
      final phone = await device();
      final pc = await device();
      final phoneSync = SyncEngine(phone, server);
      final pcSync = SyncEngine(pc, server);

      expect(await phoneSync.needsSync(), isTrue, reason: 'never synced');
      await phone.saveSubject(const Subject(id: 's1', name: 'برمجة'));
      await phoneSync.syncOnce();
      await pcSync.syncOnce();
      expect(await phoneSync.needsSync(), isFalse);
      expect(await pcSync.needsSync(), isFalse);

      await pc.saveTask(const TaskItem(id: 't1', title: 'x'));
      expect(await pcSync.needsSync(), isTrue, reason: 'unsaved local edit');
      expect(await phoneSync.needsSync(), isFalse, reason: 'not saved yet');
      await pcSync.syncOnce();
      expect(await phoneSync.needsSync(), isTrue, reason: 'the pc saved');
      await phoneSync.syncOnce();
      expect(await phoneSync.needsSync(), isFalse);
      expect(phone.tasks.single.title, 'x');
      expect(server.versionChecks, greaterThan(0));
    });

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

  group('data from newer app versions', () {
    /// What a newer app version might have saved: a field this version
    /// doesn't know, a whole list it doesn't know, and a new setting.
    Map<String, dynamic> newerSave() => {
      'version': 9,
      'subjects': [
        {'id': 's1', 'name': 'برمجة', 'semesterId': 'term-1'},
      ],
      'flashcards': [
        {'id': 'c1', 'front': 'Q', 'back': 'A'},
      ],
      'settings': {'studentName': 'أحمد', 'prayerCity': 'Cairo'},
      'meta': {
        'stamps': {
          'subjects': {'s1': 5},
          'flashcards': {'c1': 5},
        },
        // The newer app's student set the new setting.
        'settingsAt': 5,
      },
    };

    test('the store lists what it syncs', () async {
      expect((await device()).collectionNames, syncedCollections);
    });

    test('unknown fields, lists and settings survive edits', () async {
      final storage = MemoryStorage(jsonEncode(newerSave()));
      final s = AppStore(storage);
      await s.load();
      await s.saveSubject(const Subject(id: 's1', name: 'برمجة 2'));
      await s.updateSettings(s.settings.copyWith(dailyGoalMinutes: 90));

      final saved = jsonDecode(storage.data!) as Map<String, dynamic>;
      final subject = (saved['subjects'] as List).single as Map;
      expect(subject['name'], 'برمجة 2');
      expect(subject['semesterId'], 'term-1');
      expect((saved['flashcards'] as List).single['front'], 'Q');
      expect(saved['settings']['prayerCity'], 'Cairo');
      expect(saved['settings']['dailyGoalMinutes'], 90);

      final doc = s.syncDoc();
      expect(doc['v'], syncFormat);
      expect(doc['flashcards'], hasLength(1));
      expect(doc['settings']['prayerCity'], 'Cairo');
      expect((doc['subjects'] as List).single['semesterId'], 'term-1');
    });

    test('deleting all data also deletes unknown lists', () async {
      final s = AppStore(MemoryStorage(jsonEncode(newerSave())));
      await s.load();
      await s.clearAll();
      expect(s.syncDoc()['flashcards'], isEmpty);
      expect(
        SyncMeta.fromJson(s.syncDoc()['meta']).tombs['flashcards'],
        contains('c1'),
      );
    });

    test('merging keeps lists only one side knows', () {
      final newer = newerSave();
      final older = {
        'v': 1,
        'subjects': <Object?>[],
        'meta': {'stamps': <String, Object?>{}},
      };
      final ab = mergeSyncDocs(newer, older);
      final ba = mergeSyncDocs(older, newer);
      expect(sameSyncDoc(ab, ba), isTrue);
      expect((ab['flashcards'] as List).single['id'], 'c1');
      expect(SyncMeta.fromJson(ab['meta']).stamps['flashcards'], {'c1': 5});
    });

    test('a copy that lost new fields loses a tie', () {
      Map<String, dynamic> doc(Map<String, dynamic> task) => {
        'tasks': [task],
        'meta': {
          'stamps': {
            'tasks': {'1': 7},
          },
        },
      };
      final full = doc({'id': '1', 'title': 'x', 'colour': 'red'});
      final stripped = doc({'id': '1', 'title': 'x'});
      for (final m in [
        mergeSyncDocs(full, stripped),
        mergeSyncDocs(stripped, full),
      ]) {
        expect((m['tasks'] as List).single['colour'], 'red');
      }
    });

    test('each app writes its own format; the oldest allowed only goes up', () {
      final m = mergeSyncDocs({'v': 7, 'minFormat': 3}, {'v': 1});
      expect(m['v'], syncFormat);
      expect(m['minFormat'], 3);
      expect(mergeSyncDocs({}, {})['minFormat'], minWriterFormat);
    });

    test('syncing still works after deleting all data', () async {
      final server = FakeRemote();
      final s = AppStore(MemoryStorage(jsonEncode(newerSave())));
      await s.load();
      await SyncEngine(s, server).syncOnce();
      await s.clearAll();
      final engine = SyncEngine(s, server);
      expect(await engine.syncOnce(), SyncOutcome.pushed);
      expect(await engine.needsSync(), isFalse);
      expect(server.doc!['flashcards'], isEmpty);
      expect(
        SyncMeta.fromJson(server.doc!['meta']).tombs['flashcards'],
        contains('c1'),
      );

      // Restoring a backup without that list doesn't break syncing either.
      final restored = await device();
      await restored.importJson(jsonEncode({'subjects': <Object?>[]}));
      await SyncEngine(restored, server).syncOnce();
      expect(await SyncEngine(restored, server).needsSync(), isTrue);
    });

    test(
      'values this version cannot show are written back untouched',
      () async {
        final server = FakeRemote();
        server.doc = {
          'v': 3,
          'studyItems': [
            {
              'id': 'l1',
              'subjectId': 's',
              'title': 'L1',
              'status': 'mastered',
              'releaseDate': '2026-10-01T00:00:00.000',
            },
          ],
          'projects': [
            {
              'id': 'p1',
              'title': 'P',
              'steps': [
                {
                  'id': 'st',
                  'title': 'x',
                  'done': false,
                  'dueDate': '2026-12-01',
                },
              ],
            },
          ],
          'focus': {
            'phase': 'focus',
            'plannedSeconds': 60,
            'startedAt': '2026-10-01T10:00:00.000',
            'endsAt': '2026-10-01T10:01:00.000',
            'sound': 'rain',
          },
          'settings': {'focusMinutes': 240, 'prayerCity': 'Cairo'},
          'meta': {
            'stamps': {
              'studyItems': {'l1': 100},
              'projects': {'p1': 100},
            },
            'settingsAt': 100,
            'focusAt': 100,
          },
        };
        server.version = 1;
        final phone = await device();
        final engine = SyncEngine(phone, server);
        await engine.syncOnce();
        // Nothing to do afterwards: no endless re-applying.
        expect(await engine.needsSync(), isFalse);
        // An unrelated edit pushes everything else back unchanged.
        await phone.saveTask(const TaskItem(id: 't', title: 't'));
        await engine.syncOnce();
        final doc = server.doc!;
        expect((doc['studyItems'] as List).single['status'], 'mastered');
        final step = (doc['projects'] as List).single['steps'].single as Map;
        expect(step['dueDate'], '2026-12-01');
        expect(doc['focus']['sound'], 'rain');
        expect(doc['settings']['focusMinutes'], 240);
        expect(doc['settings']['prayerCity'], 'Cairo');
        expect(await engine.needsSync(), isFalse);

        // Editing the record here writes what this version knows, and keeps
        // the fields it doesn't.
        await phone.setStudyStatus('l1', StudyStatus.studied);
        await engine.syncOnce();
        final item = (server.doc!['studyItems'] as List).single as Map;
        expect(item['status'], 'studied');
      },
    );

    test('undoing a deletion keeps fields from newer versions', () async {
      final s = AppStore(
        MemoryStorage(
          jsonEncode({
            'tasks': [
              {'id': 't1', 'title': 'x', 'colour': 'red'},
            ],
          }),
        ),
      );
      await s.load();
      final task = s.tasks.single;
      await s.deleteTask('t1');
      // Another device's change arrives in between.
      await s.applySyncDoc(s.syncDoc());
      await s.saveTask(task);
      expect((s.syncDoc()['tasks'] as List).single['colour'], 'red');
    });

    test(
      'restoring a backup with other unknown settings stamps them',
      () async {
        final s = await device();
        final before = SyncMeta.fromJson(s.syncDoc()['meta']).settingsAt;
        await s.importJson(
          jsonEncode({
            'subjects': <Object?>[],
            'settings': {'prayerCity': 'Alex'},
          }),
        );
        expect(
          SyncMeta.fromJson(s.syncDoc()['meta']).settingsAt,
          greaterThan(before),
        );
        expect(s.syncDoc()['settings']['prayerCity'], 'Alex');
      },
    );

    test('syncing never removes what a newer device saved', () async {
      final server = FakeRemote();
      final phone = await device();
      await phone.saveTask(const TaskItem(id: 't1', title: 'old'));
      await SyncEngine(phone, server).syncOnce();

      // A newer app version on another device adds its own data.
      final newer = AppStore(MemoryStorage(jsonEncode(newerSave())));
      await newer.load();
      await SyncEngine(newer, server).syncOnce();

      // This device syncs, edits and syncs again.
      await SyncEngine(phone, server).syncOnce();
      await phone.saveTask(const TaskItem(id: 't1', title: 'new'));
      await SyncEngine(phone, server).syncOnce();

      final doc = server.doc!;
      expect((doc['flashcards'] as List).single['id'], 'c1');
      expect((doc['subjects'] as List).single['semesterId'], 'term-1');
      expect(doc['settings']['prayerCity'], 'Cairo');
      expect((doc['tasks'] as List).single['title'], 'new');
      expect(doc['v'], syncFormat);
    });
  });
}
