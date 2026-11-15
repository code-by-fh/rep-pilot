import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'storage.dart';

JournalStorage createJournalStorage() => FileJournalStorage();

class FileJournalStorage implements JournalStorage {
  final Future<Directory> Function() _directory;
  FileJournalStorage({Future<Directory> Function()? directory})
      : _directory = directory ?? getApplicationSupportDirectory;

  Future<File> _file() async {
    final directory = await _directory();
    await directory.create(recursive: true);
    return File('${directory.path}${Platform.pathSeparator}rep-pilot-journal.json');
  }

  @override
  Future<String?> read() async {
    final file = await _file();
    if (!await file.exists()) return null;
    return file.readAsString();
  }

  @override
  Future<void> write(String source) async {
    final file = await _file();
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(source, flush: true);
    // Rename in the same directory replaces the file without a delete gap.
    // A failed rename reports the error; no delete-and-rewrite fallback is used.
    await temporary.rename(file.path);
  }
}
