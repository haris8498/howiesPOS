import 'dart:io';

void main() {
  final dir = Directory('frontend/lib');
  final dartFiles = dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));

  for (final file in dartFiles) {
    final content = file.readAsStringSync();
    final lines = content.split('\n');
    bool inBuild = false;
    int braceCount = 0;
    List<String> buildLines = [];
    int startLine = 0;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (!inBuild && RegExp(r'Widget\s+build\s*\(').hasMatch(line)) {
        inBuild = true;
        braceCount = 0;
        buildLines = [line];
        startLine = i + 1;
      }
      
      if (inBuild) {
        if (!buildLines.contains(line)) buildLines.add(line);
        braceCount += '{'.allMatches(line).length;
        braceCount -= '}'.allMatches(line).length;
        if (braceCount <= 0 && buildLines.length > 1) {
          final buildText = buildLines.join('\n');
          // Check for .notifier).<action> outside of callbacks (e.g. onTap, onPressed)
          final linesInBuild = buildLines;
          for (int j = 0; j < linesInBuild.length; j++) {
            final l = linesInBuild[j].trim();
            // If it has ref.read(...notifier) or ref.watch(...notifier)
            if ((l.contains('ref.read(') || l.contains('ref.watch(')) && l.contains('notifier)')) {
              // check if line appears inside a callback or statement
              // print candidate
              print('${file.path}:${startLine + j}: $l');
            }
          }
          inBuild = false;
          buildLines.clear();
        }
      }
    }
  }
}
