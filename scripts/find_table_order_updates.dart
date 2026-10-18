import 'dart:io';

void main() {
  final content = File('frontend/lib/features/tables/tables_screen.dart').readAsStringSync();
  final lines = content.split('\n');

  for (int i = 0; i < lines.length; i++) {
    if (lines[i].contains('ordersApi.updateOrder(effectiveOrderId')) {
      print('Line ${i + 1}:');
      for (int j = i - 5; j <= i + 15 && j < lines.length; j++) {
        print('${j + 1}: ${lines[j]}');
      }
      print('========================================');
    }
  }
}
