import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/models/delivery_model.dart';
import '../domain/models/order_model.dart';
import '../services/api/api_providers.dart';
import '../services/api/delivery_api_service.dart';
import '../services/api/orders_api_service.dart';
import '../services/receipt_printer_service.dart';
import 'daily_calculation_repository.dart';

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

  Future<void> loadDeliveryData() async {
    state = state.copyWith(isLoading: true);
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

      state = state.copyWith(
        riders: riders,
        deliveries: mergedDeliveries,
        isLoading: false,
      );
    } catch (e) {
      print('Error loading delivery tracking data: $e');
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
  }) async {
    final now = DateTime.now();
    final tempOrderNum = 'HH-${(now.millisecondsSinceEpoch % 10000).toString().padLeft(4, '0')}';

    DeliveryOrder createdOrder = DeliveryOrder(
      id: 'del-${now.millisecondsSinceEpoch}',
      orderId: 'ord-${now.millisecondsSinceEpoch}',
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
    );

    try {
      final res = await _ordersApiService.createOrder({
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
    } catch (e) {
      print('⚠️ Error creating delivery order in DB: $e');
    }

    state = state.copyWith(deliveries: [createdOrder, ...state.deliveries]);
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
