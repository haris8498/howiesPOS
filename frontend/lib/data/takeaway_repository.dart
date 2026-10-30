import 'dart:convert';
import 'package:drift/drift.dart';
import '../config/feature_flags.dart';
import '../core/database/app_database.dart';
import '../core/sync/sync_providers.dart';
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

    // 1. First, load from local Drift SQLite if offline-first is enabled:
    List<TakeawayOrder> localTakeawayOrders = [];
    if (FeatureFlags.offlineFirstEnabled && _ref != null) {
      try {
        final db = _ref!.read(appDatabaseProvider);
        final localOrders = await (db.select(db.localOrders)
              ..where((t) => (t.orderType.equals('takeaway') | t.orderType.equals('takeAway')) & t.isDeleted.equals(false))
              ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
            .get();

        for (final lo in localOrders) {
          final items = await db.ordersDao.getOrderItems(lo.id);
          final outbox = await (db.select(db.syncOutbox)..where((t) => t.entityId.equals(lo.id))).getSingleOrNull();

          String custName = 'Guest Customer';
          String custPhone = 'N/A';
          String tok = lo.orderNumber;

          if (outbox != null && outbox.payload.isNotEmpty) {
            try {
              final payload = jsonDecode(outbox.payload) as Map<String, dynamic>;
              custName = payload['customer_name']?.toString() ?? payload['takeaway_detail']?['customer_name']?.toString() ?? custName;
              custPhone = payload['customer_phone']?.toString() ?? payload['takeaway_detail']?['customer_phone']?.toString() ?? custPhone;
              tok = payload['token_number']?.toString() ?? payload['takeaway_detail']?['token_number']?.toString() ?? tok;
            } catch (_) {}
          }

          final activeItems = items.where((i) => !i.isCancelled).toList();
          final itemsDesc = activeItems.map((i) => '${i.quantity}x ${i.itemName}').join(', ');
          final mappedItems = items.map((i) {
            return OrderItem(
              id: i.id,
              item: MenuItem(
                id: i.menuItemId ?? i.id,
                name: i.itemName,
                category: 'General',
                description: '',
                basePrice: i.unitPrice,
                imageUrl: '',
              ),
              quantity: i.quantity,
              selectedSize: i.sizeName ?? 'Regular',
              backendUnitPrice: i.unitPrice,
              isCancelled: i.isCancelled,
              cancelReason: i.cancelReason,
            );
          }).toList();

          String status = 'In Kitchen';
          if (lo.status == 'ready') {
            status = 'Ready for Pickup';
          } else if (lo.status == 'completed' || lo.status == 'served') {
            status = 'Completed';
          } else if (lo.status == 'cancelled') {
            status = 'Cancelled';
          }

          localTakeawayOrders.add(TakeawayOrder(
            id: lo.id,
            tokenNumber: tok,
            customerName: custName,
            customerPhone: custPhone,
            itemsSummary: itemsDesc.isNotEmpty ? itemsDesc : 'Takeaway Order',
            subtotal: lo.subtotal,
            discountPercentage: lo.discountPercentage,
            discountAmount: lo.discountAmount,
            taxAmount: lo.taxAmount,
            grandTotal: lo.grandTotal,
            createdAt: lo.createdAt,
            status: status,
            isPaid: lo.isPaid,
            items: mappedItems,
          ));
        }
      } catch (err) {
        print('Error loading local takeaway orders from Drift: $err');
      }
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

              final activeItems = ord.items.where((i) => !i.isCancelled).toList();
              final itemsDesc = activeItems.map((i) => '${i.quantity}x ${i.item.name}').join(', ');
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

        // Merge backend list with any local pending unsynced orders
        final serverIds = list.map((o) => o.id).toSet();
        final pendingLocals = localTakeawayOrders.where((lo) => !serverIds.contains(lo.id)).toList();
        final combined = [...pendingLocals, ...list];

        state = state.copyWith(orders: combined, tokenCounter: combined.isEmpty ? 1 : maxToken, isLoading: false);
        return;
      } else {
        if (localTakeawayOrders.isNotEmpty) {
          state = state.copyWith(orders: localTakeawayOrders, tokenCounter: localTakeawayOrders.length + 1, isLoading: false);
          return;
        }
        state = state.copyWith(orders: [], tokenCounter: 1, isLoading: false);
        return;
      }
    } catch (e) {
      print('Network offline for takeaway orders: $e');
      if (localTakeawayOrders.isNotEmpty) {
        state = state.copyWith(orders: localTakeawayOrders, tokenCounter: localTakeawayOrders.length + 1, isLoading: false);
        return;
      }
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
    Map<String, dynamic>? managerApproval,
    String? approvedByManagerId,
    String? existingOrderId,
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

    final orderId = existingOrderId ?? const Uuid().v4();
    final newOrder = TakeawayOrder(
      id: orderId,
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

    // 1. OFFLINE_FIRST_ENABLED=true: route checkout only through orderRepositoryProvider (local write + outbox).
    // Remove the direct HTTP create and the fallback new-order path (§Wave 5a / #10).
    if (FeatureFlags.offlineFirstEnabled && _ref != null) {
      try {
        final orderRepo = _ref!.read(orderRepositoryProvider);
        final calcState = _ref!.read(dailyCalculationProvider);
        final String? activeShiftId = calcState.selectedRecord?.id;

        final orderModel = OrderModel(
          id: orderId,
          orderNumber: tokenStr,
          type: OrderType.takeaway,
          status: OrderStatus.accepted,
          items: fallbackItems,
          createdAt: DateTime.now(),
          shiftId: activeShiftId,
          subtotalOverride: subtotal,
          discountPercentage: discountPercentage,
          discountAmount: effectiveDiscount,
          grandTotalOverride: grandTotal,
          paymentStatus: 'UNPAID',
          isPaid: false,
          kitchenTicketSent: true,
          approvedByManagerId: approvedByManagerId ?? managerApproval?['manager_id']?.toString(),
          managerApproval: managerApproval,
          takeawayDetail: TakeawayOrderDetail(
            id: const Uuid().v7(),
            orderId: orderId,
            customerName: customerName.isNotEmpty ? customerName : 'Guest Customer',
            customerPhone: customerPhone.isNotEmpty ? customerPhone : 'N/A',
            tokenNumber: tokenStr,
          ),
        );
        await orderRepo.saveOrder(orderModel);
        _ref!.read(syncBackgroundWorkerProvider).triggerPush();
      } catch (err) {
        print('Error saving takeaway order to local SQLite/outbox: $err');
      }

      state = state.copyWith(
        orders: [newOrder, ...state.orders.where((o) => o.id != orderId)],
        tokenCounter: nextToken + 1,
      );
      return;
    }

    // 2. OFFLINE_FIRST_ENABLED=false: keep the online-only path working.
    // A timeout must not create a second order with a new ID. Reuse the same client-generated order ID/idempotency key on any retry.
    state = state.copyWith(
      orders: [newOrder, ...state.orders.where((o) => o.id != orderId)],
      tokenCounter: nextToken + 1,
    );

    try {
      await _ordersApiService.createOrder({
        'id': orderId,
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
        if (approvedByManagerId != null || managerApproval != null)
          'approved_by_manager_id': approvedByManagerId ?? managerApproval?['manager_id'],
        if (managerApproval != null) 'manager_approval': managerApproval,
      });

      await loadTakeawayOrders(silent: true);
    } catch (e) {
      print('Online takeaway order creation error (idempotency key preserved: $orderId): $e');
      rethrow;
    }
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
    Map<String, dynamic>? managerApproval,
    String? approvedByManagerId,
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

    // Update local SQLite order atomically
    if (FeatureFlags.offlineFirstEnabled && _ref != null) {
      try {
        final orderRepo = _ref!.read(orderRepositoryProvider);
        final existingLocal = await orderRepo.getOrderById(orderId);
        if (existingLocal != null) {
          final updated = existingLocal.copyWith(
            subtotalOverride: subtotal,
            discountPercentage: discountPercentage,
            discountAmount: effectiveDiscount,
            grandTotalOverride: grandTotal,
            approvedByManagerId: approvedByManagerId ?? managerApproval?['manager_id']?.toString(),
            managerApproval: managerApproval,
            items: updatedItems,
            takeawayDetail: TakeawayOrderDetail(
              id: existingLocal.takeawayDetail?.id ?? const Uuid().v7(),
              orderId: orderId,
              customerName: customerName.isNotEmpty ? customerName : existingLocal.customerName ?? 'Guest Customer',
              customerPhone: customerPhone.isNotEmpty ? customerPhone : existingLocal.customerPhone ?? 'N/A',
              tokenNumber: existingLocal.tokenNumber ?? existingLocal.orderNumber,
            ),
          );
          await orderRepo.updateOrder(updated);
          try {
            _ref!.read(syncBackgroundWorkerProvider).triggerPush();
          } catch (_) {}
        }
      } catch (err) {
        print('Error updating local takeaway order in Drift: $err');
      }
    }

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
    Map<String, dynamic>? managerApproval,
    String? approvedByManagerId,
  }) async {
    final existing = state.orders.firstWhere((o) => o.id == orderId, orElse: () => state.orders.first);
    final subtotal = existing.subtotal;
    final pct = discountPercentage ?? 0.0;
    final amt = discountAmount ?? (subtotal * (pct / 100));
    final grandTotal = (subtotal - amt + existing.taxAmount).clamp(0.0, double.infinity);

    // Update local SQLite order atomically if offline-first is enabled
    if (FeatureFlags.offlineFirstEnabled && _ref != null) {
      try {
        final orderRepo = _ref!.read(orderRepositoryProvider);
        final existingLocal = await orderRepo.getOrderById(orderId);
        if (existingLocal != null) {
          final updated = existingLocal.copyWith(
            discountPercentage: pct,
            discountAmount: amt,
            grandTotalOverride: grandTotal,
            approvedByManagerId: approvedByManagerId ?? managerApproval?['manager_id']?.toString(),
            managerApproval: managerApproval,
          );
          await orderRepo.updateOrder(updated);
          try {
            _ref!.read(syncBackgroundWorkerProvider).triggerPush();
          } catch (_) {}
        }
      } catch (err) {
        print('Error updating local order discount in Drift: $err');
      }
    }

    try {
      await _ordersApiService.updateOrder(orderId, {
        'discount_percentage': pct,
        'discount_amount': amt,
        'grand_total': grandTotal,
        if (approvedByManagerId != null || managerApproval != null)
          'approved_by_manager_id': approvedByManagerId ?? managerApproval?['manager_id'],
        if (managerApproval != null) 'manager_approval': managerApproval,
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

    // 1. Update in Local SQLite & sync outbox atomically
    if (FeatureFlags.offlineFirstEnabled && _ref != null) {
      try {
        final orderRepo = _ref!.read(orderRepositoryProvider);
        final existingLocal = await orderRepo.getOrderById(orderId);
        final calcState = _ref!.read(dailyCalculationProvider);
        final String? activeShiftId = calcState.selectedRecord?.id;

        final paymentList = <OrderPaymentModel>[];
        if (payments != null && payments.isNotEmpty) {
          for (final p in payments) {
            paymentList.add(OrderPaymentModel(
              id: const Uuid().v7(),
              paymentMethod: (p['payment_method']?.toString() ?? paymentMethod).toLowerCase(),
              amount: double.tryParse(p['amount']?.toString() ?? '0') ?? grandTotal,
              tenderedAmount: double.tryParse(p['tendered_amount']?.toString() ?? p['amount']?.toString() ?? '0') ?? grandTotal,
              changeReturned: double.tryParse(p['change_returned']?.toString() ?? '0') ?? 0.0,
              paymentStatus: 'COMPLETED',
              createdAt: DateTime.now(),
            ));
          }
        } else {
          paymentList.add(OrderPaymentModel(
            id: const Uuid().v7(),
            paymentMethod: paymentMethod.toLowerCase(),
            amount: grandTotal,
            tenderedAmount: grandTotal,
            changeReturned: 0.0,
            paymentStatus: 'COMPLETED',
            createdAt: DateTime.now(),
          ));
        }

        if (existingLocal != null) {
          final updated = existingLocal.copyWith(
            status: OrderStatus.completed,
            isPaid: true,
            paymentStatus: 'PAID',
            discountPercentage: pct,
            discountAmount: amt,
            grandTotalOverride: grandTotal,
            payments: paymentList,
            shiftId: existingLocal.shiftId ?? activeShiftId,
          );
          await orderRepo.updateOrder(updated);
        } else {
          final newOrderModel = OrderModel(
            id: orderId,
            orderNumber: existing.tokenNumber,
            type: OrderType.takeaway,
            status: OrderStatus.completed,
            items: existing.items,
            createdAt: existing.createdAt,
            shiftId: activeShiftId,
            subtotalOverride: subtotal,
            discountPercentage: pct,
            discountAmount: amt,
            grandTotalOverride: grandTotal,
            paymentStatus: 'PAID',
            isPaid: true,
            kitchenTicketSent: true,
            takeawayDetail: TakeawayOrderDetail(
              id: const Uuid().v7(),
              orderId: orderId,
              customerName: existing.customerName,
              customerPhone: existing.customerPhone,
              tokenNumber: existing.tokenNumber,
            ),
            payments: paymentList,
          );
          await orderRepo.saveOrder(newOrderModel);
        }
        try {
          _ref!.read(syncBackgroundWorkerProvider).triggerPush();
        } catch (_) {}
      } catch (err) {
        print('Error updating takeaway payment in Drift: $err');
      }
    }

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
