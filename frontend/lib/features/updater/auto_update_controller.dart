import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/updater/app_version_provider.dart';
import '../../core/updater/update_models.dart';
import '../../core/updater/update_service.dart';
import 'update_dialog.dart';

/// Global helper function to manually check for updates with user feedback.
Future<void> triggerManualUpdateCheck(
  BuildContext context,
  WidgetRef ref,
) async {
  final scaffoldMessenger = ScaffoldMessenger.of(context);
  scaffoldMessenger.hideCurrentSnackBar();
  scaffoldMessenger.showSnackBar(
    const SnackBar(
      content: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          ),
          SizedBox(width: 12),
          Text('Checking for updates from GitHub...'),
        ],
      ),
      duration: Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
    ),
  );

  final result = await ref
      .read(autoUpdateControllerProvider.notifier)
      .manualCheckForUpdate(context);

  if (!context.mounted || result == null) return;
  scaffoldMessenger.hideCurrentSnackBar();

  if (result.isFailed) {
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Could not check for updates. Please check the internet connection and try again.',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.amber.shade800,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  } else if (result.isUpToDate) {
    final ver = await const DefaultAppVersionProvider().getAppVersion();
    if (!context.mounted) return;
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Hungry Howie\'s POS is up to date (Version $ver). No new updates found.',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF16A34A),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }
}

/// State of the auto-update controller.
class AutoUpdateState {
  final bool isChecking;
  final UpdateInfo? availableUpdate;
  final String? errorMessage;
  final UpdateCheckResult? lastResult;

  const AutoUpdateState({
    this.isChecking = false,
    this.availableUpdate,
    this.errorMessage,
    this.lastResult,
  });

  AutoUpdateState copyWith({
    bool? isChecking,
    UpdateInfo? availableUpdate,
    String? errorMessage,
    UpdateCheckResult? lastResult,
  }) {
    return AutoUpdateState(
      isChecking: isChecking ?? this.isChecking,
      availableUpdate: availableUpdate ?? this.availableUpdate,
      errorMessage: errorMessage,
      lastResult: lastResult ?? this.lastResult,
    );
  }
}

/// Controller that coordinates background update checking and prompt presentation.
class AutoUpdateController extends StateNotifier<AutoUpdateState> {
  final UpdateService _updateService;
  bool _hasCheckedThisSession = false;

  AutoUpdateController(this._updateService) : super(const AutoUpdateState());

  /// Silently checks for updates in the background on Windows desktop.
  ///
  /// Safe to call on application startup; will not block the UI or throw exceptions.
  Future<void> startBackgroundCheck(
    BuildContext context, {
    bool force = false,
  }) async {
    // Check once per application session unless forced
    if (_hasCheckedThisSession && !force) {
      return;
    }
    _hasCheckedThisSession = true;

    // Only run updater on Windows desktop platform
    try {
      if (!Platform.isWindows) {
        return;
      }
    } catch (_) {
      // Platform check may fail in some unit test environments
      return;
    }

    if (!mounted) return;
    state = state.copyWith(isChecking: true, errorMessage: null);

    try {
      final result = await _updateService.checkForUpdate(force: force);
      if (!mounted) return;
      state = state.copyWith(
        isChecking: false,
        availableUpdate: result.updateInfo,
        lastResult: result,
        errorMessage: result.isFailed ? result.errorMessage : null,
      );

      if (result.isFailed) {
        debugPrint(
          '[AutoUpdateController] Background update check failed: ${result.errorMessage}',
        );
        return;
      }

      if (result.hasUpdate && result.updateInfo != null && context.mounted) {
        await UpdateDialog.show(
          context,
          updateInfo: result.updateInfo!,
          updateService: _updateService,
        );
      }
    } catch (e) {
      debugPrint('[AutoUpdateController] Background update check error: $e');
      if (mounted) {
        state = state.copyWith(isChecking: false, errorMessage: e.toString());
      }
    }
  }

  /// Manually triggers an update check (e.g. from Settings or Diagnostic screens).
  Future<UpdateCheckResult?> manualCheckForUpdate(BuildContext context) async {
    if (!mounted) return null;
    state = state.copyWith(isChecking: true, errorMessage: null);
    try {
      final result = await _updateService.checkForUpdate(force: true);
      if (!mounted) return result;
      state = state.copyWith(
        isChecking: false,
        availableUpdate: result.updateInfo,
        lastResult: result,
        errorMessage: result.isFailed ? result.errorMessage : null,
      );

      if (result.isFailed) {
        debugPrint(
          '[AutoUpdateController] Manual update check failed: ${result.errorMessage}',
        );
      } else if (result.hasUpdate &&
          result.updateInfo != null &&
          context.mounted) {
        await UpdateDialog.show(
          context,
          updateInfo: result.updateInfo!,
          updateService: _updateService,
        );
      }
      return result;
    } catch (e) {
      debugPrint('[AutoUpdateController] Manual update check error: $e');
      if (mounted) {
        state = state.copyWith(isChecking: false, errorMessage: e.toString());
      }
      return UpdateCheckResult.checkFailed(e.toString());
    }
  }
}

final autoUpdateControllerProvider =
    StateNotifierProvider<AutoUpdateController, AutoUpdateState>((ref) {
      final updateService = ref.watch(updateServiceProvider);
      return AutoUpdateController(updateService);
    });
