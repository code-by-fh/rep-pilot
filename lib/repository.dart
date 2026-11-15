import 'model.dart';
import 'storage.dart';
import 'storage_factory.dart';

export 'storage.dart';

class JournalRepository {
  final JournalStorage _storage;
  Journal? _journal;
  bool _loaded = false;
  Future<Journal>? _loading;
  Future<void> _pending = Future<void>.value();

  JournalRepository({JournalStorage? storage}) : _storage = storage ?? createJournalStorage();

  Journal? get journal => _journal;

  Future<Journal> load() {
    if (_loaded) return Future.value(_journal!);
    return _loading ??= _load();
  }

  Future<Journal> _load() async {
    try {
      final source = await _storage.read();
      final result = source == null ? Journal.empty() : Journal.fromBackupJson(source);
      _journal = result;
      _loaded = true;
      return result;
    } finally {
      _loading = null;
    }
  }

  Future<void> save(Journal journal) {
    if (!_loaded) {
      return Future.error(StateError('Load the journal successfully before saving.'));
    }
    final operation = _pending.then((_) async {
      await _storage.write(journal.toBackupJson());
      _journal = journal;
    });
    _pending = operation.then((_) {}, onError: (Object _, StackTrace __) {});
    return operation;
  }
}
