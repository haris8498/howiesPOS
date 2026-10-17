import '../models/order_model.dart';

/// Abstract contract for Order persistence and queries
abstract class IOrderRepository {
  Future<List<OrderModel>> getAllOrders();
  Future<OrderModel?> getOrderById(String id);
  Future<List<OrderModel>> getCompletedOrders();
  Future<List<OrderModel>> getHeldOrders();
  Future<OrderModel> saveOrder(OrderModel order);
  Future<void> updateOrderStatus(String orderId, OrderStatus status);
  Future<void> cancelOrder(String orderId);
  Future<void> deleteHeldOrder(String orderId);
}
