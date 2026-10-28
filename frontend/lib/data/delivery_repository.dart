import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../config/feature_flags.dart';
import '../core/database/app_database.dart';
import '../core/sync/sync_providers.dart';
import '../domain/models/delivery_model.dart';
import '../domain/models/menu_item.dart';
import '../domain/models/order_model.dart';
import '../services/api/api_providers.dart';
import '../services/api/delivery_api_service.dart';
import '../services/api/orders_api_service.dart';
import '../services/receipt_printer_service.dart';
import 'daily_calculation_repository.dart';
import 'repositories/order_repository_provider.dart';

class DeliveryState {
  final List<DeliveryOrder> deliveries;
  final List<DeliveryRider> riders;
  final bool isLoading;

  const DeliveryState({
    required this.deliveries,
    required this.riders,
    this.isLoading = false,
  });

  DeliveryState copyWith({
    List<DeliveryOrder>? deliveries,
    List<DeliveryRider>? riders,
    bool? isLoading,
  }) {
    return DeliveryState(
      deliveries: deliveries ?? this.deliveries,
      riders: riders ?? this.riders,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class DeliveryNotifier extends StateNotifier<DeliveryState> {
  final DeliveryApiService _deliveryApiService;
  final OrdersApiService _ordersApiService;
  final Ref? _ref;

  DeliveryNotifier({
    DeliveryApiService? deliveryApiService,
    OrdersApiService? ordersApiService,
    Ref? ref,
  })  : _deliveryApiService = deliveryApiService ?? DeliveryApiService(),
        _ordersApiService = ordersApiService ?? OrdersApiService(),
        _ref = ref ?? null,
        super(const DeliveryState(
          deliveries: [],
          riders: [],
        )) {
    loadDeliveryData();
  }

  Future<void> loadDeliveryData({bool silent = false}) async {
    if (!silent && state.deliveries.isEmpty) {
      state = state.copyWith(isLoading: true);
    }

    // 1. First, load any delivery/online orders from local Drift SQLite
    List<DeliveryOrder> localDeliveries = [];
    if (FeatureFlags.offlineFirstEnabled && _ref != null) {
      try {
        final db = _ref!.read(appDatabaseProvider);
        final localOrders = await (db.select(db.localOrders)
              ..where((t) => (t.orderType.equals('online') | t.orderType.equals('delivery')) & t.isDeleted.equals(false))
              ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
            .get();

        for (final lo in localOrders) {
          final items = await db.ordersDao.getOrderItems(lo.id);
          final outbox = await (db.select(db.syncOutbox)..where((t) => t.entityId.equals(lo.id))).getSingleOrNull();

          String custName = 'Customer';
          String custPhone = 'N/A';
          String delAddress = 'Direct Delivery';
          double fee = 150.0;
          String payMethod = 'Cash on Delivery';

          if (outbox != null && outbox.payload.isNotEmpty) {
            try {
              final payload = jsonDecode(outbox.payload) as Map<String, dynamic>;
              custName = payload['customer_name']?.toString() ?? custName;
              custPhone = payload['customer_phone']?.toString() ?? custPhone;
              delAddress = payload['delivery_address']?.toString() ?? delAddress;
              fee = double.tryParse(payload['delivery_fee']?.toString() ?? '150') ?? fee;
              payMethod = payload['payment_method']?.toString() ?? payMethod;
            } catch (_) {}
          }

          final itemsDesc = items.map((i) => '${i.quantity}x ${i.itemName}').join(', ');
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

          DeliveryStatus status = DeliveryStatus.pending;
          if (lo.status == 'ready' || lo.status == 'readyForDispatch') {
            status = DeliveryStatus.readyForDispatch;
          } else if (lo.status == 'outForDelivery' || lo.status == 'on_the_way') {
            status = DeliveryStatus.outForDelivery;
          } else if (lo.status == 'completed' || lo.status == 'delivered') {
            status = DeliveryStatus.delivered;
          } else if (lo.status == 'cancelled') {
            status = DeliveryStatus.cancelled;
          }

          localDeliveries.add(DeliveryOrder(
            id: 'del-${lo.id}',
            orderId: lo.id,
            orderNumber: lo.orderNumber,
            customerName: custName,
            customerPhone: custPhone,
            deliveryAddress: delAddress,
            deliveryCharge: fee,
            totalAmount: lo.grandTotal,
            itemsSummary: itemsDesc.isNotEmpty ? itemsDesc : 'Delivery Order',
            paymentStatus: lo.paymentStatus,
            paymentMethod: payMethod,
            status: status,
            createdAt: lo.createdAt,
            estimatedDeliveryTime: lo.createdAt.add(const Duration(minutes: 30)),
            orderSource: 'Direct Delivery',
            items: mappedItems,
          ));
        }
      } catch (err) {
        print('Error loading local delivery orders from Drift: $err');
      }
    }

    try {
      // 1. Riders
      final ridersJson = await _deliveryApiService.listRiders();
      final riders = ridersJson.map((j) => DeliveryRider.fromBackendJson(j)).toList();

      final now = DateTime.now();
      final calcState = _ref?.read(dailyCalculationProvider);
      final bool hasActiveSession = calcState?.hasActiveSession ?? true;
      final String? activeShiftId = calcState?.selectedRecord?.id;
      final DateTime? activeShiftStartTime = calcState?.selectedRecord?.createdAt;

      // 2. Dispatches (already created dispatch records)
      final dispatchesJson = await _deliveryApiService.listDispatches();
      final dispatches = dispatchesJson
          .map((j) => DeliveryOrder.fromBackendJson(j))
          .where((d) {
            final isActive = d.status != DeliveryStatus.delivered &&
                d.status != DeliveryStatus.cancelled;
            if (isActive) return true;
            if (!hasActiveSession) return false;
            if (activeShiftStartTime != null) {
              return d.createdAt.isAfter(activeShiftStartTime.subtract(const Duration(seconds: 10)));
            }
            final isToday = d.createdAt.year == now.year &&
                d.createdAt.month == now.month &&
                d.createdAt.day == now.day;
            return isToday;
          })
          .where((d) =>
              d.orderSource.toLowerCase() == 'pos' ||
              d.orderSource.toLowerCase().contains('direct') ||
              d.orderSource.toLowerCase().contains('counter'))
          .toList();

      // 3. POS Orders with type 'online' / 'delivery' from DB
      final ordersJson = await _ordersApiService.listOrders(orderType: 'online');
      final posOrders = ordersJson
          .where((j) {
            final ord = OrderModel.fromBackendJson(j);
            final src = ord.orderSource?.trim().toLowerCase() ?? '';
            final isActive = ord.status != OrderStatus.completed &&
                ord.status != OrderStatus.cancelled;
            bool shouldInclude = isActive;
            if (!shouldInclude && hasActiveSession) {
              if (activeShiftId != null && ord.shiftId != null) {
                shouldInclude = ord.shiftId == activeShiftId;
              } else if (activeShiftStartTime != null) {
                shouldInclude = ord.createdAt.isAfter(activeShiftStartTime.subtract(const Duration(seconds: 10)));
              } else {
                shouldInclude = ord.createdAt.year == now.year &&
                    ord.createdAt.month == now.month &&
                    ord.createdAt.day == now.day;
              }
            }
            return (src == 'pos' || src == 'direct delivery' || src.isEmpty) && shouldInclude;
          })
          .map((j) => DeliveryOrder.fromBackendJson(j))
          .toList();

      // Merge: dispatches take precedence; append POS orders not yet dispatched
      final mergedDeliveries = List<DeliveryOrder>.from(dispatches);
      for (final po in posOrders) {
        final alreadyInDispatches = mergedDeliveries.any(
          (d) => (d.orderId.isNotEmpty && d.orderId == po.orderId) ||
                 (d.orderNumber.isNotEmpty && d.orderNumber == po.orderNumber),
        );
        if (!alreadyInDispatches) {
          mergedDeliveries.add(po);
        }
      }

      // Merge with any local pending unsynced delivery orders
      final serverOrderIds = mergedDeliveries.map((d) => d.orderId).toSet();
      final pendingLocals = localDeliveries.where((ld) => !serverOrderIds.contains(ld.orderId)).toList();
      final combined = [...pendingLocals, ...mergedDeliveries];

      state = state.copyWith(
        riders: riders,
        deliveries: combined,
        isLoading: false,
      );
    } catch (e) {
      print('Network offline for delivery tracking: $e');
      if (localDeliveries.isNotEmpty) {
        state = state.copyWith(deliveries: localDeliveries, isLoading: false);
        return;
      }
      state = state.copyWith(isLoading: false);
    }
  }

  void resetForNewShift() {
    state = state.copyWith(deliveries: [], isLoading: false);
  }

  Future<DeliveryOrder> createDeliveryOrder({
    required String customerName,
    required String customerPhone,
    required String deliveryAddress,
    required double deliveryFee,
    required double subtotal,
    double discountPercentage = 0.0,
    double discountAmount = 0.0,
    double taxAmount = 0.0,
    required double grandTotal,
    required String paymentMethod,
    required String paymentStatus,
    required String itemsSummary,
    required List<Map<String, dynamic>> items,
    String? existingOrderId,
  }) async {
    final now = DateTime.now();
    final tempOrderNum = 'HH-${(now.millisecondsSinceEpoch % 10000).toString().padLeft(4, '0')}';
    final rawOrderId = existingOrderId ?? const Uuid().v4();

    final effectiveItems = items.map((it) {
      final itemName = it['item_name']?.toString() ?? it['name']?.toString() ?? 'Delivery Meal';
      final qty = (it['quantity'] as num?)?.toInt() ?? 1;
      final unitPrice = double.tryParse(it['unit_price']?.toString() ?? it['price']?.toString() ?? '0') ?? (subtotal / (qty > 0 ? qty : 1));
      return OrderItem(
        id: const Uuid().v4(),
        item: MenuItem(
          id: it['menu_item_id']?.toString() ?? it['id']?.toString() ?? const Uuid().v4(),
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

    DeliveryOrder createdOrder = DeliveryOrder(
      id: 'del-$rawOrderId',
      orderId: rawOrderId,
      orderNumber: tempOrderNum,
      customerName: customerName,
      customerPhone: customerPhone,
      deliveryAddress: deliveryAddress,
      deliveryCharge: deliveryFee,
      totalAmount: grandTotal,
      itemsSummary: itemsSummary,
      paymentStatus: paymentStatus,
      paymentMethod: paymentMethod,
      status: DeliveryStatus.pending,
      createdAt: now,
      estimatedDeliveryTime: now.add(const Duration(minutes: 30)),
      orderSource: 'Direct Delivery',
      items: effectiveItems,
    );

    // 1. OFFLINE_FIRST_ENABLED=true: route checkout only through orderRepositoryProvider (local write + outbox).
    // Remove the direct HTTP create and the fallback new-order path (§Wave 5a / #10).
    if (FeatureFlags.offlineFirstEnabled && _ref != null) {
      try {
        final orderRepo = _ref!.read(orderRepositoryProvider);
        final calcState = _ref!.read(dailyCalculationProvider);
        final String? activeShiftId = calcState.selectedRecord?.id;
        final bool isPaidNow = paymentStatus.toUpperCase() == 'PAID';

        final paymentList = <OrderPaymentModel>[];
        if (isPaidNow) {
          paymentList.add(OrderPaymentModel(
            id: const Uuid().v7(),
            paymentMethod: paymentMethod.toLowerCase(),
            amount: grandTotal,
            tenderedAmount: grandTotal,
            changeReturned: 0.0,
            paymentStatus: 'COMPLETED',
            createdAt: now,
          ));
        }

        final orderModel = OrderModel(
          id: rawOrderId,
          orderNumber: tempOrderNum,
          type: OrderType.online,
          status: isPaidNow ? OrderStatus.completed : OrderStatus.accepted,
          items: effectiveItems,
          createdAt: now,
          shiftId: activeShiftId,
          subtotalOverride: subtotal,
          discountPercentage: discountPercentage,
          discountAmount: discountAmount,
          taxAmount: taxAmount,
          grandTotalOverride: grandTotal,
          paymentStatus: paymentStatus.toUpperCase(),
          isPaid: isPaidNow,
          kitchenTicketSent: true,
          payments: paymentList,
          onlineDetail: OnlineOrderDetail(
            id: const Uuid().v7(),
            orderId: rawOrderId,
            customerName: customerName,
            customerPhone: customerPhone,
            deliveryAddress: deliveryAddress,
            deliveryFee: deliveryFee,
            orderSource: 'Direct Delivery',
          ),
        );
        await orderRepo.saveOrder(orderModel);
        _ref!.read(syncBackgroundWorkerProvider).triggerPush();
      } catch (err) {
        print('Error saving delivery order to local SQLite/outbox: $err');
      }

      state = state.copyWith(
        deliveries: [createdOrder, ...state.deliveries.where((d) => d.orderId != rawOrderId && d.id != createdOrder.id)],
      );
      return createdOrder;
    }

    // 2. OFFLINE_FIRST_ENABLED=false: keep the online-only path working.
    // A timeout must not create a second order with a new ID. Reuse the same client-generated order ID/idempotency key on any retry.
    state = state.copyWith(deliveries: [createdOrder, ...state.deliveries.where((d) => d.orderId != rawOrderId)]);

    try {
      final res = await _ordersApiService.createOrder({
        'id': rawOrderId,
        'order_type': 'online',
        'order_source': 'Direct Delivery',
        'customer_name': customerName,
        'customer_phone': customerPhone,
        'delivery_address': deliveryAddress,
        'delivery_fee': deliveryFee,
        'subtotal': subtotal,
        'discount_percentage': discountPercentage,
        'discount_amount': discountAmount,
        'tax_amount': taxAmount,
        'grand_total': grandTotal,
        'payment_method': paymentMethod.toLowerCase(),
        'payment_status': paymentStatus,
        'status': 'pending',
        'items': items,
      });

      if (res['id'] != null) {
        createdOrder = DeliveryOrder.fromBackendJson(res);
      }
      await loadDeliveryData(silent: true);
    } catch (e) {
      print('Online delivery order creation error (idempotency key preserved: $rawOrderId): $e');
      rethrow;
    }

    state = state.copyWith(deliveries: [createdOrder, ...state.deliveries.where((d) => d.orderId != rawOrderId && d.id != createdOrder.id)]);
    return createdOrder;
  }

  Future<void> updateDeliveryOrder({
    required String orderId,
    required String customerName,
    required String customerPhone,
    required String deliveryAddress,
    required double deliveryFee,
    required double subtotal,
    double discountPercentage = 0.0,
    double discountAmount = 0.0,
    double taxAmount = 0.0,
    required double grandTotal,
    required String paymentMethod,
    required String itemsSummary,
    required List<Map<String, dynamic>> items,
  }) async {
    final rawOrderId = orderId.startsWith('del-') || orderId.startsWith('del_') ? (orderId.contains('_') ? orderId.substring(4) : orderId) : orderId;

    // Update local SQLite order atomically
    if (FeatureFlags.offlineFirstEnabled && _ref != null) {
      try {
        final orderRepo = _ref!.read(orderRepositoryProvider);
        final existingLocal = await orderRepo.getOrderById(rawOrderId);
        if (existingLocal != null) {
          final updated = existingLocal.copyWith(
            subtotalOverride: subtotal,
            discountPercentage: discountPercentage,
            discountAmount: discountAmount,
            taxAmount: taxAmount,
            grandTotalOverride: grandTotal,
            onlineDetail: OnlineOrderDetail(
              id: existingLocal.onlineDetail?.id ?? const Uuid().v7(),
              orderId: rawOrderId,
              customerName: customerName,
              customerPhone: customerPhone,
              deliveryAddress: deliveryAddress,
              deliveryFee: deliveryFee,
              orderSource: existingLocal.onlineDetail?.orderSource ?? 'Direct Delivery',
            ),
          );
          await orderRepo.updateOrder(updated);
          try {
            _ref!.read(syncBackgroundWorkerProvider).triggerPush();
          } catch (_) {}
        }
      } catch (err) {
        print('Error updating local delivery order in Drift: $err');
      }
    }

    try {
      await _ordersApiService.updateOrder(rawOrderId, {
        'customer_name': customerName,
        'customer_phone': customerPhone,
        'delivery_address': deliveryAddress,
        'delivery_fee': deliveryFee,
        'subtotal': subtotal,
        'discount_percentage': discountPercentage,
        'discount_amount': discountAmount,
        'tax_amount': taxAmount,
        'grand_total': grandTotal,
        'payment_method': paymentMethod.toLowerCase(),
        'items': items,
      });
      // Invalidate KOT print lock so modified order can be printed to the kitchen
      await ReceiptPrinterService.unmarkOrderKitchenReceiptPrinted(orderId: orderId);
      // Synchronize with database so dispatches, order items, and pricing match DB records
      await loadDeliveryData();
      return;
    } catch (e) {
      print('⚠️ Error updating delivery order in DB: $e');
      await ReceiptPrinterService.unmarkOrderKitchenReceiptPrinted(orderId: orderId);
    }

    final updated = state.deliveries.map((del) {
      if (del.id == orderId || del.orderId == orderId || del.orderId == rawOrderId) {
        return del.copyWith(
          customerName: customerName,
          customerPhone: customerPhone,
          deliveryAddress: deliveryAddress,
          deliveryCharge: deliveryFee,
          totalAmount: grandTotal,
          itemsSummary: itemsSummary,
          paymentMethod: paymentMethod,
        );
      }
      return del;
    }).toList();
    state = state.copyWith(deliveries: updated);
  }

  void markBillPrinted(String deliveryId) {
    final updated = state.deliveries.map((del) {
      if (del.id == deliveryId || del.orderId == deliveryId) {
        return del.copyWith(
          isBillPrinted: true,
          status: del.status == DeliveryStatus.pending ? DeliveryStatus.outForDelivery : del.status,
        );
      }
      return del;
    }).toList();
    state = state.copyWith(deliveries: updated);
  }

  void addDeliveryOrder(DeliveryOrder order) {
    state = state.copyWith(deliveries: [order, ...state.deliveries]);
  }

  void addOrUpdateDeliveryOrder(DeliveryOrder order) {
    final existingIndex = state.deliveries.indexWhere((d) => d.orderId == order.orderId || d.orderNumber == order.orderNumber);
    if (existingIndex != -1) {
      final updated = List<DeliveryOrder>.from(state.deliveries);
      updated[existingIndex] = order;
      state = state.copyWith(deliveries: updated);
    } else {
      state = state.copyWith(deliveries: [order, ...state.deliveries]);
    }
  }

  Future<bool> assignRider(String deliveryId, String riderId, String riderName) async {
    // Prevent assigning off-duty riders
    final targetRider = state.riders.firstWhere(
      (r) => r.id == riderId,
      orElse: () => const DeliveryRider(id: '', name: '', phone: '', isClockedIn: false),
    );

    if (!targetRider.isClockedIn) {
      return false; // Off-duty rider cannot be assigned
    }

    final targetDelivery = state.deliveries.firstWhere(
      (d) => d.id == deliveryId || d.orderId == deliveryId,
      orElse: () => state.deliveries.first,
    );

    try {
      if (targetDelivery.id.isNotEmpty && targetDelivery.id != targetDelivery.orderId) {
        await _deliveryApiService.assignRider(targetDelivery.id, riderId: riderId);
      } else if (targetDelivery.orderId.isNotEmpty) {
        final created = await _deliveryApiService.createDispatch({
          'order_id': targetDelivery.orderId,
          'rider_id': riderId,
          'dispatch_status': 'outForDelivery',
        });
        if (created['id'] != null) {
          deliveryId = created['id'].toString();
        }
      }
    } catch (_) {}

    final updated = state.deliveries.map((del) {
      if (del.id == deliveryId || del.orderId == deliveryId || (targetDelivery.orderId.isNotEmpty && del.orderId == targetDelivery.orderId)) {
        return del.copyWith(
          status: DeliveryStatus.outForDelivery,
          riderId: riderId,
          riderName: riderName,
        );
      }
      return del;
    }).toList();
    state = state.copyWith(deliveries: updated);
    return true;
  }

  Future<void> updateDeliveryStatus(String deliveryId, DeliveryStatus newStatus) async {
    try {
      String statusStr = 'pending';
      switch (newStatus) {
        case DeliveryStatus.outForDelivery:
          statusStr = 'out_for_delivery';
          break;
        case DeliveryStatus.delivered:
          statusStr = 'delivered';
          break;
        case DeliveryStatus.cancelled:
          statusStr = 'cancelled';
          break;
        default:
          statusStr = newStatus.name;
      }
      await _deliveryApiService.updateDispatchStatus(deliveryId, statusStr);
    } catch (_) {}

    final updated = state.deliveries.map((del) {
      if (del.id == deliveryId) {
        return del.copyWith(status: newStatus);
      }
      return del;
    }).toList();
    state = state.copyWith(deliveries: updated);
  }

  Future<void> updatePaymentStatus(
    String deliveryId,
    String paymentStatus, {
    String? paymentMethod,
    List<Map<String, dynamic>>? payments,
  }) async {
    final isPaid = paymentStatus.toUpperCase() == 'PAID';
    final target = state.deliveries.firstWhere(
      (d) => d.id == deliveryId || d.orderId == deliveryId,
      orElse: () => DeliveryOrder(
        id: deliveryId,
        orderId: deliveryId,
        orderNumber: '',
        customerName: '',
        customerPhone: '',
        deliveryAddress: '',
        status: DeliveryStatus.pending,
        createdAt: DateTime.now(),
        estimatedDeliveryTime: DateTime.now(),
      ),
    );

    final rawOrderId = target.orderId.isNotEmpty
        ? target.orderId
        : (deliveryId.startsWith('del_') ? deliveryId.substring(4) : (deliveryId.startsWith('del-') ? deliveryId.substring(4) : deliveryId));

    // 1. Update in Local SQLite & sync outbox atomically
    if (FeatureFlags.offlineFirstEnabled && _ref != null && rawOrderId.isNotEmpty && rawOrderId.length >= 20) {
      try {
        final orderRepo = _ref!.read(orderRepositoryProvider);
        final existingLocal = await orderRepo.getOrderById(rawOrderId);
        final calcState = _ref!.read(dailyCalculationProvider);
        final String? activeShiftId = calcState.selectedRecord?.id;

        final paymentList = <OrderPaymentModel>[];
        if (isPaid) {
          if (payments != null && payments.isNotEmpty) {
            for (final p in payments) {
              paymentList.add(OrderPaymentModel(
                id: const Uuid().v7(),
                paymentMethod: (p['payment_method']?.toString() ?? paymentMethod ?? 'cash').toLowerCase(),
                amount: double.tryParse(p['amount']?.toString() ?? '0') ?? (existingLocal?.grandTotal ?? 0.0),
                tenderedAmount: double.tryParse(p['tendered_amount']?.toString() ?? p['amount']?.toString() ?? '0') ?? (existingLocal?.grandTotal ?? 0.0),
                changeReturned: double.tryParse(p['change_returned']?.toString() ?? '0') ?? 0.0,
                paymentStatus: 'COMPLETED',
                createdAt: DateTime.now(),
              ));
            }
          } else {
            paymentList.add(OrderPaymentModel(
              id: const Uuid().v7(),
              paymentMethod: (paymentMethod ?? 'cash').toLowerCase(),
              amount: existingLocal?.grandTotal ?? 0.0,
              tenderedAmount: existingLocal?.grandTotal ?? 0.0,
              changeReturned: 0.0,
              paymentStatus: 'COMPLETED',
              createdAt: DateTime.now(),
            ));
          }
        }

        if (existingLocal != null) {
          final updated = existingLocal.copyWith(
            status: isPaid ? OrderStatus.completed : existingLocal.status,
            isPaid: isPaid,
            paymentStatus: paymentStatus.toUpperCase(),
            payments: paymentList.isNotEmpty ? paymentList : existingLocal.payments,
            shiftId: existingLocal.shiftId ?? activeShiftId,
          );
          await orderRepo.updateOrder(updated);
        }
        try {
          _ref!.read(syncBackgroundWorkerProvider).triggerPush();
        } catch (_) {}
      } catch (err) {
        print('Error updating local delivery payment in Drift: $err');
      }
    }

    if (rawOrderId.isNotEmpty && rawOrderId.length >= 20) {
      try {
        await _ordersApiService.updateOrder(rawOrderId, {
          'is_paid': isPaid,
          'payment_status': paymentStatus.toUpperCase(),
          if (isPaid) 'status': 'completed',
          ...?paymentMethod == null ? null : {'payment_method': paymentMethod},
          ...?payments == null || payments.isEmpty ? null : {'payments': payments},
        });
      } catch (_) {}
    }

    if (isPaid) {
      try {
        final dispatchTargetId = (target.id.isNotEmpty && !target.id.startsWith('del-')) ? target.id : rawOrderId;
        await _deliveryApiService.updateDispatchStatus(dispatchTargetId, 'delivered');
      } catch (_) {}
    }

    final updated = state.deliveries.map((del) {
      if (del.id == deliveryId || del.orderId == deliveryId || (rawOrderId.isNotEmpty && del.orderId == rawOrderId)) {
        return del.copyWith(
          paymentStatus: paymentStatus,
          paymentMethod: paymentMethod ?? del.paymentMethod,
          status: isPaid ? DeliveryStatus.delivered : del.status,
        );
      }
      return del;
    }).toList();
    state = state.copyWith(deliveries: updated);
  }

  Future<void> toggleRiderDuty(String riderId) async {
    final currentRider = state.riders.firstWhere(
      (r) => r.id == riderId,
      orElse: () => const DeliveryRider(id: '', name: '', phone: '', isClockedIn: false),
    );
    final nextDuty = !currentRider.isClockedIn;

    try {
      await _deliveryApiService.toggleRiderDuty(riderId, nextDuty);
    } catch (_) {}

    final updated = state.riders.map((r) {
      if (r.id == riderId) {
        return r.copyWith(isClockedIn: nextDuty);
      }
      return r;
    }).toList();
    state = state.copyWith(riders: updated);
  }

  Future<void> addRider(DeliveryRider rider) async {
    try {
      final res = await _deliveryApiService.createRider({
        'name': rider.name,
        'phone': rider.phone,
        'is_available': rider.isAvailable,
        'is_clocked_in': rider.isClockedIn,
      });
      final created = DeliveryRider.fromBackendJson(res);
      state = state.copyWith(riders: [...state.riders, created]);
    } catch (_) {
      state = state.copyWith(riders: [...state.riders, rider]);
    }
  }
}

final deliveryProvider = StateNotifierProvider<DeliveryNotifier, DeliveryState>((ref) {
  final deliveryApi = ref.watch(deliveryApiServiceProvider);
  final ordersApi = ref.watch(ordersApiServiceProvider);
  return DeliveryNotifier(
    deliveryApiService: deliveryApi,
    ordersApiService: ordersApi,
    ref: ref,
  );
});
