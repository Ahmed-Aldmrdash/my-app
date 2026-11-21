import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<String?> exportPng(Uint8List bytes, String fileName) async {
  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    final dir =
        await getDownloadsDirectory() ??
        await getApplicationDocumentsDirectory();
    final file = File('${dir.path}${Platform.pathSeparator}$fileName');
    await file.writeAsBytes(bytes, flush: true);
    return 'اتحفظت الصورة في ${file.path}';
  }
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile.fromData(bytes, mimeType: 'image/png', name: fileName)],
      fileNameOverrides: [fileName],
    ),
  );
  return null;
}
