/// Tolerant JSON readers, so that older or partially-corrupted saves still
/// load instead of crashing the app.
library;

T enumByName<T extends Enum>(List<T> values, Object? name, T fallback) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}

DateTime? readDate(Object? v) => v is String ? DateTime.tryParse(v) : null;

String? writeDate(DateTime? d) => d?.toIso8601String();

double readDouble(Object? v, [double fallback = 0]) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? fallback;
  return fallback;
}

int readInt(Object? v, [int fallback = 0]) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? fallback;
  return fallback;
}

String readString(Object? v, [String fallback = '']) =>
    v is String ? v : fallback;

String? readNullableString(Object? v) => v is String && v.isNotEmpty ? v : null;

bool readBool(Object? v, [bool fallback = false]) => v is bool ? v : fallback;

List<int> readIntList(Object? v, [List<int> fallback = const []]) {
  if (v is! List) return fallback;
  return v.whereType<num>().map((e) => e.toInt()).toList();
}

List<T> readList<T>(Object? v, T Function(Map<String, dynamic>) parse) {
  if (v is! List) return <T>[];
  final out = <T>[];
  for (final e in v) {
    if (e is Map) {
      try {
        out.add(parse(Map<String, dynamic>.from(e)));
      } catch (_) {
        // Skip a single malformed record rather than losing everything.
      }
    }
  }
  return out;
}
