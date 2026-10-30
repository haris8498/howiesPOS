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
  Future<void> voidOrderItem(
    String orderId,
    String itemId, {
    String? voidedBy,
    String? reason,
    int? quantity,
    String? splitItemId,
  }) async {
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index >= 0) {
      final order = _orders[index];
      final itemIndex = order.items.indexWhere((i) => i.id == itemId);
      if (itemIndex >= 0) {
        final item = order.items[itemIndex];
        final now = DateTime.now();
        if (quantity != null && quantity > 0 && quantity < item.quantity) {
          final remainingQty = item.quantity - quantity;
          final updatedOriginal = item.copyWith(quantity: remainingQty);
          final splitItem = item.copyWith(
            id: splitItemId ?? const Uuid().v7(),
            quantity: quantity,
            isCancelled: true,
            cancelledAt: now,
            cancelReason: reason,
            voidedAt: now,
            voidedBy: voidedBy,
          );
          final updatedItems = List<OrderItem>.from(order.items);
          updatedItems[itemIndex] = updatedOriginal;
          updatedItems.add(splitItem);
          _orders[index] = order.copyWith(items: updatedItems);
        } else {
          final updatedItems = order.items.map((i) {
            if (i.id == itemId) {
              return i.copyWith(
                isCancelled: true,
                cancelledAt: now,
                cancelReason: reason,
                voidedAt: now,
                voidedBy: voidedBy,
              );
            }
            return i;
          }).toList();
          _orders[index] = order.copyWith(items: updatedItems);
        }
      }
    }
  }
}
