import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

Future<void> saveFileBytesImpl(List<int> bytes, String filename, String mimeType) async {
  try {
    Directory? directory;
    if (Platform.isAndroid) {
      directory = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
    } else {
      directory = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
    }
    final file = File('${directory.path}/$filename');
    await file.writeAsBytes(bytes);
    debugPrint('File saved to: ${file.path}');
  } catch (e) {
    debugPrint('Failed to save file: $e');
  }
}
