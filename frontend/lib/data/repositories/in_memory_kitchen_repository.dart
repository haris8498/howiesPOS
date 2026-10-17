import '../../domain/models/order_model.dart';
import '../../domain/repositories/kitchen_repository.dart';

/// In-Memory implementation of IKitchenRepository
class InMemoryKitchenRepository implements IKitchenRepository {
  final List<OrderModel> _kitchenOrders = [];

  @override
  Future<List<OrderModel>> getKitchenOrders() async => List.unmodifiable(_kitchenOrders);

  @override
  Future<void> addKitchenOrder(OrderModel order) async {
    _kitchenOrders.insert(0, order);
  }

  @override
  Future<void> updateKitchenOrderStatus(String orderId, OrderStatus status) async {
    final index = _kitchenOrders.indexWhere((o) => o.id == orderId);
    if (index >= 0) {
      _kitchenOrders[index] = _kitchenOrders[index].copyWith(status: status);
    }
  }

  @override
  Future<void> clearCompletedKitchenOrders() async {
    _kitchenOrders.removeWhere((o) => o.status == OrderStatus.served || o.status == OrderStatus.completed);
  }
}
