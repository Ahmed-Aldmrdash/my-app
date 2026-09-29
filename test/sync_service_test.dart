import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_planner/data/app_store.dart';
import 'package:study_planner/data/demo_data.dart';
import 'package:study_planner/data/storage.dart';
import 'package:study_planner/models/models.dart';
import 'package:study_planner/sync/sync_backend.dart';
import 'package:study_planner/sync/sync_config.dart';
import 'package:study_planner/sync/sync_engine.dart';
import 'package:study_planner/sync/sync_service.dart';

/// The sync server the fake devices share: accounts, each account's saved
/// data, and live notifications when it changes.
class FakeCloud {
  final passwords = <String, String>{};
  final docs = <String, Map<String, dynamic>>{};
  final versions = <String, int>{};
  final _listeners = <String, List<void Function(int?)>>{};

  /// Whether live notifications get through (some networks block them).
  bool live = true;

  /// Downloads of all the data, as opposed to version checks.
  int downloads = 0;

  static String userIdOf(String email) => 'user-$email';

  List<String> subjectNames(String email) {
    final subjects = docs[userIdOf(email)]?['subjects'] as List? ?? [];
    return [for (final s in subjects) (s as Map)['name'] as String]..sort();
  }

  List<String> taskTitles(String email) {
    final tasks = docs[userIdOf(email)]?['tasks'] as List? ?? [];
    return [for (final t in tasks) (t as Map)['title'] as String]..sort();
  }

  void _saved(String userId) {
    final version = versions[userId];
    // Arrives a moment later, like a message over the network.
    Timer.run(() {
      if (!live) return;
      for (final listener in [...?_listeners[userId]]) {
        listener(version);
      }
    });
  }
}

class FakeCloudRemote implements LiveRemote {
  FakeCloudRemote(this.cloud, this.userId);

  final FakeCloud cloud;
  final String userId;
  void Function(int?)? _listener;

  static Map<String, dynamic> _copy(Map<String, dynamic> doc) =>
      jsonDecode(jsonEncode(doc)) as Map<String, dynamic>;

  @override
  Future<RemoteDoc?> fetch() async {
    cloud.downloads++;
    final doc = cloud.docs[userId];
    return doc == null ? null : RemoteDoc(_copy(doc), cloud.versions[userId]!);
  }

  @override
  Future<int?> fetchVersion() async => cloud.versions[userId];

  @override
  Future<int?> create(Map<String, dynamic> doc) async {
    if (cloud.docs.containsKey(userId)) return null;
    cloud.docs[userId] = _copy(doc);
    cloud.versions[userId] = 1;
    cloud._saved(userId);
    return 1;
  }

  @override
  Future<int?> replace(Map<String, dynamic> doc, int expectedVersion) async {
    if (cloud.versions[userId] != expectedVersion) return null;
    cloud.docs[userId] = _copy(doc);
    final version = cloud.versions[userId] = expectedVersion + 1;
    cloud._saved(userId);
    return version;
  }

  @override
  void listen(void Function(int? version) onChange) {
    _listener = onChange;
    cloud._listeners.putIfAbsent(userId, () => []).add(onChange);
  }

  @override
  Future<void> close() async => cloud._listeners[userId]?.remove(_listener);
}

/// One device's connection. Like Supabase, it remembers who signed in, so
/// the app is still signed in after a restart.
class FakeBackend implements SyncBackend {
  FakeBackend(this.cloud, {this.savedUser});

  final FakeCloud cloud;
  SyncUser? savedUser;
  bool _open = false;
  final _changes = StreamController<SyncUser?>.broadcast();

  @override
  Future<void> open(SyncConfig config) async {
    _open = true;
    // Supabase reports the restored session as an event too.
    Timer.run(() => _changes.add(savedUser));
  }

  @override
  Future<void> close() async => _open = false;

  @override
  SyncUser? get currentUser => _open ? savedUser : null;

  @override
  Stream<SyncUser?> get userChanges => _changes.stream;

  @override
  Future<void> signIn(String email, String password) async {
    if (cloud.passwords[email] != password) throw Exception('wrong password');
    savedUser = SyncUser(FakeCloud.userIdOf(email), email);
    _changes.add(savedUser);
  }

  @override
  Future<SignUpResult> signUp(String email, String password) async {
    if (cloud.passwords.containsKey(email)) {
      return SignUpResult.alreadyRegistered;
    }
    cloud.passwords[email] = password;
    await signIn(email, password);
    return SignUpResult.signedIn;
  }

  @override
  Future<void> signOut() async {
    savedUser = null;
    _changes.add(null);
  }

  @override
  LiveRemote remoteFor(SyncUser user) => FakeCloudRemote(cloud, user.id);
}

const _project = SyncConfig(
  url: 'https://demo.supabase.co',
  key: 'sb_publishable_0123456789abcdef',
);
const _email = 'me@uni.edu';
const _password = 'secret1';

/// A phone or computer with the app open.
class Device {
  Device(this.cloud, {MemoryStorage? storage, SyncUser? signedIn})
    : storage = storage ?? MemoryStorage(),
      backend = FakeBackend(cloud, savedUser: signedIn);

  final FakeCloud cloud;
  final MemoryStorage storage;
  final FakeBackend backend;
  late final AppStore store;
  late final SyncService sync;
  bool _closed = false;

