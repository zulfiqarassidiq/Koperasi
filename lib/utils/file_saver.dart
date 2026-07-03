import 'file_saver_stub.dart'
    if (dart.library.html) 'file_saver_web.dart'
    if (dart.library.io) 'file_saver_io.dart';

/// Menyimpan file ke sistem perangkat pengguna dengan dukungan multi-platform.
/// Web: menggunakan HTML anchor untuk mendownload file.
/// IO (Android/Windows): menyimpan file ke Application Documents Directory.
Future<void> saveFileBytes(List<int> bytes, String filename, String mimeType) async {
  await saveFileBytesImpl(bytes, filename, mimeType);
}
