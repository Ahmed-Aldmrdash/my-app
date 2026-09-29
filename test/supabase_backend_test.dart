import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_planner/data/app_store.dart';
import 'package:study_planner/data/storage.dart';
import 'package:study_planner/models/models.dart';
import 'package:study_planner/sync/supabase_backend.dart';
import 'package:study_planner/sync/sync_config.dart';
import 'package:study_planner/sync/sync_service.dart';

/// A local stand-in for a Supabase project with the parts the app uses:
/// email sign-up and sign-in, token refresh, and the planner_state table
/// with row-level security. Live updates are not served, so the app falls
/// back to its regular checks.
class FakeSupabase {
  late HttpServer _server;
  String get url => 'http://127.0.0.1:${_server.port}';

  /// How long new access tokens are valid.
  Duration tokenLife = const Duration(hours: 1);

  final _users = <String, ({String id, String password})>{};
  final _refreshTokens = <String, ({String id, String email})>{};
  final rows = <String, ({Map<String, dynamic> data, int version})>{};
  int refreshes = 0;
  int _next = 0;

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server.listen(_handle);
  }

  Future<void> stop() => _server.close(force: true);

  List<String> subjectNames() => [
    for (final row in rows.values)
      for (final s in row.data['subjects'] as List)
        (s as Map)['name'] as String,
  ]..sort();

  List<String> taskTitles() => [
    for (final row in rows.values)
      for (final t in row.data['tasks'] as List) (t as Map)['title'] as String,
  ]..sort();

  static String _b64(Object o) =>
      base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');

  Map<String, dynamic> _session(String id, String email) {
    final exp = DateTime.now().add(tokenLife).millisecondsSinceEpoch ~/ 1000;
    final refresh = 'refresh-${_next++}';
    _refreshTokens[refresh] = (id: id, email: email);
    return {
      'access_token':
          '${_b64({'alg': 'HS256', 'typ': 'JWT'})}.'
          '${_b64({'sub': id, 'exp': exp, 'role': 'authenticated', 'aud': 'authenticated'})}.sig',
      'token_type': 'bearer',
      'expires_in': tokenLife.inSeconds,
      'expires_at': exp,
      'refresh_token': refresh,
      'user': {
        'id': id,
        'aud': 'authenticated',
        'role': 'authenticated',
        'email': email,
        'app_metadata': {'provider': 'email'},
        'user_metadata': <String, dynamic>{},
        'identities': [
          {
            'id': id,
            'user_id': id,
            'identity_id': id,
            'provider': 'email',
            'identity_data': {'email': email},
            'created_at': '2026-09-29T00:00:00Z',
            'last_sign_in_at': '2026-09-29T00:00:00Z',
            'updated_at': '2026-09-29T00:00:00Z',
          },
        ],
        'created_at': '2026-09-29T00:00:00Z',
      },
    };
  }

  /// The signed-in user of a data request, like row-level security.
  String? _userOf(HttpRequest req) {
    final auth = req.headers.value('authorization') ?? '';
    final parts = auth.replaceFirst('Bearer ', '').split('.');
    if (parts.length != 3) return null;
    final payload =
        jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))))
            as Map;
    final exp = payload['exp'] as int;
    if (exp * 1000 < DateTime.now().millisecondsSinceEpoch) return null;
    return payload['sub'] as String;
  }

  Future<void> _handle(HttpRequest req) async {
    final res = req.response;
    void send(int status, [Object? body]) {
      res.statusCode = status;
      res.headers.contentType = ContentType.json;
      if (body != null) res.write(jsonEncode(body));
      res.close();
    }

    final raw = await utf8.decoder.bind(req).join();
    final body = raw.isEmpty ? null : jsonDecode(raw);
    final path = req.uri.path;
    final query = req.uri.queryParameters;

    if (path == '/auth/v1/signup') {
      final email = body['email'] as String;
      final id = 'user-${_users.length + 1}';
      _users[email] = (id: id, password: body['password'] as String);
      return send(200, _session(id, email));
    }
    if (path == '/auth/v1/token') {
      if (query['grant_type'] == 'password') {
        final user = _users[body['email']];
        if (user == null || user.password != body['password']) {
          return send(400, {
            'code': 400,
            'error_code': 'invalid_credentials',
            'msg': 'Invalid login credentials',
          });
        }
        return send(200, _session(user.id, body['email'] as String));
      }
      // Refresh tokens work once, like Supabase's rotation.
      final owner = _refreshTokens.remove(body['refresh_token']);
      if (owner == null) {
        return send(400, {
          'code': 400,
          'error_code': 'refresh_token_not_found',
          'msg': 'Invalid Refresh Token: Refresh Token Not Found',
        });
      }
      refreshes++;
      return send(200, _session(owner.id, owner.email));
    }
    if (path == '/auth/v1/logout') return send(204);

    if (path == '/rest/v1/planner_state') {
      final user = _userOf(req);
      if (user == null) {
        return send(401, {'code': 'PGRST301', 'message': 'JWT expired'});
      }
      final forUser = query['user_id']?.replaceFirst('eq.', '');
      final row = forUser == user ? rows[user] : null;
      switch (req.method) {
        case 'GET':
          final fields = query['select']!.split(',');
          if (row == null) return send(200, []);
          return send(200, [
            {
              if (fields.contains('data')) 'data': row.data,
              'version': row.version,
            },
          ]);
        case 'POST':
          if (body['user_id'] != user) return send(403, {'code': '42501'});
          if (rows.containsKey(user)) {
            return send(409, {'code': '23505', 'message': 'duplicate key'});
          }
          rows[user] = (
            data: body['data'] as Map<String, dynamic>,
            version: body['version'] as int,
          );
          return send(201);
        case 'PATCH':
          final expected = int.parse(query['version']!.replaceFirst('eq.', ''));
          if (row == null || row.version != expected) return send(200, []);
          rows[user] = (
            data: body['data'] as Map<String, dynamic>,
            version: body['version'] as int,
          );
          return send(200, [
            {'version': body['version']},
          ]);
      }
    }
    // Live updates (websocket) and anything else.
    send(404, {'message': 'not found'});
  }
}

