// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:typed_data';

Future<bool> downloadFileFromBytes(List<int> bytes, String filename, String mimeType) async {
  try {
    final uint8Bytes = Uint8List.fromList(bytes);
    final blob = html.Blob([uint8Bytes], mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.document.createElement('a') as html.AnchorElement
      ..href = url
      ..style.display = 'none'
      ..download = filename;
    html.document.body?.children.add(anchor);
    anchor.click();
    html.document.body?.children.remove(anchor);
    html.Url.revokeObjectUrl(url);
    return true;
  } catch (e) {
    return false;
  }
}

