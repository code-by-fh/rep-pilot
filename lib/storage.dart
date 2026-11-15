abstract class JournalStorage {
  Future<String?> read();
  Future<void> write(String source);
}