Future<void> waitFor(bool Function() done, {String? reason}) async {
  for (var i = 0; i < 200 && !done(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  expect(done(), isTrue, reason: reason);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeSupabase server;

  setUp(() async {
    // The test binding blocks the network; this talks to a local server.
    HttpOverrides.global = null;
    SharedPreferences.setMockInitialValues({});
    server = FakeSupabase();
    await server.start();
  });

  tearDown(() => server.stop());

  SyncService openApp(AppStore store) => SyncService(
    store,
    backend: SupabaseBackend(),
    saveDelay: const Duration(milliseconds: 50),
    checkEvery: const Duration(milliseconds: 300),
  );

  test(
    'stays signed in after a restart, even once the token expired',
    () async {
      final storage = MemoryStorage();
      var store = AppStore(storage);
      await store.load();
      var sync = openApp(store);

      // The first session expires half a minute early, as far as the app is
      // concerned (it refreshes tokens 30 seconds before they run out).
      server.tokenLife = const Duration(seconds: 31);
      expect(
        await sync.configure(
          SyncConfig(url: server.url, key: 'sb_publishable_local_test'),
        ),
        isNull,
      );
      expect(sync.state, SyncState.signedOut);
      expect(await sync.signUp('me@uni.edu', 'secret1'), isNull);
      await waitFor(
        () => sync.state == SyncState.idle && server.rows.isNotEmpty,
      );

      await store.saveSubject(const Subject(id: 's1', name: 'برمجة'));
      await waitFor(() => server.subjectNames().contains('برمجة'));

      // Close the app; by the time it opens again the token has expired.
      sync.dispose();
      await Future<void>.delayed(const Duration(seconds: 2));
      server.tokenLife = const Duration(hours: 1);

      store = AppStore(MemoryStorage(storage.data));
      await store.load();
      sync = openApp(store);
      await sync.init();
      expect(sync.isSignedIn, isTrue, reason: 'no need to sign in again');
      await waitFor(
        () => sync.state == SyncState.idle,
        reason: '${sync.error}',
      );
      expect(server.refreshes, greaterThan(0));

      // And it keeps saving by itself.
      await store.saveTask(const TaskItem(id: 't1', title: 'شيت 3'));
      await waitFor(() => server.taskTitles().contains('شيت 3'));
      await store.saveTask(const TaskItem(id: 't2', title: 'مشروع'));
      await waitFor(() => server.taskTitles().length == 2);
      expect(sync.isSignedIn, isTrue);
      sync.dispose();
    },
  );

  test('picks up changes saved by another device', () async {
    final store = AppStore(MemoryStorage());
    await store.load();
    final sync = openApp(store);
    await sync.configure(
      SyncConfig(url: server.url, key: 'sb_publishable_local_test'),
    );
    await sync.signUp('me@uni.edu', 'secret1');
    await waitFor(() => server.rows.isNotEmpty);

    // Another device saves a subject straight to the server.
    final row = server.rows.values.single;
    final data = jsonDecode(jsonEncode(row.data)) as Map<String, dynamic>;
    (data['subjects'] as List).add({'id': 'other', 'name': 'فيزياء'});
    (data['meta'] as Map)['stamps'] = {
      'subjects': {'other': DateTime.now().millisecondsSinceEpoch},
    };
    server.rows[server.rows.keys.single] = (
      data: data,
      version: row.version + 1,
    );

    await waitFor(() => store.subjects.any((s) => s.name == 'فيزياء'));
    sync.dispose();
  });
}
