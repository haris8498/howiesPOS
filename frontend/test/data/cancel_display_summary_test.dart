import 'package:flutter_test/flutter_test.dart';
import 'package:hungry_howies_pos/domain/models/delivery_model.dart';

void main() {
  group('Cancel display summary tests (#39, #40)', () {
    test('DeliveryOrder.fromBackendJson produces itemsSummary with exactly one active Pizza when one Pizza is active and one is cancelled', () {
      final jsonPayload = {
        'id': 'delivery-order-1',
        'order_number': 'ORD-101',
        'status': 'pending',
        'order_items': [
          {
            'id': 'item-1',
            'item_name': 'Pizza',
            'quantity': 1,
            'unit_price': 14.99,
            'is_cancelled': false,
          },
          {
            'id': 'item-2',
            'item_name': 'Pizza',
            'quantity': 1,
            'unit_price': 14.99,
            'is_cancelled': true,
          },
        ],
      };

      final order = DeliveryOrder.fromBackendJson(jsonPayload);

      expect(order.itemsSummary, equals('1x Pizza'));
      expect(RegExp(r'\b1x Pizza\b').allMatches(order.itemsSummary).length, equals(1));
      expect(order.itemsSummary.contains('1x Pizza, 1x Pizza'), isFalse);
    });

    test('DeliveryOrder.fromBackendJson excludes voided item from itemsSummary', () {
      final jsonPayload = {
        'id': 'delivery-order-2',
        'order_number': 'ORD-102',
        'status': 'pending',
        'order_items': [
          {
            'id': 'item-1',
            'item_name': 'Pepperoni Pizza',
            'quantity': 2,
            'unit_price': 14.99,
            'is_cancelled': false,
          },
          {
            'id': 'item-2',
            'item_name': 'Buffalo Wings',
            'quantity': 1,
            'unit_price': 8.50,
            'voided_at': '2026-10-30T12:00:00.000Z',
          },
        ],
      };

      final order = DeliveryOrder.fromBackendJson(jsonPayload);

      expect(order.itemsSummary, equals('2x Pepperoni Pizza'));
      expect(order.itemsSummary.contains('Buffalo Wings'), isFalse);
    });
  });
}
