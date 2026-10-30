import 'package:flutter_test/flutter_test.dart';
import 'package:hungry_howies_pos/features/tables/table_cancel_helper.dart';

void main() {
  group('TableCancelHelper Tests (#39)', () {
    test('1. applyTableItemCancellations splits qty-2 item when cancelQty=1', () {
      final items = [
        {
          'id': 'item-1',
          'quantity': 2,
          'price': 10.0,
          'is_cancelled': false,
        },
      ];

      final result = applyTableItemCancellations(
        currentOrderItems: items,
        cancelQuantities: {'item-1': 1},
        reason: 'Customer changed mind',
        cancelledBy: 'Cashier',
      );

      expect(result.length, equals(2));

      final activeEntry = result.firstWhere((i) => i['id'] == 'item-1');
      expect(activeEntry['quantity'], equals(1));
      expect(activeEntry['is_cancelled'] != true, isTrue);

      final splitEntry = result.firstWhere((i) => i['id'] != 'item-1');
      expect(splitEntry['quantity'], equals(1));
      expect(splitEntry['is_cancelled'], isTrue);
    });
  });
}