  /// Opens the app; [setUp] also enters the project details, as the student
  /// does once per device.
  Future<Device> start({bool setUp = true}) async {
    store = AppStore(storage);
    await store.load();
    sync = SyncService(
      store,
      backend: backend,
      saveDelay: const Duration(milliseconds: 5),
      checkEvery: const Duration(milliseconds: 40),
    );
    addTearDown(close);
    if (setUp) {
      await sync.configure(_project);
    } else {
      await sync.init();
    }
    return this;
  }

  void close() {
    if (_closed) return;
    _closed = true;
    sync.dispose();
  }

  /// Closes the app and opens it again, as happens every day.
  Future<Device> restart() {
    close();
    return Device(
      cloud,
      storage: MemoryStorage(storage.data),
      signedIn: backend.savedUser,
    ).start(setUp: false);
  }
}

/// Lets timers, live updates and sync rounds run.
Future<void> settle([int ms = 150]) =>
    Future<void>.delayed(Duration(milliseconds: ms));

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('after signing in it stays signed in and keeps saving', () async {
    final cloud = FakeCloud();
    final phone = await Device(cloud).start();
    expect(phone.sync.state, SyncState.signedOut);

    expect(await phone.sync.signUp(_email, _password), isNull);
    await settle();
    expect(phone.sync.isSignedIn, isTrue);
    expect(phone.sync.state, SyncState.idle);
    expect(phone.sync.email, _email);

    // Every edit is saved by itself, not only the first round.
    for (final name in ['برمجة', 'رياضيات', 'فيزياء']) {
      await phone.store.saveSubject(Subject(id: name, name: name));
      await settle();
      expect(cloud.subjectNames(_email), contains(name));
      expect(phone.sync.isSignedIn, isTrue);
      expect(phone.sync.state, SyncState.idle);
    }
  });

  test('edits reach the other device by themselves', () async {
    final cloud = FakeCloud();
    final phone = await Device(cloud).start();
    await phone.sync.signUp(_email, _password);
    final laptop = await Device(cloud).start();
    expect(await laptop.sync.signIn(_email, _password), isNull);
    await settle();

    await phone.store.saveSubject(const Subject(id: 's1', name: 'برمجة'));
    await settle();
    expect(laptop.store.subjects.map((s) => s.name), ['برمجة']);

    await laptop.store.saveTask(const TaskItem(id: 't1', title: 'شيت 3'));
    await settle();
    expect(phone.store.tasks.map((t) => t.title), ['شيت 3']);

    await phone.store.deleteTask('t1');
    await settle();
    expect(laptop.store.tasks, isEmpty);
  });

  test('the regular check catches up when live updates are blocked', () async {
    final cloud = FakeCloud()..live = false;
    final phone = await Device(cloud).start();
    await phone.sync.signUp(_email, _password);
    final laptop = await Device(cloud).start();
    await laptop.sync.signIn(_email, _password);
    await settle();

    await phone.store.saveSubject(const Subject(id: 's1', name: 'برمجة'));
    await settle(250);
    expect(laptop.store.subjects.map((s) => s.name), ['برمجة']);
  });

  test('a restarted app is still signed in and keeps syncing', () async {
    final cloud = FakeCloud();
    var phone = await Device(cloud).start();
    await phone.sync.signUp(_email, _password);
    await phone.store.saveSubject(const Subject(id: 's1', name: 'برمجة'));
    await settle();

    for (var day = 1; day <= 3; day++) {
      phone = await phone.restart();
      await settle();
      expect(phone.sync.isSignedIn, isTrue, reason: 'day $day');
      expect(phone.sync.state, SyncState.idle, reason: 'day $day');
      expect(phone.store.subjects.map((s) => s.name), ['برمجة']);

      await phone.store.saveTask(TaskItem(id: 't$day', title: 'يوم $day'));
      await settle();
      expect(cloud.taskTitles(_email), hasLength(day), reason: 'day $day');
    }
  });

  test('quiet checks only look at the version', () async {
    final cloud = FakeCloud();
    final phone = await Device(cloud).start();
    await phone.sync.signUp(_email, _password);
    await phone.store.saveSubject(const Subject(id: 's1', name: 'برمجة'));
    await settle();

    final downloads = cloud.downloads;
    phone.sync.onResume();
    await settle(250);
    expect(cloud.downloads, downloads);
  });

  test('signing out stops syncing', () async {
    final cloud = FakeCloud();
    var phone = await Device(cloud).start();
    await phone.sync.signUp(_email, _password);
    await settle();

    await phone.sync.signOut();
    expect(phone.sync.isSignedIn, isFalse);
    expect(phone.sync.state, SyncState.signedOut);

    await phone.store.saveSubject(const Subject(id: 's1', name: 'برمجة'));
    await settle();
    expect(cloud.subjectNames(_email), isEmpty);

    // A restart doesn't sign back in by itself.
    phone = await phone.restart();
    await settle();
    expect(phone.sync.state, SyncState.signedOut);
  });

  test('trying the demo on a new device stays off the account', () async {
    final cloud = FakeCloud();
    final phone = await Device(cloud).start();
    await phone.store.saveSubject(const Subject(id: 'real', name: 'فيزياء'));
    await phone.sync.signUp(_email, _password);
    await settle();

    // The laptop is another device, with its own settings.
    SharedPreferences.setMockInitialValues({});
    final laptop = await Device(cloud).start();
    await loadDemoData(laptop.store, DateTime(2026, 9, 29));
    await laptop.sync.signIn(_email, _password);
    await settle();

    expect(laptop.store.subjects.map((s) => s.name), ['فيزياء']);
    expect(cloud.subjectNames(_email), ['فيزياء']);
    expect(phone.store.subjects.map((s) => s.name), ['فيزياء']);
  });
}
