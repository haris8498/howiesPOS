import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../core/updater/update_models.dart';
import '../../core/updater/update_service.dart';

/// Clean, POS-optimized dialog for presenting available updates and displaying update progress.
class UpdateDialog extends StatefulWidget {
  final UpdateInfo updateInfo;
  final UpdateService updateService;

  const UpdateDialog({
    super.key,
    required this.updateInfo,
    required this.updateService,
  });

  /// Displays the update dialog modally.
  static Future<void> show(
    BuildContext context, {
    required UpdateInfo updateInfo,
    required UpdateService updateService,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) =>
          UpdateDialog(updateInfo: updateInfo, updateService: updateService),
    );
  }

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _isUpdating = false;
  UpdateProgress _progress = const UpdateProgress(phase: UpdatePhase.idle);
  String? _errorMessage;

  Future<void> _startUpdate() async {
    setState(() {
      _isUpdating = true;
      _errorMessage = null;
      _progress = const UpdateProgress(
        phase: UpdatePhase.downloading,
        percentage: 0.0,
        statusMessage: 'Connecting to update server...',
      );
    });

    try {
      await widget.updateService.executeUpdate(
        widget.updateInfo,
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              _progress = progress;
            });
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUpdating = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return PopScope(
      canPop: !_isUpdating,
      child: Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isDark ? const Color(0xFF334155) : AppColors.borderGray,
            width: 1.2,
          ),
        ),
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: _isUpdating
                ? _buildUpdatingState(isDark)
                : _buildPromptState(isDark),
          ),
        ),
      ),
    );
  }

  /// Initial prompt showing new version details, release notes, and actions.
  Widget _buildPromptState(bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header with Icon
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primaryRed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.system_update_rounded,
                color: AppColors.primaryRed,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Update Available',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "A new version of Hungry Howie's POS is available.",
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Version Comparison Card
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : AppColors.lightGray,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : AppColors.borderGray,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildVersionBadge(
                'Current version',
                widget.updateInfo.currentVersion,
                isDark,
                isHighlight: false,
              ),
              Icon(
                Icons.arrow_forward_rounded,
                size: 20,
                color: isDark ? const Color(0xFF64748B) : AppColors.textMuted,
              ),
              _buildVersionBadge(
                'New version',
                widget.updateInfo.latestVersion,
                isDark,
                isHighlight: true,
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Release Notes
        Text(
          "What's new:",
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          constraints: const BoxConstraints(maxHeight: 120),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : AppColors.offWhite,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : AppColors.borderGray,
            ),
          ),
          child: SingleChildScrollView(
            child: Text(
              widget.updateInfo.releaseNotes,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.45,
                color: isDark ? const Color(0xFFCBD5E1) : AppColors.textPrimary,
              ),
            ),
          ),
        ),

        if (_errorMessage != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.danger.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.error_outline,
                  color: AppColors.danger,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.danger,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 24),

        // Actions: [Later] [Update Now]
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Later'),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: _startUpdate,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryRed,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 2,
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.download_rounded, size: 18),
                  SizedBox(width: 6),
                  Text(
                    'Update Now',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Updating progress state with animated percentage indicator.
  Widget _buildUpdatingState(bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Title
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryRed),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Updating POS',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Progress Message & Percentage
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _progress.statusMessage.isNotEmpty
                  ? _progress.statusMessage
                  : 'Downloading update...',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : AppColors.textPrimary,
              ),
            ),
            Text(
              '${(_progress.percentage * 100).toStringAsFixed(0)}%',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: AppColors.primaryRed,
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // Linear Progress Bar
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: _progress.percentage > 0.0 ? _progress.percentage : null,
            minHeight: 12,
            backgroundColor: isDark
                ? const Color(0xFF334155)
                : AppColors.borderGray,
            valueColor: const AlwaysStoppedAnimation<Color>(
              AppColors.primaryRed,
            ),
          ),
        ),

        const SizedBox(height: 8),

        // Bytes indicator (e.g., 42.1 MB / 122.7 MB)
        if (_progress.downloadedBytes > 0)
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              _progress.formattedProgress,
              style: TextStyle(
                fontSize: 11.5,
                color: isDark
                    ? const Color(0xFF94A3B8)
                    : AppColors.textSecondary,
              ),
            ),
          ),

        const SizedBox(height: 20),

        // Friendly warning notice
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.brandYellow.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppColors.brandYellow.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                color: Color(0xFFB45309),
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Please do not close the application.',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF92400E),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVersionBadge(
    String label,
    String version,
    bool isDark, {
    required bool isHighlight,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isHighlight
                ? AppColors.primaryRed.withValues(alpha: 0.12)
                : (isDark ? const Color(0xFF1E293B) : Colors.white),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isHighlight ? AppColors.primaryRed : AppColors.borderGray,
              width: 1,
            ),
          ),
          child: Text(
            version,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isHighlight
                  ? AppColors.primaryRed
                  : (isDark ? Colors.white : AppColors.textPrimary),
            ),
          ),
        ),
      ],
    );
  }
}
