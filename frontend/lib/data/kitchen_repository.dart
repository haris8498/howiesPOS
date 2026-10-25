import 'repositories/order_repository_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/models/order_model.dart';
import '../services/api/api_providers.dart';
import '../services/api/kitchen_api_service.dart';
import '../core/network/kitchen_socket_service.dart';
import '../services/mock_api_service.dart';

class KitchenState {
  final List<OrderModel> kitchenOrders;
  final String activeFilter; // All, New, Accepted, Preparing, Ready
  final bool isLoading;
  final bool isSocketConnected;

  const KitchenState({
    required this.kitchenOrders,
    this.activeFilter = 'All',
    this.isLoading = false,
    this.isSocketConnected = false,
  });

  int get newCount => kitchenOrders.where((o) => o.status == OrderStatus.newOrder).length;
  int get acceptedCount => kitchenOrders.where((o) => o.status == OrderStatus.accepted).length;
  int get preparingCount => kitchenOrders.where((o) => o.status == OrderStatus.preparing).length;
  int get readyCount => kitchenOrders.where((o) => o.status == OrderStatus.ready).length;

  List<OrderModel> get filteredOrders {
    if (activeFilter == 'All') return kitchenOrders;
    if (activeFilter == 'New') return kitchenOrders.where((o) => o.status == OrderStatus.newOrder).toList();
    if (activeFilter == 'Accepted') return kitchenOrders.where((o) => o.status == OrderStatus.accepted).toList();
    if (activeFilter == 'Preparing') return kitchenOrders.where((o) => o.status == OrderStatus.preparing).toList();
    if (activeFilter == 'Ready') return kitchenOrders.where((o) => o.status == OrderStatus.ready).toList();
    return kitchenOrders;
  }

  KitchenState copyWith({
    List<OrderModel>? kitchenOrders,
    String? activeFilter,
    bool? isLoading,
    bool? isSocketConnected,
  }) {
    return KitchenState(
      kitchenOrders: kitchenOrders ?? this.kitchenOrders,
      activeFilter: activeFilter ?? this.activeFilter,
      isLoading: isLoading ?? this.isLoading,
      isSocketConnected: isSocketConnected ?? this.isSocketConnected,
    );
  }
}

class KitchenNotifier extends StateNotifier<KitchenState> {
  final KitchenApiService _kitchenApiService;
  final KitchenSocketService? _kitchenSocketService;
  final Ref? _ref;

  KitchenNotifier({
    KitchenApiService? kitchenApiService,
    this._kitchenSocketService,
    Ref? ref,
  })  : _kitchenApiService = kitchenApiService ?? KitchenApiService(),
        _ref = ref,
        super(KitchenState(
          kitchenOrders: [
            OrderModel(
              id: 'k-101',
              orderNumber: 'HH-7412',
              tableId: 't1',
              tableName: 'Table 01',
              type: OrderType.dineIn,
              status: OrderStatus.accepted,
              items: [
                OrderItem(item: MockApiService.getInitialMenuItems()[0], quantity: 2, selectedCrust: 'Butter Cheese', selectedSize: 'Large'),
                OrderItem(item: MockApiService.getInitialMenuItems()[5], quantity: 1, selectedCrust: 'Cajun', selectedSize: 'Regular'),
              ],
              createdAt: DateTime.now().subtract(const Duration(minutes: 8)),
            ),
            OrderModel(
              id: 'k-102',
              orderNumber: 'HH-7413',
              tableId: 't5',
              tableName: 'VIP Booth 01',
              type: OrderType.dineIn,
              status: OrderStatus.preparing,
              items: [
                OrderItem(item: MockApiService.getInitialMenuItems()[1], quantity: 1, selectedCrust: 'Cajun', selectedSize: 'Extra Large'),
                OrderItem(item: MockApiService.getInitialMenuItems()[7], quantity: 2),
              ],
              createdAt: DateTime.now().subtract(const Duration(minutes: 14)),
            ),
            OrderModel(
              id: 'k-103',
              orderNumber: 'HH-7414',
              type: OrderType.takeaway,
              status: OrderStatus.ready,
              items: [
                OrderItem(item: MockApiService.getInitialMenuItems()[2], quantity: 1, selectedCrust: 'Ranch', selectedSize: 'Medium'),
              ],
              createdAt: DateTime.now().subtract(const Duration(minutes: 22)),
            ),
          ],
        )) {
    _init();
  }

  void _init() {
    loadKitchenOrders();
    _setupRealtimeSocket();
  }

