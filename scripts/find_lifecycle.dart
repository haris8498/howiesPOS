import 'dart:io';

void main() {
  final dir = Directory('frontend/lib');
  final dartFiles = dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));

  for (final file in dartFiles) {
    final content = file.readAsStringSync();
    final lines = content.split('\n');
    String? currentMethod;
    int braceCount = 0;
    bool inMethod = false;
    List<String> methodLines = [];
    int startLine = 0;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (!inMethod) {
        if (RegExp(r'\b(initState|didUpdateWidget|didChangeDependencies|dispose)\s*\(').hasMatch(line)) {
          inMethod = true;
          currentMethod = line.trim();
          braceCount = 0;
          methodLines = [line];
          startLine = i + 1;
        }
      }
      
      if (inMethod) {
        if (!methodLines.contains(line)) methodLines.add(line);
        braceCount += '{'.allMatches(line).length;
        braceCount -= '}'.allMatches(line).length;
        if (braceCount <= 0 && methodLines.length > 1) {
          final methodText = methodLines.join('\n');
          if (methodText.contains('ref.read(')) {
            print('MATCH in ${file.path}:$startLine: $currentMethod');
            print(methodText);
            print('----------------------------------------');
          }
          inMethod = false;
          methodLines.clear();
        }
      }
    }
  }
}
