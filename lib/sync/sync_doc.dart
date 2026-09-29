import 'dart:convert';

import '../utils/json.dart';

/// The lists that are synced item by item. Every item has an `id`.
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
  if (v is! List) return const [];
  return [
    for (final e in v)
      if (e is Map && e['id'] is String) Map<String, dynamic>.from(e),
  ];
}

int _compareIds(Map<String, dynamic> a, Map<String, dynamic> b) =>
    (a['id'] as String).compareTo(b['id'] as String);

/// Picks between two versions of the same record. The newer one wins; on a
/// tie the choice only depends on the content, so every device agrees.
({Object? value, int at}) _pick(Object? a, int atA, Object? b, int atB) {
  if (atA != atB) return atA > atB ? (value: a, at: atA) : (value: b, at: atB);
  return canonicalJson(a).compareTo(canonicalJson(b)) >= 0
      ? (value: a, at: atA)
      : (value: b, at: atB);
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
  final out = <String, dynamic>{'v': 1};

  for (final col in syncedCollections) {
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
    canonicalJson(_normalized(a)) == canonicalJson(_normalized(b));

Map<String, dynamic> _normalized(Map<String, dynamic> doc) {
  final meta = SyncMeta.fromJson(doc['meta']);
  // Empty maps and missing ones mean the same thing.
  meta.stamps.removeWhere((_, v) => v.isEmpty);
  meta.tombs.removeWhere((_, v) => v.isEmpty);
  return {
    for (final col in syncedCollections)
      col: _items(doc[col])..sort(_compareIds),
    'settings': doc['settings'],
    'focus': doc['focus'],
    'meta': meta.toJson(),
  };
}
