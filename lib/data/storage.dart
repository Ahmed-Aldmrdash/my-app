import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Where the app's single JSON document is kept.
abstract class Storage {
  Future<String?> read();
  Future<void> write(String data);
}

/// Stores the data in the app's private support directory. Writes go to a
/// temporary file first and are then renamed, so a crash mid-write never
/// leaves a half-written file behind.
class FileStorage implements Storage {
  FileStorage({this.fileName = 'study_planner_data.json'});

  final String fileName;
  Future<void> _pending = Future.value();

  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}${Platform.pathSeparator}$fileName');
  }

  @override
  Future<String?> read() async {
    final file = await _file();
    if (!await file.exists()) return null;
    return file.readAsString();
  }

  @override
  Future<void> write(String data) {
    // Serialise writes so an older snapshot can never overwrite a newer one.
    return _pending = _pending.then((_) async {
      final file = await _file();
      await file.parent.create(recursive: true);
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsString(data, flush: true);
      await tmp.rename(file.path);
    });
  }
}

/// In-memory storage for tests.
class MemoryStorage implements Storage {
  MemoryStorage([this.data]);

  String? data;

  @override
  Future<String?> read() async => data;

  @override
  Future<void> write(String data) async => this.data = data;
}
