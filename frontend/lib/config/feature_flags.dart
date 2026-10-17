/// Feature flags controlling rollout of offline-first capabilities.
class FeatureFlags {
  /// Controls whether offline-first Drift storage and sync pipeline are active.
  /// Defaults to false per approved deviation #3 (gated until final pilot).
  static const bool offlineFirstEnabled =
      bool.fromEnvironment('OFFLINE_FIRST_ENABLED', defaultValue: false);
}
