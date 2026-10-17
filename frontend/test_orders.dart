import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  try {
    final response = await http.get(Uri.parse('http://localhost:3000/api/orders'));
    final jsonList = jsonDecode(response.body)['data'] as List;
    print('Fetched ${jsonList.length} orders');

    final onlineList = jsonList
        .where((j) =>
            j['order_source']?.toString().toLowerCase().contains('online') == true ||
            j['order_type']?.toString().toLowerCase().contains('delivery') == true ||
            j['order_type']?.toString().toLowerCase().contains('online') == true)
        .toList();
    
    print('Filtered to ${onlineList.length} online orders');

    for (var j in onlineList) {
      print('Processing order: ${j['order_number']}');
      
      // We will just do a basic print of fields to see where it might fail
      final typeStr = j['order_type']?.toString().toLowerCase() ?? '';
      print(' Type: $typeStr');
      final items = j['order_items'] as List?;
      print(' Items: ${items?.length ?? 0}');

      if (items != null) {
        for (var i in items) {
          final itemName = i['item_name']?.toString() ?? 'Item';
          print('   Item: $itemName');
        }
      }
    }
  } catch (e, stack) {
    print('Error: $e');
    print(stack);
  }
}
