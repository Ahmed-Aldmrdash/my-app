import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Which Supabase project holds the synced data.
class SyncConfig {
  const SyncConfig({required this.url, required this.key});

  /// e.g. https://abcdefghijklmnop.supabase.co
  final String url;

  /// The project's publishable (anon) key. It is meant to be public; the
  /// table's row-level security keeps each account's data private.
  final String key;

  /// Can be baked into a build with
  /// `--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_KEY=...`.
  static const _defaultUrl = String.fromEnvironment('SUPABASE_URL');
  static const _defaultKey = String.fromEnvironment('SUPABASE_KEY');

  static const _urlPref = 'sync.url';
  static const _keyPref = 'sync.key';
  static const _codePrefix = 'SP1:';

  static SyncConfig? get builtIn => _defaultUrl.isEmpty || _defaultKey.isEmpty
      ? null
      : SyncConfig(url: _defaultUrl, key: _defaultKey);

  static Future<SyncConfig?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString(_urlPref);
    final key = prefs.getString(_keyPref);
    if (url != null && key != null) return SyncConfig(url: url, key: key);
    return builtIn;
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_urlPref, url);
    await prefs.setString(_keyPref, key);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_urlPref);
    await prefs.remove(_keyPref);
  }

  /// Checks and tidies what the student typed. Throws [FormatException]
  /// with an Arabic message when something is off.
  static SyncConfig parse(String url, String key) {
    var u = url.trim();
    final k = key.trim();
    if (u.isEmpty || k.isEmpty) {
      throw const FormatException('اكتب رابط المشروع والمفتاح');
    }
    if (!u.startsWith('http')) u = 'https://$u';
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    final uri = Uri.tryParse(u);
    if (uri == null || uri.host.isEmpty || !uri.host.contains('.')) {
      throw const FormatException(
        'الرابط مش مظبوط — لازم يبقى زي https://xxxx.supabase.co',
      );
    }
    if (k.length < 20 || k.contains(' ')) {
      throw const FormatException('المفتاح مش مظبوط — انسخه تاني من Supabase');
    }
    return SyncConfig(url: u, key: k);
  }

  /// One string holding both values, easy to send to another device.
  String toLinkCode() =>
      _codePrefix +
      base64Url
          .encode(utf8.encode(jsonEncode({'u': url, 'k': key})))
          .replaceAll('=', '');

  static SyncConfig? fromLinkCode(String code) {
    final c = code.trim();
    if (!c.startsWith(_codePrefix)) return null;
    try {
      var body = c.substring(_codePrefix.length);
      body = body.padRight((body.length + 3) ~/ 4 * 4, '=');
      final j = jsonDecode(utf8.decode(base64Url.decode(body)));
      if (j is! Map) return null;
      return parse('${j['u']}', '${j['k']}');
    } catch (_) {
      return null;
    }
  }
}
