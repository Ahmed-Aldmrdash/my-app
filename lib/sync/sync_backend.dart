import 'sync_config.dart';
import 'sync_engine.dart';

/// Who is signed in on this device.
class SyncUser {
  const SyncUser(this.id, this.email);

  final String id;
  final String? email;
}

enum SignUpResult { signedIn, alreadyRegistered, confirmEmail }

/// A [SyncRemote] that also hears when another device saves.
abstract class LiveRemote implements SyncRemote {
  /// Calls [onChange] with the new version whenever the saved data changes,
  /// including this device's own saves.
  void listen(void Function(int? version) onChange);

  Future<void> close();
}

/// Accounts and storage on the sync server. The real one is the student's
/// Supabase project; tests use a fake.
abstract class SyncBackend {
  /// Connects to the project. Whoever signed in on this device before is
  /// still signed in afterwards (see [currentUser]).
  Future<void> open(SyncConfig config);

  Future<void> close();

  SyncUser? get currentUser;

  /// Fires on every sign-in, sign-out and session refresh.
  Stream<SyncUser?> get userChanges;

  Future<void> signIn(String email, String password);

  Future<SignUpResult> signUp(String email, String password);

  Future<void> signOut();

  /// The account's saved data.
  LiveRemote remoteFor(SyncUser user);
}
