import 'dart:convert';
import 'dart:math' as math;

import '../utils/json.dart';

/// The format of the sync documents this app writes (`v`).
///
/// From format 2 on, an app keeps what it doesn't understand instead of
/// dropping it: records, settings and the focus timer it didn't edit are
/// written back exactly as they came, and lists of records added by newer
/// versions are merged like the known ones. Newer versions must therefore
/// only add lists of records with a string `id`, fields inside records, and
/// settings; other new top-level keys would be dropped. A merged document
/// always says this app's format, even when it carries data a newer app
/// wrote, so `v` must never decide whether data needs migrating.
const syncFormat = 2;

/// The oldest format allowed to save once this app has saved (`minFormat`).
/// Format-1 apps drop data they don't understand, so the server refuses
/// their saves (see `supabase/setup.sql`). A newer version raises it when
/// apps on an older format can no longer save safely; merging keeps the
/// highest value seen.
const minWriterFormat = 2;

/// Keys of a sync document that are not lists of records.
const _notCollections = {
  'v',
  'minFormat',
  'version',
  'settings',
  'focus',
  'meta',
};

/// The lists this app version syncs item by item. Every item has an `id`.
/// Lists added by newer versions are synced too, just without being read.
const syncedCollections = <String>[
  'subjects',
  'sessions',
  'studyItems',
  'tasks',
  'assessments',
  'projects',
  'grades',
  'studySessions',
  'attendance',
  'finals',
  'planEntries',
  'notes',
  'flashcards',
  'semesters',
  'planCourses',
  'contacts',
  'groups',
  'calendar',
  'achievements',
  'applications',
  'expenses',
];

/// When each synced record was last changed or deleted on any device, in
/// milliseconds since epoch. Merging keeps the newest version of every
/// record, and a deletion wins over any older edit.
class SyncMeta {
  SyncMeta({
    Map<String, Map<String, int>>? stamps,
    Map<String, Map<String, int>>? tombs,
    this.settingsAt = 0,
    this.focusAt = 0,
  }) : stamps = stamps ?? {},
       tombs = tombs ?? {};

  /// collection → id → time of the last change.
  final Map<String, Map<String, int>> stamps;

  /// collection → id → time of deletion.
  final Map<String, Map<String, int>> tombs;
  int settingsAt;
  int focusAt;

  Map<String, dynamic> toJson() => {
    'stamps': stamps,
    'tombs': tombs,
    'settingsAt': settingsAt,
    'focusAt': focusAt,
  };

  factory SyncMeta.fromJson(Object? raw) {
    if (raw is! Map) return SyncMeta();
    Map<String, Map<String, int>> nested(Object? v) {
      final out = <String, Map<String, int>>{};
      if (v is! Map) return out;
      v.forEach((col, ids) {
        if (col is! String || ids is! Map) return;
        final m = <String, int>{};
        ids.forEach((id, t) {
          if (id is String && t is num) m[id] = t.toInt();
        });
        out[col] = m;
      });
      return out;
    }

    return SyncMeta(
      stamps: nested(raw['stamps']),
      tombs: nested(raw['tombs']),
      settingsAt: readInt(raw['settingsAt']),
      focusAt: readInt(raw['focusAt']),
    );
  }
}

/// [raw] with the fields that changed from [before] to [now] put on top.
///
/// [before] and [now] are what this app made of a record before and after an
/// edit; [raw] is the record as it was stored, possibly with fields and
/// values only a newer version understands. Only what the edit changed is
/// written over it, and lists of records (maps with an `id`, like a
/// project's steps) are handled element by element the same way.
Map<String, dynamic> overlayChanges(
  Map<String, dynamic> raw,
  Map<String, dynamic> before,
  Map<String, dynamic> now,
) {
  final out = Map<String, dynamic>.of(raw);
  now.forEach((key, value) {
    final old = before[key];
    if (canonicalJson(old) == canonicalJson(value)) return;
    out[key] = _overlayValue(raw[key], old, value);
  });
  return out;
}

Object? _overlayValue(Object? raw, Object? before, Object? now) {
  if (raw is Map && before is Map && now is Map) {
    return overlayChanges(
      Map<String, dynamic>.from(raw),
      Map<String, dynamic>.from(before),
      Map<String, dynamic>.from(now),
    );
  }
  if (raw is List && before is List && now is List) {
    Map<String, Map<String, dynamic>> byId(List<Object?> list) => {
      for (final e in list)
        if (e is Map && e['id'] is String)
          e['id'] as String: Map<String, dynamic>.from(e),
    };
    final rawById = byId(raw);
    final beforeById = byId(before);
    return [
      for (final e in now)
        if (e is Map && rawById[e['id']] != null && beforeById[e['id']] != null)
          overlayChanges(
            rawById[e['id']]!,
            beforeById[e['id']]!,
            Map<String, dynamic>.from(e),
          )
        else
          e,
    ];
  }
  return now;
}

/// JSON with object keys sorted, so equal data always encodes the same.
String canonicalJson(Object? value) => jsonEncode(_sortKeys(value));

Object? _sortKeys(Object? v) {
  if (v is Map) {
    final keys = v.keys.map((k) => k.toString()).toList()..sort();
    return {for (final k in keys) k: _sortKeys(v[k])};
  }
  if (v is List) return v.map(_sortKeys).toList();
  return v;
}

