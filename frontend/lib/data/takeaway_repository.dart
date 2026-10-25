import 'repositories/order_repository_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../domain/models/menu_item.dart';
import '../domain/models/order_model.dart';
import '../domain/models/takeaway_model.dart';
import '../services/api/api_providers.dart';
import '../services/api/orders_api_service.dart';
import '../services/receipt_printer_service.dart';
import 'daily_calculation_repository.dart';

class TakeawayState {
  final List<TakeawayOrder> orders;
  final int tokenCounter;
  final bool isLoading;

  const TakeawayState({
    required this.orders,
    this.tokenCounter = 4,
    this.isLoading = false,
  });

  int get activeCount => orders.where((o) => o.status != 'Completed').length;
  int get readyCount => orders.where((o) => o.status == 'Ready for Pickup').length;
  double get totalRevenue => orders.where((o) => o.isPaid).fold(0.0, (sum, o) => sum + o.grandTotal);

  TakeawayState copyWith({
    List<TakeawayOrder>? orders,
    int? tokenCounter,
    bool? isLoading,
  }) {
    return TakeawayState(
      orders: orders ?? this.orders,
      tokenCounter: tokenCounter ?? this.tokenCounter,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class TakeawayNotifier extends StateNotifier<TakeawayState> {
  final OrdersApiService _ordersApiService;
  final Ref? _ref;

  TakeawayNotifier({OrdersApiService? ordersApiService, Ref? ref})
      : _ordersApiService = ordersApiService ?? OrdersApiService(),
        // ignore: prefer_initializing_formals
        _ref = ref,
        super(const TakeawayState(
          orders: [],
          tokenCounter: 1,
        )) {
    loadTakeawayOrders();
  }

  Future<void> loadTakeawayOrders({bool silent = false}) async {
    if (!silent && state.orders.isEmpty) {
      state = state.copyWith(isLoading: true);
    }
    try {
      final jsonList = await _ordersApiService.listOrders(orderType: 'takeaway');
      if (jsonList.isNotEmpty) {
        final calcState = _ref?.read(dailyCalculationProvider);
        final bool hasActiveSession = calcState?.hasActiveSession ?? true;
        final String? activeShiftId = calcState?.selectedRecord?.id;
        final DateTime? activeShiftStartTime = calcState?.selectedRecord?.createdAt;

        int maxToken = 1;
        final list = jsonList
            .map((j) => OrderModel.fromBackendJson(j))
            .where((ord) {
              final isActive = ord.status != OrderStatus.completed &&
                  ord.status != OrderStatus.served &&
                  ord.status != OrderStatus.cancelled &&
                  !ord.isPaid;

              // Active kitchen/pending orders must always be visible
              if (isActive) return true;

              // If shift is closed, hide completed orders
              if (!hasActiveSession) return false;

              // If active shift session is in progress, only show completed orders belonging to this active shift
              if (activeShiftId != null && ord.shiftId != null) {
                return ord.shiftId == activeShiftId;
              }

              if (activeShiftStartTime != null) {
                return ord.createdAt.isAfter(activeShiftStartTime.subtract(const Duration(seconds: 10)));
              }

              // Fallback to today if no shift record found
              final now = DateTime.now();
              return ord.createdAt.year == now.year &&
                  ord.createdAt.month == now.month &&
                  ord.createdAt.day == now.day;
            })
            .map((ord) {
              String status = 'In Kitchen';
              if (ord.status == OrderStatus.ready) {
                status = 'Ready for Pickup';
              } else if (ord.status == OrderStatus.completed || ord.status == OrderStatus.served) {
                status = 'Completed';
              } else if (ord.status == OrderStatus.cancelled) {
                status = 'Cancelled';
              }

              final itemsDesc = ord.items.map((i) => '${i.quantity}x ${i.item.name}').join(', ');
              final token = ord.tokenNumber ?? ord.takeawayDetail?.tokenNumber ?? 'TK-${ord.orderNumber}';

              final numMatch = RegExp(r'\d+').firstMatch(token);
              if (numMatch != null) {
                final numVal = int.tryParse(numMatch.group(0) ?? '') ?? 0;
                if (numVal >= maxToken) {
                  maxToken = numVal + 1;
                }
              }

              final existingOrder = state.orders.where((o) => o.id == ord.id).firstOrNull;
              final isBillPrinted = existingOrder?.isBillPrinted ?? false;

              return TakeawayOrder(
                id: ord.id,
                tokenNumber: token,
                customerName: ord.customerName ?? (ord.takeawayDetail?.customerName ?? 'Guest Customer'),
                customerPhone: ord.customerPhone ?? (ord.takeawayDetail?.customerPhone ?? 'N/A'),
                itemsSummary: itemsDesc.isNotEmpty ? itemsDesc : 'Takeaway Order',
                subtotal: ord.subtotal,
                discountPercentage: ord.discountPercentage,
                discountAmount: ord.discountAmount,
                taxAmount: ord.taxAmount,
                grandTotal: ord.grandTotal,
                createdAt: ord.createdAt,
                status: status,
                isPaid: ord.isPaid,
                isBillPrinted: isBillPrinted,
                items: ord.items,
              );
            })
            .toList();

        state = state.copyWith(orders: list, tokenCounter: list.isEmpty ? 1 : maxToken, isLoading: false);
        return;
      } else {
        state = state.copyWith(orders: [], tokenCounter: 1, isLoading: false);
        return;
      }
    } catch (e) {
      print('Error loading takeaway orders: $e');
    }
    state = state.copyWith(isLoading: false);
  }

  void resetForNewShift() {
    state = const TakeawayState(orders: [], tokenCounter: 1, isLoading: false);
  }

  Future<void> addOrder({
    required String customerName,
    required String customerPhone,
    required String itemsSummary,
    required double subtotal,
    double discountPercentage = 0.0,
    double discountAmount = 0.0,
    List<Map<String, dynamic>>? items,
  }) async {
    final nextToken = state.tokenCounter;
    final effectiveDiscount = discountPercentage > 0
        ? (subtotal * (discountPercentage / 100))
        : discountAmount;
    final grandTotal = (subtotal - effectiveDiscount).clamp(0.0, double.infinity);
    final tokenStr = 'TK-$nextToken';

    final orderItemsPayload = (items != null && items.isNotEmpty)
        ? items
        : [
            {
              'item_name': itemsSummary.isNotEmpty ? itemsSummary : 'Takeaway Meal',
              'quantity': 1,
              'unit_price': subtotal,
              'selected_size': 'Regular',
              'selected_crust': 'Original',
            }
          ];

    try {
      final res = await _ordersApiService.createOrder({
        'order_type': 'takeaway',
        'token_number': tokenStr,
        'customer_name': customerName.isNotEmpty ? customerName : 'Guest Customer',
        'customer_phone': customerPhone.isNotEmpty ? customerPhone : 'N/A',
        'subtotal': subtotal,
        'discount_percentage': discountPercentage,
        'discount_amount': effectiveDiscount,
        'grand_total': grandTotal,
        'status': 'accepted',
        'is_paid': false,
        'payment_status': 'UNPAID',
        'kitchen_ticket_sent': true,
        'items': orderItemsPayload,
      });

      final ord = OrderModel.fromBackendJson(res);
      final newOrder = TakeawayOrder(
        id: ord.id,
        tokenNumber: ord.tokenNumber ?? tokenStr,
        customerName: ord.customerName ?? (customerName.isEmpty ? 'Guest Customer' : customerName),
        customerPhone: ord.customerPhone ?? (customerPhone.isEmpty ? 'N/A' : customerPhone),
        itemsSummary: itemsSummary,
        subtotal: subtotal,
        discountPercentage: ord.discountPercentage,
        discountAmount: ord.discountAmount,
        taxAmount: 0.0,
        grandTotal: grandTotal,
        createdAt: ord.createdAt,
        status: 'In Kitchen',
        isPaid: false,
        items: ord.items,
      );

      state = state.copyWith(
        orders: [newOrder, ...state.orders.where((o) => o.id != ord.id)],
        tokenCounter: nextToken + 1,
      );
      await loadTakeawayOrders();
      return;
    } catch (e) {
      print('Error creating takeaway order in DB: $e');
    }

    final fallbackItems = orderItemsPayload.map((it) {
      final itemName = it['item_name']?.toString() ?? 'Takeaway Meal';
      final qty = (it['quantity'] as num?)?.toInt() ?? 1;
      final unitPrice = double.tryParse(it['unit_price']?.toString() ?? '0') ?? subtotal;
      return OrderItem(
        id: const Uuid().v4(),
        item: MenuItem(
          id: it['menu_item_id']?.toString() ?? const Uuid().v4(),
          name: itemName,
          category: 'General',
          description: '',
          basePrice: unitPrice,
          imageUrl: '',
        ),
        quantity: qty,
        selectedSize: it['selected_size']?.toString() ?? 'Regular',
        selectedCrust: it['selected_crust']?.toString() ?? 'Original',
        backendUnitPrice: unitPrice,
      );
    }).toList();

    final newOrder = TakeawayOrder(
      id: const Uuid().v4(),
      tokenNumber: tokenStr,
      customerName: customerName.isEmpty ? 'Guest Customer' : customerName,
      customerPhone: customerPhone.isEmpty ? 'N/A' : customerPhone,
      itemsSummary: itemsSummary,
      subtotal: subtotal,
      discountPercentage: discountPercentage,
      discountAmount: effectiveDiscount,
      taxAmount: 0.0,
      grandTotal: grandTotal,
      createdAt: DateTime.now(),
      status: 'In Kitchen',
      isPaid: false,
      items: fallbackItems,
    );

    state = state.copyWith(
      orders: [newOrder, ...state.orders],
      tokenCounter: nextToken + 1,
    );
  }

  Future<void> updateTakeawayOrder({
    required String orderId,
    required String customerName,
    required String customerPhone,
    required String itemsSummary,
    required double subtotal,
    double discountPercentage = 0.0,
    double discountAmount = 0.0,
    List<Map<String, dynamic>>? items,
  }) async {
    final effectiveDiscount = discountPercentage > 0
        ? (subtotal * (discountPercentage / 100))
        : discountAmount;
    final grandTotal = (subtotal - effectiveDiscount).clamp(0.0, double.infinity);

    final orderItemsPayload = (items != null && items.isNotEmpty)
        ? items
        : [
            {
              'item_name': itemsSummary.isNotEmpty ? itemsSummary : 'Takeaway Meal',
              'quantity': 1,
              'unit_price': subtotal,
              'selected_size': 'Regular',
              'selected_crust': 'Original',
            }
          ];

    final updatedItems = orderItemsPayload.map((it) {
      final itemName = it['item_name']?.toString() ?? 'Takeaway Meal';
      final qty = (it['quantity'] as num?)?.toInt() ?? 1;
      final unitPrice = double.tryParse(it['unit_price']?.toString() ?? '0') ?? (qty > 0 ? subtotal / qty : subtotal);
      final itemId = it['id']?.toString() ?? const Uuid().v4();
      final menuItemId = it['menu_item_id']?.toString() ?? itemId;
      return OrderItem(
        id: itemId,
        item: MenuItem(
          id: menuItemId,
          name: itemName,
          category: 'General',
          description: '',
          basePrice: unitPrice,
          imageUrl: '',
        ),
        quantity: qty,
        selectedSize: it['selected_size']?.toString() ?? 'Regular',
        selectedCrust: it['selected_crust']?.toString() ?? 'Original',
        backendUnitPrice: unitPrice,
      );
    }).toList();

    // Immediately update local state in-memory so UI instantly reflects changes
    final updatedList = state.orders.map((o) {
      if (o.id == orderId) {
        return o.copyWith(
          customerName: customerName.isEmpty ? o.customerName : customerName,
          customerPhone: customerPhone.isEmpty ? o.customerPhone : customerPhone,
          itemsSummary: itemsSummary,
          subtotal: subtotal,
          discountPercentage: discountPercentage,
          discountAmount: effectiveDiscount,
          grandTotal: grandTotal,
          items: updatedItems,
          isBillPrinted: false, // reset so updated bill can be printed
        );
      }
      return o;
    }).toList();
    state = state.copyWith(orders: updatedList);

    try {
      await _ordersApiService.updateOrder(orderId, {
        'order_type': 'takeaway',
        'customer_name': customerName.isNotEmpty ? customerName : 'Guest Customer',
        'customer_phone': customerPhone.isNotEmpty ? customerPhone : 'N/A',
        'subtotal': subtotal,
        'discount_percentage': discountPercentage,
        'discount_amount': effectiveDiscount,
        'grand_total': grandTotal,
        'items': orderItemsPayload,
      });
      // Invalidate KOT print lock so modified order can be printed to the kitchen
      await ReceiptPrinterService.unmarkOrderKitchenReceiptPrinted(orderId: orderId);
      // Synchronize with DB so all order items and calculations match database records
      await loadTakeawayOrders();
      return;
    } catch (e) {
      print('Error updating takeaway order in DB: $e');
      await ReceiptPrinterService.unmarkOrderKitchenReceiptPrinted(orderId: orderId);
    }
  }

  Future<void> updateOrderStatus(String orderId, String newStatus) async {
    String statusStr = 'accepted';
    OrderStatus parsedStatus = OrderStatus.accepted;
    if (newStatus == 'Ready for Pickup') {
      statusStr = 'ready';
      parsedStatus = OrderStatus.ready;
    } else if (newStatus == 'Completed') {
      statusStr = 'completed';
      parsedStatus = OrderStatus.completed;
    } else if (newStatus == 'Cancelled') {
      statusStr = 'cancelled';
      parsedStatus = OrderStatus.cancelled;
    }
    try {
      await _ordersApiService.updateOrderStatus(orderId, status: statusStr);
    } catch (_) {}
    if (_ref != null) {
      try {
        final orderRepo = _ref.read(orderRepositoryProvider);
        await orderRepo.updateOrderStatus(orderId, parsedStatus);
      } catch (_) {}
    }
    final updated = state.orders.map((o) {
      if (o.id == orderId) {
        return o.copyWith(status: newStatus);
      }
      return o.copyWith();
    }).toList();
    state = state.copyWith(orders: updated);
  }

  Future<void> updateOrderDiscount(
    String orderId, {
    double? discountPercentage,
    double? discountAmount,
  }) async {
    final existing = state.orders.firstWhere((o) => o.id == orderId, orElse: () => state.orders.first);
    final subtotal = existing.subtotal;
    final pct = discountPercentage ?? 0.0;
    final amt = discountAmount ?? (subtotal * (pct / 100));
    final grandTotal = (subtotal - amt + existing.taxAmount).clamp(0.0, double.infinity);

    try {
      await _ordersApiService.updateOrder(orderId, {
        'discount_percentage': pct,
        'discount_amount': amt,
        'grand_total': grandTotal,
      });
    } catch (e) {
      print('Error updating takeaway discount: $e');
    }

    final updated = state.orders.map((o) {
      if (o.id == orderId) {
        return o.copyWith(
          discountPercentage: pct,
          discountAmount: amt,
          grandTotal: grandTotal,
          isBillPrinted: true,
        );
      }
      return o;
    }).toList();
    state = state.copyWith(orders: updated);
  }

  void markBillPrinted(String orderId) {
    final updated = state.orders.map((o) {
      if (o.id == orderId) {
        return o.copyWith(isBillPrinted: true);
      }
      return o;
    }).toList();
    state = state.copyWith(orders: updated);
  }

  Future<void> markOrderPaid(
    String orderId, {
    String paymentMethod = 'Cash',
    double? discountPercentage,
    double? discountAmount,
    List<Map<String, dynamic>>? payments,
  }) async {
    final existing = state.orders.firstWhere((o) => o.id == orderId, orElse: () => state.orders.first);
    final subtotal = existing.subtotal;
    final pct = discountPercentage ?? existing.discountPercentage;
    final amt = discountAmount ?? existing.discountAmount;
    final grandTotal = (subtotal - amt + existing.taxAmount).clamp(0.0, double.infinity);

    try {
      await _ordersApiService.updateOrder(orderId, {
        'is_paid': true,
        'payment_status': 'PAID',
        'status': 'completed',
        'payment_method': paymentMethod.toLowerCase(),
        'discount_percentage': pct,
        'discount_amount': amt,
        'grand_total': grandTotal,
        if (payments != null && payments.isNotEmpty) 'payments': payments,
      });
    } catch (_) {}

    final updated = state.orders.map((o) {
      if (o.id == orderId) {
        return o.copyWith(
          isPaid: true,
          status: 'Completed',
          discountPercentage: pct,
          discountAmount: amt,
          grandTotal: grandTotal,
        );
      }
      return o;
    }).toList();
    state = state.copyWith(orders: updated);
  }

  Future<void> cancelTakeawayOrder(
    String orderId, {
    String? reason,
    String? cancelledBy,
  }) async {
    try {
      await _ordersApiService.updateOrderStatus(
        orderId,
        status: 'cancelled',
        rejectionReason: reason ?? 'Cancelled by Cashier',
      );
      await ReceiptPrinterService.unmarkKitchenReceiptPrinted(orderId);
    } catch (e) {
      print('Error cancelling takeaway order: $e');
    }
    await loadTakeawayOrders();
  }

  Future<void> cancelTakeawayItem(
    String orderId, {
    required String itemId,
    int? cancelQuantity,
    String? reason,
    String? cancelledBy,
  }) async {
    try {
      await _ordersApiService.cancelOrderItem(
        orderId,
        itemId: itemId,
        cancelQuantity: cancelQuantity,
        reason: reason,
        cancelledBy: cancelledBy,
      );
    } catch (e) {
      print('Error cancelling takeaway item: $e');
    }
    await loadTakeawayOrders();
  }
}

final takeawayProvider = StateNotifierProvider<TakeawayNotifier, TakeawayState>((ref) {
  final ordersApi = ref.watch(ordersApiServiceProvider);
  return TakeawayNotifier(ordersApiService: ordersApi, ref: ref);
});
