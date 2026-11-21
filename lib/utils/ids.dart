import 'dart:math';

final _random = Random();

/// Short unique id: time-based prefix plus a random suffix.
String newId() {
  final time = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  // Not `1 << 32`: on the web shifts are 32-bit, so that is 0 and nextInt
  // throws, which broke adding anything in the browser version.
  final rand = _random.nextInt(0x7fffffff).toRadixString(36).padLeft(6, '0');
  return '$time$rand';
}
