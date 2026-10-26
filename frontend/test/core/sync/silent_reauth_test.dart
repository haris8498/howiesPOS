import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:hungry_howies_pos/core/database/app_database.dart';
import 'package:hungry_howies_pos/core/network/api_client.dart';
import 'package:hungry_howies_pos/core/sync/connectivity_notifier.dart';
import 'package:hungry_howies_pos/core/sync/sync_background_worker.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SYNC-008: Silent Re-Authentication Security Tests', () {
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
      await db.close();
    });

    test('trySilentReauth does not guess passwords or make login calls, returns null', () async {
      bool attemptedLoginRequest = false;

      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/auth/login')) {
          attemptedLoginRequest = true;
          return http.Response('{"error":"Unauthenticated"}', 401);
        }
        return http.Response('{"status":"ok"}', 200);
      });

      final worker = SyncBackgroundWorker(
        db: db,
        connectivityNotifier: connectivityNotifier,
        httpClient: mockClient,
        syncUrlOverride: 'http://localhost:3000/api',
      );

      final result = await worker.trySilentReauth('noman');

      expect(result, isNull);
      expect(attemptedLoginRequest, isFalse,
          reason: 'Worker must not guess plaintext passwords against the login endpoint');
    });
  });
}
