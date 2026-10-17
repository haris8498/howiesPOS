import 'dart:io';
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hungry_howies_pos/core/database/encrypted_connection.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  const keyA = 'a1b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718293a4b5c6d7e8f90';
  const keyB = 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';

  group('Encrypted Connection & Pragmas Tests (§5.1)', () {
    late Directory tempDir;
    late File testDbFile;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('drift_test_db_');
      testDbFile = File('${tempDir.path}${Platform.pathSeparator}test_pos.db');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('applySpecPragmas sets WAL mode, synchronous NORMAL, busy_timeout, foreign_keys', () {
      final db = sqlite.sqlite3.open(testDbFile.path);
      applySpecPragmas(db, encryptionKeyHex: keyA);

      final journalMode = db.select('PRAGMA journal_mode;').first.values.first;
      expect(journalMode.toString().toLowerCase(), equals('wal'));

      final synchronous = db.select('PRAGMA synchronous;').first.values.first;
      // SQLite PRAGMA synchronous NORMAL returns 1
      expect(synchronous, equals(1));

      final busyTimeout = db.select('PRAGMA busy_timeout;').first.values.first;
      expect(busyTimeout, equals(5000));

      final foreignKeys = db.select('PRAGMA foreign_keys;').first.values.first;
      expect(foreignKeys, equals(1));

      db.close();
    });

    test('createEncryptedExecutor writes encrypted DB and succeeds with correct key', () async {
      final executor1 = createEncryptedExecutor(testDbFile, encryptionKeyHex: keyA);
      await executor1.ensureOpen(_FakeQueryExecutorUser());

      await executor1.runCustom('CREATE TABLE orders (id TEXT PRIMARY KEY, amount REAL);');
      await executor1.runInsert('INSERT INTO orders (id, amount) VALUES (?, ?);', ['ord_001', 99.50]);
      await executor1.close();

      // Open with correct key
      final executor2 = createEncryptedExecutor(testDbFile, encryptionKeyHex: keyA);
      await executor2.ensureOpen(_FakeQueryExecutorUser());
      final result = await executor2.runSelect('SELECT id, amount FROM orders WHERE id = ?;', ['ord_001']);
      expect(result.length, equals(1));
      expect(result.first['id'], equals('ord_001'));
      expect(result.first['amount'], equals(99.50));
      await executor2.close();
    });

    test('createEncryptedExecutor fails when opened with wrong key', () async {
      // 1. Create and populate with keyA
      final executor1 = createEncryptedExecutor(testDbFile, encryptionKeyHex: keyA);
      await executor1.ensureOpen(_FakeQueryExecutorUser());
      await executor1.runCustom('CREATE TABLE vault (secret TEXT);');
      await executor1.runInsert('INSERT INTO vault (secret) VALUES (?);', ['sensitive-passcode']);
      await executor1.close();

      // 2. Attempt to open with wrong keyB fails during opening/setup
      final executorWrongKey = createEncryptedExecutor(testDbFile, encryptionKeyHex: keyB);
      expect(
        () => executorWrongKey.ensureOpen(_FakeQueryExecutorUser()),
        throwsA(anyOf(
          isA<sqlite.SqliteException>(),
          isA<DriftWrappedException>(),
        )),
      );

      await executorWrongKey.close();
    });

    test('createEncryptedExecutor fails when opened without key', () async {
      // 1. Create and populate with keyA
      final executor1 = createEncryptedExecutor(testDbFile, encryptionKeyHex: keyA);
      await executor1.ensureOpen(_FakeQueryExecutorUser());
      await executor1.runCustom('CREATE TABLE vault (secret TEXT);');
      await executor1.runInsert('INSERT INTO vault (secret) VALUES (?);', ['sensitive-passcode']);
      await executor1.close();

      // 2. Attempt to open with null key fails during opening/setup
      final executorNoKey = createEncryptedExecutor(testDbFile, encryptionKeyHex: null);
      expect(
        () => executorNoKey.ensureOpen(_FakeQueryExecutorUser()),
        throwsA(anyOf(
          isA<sqlite.SqliteException>(),
          isA<DriftWrappedException>(),
        )),
      );

      await executorNoKey.close();
    });

    test('openEncryptedConnection returns LazyDatabase executor', () async {
      final lazyDb = openEncryptedConnection(
        file: testDbFile,
        encryptionKeyHex: keyA,
      );

      await lazyDb.ensureOpen(_FakeQueryExecutorUser());
      await lazyDb.runCustom('CREATE TABLE ping (status TEXT);');
      await lazyDb.runInsert('INSERT INTO ping (status) VALUES (?);', ['pong']);

      final rows = await lazyDb.runSelect('SELECT status FROM ping;', []);
      expect(rows.first['status'], equals('pong'));
      await lazyDb.close();
    });
  });
}

class _FakeQueryExecutorUser extends QueryExecutorUser {
  @override
  int get schemaVersion => 1;

  @override
  Future<void> beforeOpen(QueryExecutor executor, OpeningDetails details) async {}
}
