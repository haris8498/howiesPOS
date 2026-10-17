import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import '../security/windows_dpapi.dart';

/// Default database file name
const String kDefaultDatabaseFileName = 'hungry_howies_pos.db';

/// Resolves the default persistent database file on disk.
/// On Windows desktop, prefers `%LOCALAPPDATA%\HungryHowies\hungry_howies_pos.db`.
/// Falls back to application support directory on other environments.
Future<File> getDefaultDatabaseFile() async {
  if (Platform.isWindows) {
    final localAppData = Platform.environment['LOCALAPPDATA'];
    if (localAppData != null && localAppData.isNotEmpty) {
      final dbFolder = Directory(p.join(localAppData, 'HungryHowies'));
      if (!dbFolder.existsSync()) {
        dbFolder.createSync(recursive: true);
      }
      return File(p.join(dbFolder.path, kDefaultDatabaseFileName));
    }
  }

  final appDir = await getApplicationSupportDirectory();
  final dbFolder = Directory(appDir.path);
  if (!dbFolder.existsSync()) {
    dbFolder.createSync(recursive: true);
  }
  return File(p.join(dbFolder.path, kDefaultDatabaseFileName));
}

/// Applies standard SQLite pragmas per Architecture Spec §5.1:
/// - PRAGMA key = "x'<64-char-hex>'";
/// - PRAGMA cipher_page_size = 4096;
/// - PRAGMA kdf_iter = 64000;
/// - PRAGMA journal_mode = WAL;
/// - PRAGMA synchronous = NORMAL;
/// - PRAGMA busy_timeout = 5000;
/// - PRAGMA foreign_keys = ON;
void applySpecPragmas(Database rawDb, {String? encryptionKeyHex}) {
  if (encryptionKeyHex != null && encryptionKeyHex.isNotEmpty) {
    rawDb.execute("PRAGMA key = \"x'$encryptionKeyHex'\";");
    rawDb.execute('PRAGMA cipher_page_size = 4096;');
    rawDb.execute('PRAGMA kdf_iter = 64000;');
  }

  rawDb.execute('PRAGMA journal_mode = WAL;');
  rawDb.execute('PRAGMA synchronous = NORMAL;');
  rawDb.execute('PRAGMA busy_timeout = 5000;');
  rawDb.execute('PRAGMA foreign_keys = ON;');
}

/// Creates a synchronous or background [QueryExecutor] pointing to [file],
/// encrypted with [encryptionKeyHex] and configured with §5.1 pragmas.
QueryExecutor createEncryptedExecutor(
  File file, {
  String? encryptionKeyHex,
  bool inBackground = false,
  bool logStatements = false,
}) {
  void setup(Database rawDb) {
    applySpecPragmas(rawDb, encryptionKeyHex: encryptionKeyHex);
  }

  if (inBackground) {
    return NativeDatabase.createInBackground(
      file,
      setup: setup,
      logStatements: logStatements,
    );
  } else {
    return NativeDatabase(
      file,
      setup: setup,
      logStatements: logStatements,
    );
  }
}

/// Creates a lazily-opened encrypted Drift database connection factory.
///
/// Can be provided directly to Drift `AppDatabase(openEncryptedConnection())`.
/// If [encryptionKeyHex] is omitted, derives/retrieves it automatically
/// via Windows user-scope DPAPI on Windows desktop.
LazyDatabase openEncryptedConnection({
  File? file,
  String? encryptionKeyHex,
  bool inBackground = false,
  bool logStatements = false,
}) {
  return LazyDatabase(() async {
    final targetFile = file ?? await getDefaultDatabaseFile();
    final keyHex = encryptionKeyHex ??
        (Platform.isWindows
            ? WindowsDpapi.getOrCreateSqlCipherKeyHex()
            : null);

    return createEncryptedExecutor(
      targetFile,
      encryptionKeyHex: keyHex,
      inBackground: inBackground,
      logStatements: logStatements,
    );
  });
}
