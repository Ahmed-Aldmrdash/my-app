import 'dart:typed_data';

import 'image_export_io.dart'
    if (dart.library.js_interop) 'image_export_web.dart'
    as platform;

/// Hands a PNG to the student: saved to Downloads on computers, the share
/// sheet on phones, a download in the browser. Returns a message to show
/// (where it was saved), or null when the system UI already said enough.
Future<String?> exportPng(Uint8List bytes, String fileName) =>
    platform.exportPng(bytes, fileName);
