import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:hungry_howies_pos/core/network/api_client.dart';
import 'package:hungry_howies_pos/core/sync/connectivity_notifier.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SYNC-035: Captive Portal Probe Tests', () {
    test('probeHealth returns false and sets offline when server returns HTML 200', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          '<!DOCTYPE html><html><body>Please sign in to the Hotel WiFi</body></html>',
          200,
          headers: {'content-type': 'text/html'},
        );
      });

      final notifier = ConnectivityNotifier(
        apiClient: ApiClient(baseUrl: 'http://localhost:3000'),
        httpClient: mockClient,
        probeTimeout: const Duration(milliseconds: 200),
      );

      final isOnline = await notifier.probeHealth();

      expect(isOnline, isFalse);
      expect(notifier.state.status, equals(ConnectivityStatus.offline));
      expect(notifier.isOnline, isFalse);

      notifier.dispose();
    });

    test('probeHealth returns true when server returns valid JSON 200', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          '{"success": true, "status": "ok"}',
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final notifier = ConnectivityNotifier(
        apiClient: ApiClient(baseUrl: 'http://localhost:3000'),
        httpClient: mockClient,
        probeTimeout: const Duration(milliseconds: 200),
      );

      final isOnline = await notifier.probeHealth();

      expect(isOnline, isTrue);
      expect(notifier.state.status, equals(ConnectivityStatus.online));
      expect(notifier.isOnline, isTrue);

      notifier.dispose();
    });
  });
}
