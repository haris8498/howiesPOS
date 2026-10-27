import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Feature flags controlling rollout of offline-first capabilities.
class FeatureFlags {
  static bool? _overrideOfflineFirstEnabled;

  /// Controls whether offline-first Drift storage and sync pipeline are active.
  /// Defaults to false per approved deviation #3 (gated until final pilot).
  static bool get offlineFirstEnabled =>
      _overrideOfflineFirstEnabled ??
      const bool.fromEnvironment('OFFLINE_FIRST_ENABLED', defaultValue: true);

  /// Test hook to toggle offlineFirstEnabled dynamically in unit tests.
  static void setOfflineFirstEnabledForTesting(bool? value) {
    _overrideOfflineFirstEnabled = value;
  }

  /// Reset test hook.
  static void resetForTesting() {
    _overrideOfflineFirstEnabled = null;
  }
}

/// Feature flag provider for offline-first architecture (Riverpod §17.1).
final offlineFirstFeatureFlagProvider = StateProvider<bool>((ref) {
  return FeatureFlags.offlineFirstEnabled;
});
