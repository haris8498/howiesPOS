/// Information about an available update.
class UpdateInfo {
  final String currentVersion;
  final String latestVersion;
  final String releaseTag;
  final String releaseName;
  final String releaseNotes;
  final String assetName;
  final String downloadUrl;
  final int assetSize;
  final DateTime? publishedAt;
  final bool hasUpdate;

  const UpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.releaseTag,
    required this.releaseName,
    required this.releaseNotes,
    required this.assetName,
    required this.downloadUrl,
    required this.assetSize,
    this.publishedAt,
    required this.hasUpdate,
  });

  @override
  String toString() =>
      'UpdateInfo(current: $currentVersion, latest: $latestVersion, asset: $assetName, size: $assetSize, hasUpdate: $hasUpdate)';
}

/// The different phases of the update lifecycle.
enum UpdatePhase {
  idle,
  checking,
  available,
  downloading,
  extracting,
  preparing,
  readyToRestart,
  error,
}

/// Progress state emitted during download and extraction.
class UpdateProgress {
  final UpdatePhase phase;
  final double percentage; // 0.0 to 1.0
  final int downloadedBytes;
  final int totalBytes;
  final String statusMessage;
  final String? errorMessage;

  const UpdateProgress({
    required this.phase,
    this.percentage = 0.0,
    this.downloadedBytes = 0,
    this.totalBytes = 0,
    this.statusMessage = '',
    this.errorMessage,
  });

  bool get isDownloading => phase == UpdatePhase.downloading;
  bool get isExtracting => phase == UpdatePhase.extracting;
  bool get isPreparing => phase == UpdatePhase.preparing;
  bool get isReady => phase == UpdatePhase.readyToRestart;
  bool get isError => phase == UpdatePhase.error;

  /// Helper to format bytes into readable MB string.
  String get formattedProgress {
    if (totalBytes > 0) {
      final currentMb = (downloadedBytes / (1024 * 1024)).toStringAsFixed(1);
      final totalMb = (totalBytes / (1024 * 1024)).toStringAsFixed(1);
      return '$currentMb MB / $totalMb MB (${(percentage * 100).toStringAsFixed(0)}%)';
    } else if (downloadedBytes > 0) {
      final currentMb = (downloadedBytes / (1024 * 1024)).toStringAsFixed(1);
      return '$currentMb MB';
    }
    return '${(percentage * 100).toStringAsFixed(0)}%';
  }
}
