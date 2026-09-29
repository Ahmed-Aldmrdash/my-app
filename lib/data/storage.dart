import 'storage_io.dart'
    if (dart.library.js_interop) 'storage_web.dart'
    as platform;

/// Where the app's single JSON document is kept.
abstract class Storage {
  Future<String?> read();
  Future<void> write(String data);
}

/// A file on phones and computers, the browser's storage on the web.
Storage createDefaultStorage() => platform.createPlatformStorage();

/// In-memory storage for tests.
class MemoryStorage implements Storage {
  MemoryStorage([this.data]);

  String? data;

  @override
  Future<String?> read() async => data;

  @override
  Future<void> write(String data) async => this.data = data;
}
