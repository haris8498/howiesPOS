import '../../domain/models/order_model.dart';
import '../../domain/repositories/order_repository.dart';
import '../../services/api/orders_api_service.dart';

class ApiOrderRepository implements IOrderRepository {
  final OrdersApiService _ordersApiService;
  final List<OrderModel> _localCache = [];

  ApiOrderRepository({OrdersApiService? ordersApiService})
      : _ordersApiService = ordersApiService ?? OrdersApiService();

  @override
  Future<List<OrderModel>> getAllOrders() async {
    try {
      final jsonList = await _ordersApiService.listOrders();
      final orders = jsonList.map((j) => OrderModel.fromBackendJson(j)).toList();
      _localCache.clear();
      _localCache.addAll(orders);
      return orders;
    } catch (_) {
      return List.unmodifiable(_localCache);
    }
  }

  @override
  Future<OrderModel?> getOrderById(String id) async {
    try {
      final json = await _ordersApiService.getOrderById(id);
      return OrderModel.fromBackendJson(json);
    } catch (_) {
      try {
        return _localCache.firstWhere((o) => o.id == id);
      } catch (_) {
        return null;
      }
    }
  }

  @override
  Future<List<OrderModel>> getCompletedOrders() async {
    try {
      final jsonList = await _ordersApiService.listOrders(status: 'completed');
      return jsonList.map((j) => OrderModel.fromBackendJson(j)).toList();
    } catch (_) {
      return _localCache.where((o) => o.status == OrderStatus.completed).toList();
    }
  }

  @override
  Future<List<OrderModel>> getHeldOrders() async {
    try {
      final jsonList = await _ordersApiService.listOrders(isHeld: true);
      return jsonList.map((j) => OrderModel.fromBackendJson(j)).toList();
    } catch (_) {
      return _localCache.where((o) => o.isHeld).toList();
    }
  }

  @override
  Future<OrderModel> saveOrder(OrderModel order) async {
    // SYNC-009: In online-only mode, do not catch & swallow errors.
    // Propagate API / network exceptions so checkout handles failures truthfully.
    final dto = order.toCreateOrderDto();
    final res = await _ordersApiService.createOrder(dto);
    final created = OrderModel.fromBackendJson(res);
    _localCache.insert(0, created);
    return created;
  }

  @override
  Future<OrderModel> updateOrder(OrderModel order) async {
    // SYNC-009: In online-only mode, do not catch & swallow errors.
    final dto = order.toCreateOrderDto();
    final res = await _ordersApiService.updateOrder(order.id, dto);
    final updated = OrderModel.fromBackendJson(res);
    final index = _localCache.indexWhere((o) => o.id == order.id);
    if (index >= 0) {
      _localCache[index] = updated;
    }
    return updated;
  }

  @override
  Future<void> updateOrderStatus(String orderId, OrderStatus status) async {
    try {
      await _ordersApiService.updateOrderStatus(orderId, status: status.name);
    } catch (_) {}

    final index = _localCache.indexWhere((o) => o.id == orderId);
    if (index >= 0) {
      _localCache[index] = _localCache[index].copyWith(status: status);
    }
  }

  @override
  Future<void> cancelOrder(String orderId) async {
    try {
      await _ordersApiService.updateOrderStatus(orderId, status: 'cancelled');
    } catch (_) {
      await _ordersApiService.deleteOrder(orderId);
    }

    _localCache.removeWhere((o) => o.id == orderId);
  }

  @override
  Future<void> deleteHeldOrder(String orderId) async {
    try {
      await _ordersApiService.deleteOrder(orderId);
    } catch (_) {}
    _localCache.removeWhere((o) => o.id == orderId);
  }

  @override
  Future<OrderItem> addOrderItem(String orderId, OrderItem item) async {
    final res = await _ordersApiService.appendOrderItems(orderId, [item.toCreateItemDto()]);
    if (res.isNotEmpty) {
      return OrderItem.fromBackendJson(res.first);
    }
    return item;
  }

  @override
  Future<void> voidOrderItem(String orderId, String itemId, {int? cancelQuantity, String? voidedBy, String? reason}) async {
    if (cancelQuantity != null && cancelQuantity > 0) {
      await _ordersApiService.cancelOrderItem(
        orderId,
        itemId: itemId,
        cancelQuantity: cancelQuantity,
        reason: reason,
        cancelledBy: voidedBy,
      );
    } else {
      await _ordersApiService.voidOrderItem(orderId, itemId, voidedBy: voidedBy, reason: reason);
    }
  }
}
