import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_remote.dart';
import 'sync_backend.dart';
import 'sync_config.dart';

/// The student's own Supabase project. Supabase keeps the session on the
/// device, so a student who signed in once stays signed in.
class SupabaseBackend implements SyncBackend {
  bool _open = false;

  GoTrueClient get _auth => Supabase.instance.client.auth;

  @override
  Future<void> open(SyncConfig config) async {
    await Supabase.initialize(
      url: config.url,
      publishableKey: config.key,
      debug: false,
    );
    _open = true;
  }

  @override
  Future<void> close() async {
    if (!_open) return;
    _open = false;
    await Supabase.instance.dispose();
  }

  @override
  SyncUser? get currentUser => _open ? _toUser(_auth.currentUser) : null;

  @override
  Stream<SyncUser?> get userChanges =>
      _auth.onAuthStateChange.map((s) => _toUser(s.session?.user));

  @override
  Future<void> signIn(String email, String password) =>
      _auth.signInWithPassword(email: email, password: password);

  @override
  Future<SignUpResult> signUp(String email, String password) async {
    final res = await _auth.signUp(email: email, password: password);
    if (res.session != null) return SignUpResult.signedIn;
    // Supabase hides whether an address is taken by returning a user
    // without identities.
    final identities = res.user?.identities;
    if (identities != null && identities.isEmpty) {
      return SignUpResult.alreadyRegistered;
    }
    return SignUpResult.confirmEmail;
  }

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  LiveRemote remoteFor(SyncUser user) =>
      SupabaseRemote(Supabase.instance.client, user.id);

  static SyncUser? _toUser(User? user) =>
      user == null ? null : SyncUser(user.id, user.email);
}
