import '../../domain/models/order_model.dart';
import '../../domain/repositories/kitchen_repository.dart';
import '../../services/api/kitchen_api_service.dart';

class ApiKitchenRepository implements IKitchenRepository {
  final KitchenApiService _kitchenApiService;
  final List<OrderModel> _localCache = [];

  ApiKitchenRepository({KitchenApiService? kitchenApiService})
      : _kitchenApiService = kitchenApiService ?? KitchenApiService();

  @override
  Future<List<OrderModel>> getKitchenOrders() async {
    try {
      final jsonList = await _kitchenApiService.getKitchenOrders();
      if (jsonList.isNotEmpty) {
        final orders = jsonList.map((j) => OrderModel.fromBackendJson(j)).toList();
        _localCache.clear();
        _localCache.addAll(orders);
        return orders;
      }
    } catch (_) {}
    return List.unmodifiable(_localCache);
  }

  @override
  Future<void> addKitchenOrder(OrderModel order) async {
    try {
      if (order.id.isNotEmpty && !order.id.startsWith('temp_')) {
        await _kitchenApiService.sendKitchenTicket(order.id);
      }
    } catch (_) {}

    final index = _localCache.indexWhere((o) => o.id == order.id);
    if (index >= 0) {
      _localCache[index] = order;
    } else {
      _localCache.insert(0, order);
    }
  }

  @override
  Future<void> updateKitchenOrderStatus(String orderId, OrderStatus status) async {
    try {
      await _kitchenApiService.updateStatus(orderId, status.name);
    } catch (_) {}

    final index = _localCache.indexWhere((o) => o.id == orderId);
    if (index >= 0) {
      _localCache[index] = _localCache[index].copyWith(status: status);
    }
  }

  @override
  Future<void> clearCompletedKitchenOrders() async {
    _localCache.removeWhere((o) => o.status == OrderStatus.completed || o.status == OrderStatus.cancelled);
  }
}
