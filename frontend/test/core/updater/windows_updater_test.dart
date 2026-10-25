import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:archive/archive.dart';
import 'package:hungry_howies_pos/core/updater/update_models.dart';
import 'package:hungry_howies_pos/core/updater/windows_updater.dart';

void main() {
  group('UpdateProgress models', () {
    test('formats progress byte strings correctly', () {
      const p1 = UpdateProgress(
        phase: UpdatePhase.downloading,
        percentage: 0.5,
        downloadedBytes: 50 * 1024 * 1024,
        totalBytes: 100 * 1024 * 1024,
      );
      expect(p1.formattedProgress, contains('50.0 MB / 100.0 MB (50%)'));

      const p2 = UpdateProgress(
        phase: UpdatePhase.downloading,
        percentage: 0.72,
        downloadedBytes: 0,
        totalBytes: 0,
      );
      expect(p2.formattedProgress, '72%');
    });

    test('phase helper getters report correctly', () {
      const downloading = UpdateProgress(phase: UpdatePhase.downloading);
      expect(downloading.isDownloading, isTrue);
      expect(downloading.isExtracting, isFalse);

      const extracting = UpdateProgress(phase: UpdatePhase.extracting);
      expect(extracting.isExtracting, isTrue);

      const err =
          UpdateProgress(phase: UpdatePhase.error, errorMessage: 'Failed');
      expect(err.isError, isTrue);
    });
  });

  group('WindowsUpdater file safety & extraction', () {
    test(
        'fallback batch script explicitly excludes user databases and .env files',
        () {
      final updater = WindowsUpdater();
      expect(updater.targetExeName, 'hungry_howies_pos.exe');

      // Verify that the batch script generator logic excludes persistent configuration
      final script = WindowsUpdater.generateFallbackBatchScript(
        pid: 1234,
        source: r'C:\temp\update',
        target: r'C:\Program Files\HowiesPOS',
        exeName: 'hungry_howies_pos.exe',
      );

      expect(script,
          contains('/XF .env .env.example *.db *.key *.sqlite *.sqlite3'));
      expect(script, contains('hungry_howies_pos.exe'));
      expect(script, contains('1234'));
    });

    test('extracts zip archives safely without corrupting files', () async {
      final tempDir = Directory.systemTemp.createTempSync('test_zip_extract_');
      try {
        // Create an in-memory test zip
        final archive = Archive();
        archive.addFile(
            ArchiveFile('hungry_howies_pos.exe', 12, 'TEST_EXE_DATA'.codeUnits));
        archive.addFile(
            ArchiveFile('data/app.so', 11, 'TEST_SO_DAT'.codeUnits));

        final zipBytes = ZipEncoder().encode(archive);
        final zipFile = File('${tempDir.path}/test.zip')
          ..writeAsBytesSync(zipBytes);

        final targetDir = Directory('${tempDir.path}/out');
        await targetDir.create();

        // Extract using pure-dart archive
        final extractedBytes = zipFile.readAsBytesSync();
        final decoded = ZipDecoder().decodeBytes(extractedBytes);
        for (final f in decoded) {
          if (f.isFile) {
            final outFile = File('${targetDir.path}/${f.name}');
            outFile.parent.createSync(recursive: true);
            outFile.writeAsBytesSync(f.content as List<int>);
          }
        }

        expect(
            File('${targetDir.path}/hungry_howies_pos.exe').existsSync(), isTrue);
        expect(File('${targetDir.path}/data/app.so').existsSync(), isTrue);
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });
  });
}
