import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/app_store.dart';
import 'supabase_remote.dart';
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

/// Keeps this device's data in sync with the student's account: it syncs
/// after every local change, whenever another device saves, when the app
/// comes back to the foreground and every few minutes.
class SyncService extends ChangeNotifier {
  SyncService(this.store);

  final AppStore store;

  /// The account this device last synced with.
  static const _linkedUserPref = 'sync.user';

  SyncConfig? _config;
  SyncState _state = SyncState.notConfigured;
  String? _error;
  DateTime? _lastSynced;
  String? _email;
  String? _userId;

  bool _supabaseReady = false;
  StreamSubscription<AuthState>? _authSub;
  StreamSubscription<void>? _localSub;
  SupabaseRemote? _remote;
  SyncEngine? _engine;
  Timer? _debounce;
  Timer? _periodic;
  bool _running = false;
  bool _again = false;
  bool _linked = false;

  SyncState get state => _state;
  SyncConfig? get config => _config;
  String? get error => _error;
  DateTime? get lastSynced => _lastSynced;
  String? get email => _email;
  bool get isSignedIn => _userId != null;

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
      await Supabase.initialize(
        url: config.url,
        publishableKey: config.key,
        debug: false,
      );
      _supabaseReady = true;
      final auth = Supabase.instance.client.auth;
      _authSub = auth.onAuthStateChange.listen(
        (s) => _onUser(s.session?.user),
        onError: (Object e) => debugPrint('Auth error: $e'),
      );
      _onUser(auth.currentUser);
    } catch (e) {
      _error = 'مش قادر أوصل لمشروع Supabase — راجع الرابط والمفتاح';
      _set(SyncState.error);
    }
  }

  Future<void> _disconnect() async {
    await _stopSyncing();
    await _authSub?.cancel();
    _authSub = null;
    if (_supabaseReady) {
      _supabaseReady = false;
      try {
        await Supabase.instance.dispose();
      } catch (e) {
        debugPrint('Could not close Supabase: $e');
      }
    }
  }

  void _onUser(User? user) {
    if (user == null) {
      _stopSyncing();
      _email = null;
      _set(SyncState.signedOut);
      return;
    }
    if (_userId == user.id && _engine != null) return;
    _startSyncing(user);
  }

  void _startSyncing(User user) {
    _stopSyncing();
    _userId = user.id;
    _email = user.email;
    _linked = false;
    final remote = SupabaseRemote(Supabase.instance.client, user.id);
    final engine = SyncEngine(store, remote);
    _remote = remote;
    _engine = engine;
    remote.listen((version) {
      // Our own save comes back too; only react to other devices.
      if (version == null || version != engine.lastVersion) syncNow();
    });
    _localSub = store.localChanges.listen((_) => _scheduleSync());
    _periodic = Timer.periodic(const Duration(minutes: 3), (_) => syncNow());
    _error = null;
    _set(SyncState.idle);
    syncNow();
  }

  Future<void> _stopSyncing() async {
    _debounce?.cancel();
    _periodic?.cancel();
    await _localSub?.cancel();
    _localSub = null;
    final remote = _remote;
    _remote = null;
    _engine = null;
    _userId = null;
    if (remote != null) {
      try {
        await remote.close();
      } catch (_) {}
    }
  }

  void _scheduleSync() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 1200), syncNow);
  }

  /// Runs a sync round now (or right after the one in progress).
  Future<void> syncNow() async {
    final engine = _engine;
    final userId = _userId;
    if (engine == null || userId == null) return;
    if (_running) {
      _again = true;
      return;
    }
    _running = true;
    _set(SyncState.syncing);
    try {
      if (!_linked) await _link(userId);
      do {
        _again = false;
        await engine.syncOnce();
      } while (_again && identical(engine, _engine));
      _lastSynced = DateTime.now();
      _error = null;
      if (identical(engine, _engine)) _set(SyncState.idle);
    } catch (e) {
      debugPrint('Sync failed: $e');
      _error = describeSyncError(e);
      if (identical(engine, _engine)) _set(SyncState.error);
    } finally {
      _running = false;
    }
  }

  /// Before this device first syncs with an account: drops the sample
  /// semester, so trying the app out never mixes fake subjects into the
  /// student's real data on their other devices.
  Future<void> _link(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_linkedUserPref) != userId && store.onlyDemoData) {
      await store.clearAll();
    }
    await prefs.setString(_linkedUserPref, userId);
    _linked = true;
  }

  /// Called when the app returns to the foreground.
  void onResume() {
    if (_engine != null) syncNow();
  }

  /// Signs in. Returns an error message, or null on success.
  Future<String?> signIn(String email, String password) async {
    if (!_supabaseReady) return 'جهّز السيرفر الأول';
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      return null;
    } catch (e) {
      return describeAuthError(e);
    }
  }

  /// Creates an account. Returns null when signed in right away, or a
  /// message (e.g. "check your email") otherwise.
  Future<String?> signUp(String email, String password) async {
    if (!_supabaseReady) return 'جهّز السيرفر الأول';
    try {
      final res = await Supabase.instance.client.auth.signUp(
        email: email.trim(),
        password: password,
      );
      if (res.session != null) return null;
      final identities = res.user?.identities;
      if (identities != null && identities.isEmpty) {
        return 'الإيميل ده عليه حساب قبل كده — ادخل بيه';
      }
      return 'بعتنالك إيميل تأكيد 📩 افتحه ودوس على اللينك، وبعدين ادخل من هنا';
    } catch (e) {
      return describeAuthError(e);
    }
  }

  Future<void> signOut() async {
    if (!_supabaseReady) return;
    try {
      await Supabase.instance.client.auth.signOut();
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
