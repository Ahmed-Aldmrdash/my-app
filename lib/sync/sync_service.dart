import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthException, PostgrestException;

import '../data/app_store.dart';
import 'supabase_backend.dart';
import 'sync_backend.dart';
import 'sync_config.dart';
import 'sync_engine.dart';

enum SyncState {
  /// No Supabase project set up on this device yet.
  notConfigured,

  /// Connecting to the project.
  connecting,

  /// Set up but nobody is signed in.
  signedOut,

  /// Signed in; last round succeeded (or none ran yet).
  idle,
  syncing,

  /// The last round failed; see [SyncService.error].
  error,
}

/// Keeps this device's data in sync with the student's account. Once
/// signed in, the device stays signed in (also after restarts) and syncs by
/// itself: after every local change, as soon as another device saves, when
/// the app comes back to the foreground, and with a quick check every
/// minute in case a live update was missed.
class SyncService extends ChangeNotifier {
  SyncService(
    this.store, {
    SyncBackend? backend,
    this.saveDelay = const Duration(milliseconds: 1200),
    this.checkEvery = const Duration(minutes: 1),
  }) : backend = backend ?? SupabaseBackend();

  final AppStore store;
  final SyncBackend backend;

  /// How long after a local edit to save it, so quick edits go together.
  final Duration saveDelay;

  /// How often to check for changes a live update might have missed.
  final Duration checkEvery;

  /// The account this device last synced with.
  static const _linkedUserPref = 'sync.user';

  SyncConfig? _config;
  SyncState _state = SyncState.notConfigured;
  String? _error;
  DateTime? _lastSynced;

  bool _open = false;
  StreamSubscription<SyncUser?>? _userSub;
  _AccountSync? _account;
  bool _running = false;
  bool _again = false;

  SyncState get state => _state;
  SyncConfig? get config => _config;
  String? get error => _error;
  DateTime? get lastSynced => _lastSynced;
  String? get email => _account?.user.email;
  bool get isSignedIn => _account != null;

  /// Loads the saved project settings and reconnects.
  Future<void> init() async {
    try {
      _config = await SyncConfig.load();
    } catch (e) {
      debugPrint('Could not read sync settings: $e');
    }
    if (_config != null) await _connect();
  }

  /// Saves a new project and connects to it. Returns an error message, or
  /// null when connected.
  Future<String?> configure(SyncConfig config) async {
    await config.save();
    _config = config;
    await _connect();
    return _state == SyncState.error ? _error : null;
  }

  /// Forgets the project on this device (the data stays on the device).
  Future<void> forgetProject() async {
    await _disconnect();
    await SyncConfig.clear();
    _config = SyncConfig.builtIn;
    if (_config != null) {
      await _connect();
    } else {
      _set(SyncState.notConfigured);
    }
  }

  Future<void> _connect() async {
    final config = _config;
    if (config == null) return;
    await _disconnect();
    _set(SyncState.connecting);
    try {
      await backend.open(config);
      _open = true;
      _userSub = backend.userChanges.listen(
        _onUser,
        onError: (Object e) => debugPrint('Auth error: $e'),
      );
      _onUser(backend.currentUser);
    } catch (e) {
      debugPrint('Could not connect: $e');
      _error = 'مش قادر أوصل لمشروع Supabase — راجع الرابط والمفتاح';
      _set(SyncState.error);
    }
  }

  Future<void> _disconnect() async {
    _stopSyncing();
    await _userSub?.cancel();
    _userSub = null;
    if (_open) {
      _open = false;
      try {
        await backend.close();
      } catch (e) {
        debugPrint('Could not close the connection: $e');
      }
    }
  }

  void _onUser(SyncUser? user) {
    if (user == null) {
      _stopSyncing();
      _set(SyncState.signedOut);
      return;
    }
    // Session refreshes report the same account again.
    if (_account?.user.id == user.id) return;
    _startSyncing(user);
  }

  void _startSyncing(SyncUser user) {
    _stopSyncing();
    final remote = backend.remoteFor(user);
    final account = _AccountSync(user, remote, SyncEngine(store, remote));
    _account = account;
    remote.listen((version) {
      // This device's own saves come back too; only react to others'.
      if (version == null || version != account.engine.lastVersion) {
        syncNow();
      }
    });
    account.localChanges = store.localChanges.listen((_) {
      account.saveTimer?.cancel();
      account.saveTimer = Timer(saveDelay, syncNow);
    });
    account.checkTimer = Timer.periodic(checkEvery, (_) => _check());
    _error = null;
    _set(SyncState.idle);
    syncNow();
  }

  /// Stops syncing the current account at once; its connection closes in
  /// the background.
  void _stopSyncing() {
    final account = _account;
    _account = null;
    account?.close();
  }

  /// Runs a sync round now (or right after the one in progress).
  Future<void> syncNow() async {
    final account = _account;
    if (account == null) return;
    if (_running) {
      _again = true;
      return;
    }
    _running = true;
    _set(SyncState.syncing);
    try {
      if (!account.linked) await _link(account);
      do {
        _again = false;
        await account.engine.syncOnce();
      } while (_again && identical(account, _account));
      if (identical(account, _account)) {
        _lastSynced = DateTime.now();
        _error = null;
        _set(SyncState.idle);
      }
    } catch (e) {
      debugPrint('Sync failed: $e');
      if (identical(account, _account)) {
        _error = describeSyncError(e);
        _set(SyncState.error);
      }
    } finally {
      _running = false;
      // Another account signed in during this round: sync that one too.
      if (_account != null && !identical(account, _account)) syncNow();
    }
  }