  void _setupRealtimeSocket() {
    final socket = _kitchenSocketService;
    if (socket == null) return;

    socket.connect();
    socket.joinKitchen();

    // Listen to real-time events from NestJS KitchenGateway
    socket.on('order.created', _onSocketOrderReceived);
    socket.on('kitchen.order_created', _onSocketOrderReceived);
    socket.on('order.updated', _onSocketOrderReceived);
    socket.on('kitchen.order_updated', _onSocketOrderReceived);
    socket.on('order.status_changed', _onSocketStatusChanged);
    socket.on('kitchen.status_changed', _onSocketStatusChanged);
    socket.on('order.ready', _onSocketOrderReady);
    socket.on('kitchen.order_ready', _onSocketOrderReady);
    socket.on('kitchen.ticket_sent', _onSocketOrderReceived);
    socket.on('order.cancelled', _onSocketOrderCancelled);
  }

  void _onSocketOrderReceived(Map<String, dynamic> payload) {
    try {
      final order = OrderModel.fromBackendJson(payload);
      addIncomingOrder(order);
    } catch (_) {}
  }

  void _onSocketStatusChanged(Map<String, dynamic> payload) {
    try {
      final orderId = payload['orderId']?.toString() ?? payload['id']?.toString();
      final statusStr = payload['status']?.toString().toLowerCase() ?? '';
      if (orderId != null) {
        OrderStatus next = OrderStatus.accepted;
        if (statusStr == 'preparing') next = OrderStatus.preparing;
        if (statusStr == 'ready') next = OrderStatus.ready;
        if (statusStr == 'served') next = OrderStatus.served;
        if (statusStr == 'completed') next = OrderStatus.completed;
        if (statusStr == 'cancelled') next = OrderStatus.cancelled;

        _applyStatusUpdate(orderId, next);
      }
    } catch (_) {}
  }

  void _onSocketOrderReady(Map<String, dynamic> payload) {
    final orderId = payload['orderId']?.toString() ?? payload['id']?.toString();
    if (orderId != null) {
      _applyStatusUpdate(orderId, OrderStatus.ready);
    }
  }

  void _onSocketOrderCancelled(Map<String, dynamic> payload) {
    final orderId = payload['orderId']?.toString() ?? payload['id']?.toString();
    if (orderId != null) {
      _applyStatusUpdate(orderId, OrderStatus.cancelled);
    }
  }

  Future<void> loadKitchenOrders() async {
    state = state.copyWith(isLoading: true);
    try {
      final ordersJson = await _kitchenApiService.getKitchenOrders();
      if (ordersJson.isNotEmpty) {
        final orders = ordersJson.map((j) => OrderModel.fromBackendJson(j)).toList();
        state = state.copyWith(kitchenOrders: orders, isLoading: false);
        return;
      }
    } catch (_) {}
    state = state.copyWith(isLoading: false);
  }

  void setFilter(String filter) {
    state = state.copyWith(activeFilter: filter);
  }

  Future<void> updateOrderStatus(String orderId, OrderStatus nextStatus) async {
    try {
      await _kitchenApiService.updateStatus(orderId, nextStatus.name);
    } catch (_) {}
    if (_ref != null) {
      try {
        final orderRepo = _ref!.read(orderRepositoryProvider);
        await orderRepo.updateOrderStatus(orderId, nextStatus);
      } catch (_) {}
    }
    _applyStatusUpdate(orderId, nextStatus);
  }

  void _applyStatusUpdate(String orderId, OrderStatus nextStatus) {
    final updated = state.kitchenOrders.map((order) {
      if (order.id == orderId || order.orderNumber == orderId) {
        return order.copyWith(status: nextStatus);
      }
      return order;
    }).toList();
    state = state.copyWith(kitchenOrders: updated);
  }

  Future<void> updateCookingTimer(String orderId, int minutes) async {
    try {
      await _kitchenApiService.updateCookingTime(orderId, minutes);
    } catch (_) {}
  }

  void addIncomingOrder(OrderModel newOrder) {
    final index = state.kitchenOrders.indexWhere((o) => o.id == newOrder.id || o.orderNumber == newOrder.orderNumber);
    if (index >= 0) {
      final updated = List<OrderModel>.from(state.kitchenOrders);
      updated[index] = newOrder;
      state = state.copyWith(kitchenOrders: updated);
    } else {
      state = state.copyWith(kitchenOrders: [newOrder, ...state.kitchenOrders]);
    }
  }
}

final kitchenProvider = StateNotifierProvider<KitchenNotifier, KitchenState>((ref) {
  final kitchenApi = ref.read(kitchenApiServiceProvider);
  final socketService = ref.read(kitchenSocketServiceProvider);
  return KitchenNotifier(
    kitchenApiService: kitchenApi,
    kitchenSocketService: socketService,
    ref: ref,
  );
});
