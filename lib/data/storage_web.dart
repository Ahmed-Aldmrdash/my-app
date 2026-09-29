import 'package:shared_preferences/shared_preferences.dart';

import 'storage.dart';

Storage createPlatformStorage() => WebStorage();

/// Keeps the data in the browser's local storage.
class WebStorage implements Storage {
  static const _key = 'study_planner_data';

  @override
  Future<String?> read() async =>
      (await SharedPreferences.getInstance()).getString(_key);

  @override
  Future<void> write(String data) async {
    await (await SharedPreferences.getInstance()).setString(_key, data);
  }
}
