import 'package:flutter_test/flutter_test.dart';
import 'package:hungry_howies_pos/domain/models/menu_item.dart';
import 'package:hungry_howies_pos/domain/models/order_model.dart';

void main() {
  group('Cancel display summary tests (#39, #40)', () {
    test('OrderItem list with active and cancelled items produces summary containing only active items', () {
      const pizza = MenuItem(
        id: 'item-1',
        name: 'Pepperoni Pizza',
        category: 'Pizza',
        description: 'Classic Pepperoni',
        basePrice: 14.99,
        imageUrl: '',
      );

      const wings = MenuItem(
        id: 'item-2',
        name: 'Buffalo Wings',
        category: 'Sides',
        description: 'Spicy Wings',
        basePrice: 8.50,
        imageUrl: '',
      );

      final items = [
        const OrderItem(
          id: 'order-item-1',
          item: pizza,
          quantity: 2,
          isCancelled: false,
        ),
        const OrderItem(
          id: 'order-item-2',
          item: wings,
          quantity: 1,
          isCancelled: true,
        ),
      ];

      final activeItems = items.where((i) => !i.isCancelled).toList();
      final summary = activeItems.map((i) => '${i.quantity}x ${i.item.name}').join(', ');

      expect(summary, equals('2x Pepperoni Pizza'));
      expect(summary.contains('Buffalo Wings'), isFalse);
    });
  });
}
