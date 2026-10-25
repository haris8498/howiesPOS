import 'dart:async';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'update_models.dart';

/// Abstraction for the platform updater mechanism.
abstract class IWindowsUpdater {
  Future<void> executeUpdate(
    UpdateInfo update, {
    void Function(UpdateProgress progress)? onProgress,
  });
}

/// Production implementation of [IWindowsUpdater] for Windows POS systems.
class WindowsUpdater implements IWindowsUpdater {
  final http.Client _client;
  final String targetExeName;

  WindowsUpdater({
    http.Client? client,
    this.targetExeName = 'hungry_howies_pos.exe',
  }) : _client = client ?? http.Client();

  @override
  Future<void> executeUpdate(
    UpdateInfo update, {
    void Function(UpdateProgress progress)? onProgress,
  }) async {
    Directory? tempDir;
    try {
      // Step 1: Prepare temporary update directory
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final systemTemp = Directory.systemTemp.path;
      tempDir = Directory(p.join(systemTemp, 'howies_pos_update_$timestamp'));
      if (!await tempDir.exists()) {
        await tempDir.create(recursive: true);
      }

      final zipFilePath = p.join(tempDir.path, update.assetName);
      final zipFile = File(zipFilePath);

      // Step 2: Download the update ZIP
      onProgress?.call(
        const UpdateProgress(
          phase: UpdatePhase.downloading,
          percentage: 0.0,
          statusMessage: 'Starting download...',
        ),
      );

      await _downloadZip(
        url: update.downloadUrl,
        destinationFile: zipFile,
        expectedBytes: update.assetSize,
        onProgress: onProgress,
      );

      // Step 3: Validate downloaded file
      if (!await zipFile.exists() || await zipFile.length() == 0) {
        throw Exception('Downloaded update package is empty or missing.');
      }

      // If the asset is an InnoSetup .exe installer, run it directly and close POS
      if (update.assetName.toLowerCase().endsWith('.exe')) {
        onProgress?.call(
          const UpdateProgress(
            phase: UpdatePhase.preparing,
            percentage: 1.0,
            statusMessage: 'Launching installer and closing POS...',
          ),
        );
        debugPrint('[WindowsUpdater] Launching Setup installer: ${zipFile.path}');
        await Process.start(zipFile.path, ['/SILENT', '/CLOSEAPPLICATIONS'],
            mode: ProcessStartMode.detached);
        exit(0);
      }

      onProgress?.call(
        const UpdateProgress(
          phase: UpdatePhase.extracting,
          percentage: 1.0,
          statusMessage: 'Validating and extracting update...',
        ),
      );

      // Step 4: Extract update ZIP to temporary folder
      final extractedDir = Directory(p.join(tempDir.path, 'extracted'));
      await extractedDir.create(recursive: true);
      await _extractZip(zipFile, extractedDir);

      // Step 5: Locate installation directory and prepare files
      final installDir = _resolveInstallationDirectory();
      debugPrint(
        '[WindowsUpdater] Target install directory: ${installDir.path}',
      );

      // Step 6: Verify extracted bundle contains the executable or subfolder
      final resolvedSourceDir = _findAppRoot(extractedDir, targetExeName);
      if (!File(p.join(resolvedSourceDir.path, targetExeName)).existsSync()) {
        throw Exception(
          'Extracted update package does not contain $targetExeName.',
        );
      }

      onProgress?.call(
        const UpdateProgress(
          phase: UpdatePhase.preparing,
          percentage: 1.0,
          statusMessage: 'Applying update and restarting...',
        ),
      );

      // Step 7: Launch detached helper updater and safely exit
      await _launchUpdaterAndExit(
        sourceDir: resolvedSourceDir,
        targetDir: installDir,
        exeName: targetExeName,
      );
    } catch (e, stack) {
      debugPrint('[WindowsUpdater] Error during update process: $e\n$stack');
      onProgress?.call(
        UpdateProgress(
          phase: UpdatePhase.error,
          statusMessage: 'Update failed',
          errorMessage: e.toString(),
        ),
      );
      // Re-throw so callers can react if needed
      rethrow;
    }
  }

