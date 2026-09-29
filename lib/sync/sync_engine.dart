import '../data/app_store.dart';
import 'sync_doc.dart';

/// The server's copy of the data and its version number.
class RemoteDoc {
  const RemoteDoc(this.doc, this.version);
  final Map<String, dynamic> doc;
  final int version;
}

/// Where the shared copy of the data lives (e.g. a Supabase table).
abstract class SyncRemote {
  /// The stored document, or null when nothing was stored yet.
  Future<RemoteDoc?> fetch();

  /// Just the stored version (null when nothing was stored yet), to check
  /// cheaply whether anything changed.
  Future<int?> fetchVersion();

  /// Stores the first version. Returns its version number, or null if
  /// another device created it first.
  Future<int?> create(Map<String, dynamic> doc);

  /// Replaces the stored document if it is still at [expectedVersion].
  /// Returns the new version, or null if another device changed it first.
  Future<int?> replace(Map<String, dynamic> doc, int expectedVersion);
}

enum SyncOutcome { upToDate, pulled, pushed, pulledAndPushed }

class SyncConflictException implements Exception {
  @override
  String toString() => 'Too many conflicting updates, try again later';
}

/// One round of: download, merge with local data, apply, upload.
class SyncEngine {
  SyncEngine(this.store, this.remote);

  final AppStore store;
  final SyncRemote remote;

  /// The server version after the last successful round.
  int? lastVersion;

  /// The data as of [lastVersion] (see [syncDocKey]).
  String? _lastKey;

  /// Whether a round would change anything: this device has edits the
  /// server hasn't got, or another device saved since the last round. Only
  /// downloads the version number.
  Future<bool> needsSync() async {
    final key = _lastKey;
    if (key == null || lastVersion == null) return true;
    if (key != syncDocKey(store.syncDoc())) return true;
    return await remote.fetchVersion() != lastVersion;
  }

  Future<SyncOutcome> syncOnce() async {
    for (var attempt = 0; attempt < 5; attempt++) {
      final remoteDoc = await remote.fetch();
      // Read and apply without awaiting in between, so an edit made while
      // downloading is never overwritten.
      final local = store.syncDoc();
      final merged = remoteDoc == null
          ? local
          : mergeSyncDocs(local, remoteDoc.doc);
      var pulled = false;
      if (!sameSyncDoc(merged, local)) {
        pulled = true;
        await store.applySyncDoc(merged);
      }
      if (remoteDoc != null && sameSyncDoc(merged, remoteDoc.doc)) {
        lastVersion = remoteDoc.version;
        _lastKey = syncDocKey(merged);
        return pulled ? SyncOutcome.pulled : SyncOutcome.upToDate;
      }
      final version = remoteDoc == null
          ? await remote.create(merged)
          : await remote.replace(merged, remoteDoc.version);
      if (version != null) {
        lastVersion = version;
        _lastKey = syncDocKey(merged);
        return pulled ? SyncOutcome.pulledAndPushed : SyncOutcome.pushed;
      }
      // Another device saved in between: merge with theirs and retry.
    }
    throw SyncConflictException();
  }
}
