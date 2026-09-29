import 'package:supabase_flutter/supabase_flutter.dart';

import 'sync_engine.dart';

/// Keeps each account's data as one row of the `planner_state` table (see
/// `supabase/setup.sql`), with a version number for safe concurrent saves.
class SupabaseRemote implements SyncRemote {
  SupabaseRemote(this.client, this.userId);

  static const table = 'planner_state';

  final SupabaseClient client;
  final String userId;
  RealtimeChannel? _channel;

  @override
  Future<RemoteDoc?> fetch() async {
    final row = await client
        .from(table)
        .select('data, version')
        .eq('user_id', userId)
        .maybeSingle();
    if (row == null) return null;
    return RemoteDoc(
      Map<String, dynamic>.from(row['data'] as Map),
      (row['version'] as num).toInt(),
    );
  }

  @override
  Future<int?> create(Map<String, dynamic> doc) async {
    try {
      await client.from(table).insert({
        'user_id': userId,
        'data': doc,
        'version': 1,
      });
      return 1;
    } on PostgrestException catch (e) {
      // Unique violation: another device created the row first.
      if (e.code == '23505') return null;
      rethrow;
    }
  }

  @override
  Future<int?> replace(Map<String, dynamic> doc, int expectedVersion) async {
    final next = expectedVersion + 1;
    final rows = await client
        .from(table)
        .update({
          'data': doc,
          'version': next,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('user_id', userId)
        .eq('version', expectedVersion)
        .select('version');
    return rows.isEmpty ? null : next;
  }

  /// Calls [onChange] with the new version whenever the row changes,
  /// including changes made by other devices.
  void listen(void Function(int? version) onChange) {
    _channel = client
        .channel('planner_state:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: table,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            final v = payload.newRecord['version'];
            onChange(v is num ? v.toInt() : null);
          },
        )
        .subscribe();
  }

  Future<void> close() async {
    final c = _channel;
    _channel = null;
    if (c != null) await client.removeChannel(c);
  }
}
