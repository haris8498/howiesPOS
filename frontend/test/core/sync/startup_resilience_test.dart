import 'dart:async';
import 'package:drift/native.dart';
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hungry_howies_pos/core/database/app_database.dart';
import 'package:hungry_howies_pos/core/network/api_client.dart';
import 'package:hungry_howies_pos/core/sync/connectivity_notifier.dart';
import 'package:hungry_howies_pos/core/sync/sync_background_worker.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FLT-11: Worker Startup Sequence and Resilience Tests', () {
    late AppDatabase db;
    late ConnectivityNotifier connectivityNotifier;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      db = AppDatabase(NativeDatabase.memory());
      connectivityNotifier = ConnectivityNotifier(
        apiClient: ApiClient(baseUrl: 'http://localhost:3000'),
        probeTimeout: const Duration(milliseconds: 100),
      );
    });

    tearDown(() async {
      connectivityNotifier.dispose();
      try {
        await db.close();
      } catch (_) {}
    });

    test('worker.start() initializes periodic timer and completes without throwing', () async {
      final worker = SyncBackgroundWorker(
        db: db,
        connectivityNotifier: connectivityNotifier,
        syncUrlOverride: 'http://localhost:3000/api',
        pollInterval: const Duration(milliseconds: 50),
      );

      // Verify start() completes successfully
      await expectLater(worker.start(), completes);

      worker.stop();
      worker.dispose();
    });

    test('worker.start() is resilient if db is closed or throws during post-timer steps', () async {
      // Close the DB before start to simulate a failure during recovery/outboxDao queries
      await db.close();

      final worker = SyncBackgroundWorker(
        db: db,
        connectivityNotifier: connectivityNotifier,
        syncUrlOverride: 'http://localhost:3000/api',
        pollInterval: const Duration(milliseconds: 50),
      );

      // start() should catch DB errors during startup steps and NOT rethrow
      await expectLater(worker.start(), completes);

      worker.stop();
      worker.dispose();
    });
  });
}
