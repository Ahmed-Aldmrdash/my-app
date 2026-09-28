import 'dart:math';

final _random = Random();

/// Short unique id: time-based prefix plus a random suffix.
String newId() {
  final time = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  final rand = _random.nextInt(1 << 32).toRadixString(36).padLeft(7, '0');
  return '$time$rand';
}
