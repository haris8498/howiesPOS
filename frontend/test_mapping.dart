import 'dart:convert';
import 'package:http/http.dart' as http;
import 'lib/domain/models/order_model.dart';
import 'lib/domain/models/online_order_model.dart';
import 'lib/domain/models/menu_item.dart';

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
        .map((j) {
           return OrderModel.fromBackendJson(j as Map<String, dynamic>);
        })
        .where((ord) => ord.items.isNotEmpty)
        .toList();
    
    print('Successfully mapped to ${onlineList.length} OrderModels');

    for (var ord in onlineList) {
       print('Mapping items for ${ord.orderNumber}');
       final onlineItems = ord.items.map((i) => OnlineOrderItemModel(
          itemName: i.item.name,
          quantity: i.quantity,
          unitPrice: i.unitPrice,
          size: i.selectedSize,
          toppings: i.extraToppings,
          specialInstructions: i.notes,
       )).toList();
       print('  Mapped ${onlineItems.length} items successfully');
    }
  } catch (e, stack) {
    print('Error: $e');
    print(stack);
  }
}