  /// Downloads ZIP using streaming HTTP request to report percentage progress.
  Future<void> _downloadZip({
    required String url,
    required File destinationFile,
    required int expectedBytes,
    void Function(UpdateProgress progress)? onProgress,
  }) async {
    final request = http.Request('GET', Uri.parse(url));
    request.headers['User-Agent'] = 'HungryHowiesPOS';
    final response = await _client.send(request);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Failed to download update (HTTP status ${response.statusCode})',
      );
    }

    final totalBytes = response.contentLength ?? expectedBytes;
    int receivedBytes = 0;
    final sink = destinationFile.openWrite();

    try {
      await response.stream.listen((chunk) {
        receivedBytes += chunk.length;
        sink.add(chunk);

        final pct = totalBytes > 0 ? (receivedBytes / totalBytes) : 0.0;
        onProgress?.call(
          UpdateProgress(
            phase: UpdatePhase.downloading,
            percentage: pct.clamp(0.0, 1.0),
            downloadedBytes: receivedBytes,
            totalBytes: totalBytes,
            statusMessage: 'Downloading update...',
          ),
        );
      }).asFuture();
    } finally {
      await sink.flush();
      await sink.close();
    }
  }

  /// Extracts the ZIP archive using the pure-Dart [archive] package.
  Future<void> _extractZip(File zipFile, Directory targetDir) async {
    final bytes = await zipFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    for (final file in archive) {
      final filename = file.name;
      final outPath = p.join(targetDir.path, filename);
      if (file.isFile) {
        final outFile = File(outPath);
        await outFile.parent.create(recursive: true);
        await outFile.writeAsBytes(file.content as List<int>);
      } else {
        await Directory(outPath).create(recursive: true);
      }
    }
  }

  /// Resolves the current application's installation folder.
  Directory _resolveInstallationDirectory() {
    final exePath = Platform.resolvedExecutable;
    return Directory(p.dirname(exePath));
  }

  /// Finds the directory inside the extracted update that contains [exeName].
  Directory _findAppRoot(Directory root, String exeName) {
    if (File(p.join(root.path, exeName)).existsSync()) {
      return root;
    }

    // Search immediate subdirectories (in case ZIP was archived with a top folder)
    for (final entity in root.listSync()) {
      if (entity is Directory) {
        if (File(p.join(entity.path, exeName)).existsSync()) {
          return entity;
        }
      }
    }
    return root;
  }

  /// Launches the standalone updater helper and exits the current process.
  Future<void> _launchUpdaterAndExit({
    required Directory sourceDir,
    required Directory targetDir,
    required String exeName,
  }) async {
    final currentPid = pid;

    // Check for native updater.exe helper in targetDir or sourceDir
    final installedUpdater = File(p.join(targetDir.path, 'updater.exe'));
    final sourceUpdater = File(p.join(sourceDir.path, 'updater.exe'));

    File? updaterBinary;
    if (installedUpdater.existsSync()) {
      updaterBinary = installedUpdater;
    } else if (sourceUpdater.existsSync()) {
      updaterBinary = sourceUpdater;
    }

    final runnerDir = Directory(
      p.join(Directory.systemTemp.path, 'howies_updater_runner'),
    );
    if (!runnerDir.existsSync()) {
      await runnerDir.create(recursive: true);
    }

    if (updaterBinary != null && updaterBinary.existsSync()) {
      // Copy updater.exe to temp so it is not locked inside targetDir during update
      final runnerExe = File(p.join(runnerDir.path, 'updater.exe'));
      try {
        if (runnerExe.existsSync()) {
          runnerExe.deleteSync();
        }
      } catch (_) {}
      await updaterBinary.copy(runnerExe.path);

      debugPrint(
        '[WindowsUpdater] Launching native updater.exe: ${runnerExe.path}',
      );
      await Process.start(runnerExe.path, [
        currentPid.toString(),
        sourceDir.path,
        targetDir.path,
        exeName,
      ], mode: ProcessStartMode.detached);
    } else {
      // Fallback: Windows batch script that performs safe out-of-process file replacement
      final cmdScriptFile = File(p.join(runnerDir.path, 'apply_update.cmd'));
      final scriptContent = generateFallbackBatchScript(
        pid: currentPid,
        source: sourceDir.path,
        target: targetDir.path,
        exeName: exeName,
      );
      await cmdScriptFile.writeAsString(scriptContent);

      debugPrint(
        '[WindowsUpdater] Launching fallback cmd updater: ${cmdScriptFile.path}',
      );
      await Process.start('cmd.exe', [
        '/c',
        cmdScriptFile.path,
      ], mode: ProcessStartMode.detached);
    }

    // Safely exit the current POS process to release executable and DLL file locks
    exit(0);
  }

  /// Generates a robust Windows batch updater script with file preservation.
  static String generateFallbackBatchScript({
    required int pid,
    required String source,
    required String target,
    required String exeName,
  }) {
    return '''
@echo off
setlocal enabledelayedexpansion

:: 1. Wait for POS process $pid to terminate
:WAIT_PID
tasklist /fi "PID eq $pid" 2>nul | find /i "$pid" >nul
if not errorlevel 1 (
    timeout /t 1 /nobreak >nul
    goto WAIT_PID
)

:: Extra wait to ensure all file locks are released
timeout /t 1 /nobreak >nul

:: 2. Copy all release files from source to target, strictly preserving user configuration and databases
:: Excluded files: .env, .env.example, *.db, *.key, *.sqlite, *.sqlite3
robocopy "$source" "$target" /E /IS /IT /NP /R:3 /W:1 /XF .env .env.example *.db *.key *.sqlite *.sqlite3

:: 3. Restart POS application
cd /d "$target"
start "" "$target\\$exeName"

:: 4. Clean up temporary files
timeout /t 2 /nobreak >nul
rmdir /s /q "$source" 2>nul

exit
''';
  }
}
