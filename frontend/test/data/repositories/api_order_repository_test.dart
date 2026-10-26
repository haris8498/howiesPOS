import 'package:flutter_test/flutter_test.dart';
import 'package:hungry_howies_pos/data/repositories/api_order_repository.dart';
import 'package:hungry_howies_pos/domain/models/order_model.dart';
import 'package:hungry_howies_pos/services/api/orders_api_service.dart';

class FailingOrdersApiService extends OrdersApiService {
  @override
  Future<Map<String, dynamic>> createOrder(Map<String, dynamic> dto) async {
    throw Exception('HTTP 409 Conflict: Order number already exists');
  }

  @override
  Future<Map<String, dynamic>> updateOrder(String orderId, Map<String, dynamic> dto) async {
    throw Exception('HTTP 500 Internal Server Error');
  }
}

class SuccessfulOrdersApiService extends OrdersApiService {
  @override
  Future<Map<String, dynamic>> createOrder(Map<String, dynamic> dto) async {
    return {
      'id': 'ord-online-1',
      'order_number': dto['order_number'] ?? 'HH-261026-1001',
      'order_type': dto['order_type'] ?? 'takeaway',
      'status': 'newOrder',
      'subtotal': 1500.0,
      'discount_amount': 0.0,
      'tax_amount': 0.0,
      'grand_total': 1500.0,
      'is_paid': false,
      'payment_status': 'UNPAID',
      'created_at': DateTime.now().toIso8601String(),
    };
  }
}

void main() {
  group('ApiOrderRepository Tests (SYNC-009: Online mode error propagation)', () {
    test('saveOrder propagates exceptions on API failure instead of silently swallowing', () async {
      final repo = ApiOrderRepository(ordersApiService: FailingOrdersApiService());
      final order = OrderModel(
        id: 'temp-1',
        orderNumber: 'P1-101',
        type: OrderType.takeaway,
        status: OrderStatus.newOrder,
        items: const [],
        subtotalOverride: 1000,
        discountAmount: 0,
        taxAmount: 0,
        grandTotalOverride: 1000,
        isPaid: false,
        createdAt: DateTime.now(),
      );

      expect(
        () => repo.saveOrder(order),
        throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('409 Conflict'))),
      );
    });

    test('updateOrder propagates exceptions on API failure', () async {
      final repo = ApiOrderRepository(ordersApiService: FailingOrdersApiService());
      final order = OrderModel(
        id: 'ord-100',
        orderNumber: 'P1-101',
        type: OrderType.takeaway,
        status: OrderStatus.newOrder,
        items: const [],
        subtotalOverride: 1000,
        discountAmount: 0,
        taxAmount: 0,
        grandTotalOverride: 1000,
        isPaid: false,
        createdAt: DateTime.now(),
      );

      expect(
        () => repo.updateOrder(order),
        throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('500 Internal Server Error'))),
      );
    });

    test('saveOrder persists and returns created order on API success', () async {
      final repo = ApiOrderRepository(ordersApiService: SuccessfulOrdersApiService());
      final order = OrderModel(
        id: 'temp-2',
        orderNumber: 'HH-261026-1001',
        type: OrderType.takeaway,
        status: OrderStatus.newOrder,
        items: const [],
        subtotalOverride: 1500,
        discountAmount: 0,
        taxAmount: 0,
        grandTotalOverride: 1500,
        isPaid: false,
        createdAt: DateTime.now(),
      );

      final result = await repo.saveOrder(order);
      expect(result.id, equals('ord-online-1'));
      expect(result.orderNumber, equals('HH-261026-1001'));
    });
  });
}
