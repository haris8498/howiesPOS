import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

Future<bool> downloadFileFromBytes(
  List<int> bytes,
  String filename,
  String mimeType,
) async {
  try {
    final extension = filename.contains('.') ? filename.split('.').last : '';
    final outputFile = await FilePicker.platform.saveFile(
      dialogTitle: 'Save File',
      fileName: filename,
      type: extension.isNotEmpty ? FileType.custom : FileType.any,
      allowedExtensions: extension.isNotEmpty ? [extension] : null,
      bytes: Uint8List.fromList(bytes),
    );

    if (outputFile != null && outputFile.isNotEmpty) {
      final file = File(outputFile);
      if (!await file.exists() || (await file.length()) == 0) {
        await file.writeAsBytes(bytes, flush: true);
      }
      return true;
    }
    return false;
  } catch (e) {
    debugPrint('FilePicker save error: $e');
    try {
      final homeOrUser = Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'] ?? '.';
      final downloadsDir = Directory('$homeOrUser\\Downloads');
      final targetDir = await downloadsDir.exists() ? downloadsDir.path : homeOrUser;
      final file = File('$targetDir\\$filename');
      await file.writeAsBytes(bytes, flush: true);
      return true;
    } catch (err) {
      debugPrint('Fallback save error: $err');
      return false;
    }
  }
}

