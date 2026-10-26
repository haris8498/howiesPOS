import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hungry_howies_pos/config/feature_flags.dart';
import 'package:hungry_howies_pos/core/network/api_client.dart';
import 'package:hungry_howies_pos/core/sync/connectivity_notifier.dart';
import 'package:hungry_howies_pos/core/sync/sync_health_provider.dart';
import 'package:hungry_howies_pos/core/sync/sync_providers.dart';
import 'package:hungry_howies_pos/services/api/api_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FLG-04 & FLT-12: Flag-OFF Monitoring & Health Ticker Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('FLG-04: connectivityNotifierProvider does not start background timer when offlineFirstEnabled is false', () {
      FeatureFlags.setOfflineFirstEnabledForTesting(false);

      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(ApiClient(baseUrl: 'http://localhost:3000')),
        ],
      );
      addTearDown(() {
        FeatureFlags.resetForTesting();
        container.dispose();
      });

      final notifier = container.read(connectivityNotifierProvider.notifier);
      // Since offlineFirstEnabled is false, monitoring timer should NOT be running
      expect(notifier.isMonitoring, isFalse);
    });

    test('FLG-04: connectivityNotifierProvider starts background timer when offlineFirstEnabled is true', () {
      FeatureFlags.setOfflineFirstEnabledForTesting(true);

      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(ApiClient(baseUrl: 'http://localhost:3000')),
        ],
      );
      addTearDown(() {
        FeatureFlags.resetForTesting();
        container.dispose();
      });

      final notifier = container.read(connectivityNotifierProvider.notifier);
      expect(notifier.isMonitoring, isTrue);
    });

    test('FLT-12: rawSyncHealthProvider returns initial when offlineFirstEnabled is false', () {
      FeatureFlags.setOfflineFirstEnabledForTesting(false);

      final container = ProviderContainer();
      addTearDown(() {
        FeatureFlags.resetForTesting();
        container.dispose();
      });

      final health = container.read(rawSyncHealthProvider);
      expect(health, SyncHealthState.initial);
    });
  });
}
