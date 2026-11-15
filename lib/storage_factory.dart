import 'storage.dart';
import 'storage_native.dart' if (dart.library.js_interop) 'storage_web.dart' as platform;

JournalStorage createJournalStorage() => platform.createJournalStorage();
