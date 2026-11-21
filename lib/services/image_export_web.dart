import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

Future<String?> exportPng(Uint8List bytes, String fileName) async {
  // Browsers without file sharing download the image instead.
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile.fromData(bytes, mimeType: 'image/png', name: fileName)],
      fileNameOverrides: [fileName],
    ),
  );
  return null;
}
