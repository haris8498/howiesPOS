import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_version_provider.dart';
import 'github_release_client.dart';
import 'update_models.dart';
import 'version_utils.dart';
import 'windows_updater.dart';

/// The status of an update check.
enum UpdateCheckStatus {
  upToDate,
  updateAvailable,
  checkFailed,
}

/// Result of checking for application updates.
class UpdateCheckResult {
  final UpdateCheckStatus status;
  final UpdateInfo? updateInfo;
  final String? errorMessage;

  const UpdateCheckResult({
    required this.status,
    this.updateInfo,
    this.errorMessage,
  });

  const UpdateCheckResult.upToDate()
      : status = UpdateCheckStatus.upToDate,
        updateInfo = null,
        errorMessage = null;

  const UpdateCheckResult.updateAvailable(UpdateInfo info)
      : status = UpdateCheckStatus.updateAvailable,
        updateInfo = info,
        errorMessage = null;

  const UpdateCheckResult.checkFailed([this.errorMessage])
      : status = UpdateCheckStatus.checkFailed,
        updateInfo = null;

  bool get isUpToDate => status == UpdateCheckStatus.upToDate;
  bool get hasUpdate =>
      status == UpdateCheckStatus.updateAvailable && updateInfo != null;
  bool get isFailed => status == UpdateCheckStatus.checkFailed;

  @override
  String toString() =>
      'UpdateCheckResult(status: $status, hasUpdate: $hasUpdate, error: $errorMessage)';
}

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
  /// Returns [UpdateCheckResult.updateAvailable] if a newer version is available and contains the required Windows asset.
  /// Returns [UpdateCheckResult.upToDate] if the app is up to date, if no release exists yet (HTTP 404), or if cooldown is active.
  /// Returns [UpdateCheckResult.checkFailed] if an error occurred (network error, timeout, HTTP 403/429/500).
  /// NEVER throws an exception.
  Future<UpdateCheckResult> checkForUpdate({bool force = false}) async {
    try {
      // 1. Check cooldown / debouncing
      SharedPreferences? sp = prefs;
      try {
        sp ??= await SharedPreferences.getInstance();
      } catch (_) {
        // Fallback for isolated unit tests without SharedPreferences mock
      }

      if (!force && sp != null) {
        final lastCheckMs = sp.getInt(_lastCheckKey);
        if (lastCheckMs != null) {
          final lastCheckTime = DateTime.fromMillisecondsSinceEpoch(
            lastCheckMs,
          );
          if (DateTime.now().difference(lastCheckTime) < _checkCooldown) {
            debugPrint('[UpdateService] Cooldown active. Skipping check.');
            return const UpdateCheckResult.upToDate();
          }
        }
      }

      // Record check timestamp
      if (sp != null) {
        await sp.setInt(
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
        debugPrint(
          '[UpdateService] No stable release retrieved from GitHub (or release not found).',
        );
        return const UpdateCheckResult.upToDate();
      }

      // 4. Validate asset existence
      if (!release.hasValidAsset) {
        debugPrint(
          '[UpdateService] Stable release ${release.tagName} is missing required Windows asset.',
        );
        return const UpdateCheckResult.upToDate();
      }

      // 5. Compare versions
      final isNewer = VersionUtils.isNewer(release.tagName, normalizedCurrent);
      if (!isNewer) {
        debugPrint(
          '[UpdateService] Current version ($normalizedCurrent) is up to date with latest (${release.tagName}).',
        );
        return const UpdateCheckResult.upToDate();
      }

      // 6. Format release notes safely
      var notes = release.body.trim();
      if (notes.isEmpty) {
        notes = "A new version of Hungry Howie's POS is available.";
      }

      final normalizedLatest = VersionUtils.normalize(release.tagName);

      final updateInfo = UpdateInfo(
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

      return UpdateCheckResult.updateAvailable(updateInfo);
    } catch (e, stack) {
      debugPrint(
        '[UpdateService] Unexpected error during update check: $e\n$stack',
      );
      return UpdateCheckResult.checkFailed(e.toString());
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
  return UpdateService();
});
