import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hungry_howies_pos/core/database/app_database.dart';
import 'package:hungry_howies_pos/core/database/tables/local_daily_calculations_table.dart';
import 'package:hungry_howies_pos/core/sync/connectivity_notifier.dart';
import 'package:hungry_howies_pos/core/sync/sync_background_worker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late HttpServer fakeServer;
  late String serverUrl;
  late ConnectivityNotifier connectivityNotifier;

  setUp(() async {
    HttpOverrides.global = null;
    SharedPreferences.setMockInitialValues({});

    db = AppDatabase(
      NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('PRAGMA foreign_keys = ON;');
        },
      ),
    );

    fakeServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    serverUrl = 'http://127.0.0.1:${fakeServer.port}';

    fakeServer.listen((req) async {
      if (req.uri.path == '/health') {
        req.response.statusCode = 200;
        req.response.headers.contentType = ContentType.json;
        req.response.write(jsonEncode({'status': 'ok'}));
        await req.response.close();
        return;
      }
      req.response.statusCode = 404;
      await req.response.close();
    });

    connectivityNotifier = ConnectivityNotifier(
      healthEndpointOverride: '$serverUrl/health',
    );
    connectivityNotifier.setOnlineManually();
  });

  tearDown(() async {
    connectivityNotifier.dispose();
    await fakeServer.close(force: true);
    await db.close();
  });

  SyncBackgroundWorker createWorker() {
    return SyncBackgroundWorker(
      db: db,
      connectivityNotifier: connectivityNotifier,
      syncUrlOverride: serverUrl,
      deviceId: 'POS-P1',
    );
  }

  group('T-04: Delta Pull Overwrite of Local Shift Closure (SYNC-004)', () {
    test('Offline shift closure and counted cash are preserved when delta pull arrives with ACTIVE status', () async {
      final worker = createWorker();
      const shiftId = '019283a0-0000-7000-8000-000000000001';

      // 1. Terminal P1 creates shift 'shift-1'
      await db.dailyCalculationsDao.insertCalculation(
        LocalDailyCalculationsCompanion(
          id: const Value(shiftId),
          cashierId: const Value('cashier-p1'),
          cashierName: const Value('Terminal P1 Cashier'),
          startingCash: const Value(5000.0),
          expectedCashDrawer: const Value(5000.0),
          status: const Value(DailyCalculationStatus.active),
          syncStatus: const Value('synced'),
          serverVersion: const Value(1),
        ),
      );

      // 2. Cashier closes shift on P1 offline: enters counted cash PKR 15,000; status becomes OFFLINE_CLOSED
      await db.dailyCalculationsDao.closeShiftOffline(
        id: shiftId,
        actualCashCounted: 15000.0,
        expectedCashDrawer: 15200.0,
        cashVariance: -200.0,
        closingNotes: 'Shift closed offline at end of day',
      );

      final locallyClosedShift = await db.dailyCalculationsDao.getCalculationById(shiftId);
      expect(locallyClosedShift!.status, DailyCalculationStatus.offlineClosed);
      expect(locallyClosedShift.actualCashCounted, 15000.0);
      expect(locallyClosedShift.cashVariance, -200.0);

      // 3. Simulate server returning delta pull change log where shift is ACTIVE and actual_cash_counted: null
      final incomingServerDelta = {
        'sequence': 105,
        'entity_type': 'shift',
        'entity_id': shiftId,
        'record_version': 2,
        'operation': 'UPDATE',
        'is_deleted': false,
        'payload': {
          'status': 'ACTIVE',
          'actual_cash_counted': null,
          'cash_variance': 0.0,
          'starting_cash': 5000.0,
          'cashier_id': 'cashier-p1',
        },
      };

      // 4. Invoke applyPullChange(). Query local Drift LocalDailyCalculations
      final applyResult = await worker.applyPullChange(incomingServerDelta);
      expect(applyResult, PullApplyResult.applied);

      final finalShift = await db.dailyCalculationsDao.getCalculationById(shiftId);
      expect(finalShift, isNotNull);

      // Expected Correct Behavior: Local OFFLINE_CLOSED status and PKR 15,000 counted cash are preserved!
      expect(finalShift!.status, DailyCalculationStatus.offlineClosed);
      expect(finalShift.actualCashCounted, 15000.0);
      expect(finalShift.cashVariance, -200.0);
      expect(finalShift.closingNotes, 'Shift closed offline at end of day');
      expect(finalShift.serverVersion, 2);

      worker.dispose();
    });

    test('Locally CLOSED shift is terminal and cannot revert to ACTIVE from stale delta', () async {
      final worker = createWorker();
      const shiftId = '019283a0-0000-7000-8000-000000000002';

      // Seed a shift that is fully CLOSED
      await db.dailyCalculationsDao.insertCalculation(
        LocalDailyCalculationsCompanion(
          id: const Value(shiftId),
          cashierId: const Value('cashier-p1'),
          cashierName: const Value('Terminal P1 Cashier'),
          startingCash: const Value(5000.0),
          expectedCashDrawer: const Value(20000.0),
          actualCashCounted: const Value(20000.0),
          cashVariance: const Value(0.0),
          status: const Value(DailyCalculationStatus.closed),
          syncStatus: const Value('synced'),
          serverVersion: const Value(3),
        ),
      );

      // Server delta with higher version sends ACTIVE
      final incomingServerDelta = {
        'sequence': 110,
        'entity_type': 'shift',
        'entity_id': shiftId,
        'record_version': 10,
        'operation': 'UPDATE',
        'is_deleted': false,
        'payload': {
          'status': 'ACTIVE',
          'actual_cash_counted': null,
        },
      };

      await worker.applyPullChange(incomingServerDelta);

      final finalShift = await db.dailyCalculationsDao.getCalculationById(shiftId);
      expect(finalShift!.status, DailyCalculationStatus.closed);
      expect(finalShift.actualCashCounted, 20000.0);
      expect(finalShift.serverVersion, 10);

      worker.dispose();
    });
  });
}
