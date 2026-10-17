import '../models/order_model.dart';

/// Abstract contract for Kitchen Display System (KDS) order lifecycle
abstract class IKitchenRepository {
  Future<List<OrderModel>> getKitchenOrders();
  Future<void> addKitchenOrder(OrderModel order);
  Future<void> updateKitchenOrderStatus(String orderId, OrderStatus status);
  Future<void> clearCompletedKitchenOrders();
}
