import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_version_provider.dart';
import 'github_release_client.dart';
import 'update_models.dart';
import 'version_utils.dart';
import 'windows_updater.dart';

/// Service responsible for managing application updates.
class UpdateService {
  static const String _lastCheckKey = 'howies_updater_last_check_timestamp';
  static const Duration _checkCooldown = Duration(minutes: 15);

  final IGitHubReleaseClient _releaseClient;
  final IAppVersionProvider _versionProvider;
  final IWindowsUpdater _windowsUpdater;
  final SharedPreferences? prefs;

  UpdateService({
    IGitHubReleaseClient? releaseClient,
    IAppVersionProvider? versionProvider,
    IWindowsUpdater? windowsUpdater,
    this.prefs,
  }) : _releaseClient = releaseClient ?? GitHubReleaseClient(),
       _versionProvider = versionProvider ?? const DefaultAppVersionProvider(),
       _windowsUpdater = windowsUpdater ?? WindowsUpdater();

  /// Checks whether a newer stable release is available.
  ///
  /// Respects a cooldown timer unless [force] is true.
  /// Returns [UpdateInfo] if a newer version is available and contains the required Windows asset.
  /// Returns `null` if the app is up to date, if the check failed, or if cooldown is active.
  /// NEVER throws an exception.
  Future<UpdateInfo?> checkForUpdate({bool force = false}) async {
    try {
      // 1. Check cooldown / debouncing
      if (!force && prefs != null) {
        final lastCheckMs = prefs!.getInt(_lastCheckKey);
        if (lastCheckMs != null) {
          final lastCheckTime = DateTime.fromMillisecondsSinceEpoch(
            lastCheckMs,
          );
          if (DateTime.now().difference(lastCheckTime) < _checkCooldown) {
            debugPrint('[UpdateService] Cooldown active. Skipping check.');
            return null;
          }
        }
      }

      // Record check timestamp
      if (prefs != null) {
        await prefs!.setInt(
          _lastCheckKey,
          DateTime.now().millisecondsSinceEpoch,
        );
      }

      // 2. Fetch current app version
      final currentVersion = await _versionProvider.getAppVersion();
      final normalizedCurrent = VersionUtils.normalize(currentVersion);

      // 3. Fetch latest stable release from GitHub
      final release = await _releaseClient.getLatestStableRelease();
      if (release == null) {
        debugPrint('[UpdateService] No stable release retrieved from GitHub.');
        return null;
      }

      // 4. Validate asset existence
      if (!release.hasValidAsset) {
        debugPrint(
          '[UpdateService] Stable release ${release.tagName} is missing required Windows asset.',
        );
        return null;
      }

      // 5. Compare versions
      final isNewer = VersionUtils.isNewer(release.tagName, normalizedCurrent);
      if (!isNewer) {
        debugPrint(
          '[UpdateService] Current version ($normalizedCurrent) is up to date with latest (${release.tagName}).',
        );
        return null;
      }

      // 6. Format release notes safely
      var notes = release.body.trim();
      if (notes.isEmpty) {
        notes = "A new version of Hungry Howie's POS is available.";
      }

      final normalizedLatest = VersionUtils.normalize(release.tagName);

      return UpdateInfo(
        currentVersion: normalizedCurrent,
        latestVersion: normalizedLatest,
        releaseTag: release.tagName,
        releaseName: release.releaseName,
        releaseNotes: notes,
        assetName: release.assetName!,
        downloadUrl: release.downloadUrl!,
        assetSize: release.assetSize,
        hasUpdate: true,
      );
    } catch (e, stack) {
      debugPrint(
        '[UpdateService] Unexpected error during update check: $e\n$stack',
      );
      return null;
    }
  }

  /// Downloads and installs the given [update].
  Future<void> executeUpdate(
    UpdateInfo update, {
    void Function(UpdateProgress progress)? onProgress,
  }) async {
    await _windowsUpdater.executeUpdate(update, onProgress: onProgress);
  }
}

// ============================================================================
// Riverpod Providers
// ============================================================================

final sharedPreferencesProvider = FutureProvider<SharedPreferences>((
  ref,
) async {
  return SharedPreferences.getInstance();
});

final updateServiceProvider = Provider<UpdateService>((ref) {
  final prefsAsync = ref.watch(sharedPreferencesProvider);
  final prefs = prefsAsync.valueOrNull;

  return UpdateService(prefs: prefs);
});
