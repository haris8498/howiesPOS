import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:uuid/uuid.dart';

import 'package:hungry_howies_pos/core/database/app_database.dart';
import 'package:hungry_howies_pos/core/sync/connectivity_notifier.dart';
import 'package:hungry_howies_pos/core/sync/device_identity.dart';
import 'package:hungry_howies_pos/core/sync/sync_background_worker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DeviceIdentity Service Tests (SYNC-005)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      DeviceIdentityService.resetForTesting();
    });

    test('1. Two devices get different UUIDs on first launch and persist them across restarts', () async {
      // Device A simulation
      final prefsA = await SharedPreferences.getInstance();
      await prefsA.clear();
      final serviceA = DeviceIdentityService(customPrefs: prefsA);

      final identityA1 = await serviceA.getOrInitializeIdentity(
        defaultTerminalId: '1',
        defaultTerminalName: 'Counter Register 1',
      );
      expect(identityA1.deviceId, isNotEmpty);
      expect(identityA1.terminalId, equals('1'));
      expect(identityA1.terminalName, equals('Counter Register 1'));

      // Simulate app restart on Device A (same storage)
      DeviceIdentityService.resetForTesting();
      final serviceARestart = DeviceIdentityService(customPrefs: prefsA);
      final identityA2 = await serviceARestart.getOrInitializeIdentity();
      expect(identityA2.deviceId, equals(identityA1.deviceId),
          reason: 'Device A must persist its UUID across restarts');
      expect(identityA2.terminalId, equals('1'));

      // Device B simulation (independent storage / separate machine)
      final customPrefsStorageB = <String, Object>{};
      SharedPreferences.setMockInitialValues(customPrefsStorageB);
      final prefsB = await SharedPreferences.getInstance();
      DeviceIdentityService.resetForTesting();
      final serviceB = DeviceIdentityService(customPrefs: prefsB);

      final identityB1 = await serviceB.getOrInitializeIdentity(
        defaultTerminalId: '2',
        defaultTerminalName: 'Drive-Thru Register 2',
      );
      expect(identityB1.deviceId, isNotEmpty);
      expect(identityB1.terminalId, equals('2'));
      expect(identityB1.terminalName, equals('Drive-Thru Register 2'));

      // Invariant: Two devices must have DISTINCT device IDs
      expect(identityB1.deviceId, isNot(equals(identityA1.deviceId)),
          reason: 'Two physical devices must never share the same hardware deviceId');

      // Simulate app restart on Device B
      DeviceIdentityService.resetForTesting();
      final serviceBRestart = DeviceIdentityService(customPrefs: prefsB);
      final identityB2 = await serviceBRestart.getOrInitializeIdentity();
      expect(identityB2.deviceId, equals(identityB1.deviceId),
          reason: 'Device B must persist its UUID across restarts');
      expect(identityB2.terminalId, equals('2'));
    });

    test('2. Terminal setup update persists terminalId and terminalName outside SQLite', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      final service = DeviceIdentityService(customPrefs: prefs);

      final initial = await service.getOrInitializeIdentity();
      expect(initial.terminalId, equals('1'));

      // Administrator assigns terminal 3
      final updated = await service.updateTerminalSetup(
        terminalId: '3',
        terminalName: 'Express Kiosk 3',
        restaurantId: 'store-101',
      );

      expect(updated.terminalId, equals('3'));
      expect(updated.terminalName, equals('Express Kiosk 3'));
      expect(updated.restaurantId, equals('store-101'));
      expect(updated.deviceId, equals(initial.deviceId),
          reason: 'Updating terminal metadata must preserve the underlying hardware deviceId');

      // Restart check
      DeviceIdentityService.resetForTesting();
      final serviceRestart = DeviceIdentityService(customPrefs: prefs);
      final reloaded = await serviceRestart.getOrInitializeIdentity();
      expect(reloaded.terminalId, equals('3'));
      expect(reloaded.terminalName, equals('Express Kiosk 3'));
      expect(reloaded.restaurantId, equals('store-101'));
      expect(reloaded.deviceId, equals(initial.deviceId));
    });
  });

  group('Multi-Device Echo Suppression Tests (SYNC-005)', () {
    late AppDatabase db;
    late HttpServer server;
    late String serverUrl;
    late ConnectivityNotifier connectivityNotifier;
    late Future<void> Function(HttpRequest) requestHandler;

    setUp(() async {
      HttpOverrides.global = null;
      SharedPreferences.setMockInitialValues({});
      db = AppDatabase(NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('PRAGMA foreign_keys = ON;');
        },
      ));

      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      serverUrl = 'http://127.0.0.1:${server.port}';

      requestHandler = (request) async {
        request.response.statusCode = 404;
        await request.response.close();
      };

      server.listen((HttpRequest request) async {
        try {
          await requestHandler(request);
        } catch (_) {}
      });

      connectivityNotifier = ConnectivityNotifier(
        healthEndpointOverride: '$serverUrl/health',
      );
      connectivityNotifier.setOnlineManually();
    });

    tearDown(() async {
      connectivityNotifier.dispose();
      await server.close(force: true);
      await db.close();
      DeviceIdentityService.resetForTesting();
    });

    test('3. Device A does NOT drop Device B\'s changes as self-echo, but DOES drop its own self-echo', () async {
      final deviceAId = 'device-uuid-aaaa-1111';
      final deviceBId = 'device-uuid-bbbb-2222';
      final tableId = const Uuid().v7();

      // Seed Table 1 on Device A
      await db.catalogDao.upsertRestaurantTables([
        LocalRestaurantTablesCompanion(
          id: Value(tableId),
          tableNumber: const Value('T-1'),
          name: const Value('Original Table 1'),
          capacity: const Value(4),
          status: const Value('available'),
          version: const Value(1),
        ),
      ]);

      // Seed cursor > 0 so worker executes delta pull rather than cold bootstrap
      await db.syncCursorsDao.setCursor('GLOBAL_PULL_CURSOR', 5);

      // Phase 1: Device B modified Table 1 on the server
      requestHandler = (HttpRequest request) async {
        if (request.uri.path == '/sync/pull') {
          request.response.statusCode = 200;
          request.response.headers.contentType = ContentType.json;
          request.response.write(jsonEncode({
            'success': true,
            'cursor': 10,
            'next_cursor': 10,
            'has_more': false,
            'changes': [
              {
                'sequence': 10,
                'entity_type': 'table',
                'entity_id': tableId,
                'operation': 'UPDATE',
                'record_version': 2,
                'payload': {
                  'origin_device_id': deviceBId, // Change originated on Device B!
                  'name': 'Updated By Device B',
                  'status': 'occupied',
                  'version': 2,
                },
              },
            ],
          }));
          await request.response.close();
          return;
        }
        request.response.statusCode = 404;
        await request.response.close();
      };

      final workerDeviceA = SyncBackgroundWorker(
        db: db,
        connectivityNotifier: connectivityNotifier,
        deviceId: deviceAId, // Device A identity
        syncUrlOverride: serverUrl,
      );

      // Device A pulls changes
      await workerDeviceA.triggerPull();

      // Verification: Device A must NOT have dropped Device B's changes!
      final tableAfterPullB = await db.catalogDao.getTableById(tableId);
      expect(tableAfterPullB != null, isTrue);
      expect(tableAfterPullB!.name, equals('Updated By Device B'),
          reason: 'Device A must accept Device B\'s table change without treating it as self-echo');
      expect(tableAfterPullB.status, equals('occupied'));

      // Phase 2: Now a delta arrives with Device A's own deviceId (self-echo)
      requestHandler = (HttpRequest request) async {
        if (request.uri.path == '/sync/pull') {
          request.response.statusCode = 200;
          request.response.headers.contentType = ContentType.json;
          request.response.write(jsonEncode({
            'success': true,
            'cursor': 11,
            'next_cursor': 11,
            'has_more': false,
            'changes': [
              {
                'sequence': 11,
                'entity_type': 'table',
                'entity_id': tableId,
                'operation': 'UPDATE',
                'record_version': 3,
                'payload': {
                  'origin_device_id': deviceAId, // Echo of Device A's own write!
                  'name': 'SHOULD_BE_DROPPED_SELF_ECHO',
                  'version': 3,
                },
              },
            ],
          }));
          await request.response.close();
          return;
        }
        request.response.statusCode = 404;
        await request.response.close();
      };

      await workerDeviceA.triggerPull();

      // Verification: Self-echo from Device A MUST be ignored
      final tableAfterSelfEcho = await db.catalogDao.getTableById(tableId);
      expect(tableAfterSelfEcho!.name, equals('Updated By Device B'),
          reason: 'Device A must drop its own echo writes');

      workerDeviceA.dispose();
    });
  });
}