  /// A cheap look at whether anything changed; only syncs if so.
  Future<void> _check() async {
    final account = _account;
    if (account == null || _running) return;
    // After a failure, a full round is what clears the error.
    if (_state == SyncState.error) {
      await syncNow();
      return;
    }
    try {
      if (await account.engine.needsSync()) {
        await syncNow();
      } else if (identical(account, _account)) {
        // Confirmed up to date just now.
        _lastSynced = DateTime.now();
        notifyListeners();
      }
    } catch (e) {
      // Offline, most likely; the next check tries again.
      debugPrint('Sync check failed: $e');
    }
  }

  /// Before this device first syncs with an account: drops the sample
  /// semester, so trying the app out never mixes fake subjects into the
  /// student's real data on their other devices.
  Future<void> _link(_AccountSync account) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_linkedUserPref) != account.user.id &&
        store.onlyDemoData) {
      await store.clearAll();
    }
    await prefs.setString(_linkedUserPref, account.user.id);
    account.linked = true;
  }

  /// Called when the app returns to the foreground.
  void onResume() => _check();

  /// Signs in. Returns an error message, or null on success.
  Future<String?> signIn(String email, String password) async {
    if (!_open) return 'جهّز السيرفر الأول';
    try {
      await backend.signIn(email.trim(), password);
      _onUser(backend.currentUser);
      return null;
    } catch (e) {
      return describeAuthError(e);
    }
  }

  /// Creates an account. Returns null when signed in right away, or a
  /// message (e.g. "check your email") otherwise.
  Future<String?> signUp(String email, String password) async {
    if (!_open) return 'جهّز السيرفر الأول';
    try {
      final result = await backend.signUp(email.trim(), password);
      switch (result) {
        case SignUpResult.signedIn:
          _onUser(backend.currentUser);
          return null;
        case SignUpResult.alreadyRegistered:
          return 'الإيميل ده عليه حساب قبل كده — ادخل بيه';
        case SignUpResult.confirmEmail:
          return 'بعتنالك إيميل تأكيد 📩 افتحه ودوس على اللينك، وبعدين ادخل من هنا';
      }
    } catch (e) {
      return describeAuthError(e);
    }
  }

  Future<void> signOut() async {
    if (!_open) return;
    try {
      await backend.signOut();
    } catch (e) {
      debugPrint('Sign out failed: $e');
    }
    _onUser(null);
  }

  void _set(SyncState s) {
    _state = s;
    notifyListeners();
  }

  @override
  void dispose() {
    _disconnect();
    super.dispose();
  }
}

/// Everything that runs while one account is signed in on this device.
class _AccountSync {
  _AccountSync(this.user, this.remote, this.engine);

  final SyncUser user;
  final LiveRemote remote;
  final SyncEngine engine;
  StreamSubscription<void>? localChanges;
  Timer? saveTimer;
  Timer? checkTimer;

  /// Whether [SyncService._link] ran for this sign-in.
  bool linked = false;

  void close() {
    saveTimer?.cancel();
    checkTimer?.cancel();
    unawaited(localChanges?.cancel());
    unawaited(
      remote.close().catchError(
        (Object e) => debugPrint('Could not close live updates: $e'),
      ),
    );
  }
}

/// A friendly Arabic explanation of a sync failure.
String describeSyncError(Object e) {
  if (e is PostgrestException) {
    if (e.code == 'PGRST205' || e.code == '42P01') {
      return 'جدول المزامنة مش موجود — شغّل كود الـ SQL من خطوات التجهيز';
    }
    if (e.code == '42501') {
      return 'السيرفر رافض الحفظ — شغّل كود الـ SQL من خطوات التجهيز تاني';
    }
    return 'حصلت مشكلة في السيرفر: ${e.message}';
  }
  if (e is AuthException) return describeAuthError(e);
  if (e is SyncConflictException) {
    return 'فيه تعديلات كتير في نفس الوقت — هجرب تاني بعد شوية';
  }
  if (_looksOffline(e)) {
    return 'مفيش إنترنت دلوقتي — هزامن أول ما النت يرجع';
  }
  return 'حصلت مشكلة في المزامنة — هجرب تاني بعد شوية';
}

/// A friendly Arabic explanation of a sign-in or sign-up failure.
String describeAuthError(Object e) {
  if (e is AuthException) {
    switch (e.code) {
      case 'invalid_credentials':
        return 'الإيميل أو الباسورد غلط';
      case 'email_not_confirmed':
        return 'لازم تأكد الإيميل الأول — افتح الرسالة اللي جاتلك ودوس على اللينك';
      case 'user_already_exists':
      case 'email_exists':
        return 'الإيميل ده عليه حساب قبل كده — ادخل بيه';
      case 'weak_password':
        return 'الباسورد ضعيف — خليه 6 حروف أو أرقام على الأقل';
      case 'email_address_invalid':
      case 'validation_failed':
        return 'الإيميل مش مظبوط';
      case 'over_email_send_rate_limit':
      case 'over_request_rate_limit':
        return 'محاولات كتير — استنى شوية وجرب تاني';
      case 'signup_disabled':
        return 'إنشاء الحسابات مقفول في إعدادات مشروع Supabase';
    }
    if (_looksOffline(e)) return 'مفيش إنترنت دلوقتي';
    return e.message;
  }
  if (_looksOffline(e)) return 'مفيش إنترنت دلوقتي';
  return 'حصلت مشكلة — جرب تاني';
}

bool _looksOffline(Object e) {
  final s = e.toString();
  return s.contains('SocketException') ||
      s.contains('ClientException') ||
      s.contains('Failed host lookup') ||
      s.contains('Connection') ||
      s.contains('XMLHttpRequest') ||
      s.contains('TimeoutException');
}
