import 'package:shared_preferences/shared_preferences.dart';
import 'storage.dart';

JournalStorage createJournalStorage() => BrowserJournalStorage();

class BrowserJournalStorage implements JournalStorage {
  static const _key = 'rep-pilot-journal-v1';
  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();
  @override
  Future<String?> read() => _preferences.getString(_key);
  @override
  Future<void> write(String source) => _preferences.setString(_key, source);
}
