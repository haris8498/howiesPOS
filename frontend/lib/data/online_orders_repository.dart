import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/models/online_order_model.dart';
import '../domain/models/order_model.dart';
import '../services/api/api_providers.dart';
import '../services/api/orders_api_service.dart';

class OnlineOrdersState {
  final List<OnlineOrderModel> orders;
  final String activeFilter; // 'all', 'pending', 'accepted', 'rejected'
  final String searchQuery;
  final bool isLoading;

  const OnlineOrdersState({
    this.orders = const [],
    this.activeFilter = 'all',
    this.searchQuery = '',
    this.isLoading = false,
  });

  int get pendingCount => orders.where((o) => o.status == OnlineOrderStatus.pending).length;
  int get acceptedCount => orders.where((o) => o.status == OnlineOrderStatus.accepted).length;
  int get completedCount => orders.where((o) => o.status == OnlineOrderStatus.completed).length;
  int get rejectedCount => orders.where((o) => o.status == OnlineOrderStatus.rejected).length;

  List<OnlineOrderModel> get filteredOrders {
    return orders.where((order) {
      if (activeFilter == 'pending' && order.status != OnlineOrderStatus.pending) return false;
      if (activeFilter == 'accepted' && order.status != OnlineOrderStatus.accepted) return false;
      if (activeFilter == 'completed' && order.status != OnlineOrderStatus.completed) return false;
      if (activeFilter == 'rejected' && order.status != OnlineOrderStatus.rejected) return false;

      if (searchQuery.isNotEmpty) {
        final q = searchQuery.toLowerCase();
        final matchName = order.customerName.toLowerCase().contains(q);
        final matchPhone = order.customerPhone.toLowerCase().contains(q);
        final matchAddress = order.customerAddress.toLowerCase().contains(q);
        final matchOrderNum = order.orderNumber.toLowerCase().contains(q);
        return matchName || matchPhone || matchAddress || matchOrderNum;
      }

      return true;
    }).toList();
  }