List<Map<String, dynamic>> _items(Object? v) {
  if (v is! List) return [];
  return [
    for (final e in v)
      if (e is Map && e['id'] is String) Map<String, dynamic>.from(e),
  ];
}

int _compareIds(Map<String, dynamic> a, Map<String, dynamic> b) =>
    (a['id'] as String).compareTo(b['id'] as String);

/// Picks between two versions of the same record. The newer one wins. On a
/// tie the one with more fields wins: that is an older app's copy that lost
/// the fields a newer version added. Otherwise the choice only depends on the
/// content, so every device agrees.
({Object? value, int at}) _pick(Object? a, int atA, Object? b, int atB) {
  if (atA != atB) return atA > atB ? (value: a, at: atA) : (value: b, at: atB);
  final byFields = _fieldCount(a).compareTo(_fieldCount(b));
  if (byFields != 0) {
    return byFields > 0 ? (value: a, at: atA) : (value: b, at: atB);
  }
  return canonicalJson(a).compareTo(canonicalJson(b)) >= 0
      ? (value: a, at: atA)
      : (value: b, at: atB);
}

int _fieldCount(Object? v) => v is Map ? v.length : 0;

/// Every collection in [docs]: the known ones plus any list a newer app
/// version added, in a fixed order.
List<String> _collectionsIn(Iterable<Map<String, dynamic>> docs) {
  final names = <String>{...syncedCollections};
  for (final doc in docs) {
    doc.forEach((key, value) {
      if (value is List && !_notCollections.contains(key)) names.add(key);
    });
    final meta = SyncMeta.fromJson(doc['meta']);
    names
      ..addAll(meta.stamps.keys)
      ..addAll(meta.tombs.keys);
  }
  return names.toList()..sort();
}

/// Combines two sync documents (usually this device's and the server's)
/// record by record. The result does not depend on which side is [a] and
/// which is [b], so all devices converge on the same data.
Map<String, dynamic> mergeSyncDocs(
  Map<String, dynamic> a,
  Map<String, dynamic> b,
) {
  final metaA = SyncMeta.fromJson(a['meta']);
  final metaB = SyncMeta.fromJson(b['meta']);
  final meta = SyncMeta();
  final out = <String, dynamic>{
    'v': syncFormat,
    'minFormat': math.max(
      minWriterFormat,
      math.max(readInt(a['minFormat'], 1), readInt(b['minFormat'], 1)),
    ),
  };

  for (final col in _collectionsIn([a, b])) {
    final itemsA = {for (final i in _items(a[col])) i['id'] as String: i};
    final itemsB = {for (final i in _items(b[col])) i['id'] as String: i};
    final stampsA = metaA.stamps[col] ?? const <String, int>{};
    final stampsB = metaB.stamps[col] ?? const <String, int>{};

    final tombs = <String, int>{};
    for (final t in [metaA.tombs[col], metaB.tombs[col]]) {
      t?.forEach((id, at) {
        if (at > (tombs[id] ?? -1)) tombs[id] = at;
      });
    }

    final stamps = <String, int>{};
    final merged = <Map<String, dynamic>>[];
    for (final id in {...itemsA.keys, ...itemsB.keys}) {
      final ia = itemsA[id];
      final ib = itemsB[id];
      final ({Object? value, int at}) winner;
      if (ia != null && ib != null) {
        winner = _pick(ia, stampsA[id] ?? 0, ib, stampsB[id] ?? 0);
      } else if (ia != null) {
        winner = (value: ia, at: stampsA[id] ?? 0);
      } else {
        winner = (value: ib, at: stampsB[id] ?? 0);
      }
      final deletedAt = tombs[id];
      if (deletedAt != null && deletedAt >= winner.at) continue;
      // Edited again after it was deleted somewhere: it is alive.
      tombs.remove(id);
      merged.add(winner.value! as Map<String, dynamic>);
      if (winner.at > 0) stamps[id] = winner.at;
    }
    merged.sort(_compareIds);
    out[col] = merged;
    meta.stamps[col] = stamps;
    meta.tombs[col] = tombs;
  }

  final settings = _pick(
    a['settings'],
    metaA.settingsAt,
    b['settings'],
    metaB.settingsAt,
  );
  out['settings'] = settings.value;
  meta.settingsAt = settings.at;

  final focus = _pick(a['focus'], metaA.focusAt, b['focus'], metaB.focusAt);
  out['focus'] = focus.value;
  meta.focusAt = focus.at;

  out['meta'] = meta.toJson();
  return out;
}

/// Whether two sync documents hold the same data, ignoring list order.
bool sameSyncDoc(Map<String, dynamic> a, Map<String, dynamic> b) =>
    syncDocKey(a) == syncDocKey(b);

/// A string that is equal for two documents exactly when they hold the
/// same data.
String syncDocKey(Map<String, dynamic> doc) => canonicalJson(_normalized(doc));

Map<String, dynamic> _normalized(Map<String, dynamic> doc) {
  final meta = SyncMeta.fromJson(doc['meta']);
  // Empty maps and missing ones mean the same thing.
  meta.stamps.removeWhere((_, v) => v.isEmpty);
  meta.tombs.removeWhere((_, v) => v.isEmpty);
  return {
    'minFormat': readInt(doc['minFormat'], 1),
    for (final col in _collectionsIn([doc]))
      col: _items(doc[col])..sort(_compareIds),
    'settings': doc['settings'],
    'focus': doc['focus'],
    'meta': meta.toJson(),
  };
}
