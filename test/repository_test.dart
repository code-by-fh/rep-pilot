import 'dart:async';
import 'dart:io';
import 'package:rep_pilot/storage_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rep_pilot/model.dart';
import 'package:rep_pilot/repository.dart';

class MemoryStorage implements JournalStorage {
  String? source;
  Object? readError;
  Object? writeError;
  Completer<void>? writeGate;
  int writes = 0;
  @override
  Future<String?> read() async {
    if (readError != null) throw readError!;
    return source;
  }
  @override
  Future<void> write(String value) async {
    writes++;
    await writeGate?.future;
    if (writeError != null) throw writeError!;
    source = value;
  }
}

void main() {
  test('native storage replaces existing files and preserves bytes on write failure', () async {
    final directory = await Directory.systemTemp.createTemp('rep-pilot-storage-test-');
    addTearDown(() => directory.delete(recursive: true));
    final storage = FileJournalStorage(directory: () async => directory);
    expect(await storage.read(), isNull);
    await storage.write('first');
    await storage.write('second');
    expect(await storage.read(), 'second');
    final temporary = Directory('${directory.path}${Platform.pathSeparator}rep-pilot-journal.json.tmp');
    await temporary.create();
    await expectLater(storage.write('third'), throwsA(isA<FileSystemException>()));
    expect(await storage.read(), 'second');
    await temporary.delete();
    await storage.write('{invalid');
    final repository = JournalRepository(storage: storage);
    await expectLater(repository.load(), throwsFormatException);
    await expectLater(repository.save(Journal.empty()), throwsStateError);
    expect(await storage.read(), '{invalid');
  });
  test('missing storage offers starter exercises without writing', () async {
    final storage = MemoryStorage();
    final repository = JournalRepository(storage: storage);
    final journal = await repository.load();
    expect(journal.exercises, isNotEmpty);
    expect(journal.workouts, isEmpty);
    expect(storage.writes, 0);
    expect(storage.source, isNull);
  });

  test('stored empty journal is preserved', () async {
    final storage = MemoryStorage()..source = Journal(exercises: [], workouts: []).toBackupJson();
    final result = await JournalRepository(storage: storage).load();
    expect(result.exercises, isEmpty);
  });

  test('corrupt or unreadable storage cannot be overwritten', () async {
    final storage = MemoryStorage()..source = '{broken';
    final repository = JournalRepository(storage: storage);
    await expectLater(repository.load(), throwsFormatException);
    await expectLater(repository.save(Journal.empty()), throwsStateError);
    expect(storage.source, '{broken');
    expect(storage.writes, 0);
    storage.readError = StateError('Unavailable');
    await expectLater(repository.load(), throwsStateError);
    await expectLater(repository.save(Journal.empty()), throwsStateError);
    expect(storage.writes, 0);
  });

  test('save waits for durability and keeps old state on failure', () async {
    final storage = MemoryStorage();
    final repository = JournalRepository(storage: storage);
    final original = await repository.load();
    final changed = Journal(exercises: [], workouts: []);
    storage.writeGate = Completer<void>();
    final save = repository.save(changed);
    await Future<void>.delayed(Duration.zero);
    expect(repository.journal, same(original));
    expect(storage.source, isNull);
    storage.writeGate!.complete();
    await save;
    expect(repository.journal, same(changed));
    final durable = storage.source;
    storage.writeError = StateError('Disk full');
    await expectLater(repository.save(original), throwsStateError);
    expect(repository.journal, same(changed));
    expect(storage.source, durable);
    storage.writeError = null;
    await repository.save(original);
    expect(repository.journal, same(original));
    expect(Journal.fromBackupJson(storage.source!).toJson(), original.toJson());
  });

  test('concurrent saves retain call order', () async {
    final storage = MemoryStorage();
    final repository = JournalRepository(storage: storage);
    await repository.load();
    final first = Journal(exercises: [Exercise(id: 'first', name: 'First')], workouts: []);
    final last = Journal(exercises: [Exercise(id: 'last', name: 'Last')], workouts: []);
    await Future.wait([repository.save(first), repository.save(last)]);
    expect(repository.journal, same(last));
    expect(Journal.fromBackupJson(storage.source!).exercises.single.id, 'last');
  });
}