  OnlineOrdersState copyWith({
    List<OnlineOrderModel>? orders,
    String? activeFilter,
    String? searchQuery,
    bool? isLoading,
  }) {
    return OnlineOrdersState(
      orders: orders ?? this.orders,
      activeFilter: activeFilter ?? this.activeFilter,
      searchQuery: searchQuery ?? this.searchQuery,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class OnlineOrdersNotifier extends StateNotifier<OnlineOrdersState> {
  final OrdersApiService _ordersApiService;

  OnlineOrdersNotifier({OrdersApiService? ordersApiService})
      : _ordersApiService = ordersApiService ?? OrdersApiService(),
        super(const OnlineOrdersState(orders: [])) {
    loadOnlineOrders();
  }

  Future<void> loadOnlineOrders() async {
    state = state.copyWith(isLoading: true);
    try {
      final jsonList = await _ordersApiService.listOrders();
      if (jsonList.isNotEmpty) {
        final onlineList = jsonList
            .where((j) {
              final ord = OrderModel.fromBackendJson(j);
              final src = ord.orderSource?.trim().toLowerCase() ?? '';
              final typeStr = j['order_type']?.toString().toLowerCase() ?? '';
              
              // Must be an online order type AND from Website / Mobile App (NOT POS)
              final isOnlineType = typeStr == 'online' || ord.type == OrderType.online;
              final isWebsiteOrApp = src == 'website' ||
                  src == 'mobileapp' ||
                  src == 'mobile app' ||
                  src == 'online' ||
                  src == 'app';
              final isNotPos = src != 'pos' && src != 'direct delivery';

              return isOnlineType && (isWebsiteOrApp || (src.isNotEmpty && isNotPos));
            })
            .map((j) {
              final ord = OrderModel.fromBackendJson(j);
              OnlineOrderStatus status = OnlineOrderStatus.pending;
              if (ord.status == OrderStatus.accepted || ord.status == OrderStatus.preparing || ord.status == OrderStatus.ready) {
                status = OnlineOrderStatus.accepted;
              } else if (ord.status == OrderStatus.completed || ord.status == OrderStatus.served) {
                status = OnlineOrderStatus.completed;
              } else if (ord.status == OrderStatus.cancelled) {
                status = OnlineOrderStatus.rejected;
              }

              final onlineItems = ord.items.map((i) => OnlineOrderItemModel(
                itemName: i.item.name,
                quantity: i.quantity,
                unitPrice: i.unitPrice,
                size: i.selectedSize,
                toppings: i.extraToppings,
                specialInstructions: i.notes,
              )).toList();

              return OnlineOrderModel(
                id: ord.id,
                orderNumber: ord.orderNumber,
                customerName: ord.customerName ?? 'Online Customer',
                customerPhone: ord.customerPhone ?? '+1 555 0199',
                customerAddress: ord.deliveryAddress ?? 'Direct Online',
                items: onlineItems,
                deliveryFee: ord.deliveryFee,
                taxAmount: ord.taxAmount,
                discountAmount: ord.discountAmount,
                createdAt: ord.createdAt,
                status: status,
                isPaid: ord.isPaid,
                paymentMethod: ord.paymentMethod ?? PaymentMethod.cash,
                orderSource: ord.orderSource ?? 'Website',
                cookingTimeMinutes: ord.cookingTimeMinutes,
                estimatedReadyAt: ord.estimatedReadyAt,
                rejectionReason: ord.rejectionReason,
              );
            })
            .where((ord) => ord.items.isNotEmpty)
            .toList();

        if (onlineList.isNotEmpty) {
          print('Online orders (Website & Mobile App) loaded: ${onlineList.length}');
          state = state.copyWith(orders: onlineList, isLoading: false);
          return;
        } else {
          print('Online orders list was empty after filtering for Website & Mobile App');
        }
      }
    } catch (e, stack) {
      print('Error loading online orders: $e');
      print(stack);
    }
    state = state.copyWith(isLoading: false);
  }

  void setFilter(String filter) {
    state = state.copyWith(activeFilter: filter);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void removeOrder(String orderId) {
    state = state.copyWith(
      orders: state.orders.where((o) => o.id != orderId).toList(),
    );
  }

  Future<void> setCookingTime(String orderId, int cookingMinutes) async {
    final readyAt = DateTime.now().add(Duration(minutes: cookingMinutes));
    try {
      await _ordersApiService.updateOrder(orderId, {
        'cooking_time_minutes': cookingMinutes,
        'estimated_ready_at': readyAt.toIso8601String(),
      });
    } catch (_) {}

    final updated = state.orders.map((order) {
      if (order.id == orderId) {
        return order.copyWith(
          cookingTimeMinutes: cookingMinutes,
          estimatedReadyAt: readyAt,
        );
      }
      return order;
    }).toList();
    state = state.copyWith(orders: updated);
  }

  void setDeliveryTime(String orderId, int deliveryMinutes) {
    final updated = state.orders.map((order) {
      if (order.id == orderId) {
        return order.copyWith(
          estimatedDeliveryMinutes: deliveryMinutes,
          estimatedDeliveryAt: DateTime.now().add(Duration(minutes: deliveryMinutes)),
        );
      }
      return order;
    }).toList();
    state = state.copyWith(orders: updated);
  }

  Future<void> acceptOrder(String orderId, {double? deliveryFee}) async {
    try {
      final dto = <String, dynamic>{'status': 'accepted'};
      if (deliveryFee != null) {
        dto['delivery_fee'] = deliveryFee;
      }
      await _ordersApiService.updateOrder(orderId, dto);
    } catch (_) {}

    final updated = state.orders.map((order) {
      if (order.id == orderId) {
        return order.copyWith(
          status: OnlineOrderStatus.accepted,
          deliveryFee: deliveryFee ?? order.deliveryFee,
          rejectionReason: null,
        );
      }
      return order;
    }).toList();
    state = state.copyWith(orders: updated);
  }

  Future<void> updateDeliveryFee(String orderId, double deliveryFee) async {
    try {
      await _ordersApiService.updateOrder(orderId, {'delivery_fee': deliveryFee});
    } catch (_) {}

    final updated = state.orders.map((order) {
      if (order.id == orderId) {
        return order.copyWith(deliveryFee: deliveryFee);
      }
      return order;
    }).toList();
    state = state.copyWith(orders: updated);
  }

  Future<void> completeOrder(String orderId, {PaymentMethod paymentMethod = PaymentMethod.cash}) async {
    try {
      await _ordersApiService.updateOrder(orderId, {
        'status': 'completed',
        'is_paid': true,
        'payment_status': 'PAID',
        'payment_method': paymentMethod.name,
      });
    } catch (_) {}

    final updated = state.orders.map((order) {
      if (order.id == orderId) {
        return order.copyWith(
          status: OnlineOrderStatus.completed,
          isPaid: true,
          paymentMethod: paymentMethod,
        );
      }
      return order;
    }).toList();
    state = state.copyWith(orders: updated);
  }

  Future<void> rejectOrder(String orderId, String reason) async {
    try {
      await _ordersApiService.updateOrderStatus(
        orderId,
        status: 'cancelled',
        rejectionReason: reason,
      );
    } catch (_) {}

    final updated = state.orders.map((order) {
      if (order.id == orderId) {
        return order.copyWith(
          status: OnlineOrderStatus.rejected,
          rejectionReason: reason,
        );
      }
      return order;
    }).toList();
    state = state.copyWith(orders: updated);
  }

  void assignRider(String orderId, String riderName) {
    final updated = state.orders.map((order) {
      if (order.id == orderId) {
        return order.copyWith(riderName: riderName);
      }
      return order;
    }).toList();
    state = state.copyWith(orders: updated);
  }

}

final onlineOrdersProvider = StateNotifierProvider<OnlineOrdersNotifier, OnlineOrdersState>((ref) {
  final ordersApi = ref.read(ordersApiServiceProvider);
  return OnlineOrdersNotifier(ordersApiService: ordersApi);
});
