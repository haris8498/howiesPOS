import 'package:uuid/uuid.dart';
import '../../domain/models/order_model.dart';
import '../../domain/repositories/order_repository.dart';

/// In-Memory implementation of IOrderRepository
class InMemoryOrderRepository implements IOrderRepository {
  final List<OrderModel> _orders = [];
  final List<OrderModel> _heldOrders = [];

  @override
  Future<List<OrderModel>> getAllOrders() async => List.unmodifiable(_orders);

  @override
  Future<OrderModel?> getOrderById(String id) async {
    final index = _orders.indexWhere((o) => o.id == id);
    return index >= 0 ? _orders[index] : null;
  }

  @override
  Future<List<OrderModel>> getCompletedOrders() async {
    return _orders.where((o) => o.isPaid || o.status == OrderStatus.completed).toList();
  }

  @override
  Future<List<OrderModel>> getHeldOrders() async => List.unmodifiable(_heldOrders);

  @override
  Future<OrderModel> saveOrder(OrderModel order) async {
    final index = _orders.indexWhere((o) => o.id == order.id);
    if (index >= 0) {
      _orders[index] = order;
    } else {
      _orders.insert(0, order);
    }
    return order;
  }

  @override
  Future<OrderModel> updateOrder(OrderModel order) async {
    final index = _orders.indexWhere((o) => o.id == order.id);
    if (index >= 0) {
      _orders[index] = order;
    } else {
      _orders.insert(0, order);
    }
    return order;
  }

  @override
  Future<void> updateOrderStatus(String orderId, OrderStatus status) async {
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index >= 0) {
      _orders[index] = _orders[index].copyWith(status: status);
    }
  }

  @override
  Future<void> cancelOrder(String orderId) async {
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index >= 0) {
      _orders[index] = _orders[index].copyWith(status: OrderStatus.cancelled);
    }
  }

  @override
  Future<void> deleteHeldOrder(String orderId) async {
    _heldOrders.removeWhere((o) => o.id == orderId);
  }

  @override
  Future<OrderItem> addOrderItem(String orderId, OrderItem item) async {
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index >= 0) {
      final order = _orders[index];
      final updatedItems = List<OrderItem>.from(order.items)..add(item);
      _orders[index] = order.copyWith(items: updatedItems);
    }
    return item;
  }

  @override
  Future<void> voidOrderItem(String orderId, String itemId, {int? cancelQuantity, String? voidedBy, String? reason}) async {
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index >= 0) {
      final order = _orders[index];
      final List<OrderItem> updatedItems = [];
      for (final i in order.items) {
        if (i.id == itemId) {
          if (cancelQuantity != null && cancelQuantity > 0 && cancelQuantity < i.quantity) {
            updatedItems.add(i.copyWith(quantity: i.quantity - cancelQuantity));
            updatedItems.add(i.copyWith(
              id: const Uuid().v7(),
              quantity: cancelQuantity,
              isCancelled: true,
              cancelledAt: DateTime.now(),
              cancelReason: reason,
              voidedAt: DateTime.now(),
              voidedBy: voidedBy,
            ));
          } else {
            updatedItems.add(i.copyWith(
              isCancelled: true,
              cancelledAt: DateTime.now(),
              cancelReason: reason,
              voidedAt: DateTime.now(),
              voidedBy: voidedBy,
            ));
          }
        } else {
          updatedItems.add(i);
        }
      }
      _orders[index] = order.copyWith(items: updatedItems);
    }
  }
}
