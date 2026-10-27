import '../models/order_model.dart';

/// Abstract contract for Order persistence and queries.
/// Derived directly from legacy ApiOrderRepository so that ApiOrderRepository
/// implements this interface unchanged (Spec §17.2).
abstract class IOrderRepository {
  Future<List<OrderModel>> getAllOrders();
  Future<OrderModel?> getOrderById(String id);
  Future<List<OrderModel>> getCompletedOrders();
  Future<List<OrderModel>> getHeldOrders();
  Future<OrderModel> saveOrder(OrderModel order);
  Future<OrderModel> updateOrder(OrderModel order);
  Future<void> updateOrderStatus(String orderId, OrderStatus status);
  Future<void> cancelOrder(String orderId);
  Future<void> deleteHeldOrder(String orderId);
  Future<OrderItem> addOrderItem(String orderId, OrderItem item);
  Future<void> voidOrderItem(String orderId, String itemId, {String? voidedBy, String? reason});
}
