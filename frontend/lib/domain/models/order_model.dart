import 'menu_item.dart';
import 'order_types/online_order_detail.dart';
import 'order_types/takeaway_order_detail.dart';
import 'order_types/dine_in_order_detail.dart';

export 'order_types/online_order_detail.dart';
export 'order_types/takeaway_order_detail.dart';
export 'order_types/dine_in_order_detail.dart';

/// Normalized order types matching the DB schema.
/// - online   → POS delivery / Website / Mobile App  (was: delivery)
/// - takeaway → Walk-in counter pickup               (was: takeAway)
/// - dineIn   → Table service inside restaurant
///
/// Legacy aliases kept so existing code doesn't break:
///   OrderType.takeAway   == OrderType.takeaway
///   OrderType.delivery   == OrderType.online
///   OrderType.quickOrder == OrderType.dineIn
enum OrderType {
  online,
  takeaway,
  dineIn,

  // ── Backward-compatible aliases (map to the normalized values above) ──
  /// @Deprecated Use [OrderType.takeaway]
  // ignore: constant_identifier_names
  takeAway,
  /// @Deprecated Use [OrderType.online]
  // ignore: constant_identifier_names
  delivery,
  /// @Deprecated Use [OrderType.dineIn]
  // ignore: constant_identifier_names
  quickOrder,
}
enum OrderStatus { newOrder, accepted, preparing, ready, served, completed, cancelled }
enum PaymentMethod { cash, card, bankTransfer, split }

class OrderPaymentModel {
  final String? id;
  final String paymentMethod; // 'cash', 'card', 'bankTransfer', 'other'
  final double amount;
  final double? tenderedAmount;
  final double? changeReturned;
  final String? transactionReference;
  final String? cardLastFour;
  final String? bankName;
  final String paymentStatus;
  final String? notes;
  final String? receivedBy;
  final DateTime? createdAt;

  const OrderPaymentModel({
    this.id,
    required this.paymentMethod,
    required this.amount,
    this.tenderedAmount,
    this.changeReturned,
    this.transactionReference,
    this.cardLastFour,
    this.bankName,
    this.paymentStatus = 'COMPLETED',
    this.notes,
    this.receivedBy,
    this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'payment_method': paymentMethod,
      'amount': amount,
      if (tenderedAmount != null) 'tendered_amount': tenderedAmount,
      if (changeReturned != null) 'change_returned': changeReturned,
      if (transactionReference != null) 'transaction_reference': transactionReference,
      if (cardLastFour != null) 'card_last_four': cardLastFour,
      if (bankName != null) 'bank_name': bankName,
      'payment_status': paymentStatus,
      if (notes != null) 'notes': notes,
      if (receivedBy != null) 'received_by': receivedBy,
    };
  }

  factory OrderPaymentModel.fromJson(Map<String, dynamic> json) {
    return OrderPaymentModel(
      id: json['id']?.toString(),
      paymentMethod: json['payment_method']?.toString() ?? 'cash',
      amount: double.tryParse(json['amount']?.toString() ?? '0') ?? 0.0,
      tenderedAmount: json['tendered_amount'] != null
          ? double.tryParse(json['tendered_amount'].toString())
          : null,
      changeReturned: json['change_returned'] != null
          ? double.tryParse(json['change_returned'].toString())
          : null,
      transactionReference: json['transaction_reference']?.toString(),
      cardLastFour: json['card_last_four']?.toString(),
      bankName: json['bank_name']?.toString(),
      paymentStatus: json['payment_status']?.toString() ?? 'COMPLETED',
      notes: json['notes']?.toString(),
      receivedBy: json['received_by']?.toString(),
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
    );
  }
}

class OrderItem {
  final String? id;
  final MenuItem item;
  final int quantity;
  final String selectedSize;
  final String selectedCrust;
  final List<String> extraToppings;
  final String notes;
  final double? backendUnitPrice;
  final bool isCancelled;
  final DateTime? cancelledAt;
  final String? cancelReason;
  final String? cancelledBy;

  const OrderItem({
    this.id,
    required this.item,
    required this.quantity,
    this.selectedSize = 'Large',
    this.selectedCrust = 'Butter Cheese',
    this.extraToppings = const [],
    this.notes = '',
    this.backendUnitPrice,
    this.isCancelled = false,
    this.cancelledAt,
    this.cancelReason,
    this.cancelledBy,
  });

  double get unitPrice {
    if (backendUnitPrice != null) return backendUnitPrice!;
    double price = item.basePrice;
    if (selectedSize == 'Medium') price += 2.0;
    if (selectedSize == 'Large') price += 5.0;
    if (selectedSize == 'Extra Large') price += 8.0;
    price += extraToppings.length * 1.5;
    return price;
  }

  double get totalPrice => unitPrice * quantity;

  OrderItem copyWith({
    String? id,
    MenuItem? item,
    int? quantity,
    String? selectedSize,
    String? selectedCrust,
    List<String>? extraToppings,
    String? notes,
    bool? isCancelled,
    DateTime? cancelledAt,
    String? cancelReason,
    String? cancelledBy,
  }) {
    return OrderItem(
      id: id ?? this.id,
      item: item ?? this.item,
      quantity: quantity ?? this.quantity,
      selectedSize: selectedSize ?? this.selectedSize,
      selectedCrust: selectedCrust ?? this.selectedCrust,
      extraToppings: extraToppings ?? this.extraToppings,
      notes: notes ?? this.notes,
      backendUnitPrice: backendUnitPrice ?? backendUnitPrice,
      isCancelled: isCancelled ?? this.isCancelled,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      cancelReason: cancelReason ?? this.cancelReason,
      cancelledBy: cancelledBy ?? this.cancelledBy,
    );
  }

  Map<String, dynamic> toCreateItemDto() {
    return {
      if (item.id.isNotEmpty && !item.id.startsWith('temp_')) 'menu_item_id': item.id,
      'item_name': item.name,
      'quantity': quantity,
      'unit_price': unitPrice,
      'selected_size': selectedSize,
      'selected_crust': selectedCrust,
      'extra_toppings': extraToppings.join(', '),
      'notes': notes,
    };
  }

  factory OrderItem.fromBackendJson(Map<String, dynamic> json) {
    final extraStr = json['extra_toppings']?.toString() ?? '';
    final toppings = extraStr.isNotEmpty
        ? extraStr.split(',').map((e) => e.trim()).toList()
        : <String>[];

    final menuItem = json['menu_item'] is Map<String, dynamic>
        ? MenuItem.fromBackendJson(json['menu_item'] as Map<String, dynamic>)
        : MenuItem(
            id: json['menu_item_id']?.toString() ?? '',
            name: json['item_name']?.toString() ?? 'Item',
            category: 'General',
            description: '',
            basePrice: double.tryParse(json['unit_price']?.toString() ?? '0') ?? 0.0,
            imageUrl: '',
          );

    return OrderItem(
      id: json['id']?.toString(),
      item: menuItem,
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      selectedSize: json['selected_size']?.toString() ?? 'Regular',
      selectedCrust: json['selected_crust']?.toString() ?? 'Original',
      extraToppings: toppings,
      notes: json['notes']?.toString() ?? '',
      backendUnitPrice: double.tryParse(json['unit_price']?.toString() ?? '0') ?? 0.0,
      isCancelled: json['is_cancelled'] == true,
      cancelledAt: json['cancelled_at'] != null ? DateTime.tryParse(json['cancelled_at'].toString()) : null,
      cancelReason: json['cancel_reason']?.toString(),
      cancelledBy: json['cancelled_by']?.toString(),
    );
  }
}

class OrderModel {
  final String id;
  final String orderNumber;
  final OrderType type;
  final OrderStatus status;
  final List<OrderItem> items;
  final DateTime createdAt;
  final String? shiftId;

  // ── Universal Billing (from base `orders` table) ──────────
  final double subtotalOverride; // 0 = calculated from items
  final double discountPercentage;
  final double discountAmount;
  final double taxAmount;
  final double grandTotalOverride; // 0 = calculated
  final String paymentStatus; // 'PAID' | 'UNPAID'
  final bool isPaid;
  final bool isHeld;
  final List<OrderPaymentModel> payments;

  // ── Kitchen ───────────────────────────────────────────────
  final bool kitchenTicketSent;
  final int? cookingTimeMinutes;
  final DateTime? estimatedReadyAt;
  final String? rejectionReason;

  // ── Type-specific detail objects (one is non-null) ────────
  final OnlineOrderDetail? onlineDetail;
  final TakeawayOrderDetail? takeawayDetail;
  final DineInOrderDetail? dineInDetail;

  // ── Convenience getters ───────────────────────────────────
  String? get orderSource => onlineDetail?.orderSource;
  String? get customerName => onlineDetail?.customerName ?? takeawayDetail?.customerName;
  String? get customerPhone => onlineDetail?.customerPhone ?? takeawayDetail?.customerPhone;
  String? get deliveryAddress => onlineDetail?.deliveryAddress;
  double get deliveryFee => onlineDetail?.deliveryFee ?? 0.0;
  String? get tokenNumber => takeawayDetail?.tokenNumber;
  String? get tableId => dineInDetail?.tableId;
  String? get tableName => null; // resolved via dine_in_detail on backend
  int get guestCount => dineInDetail?.guestCount ?? 1;
  String? get waiterName => dineInDetail?.waiterName;
  double get dineInTax => (type == OrderType.dineIn || type == OrderType.quickOrder)
      ? (dineInDetail?.dineInTax ?? taxAmount)
      : 0.0;
  String? get customerId => onlineDetail?.customerId ?? takeawayDetail?.customerId;

  /// Derives the primary payment method from the payments list.
  /// Returns null when no payment has been recorded yet.
  PaymentMethod? get paymentMethod {
    if (payments.isEmpty) return null;
    final methodStr = payments.first.paymentMethod.toLowerCase();
    if (methodStr.contains('card')) return PaymentMethod.card;
    if (methodStr.contains('bank') || methodStr.contains('transfer')) return PaymentMethod.bankTransfer;
    if (methodStr.contains('split')) return PaymentMethod.split;
    return PaymentMethod.cash;
  }

  const OrderModel({
    required this.id,
    required this.orderNumber,
    required this.type,
    required this.status,
    required this.items,
    required this.createdAt,
    this.shiftId,
    this.subtotalOverride = 0.0,
    this.discountPercentage = 0.0,
    this.discountAmount = 0.0,
    this.taxAmount = 0.0,
    this.grandTotalOverride = 0.0,
    this.paymentStatus = 'UNPAID',
    this.isPaid = false,
    this.isHeld = false,
    this.payments = const [],
    this.kitchenTicketSent = false,
    this.cookingTimeMinutes,
    this.estimatedReadyAt,
    this.rejectionReason,
    this.onlineDetail,
    this.takeawayDetail,
    this.dineInDetail,
    // ── Legacy / convenience params (ignored — data lives in detail objects) ──
    // ignore: avoid_unused_constructor_parameters
    String? tokenNumber,
    // ignore: avoid_unused_constructor_parameters
    String? tableId,
    // ignore: avoid_unused_constructor_parameters
    String? tableName,
    // ignore: avoid_unused_constructor_parameters
    int? guestCount,
    // ignore: avoid_unused_constructor_parameters
    String? waiterName,
    // ignore: avoid_unused_constructor_parameters
    String? customerName,
    // ignore: avoid_unused_constructor_parameters
    String? customerPhone,
    // ignore: avoid_unused_constructor_parameters
    String? deliveryAddress,
    // ignore: avoid_unused_constructor_parameters
    PaymentMethod? paymentMethod,
    // ignore: avoid_unused_constructor_parameters
    double? taxPercentage,
    // ignore: avoid_unused_constructor_parameters
    double? serviceChargePercentage,
    // ignore: avoid_unused_constructor_parameters
    double? deliveryFee,
    // ignore: avoid_unused_constructor_parameters
    String? orderSource,
  });

  double get subtotal => subtotalOverride > 0
      ? subtotalOverride
      : items.fold(0.0, (sum, i) => sum + i.totalPrice);
  double get grandTotal => grandTotalOverride > 0
      ? grandTotalOverride
      : (subtotal - discountAmount + dineInTax + deliveryFee).clamp(0.0, double.infinity);

  OrderModel copyWith({
    String? id,
    String? orderNumber,
    OrderType? type,
    OrderStatus? status,
    List<OrderItem>? items,
    DateTime? createdAt,
    String? shiftId,
    double? subtotalOverride,
    double? discountPercentage,
    double? discountAmount,
    double? taxAmount,
    double? grandTotalOverride,
    String? paymentStatus,
    bool? isPaid,
    bool? isHeld,
    List<OrderPaymentModel>? payments,
    bool? kitchenTicketSent,
    int? cookingTimeMinutes,
    DateTime? estimatedReadyAt,
    String? rejectionReason,
    OnlineOrderDetail? onlineDetail,
    TakeawayOrderDetail? takeawayDetail,
    DineInOrderDetail? dineInDetail,
  }) {
    return OrderModel(
      id: id ?? this.id,
      orderNumber: orderNumber ?? this.orderNumber,
      type: type ?? this.type,
      status: status ?? this.status,
      items: items ?? this.items,
      createdAt: createdAt ?? this.createdAt,
      shiftId: shiftId ?? this.shiftId,
      subtotalOverride: subtotalOverride ?? this.subtotalOverride,
      discountPercentage: discountPercentage ?? this.discountPercentage,
      discountAmount: discountAmount ?? this.discountAmount,
      taxAmount: taxAmount ?? this.taxAmount,
      grandTotalOverride: grandTotalOverride ?? this.grandTotalOverride,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      isPaid: isPaid ?? this.isPaid,
      isHeld: isHeld ?? this.isHeld,
      payments: payments ?? this.payments,
      kitchenTicketSent: kitchenTicketSent ?? this.kitchenTicketSent,
      cookingTimeMinutes: cookingTimeMinutes ?? this.cookingTimeMinutes,
      estimatedReadyAt: estimatedReadyAt ?? this.estimatedReadyAt,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      onlineDetail: onlineDetail ?? this.onlineDetail,
      takeawayDetail: takeawayDetail ?? this.takeawayDetail,
      dineInDetail: dineInDetail ?? this.dineInDetail,
    );
  }

  /// Serialises this model into the JSON payload for POST /orders.
  /// Matches the new normalized schema:
  ///   - base order fields go top-level
  ///   - type-specific detail is nested under `online_detail` | `takeaway_detail` | `dine_in_detail`
  Map<String, dynamic> toCreateOrderDto() {
    final typeStr = type.name; // 'online' | 'takeaway' | 'dineIn'

    final base = <String, dynamic>{
      if (shiftId != null) 'shift_id': shiftId,
      'order_number': orderNumber,
      'order_type': typeStr,
      'status': status.name,
      'subtotal': subtotal,
      'discount_percentage': discountPercentage,
      'discount_amount': discountAmount,
      'tax_amount': taxAmount,
      'grand_total': grandTotal,
      'payment_status': isPaid ? 'PAID' : 'UNPAID',
      'is_paid': isPaid,
      'is_held': isHeld,
      'kitchen_ticket_sent': kitchenTicketSent,
      'items': items.map((i) => i.toCreateItemDto()).toList(),
      if (payments.isNotEmpty)
        'payments': payments.map((p) => p.toJson()).toList()
      else if (isPaid)
        'payments': [
          {
            'payment_method': 'cash',
            'amount': grandTotal,
            'tendered_amount': grandTotal,
            'change_returned': 0.0,
            'payment_status': 'COMPLETED',
          },
        ],
    };

    // ── Attach type-specific detail ────────────────────────
    switch (type) {
      case OrderType.online:
      case OrderType.delivery: // legacy alias for online
        if (onlineDetail != null) {
          base['customer_name'] = onlineDetail!.customerName;
          base['customer_phone'] = onlineDetail!.customerPhone;
          base['delivery_address'] = onlineDetail!.deliveryAddress;
          base['delivery_fee'] = onlineDetail!.deliveryFee;
          base['order_source'] = onlineDetail!.orderSource;
          base['online_detail'] = onlineDetail!.toJson()
            ..remove('id')
            ..remove('order_id');
        } else {
          if (customerName != null && customerName!.isNotEmpty) base['customer_name'] = customerName;
          if (customerPhone != null && customerPhone!.isNotEmpty) base['customer_phone'] = customerPhone;
          if (deliveryAddress != null && deliveryAddress!.isNotEmpty) base['delivery_address'] = deliveryAddress;
          base['delivery_fee'] = deliveryFee;
          base['order_source'] = 'POS';
        }
        break;
      case OrderType.takeaway:
      case OrderType.takeAway: // legacy alias for takeaway
        if (takeawayDetail != null) {
          base['takeaway_detail'] = takeawayDetail!.toJson()
            ..remove('id')
            ..remove('order_id');
        }
        break;
      case OrderType.dineIn:
      case OrderType.quickOrder: // legacy alias for dineIn
        base['dine_in_tax'] = dineInTax;
        base['tax_amount'] = dineInTax;
        if (dineInDetail != null) {
          base['table_id'] = dineInDetail!.tableId;
          base['guest_count'] = dineInDetail!.guestCount;
          base['waiter_name'] = dineInDetail!.waiterName;
          base['dine_in_detail'] = dineInDetail!.toJson()
            ..remove('id')
            ..remove('order_id');
        }
        break;
    }

    return base;
  }

  /// Parses the full order object returned by the backend (with nested detail objects).
  factory OrderModel.fromBackendJson(Map<String, dynamic> json) {
    // ── Order type ─────────────────────────────────────────
    OrderType parsedType = OrderType.dineIn;
    final typeStr = json['order_type']?.toString().toLowerCase() ?? '';
    if (typeStr == 'online' || typeStr.contains('delivery') || typeStr.contains('website') || typeStr.contains('mobile')) {
      parsedType = OrderType.online;
    } else if (typeStr == 'takeaway' || typeStr.contains('take')) {
      parsedType = OrderType.takeaway;
    } else {
      parsedType = OrderType.dineIn;
    }

    // ── Status ─────────────────────────────────────────────
    OrderStatus parsedStatus = OrderStatus.newOrder;
    final statusStr = json['status']?.toString().toLowerCase() ?? '';
    switch (statusStr) {
      case 'accepted': parsedStatus = OrderStatus.accepted; break;
      case 'preparing': parsedStatus = OrderStatus.preparing; break;
      case 'ready': parsedStatus = OrderStatus.ready; break;
      case 'served': parsedStatus = OrderStatus.served; break;
      case 'completed': parsedStatus = OrderStatus.completed; break;
      case 'cancelled': case 'rejected': parsedStatus = OrderStatus.cancelled; break;
    }

    // ── Items ──────────────────────────────────────────────
    List<OrderItem> items = [];
    if (json['order_items'] is List) {
      items = (json['order_items'] as List)
          .map((i) => OrderItem.fromBackendJson(i as Map<String, dynamic>))
          .toList();
    } else if (json['items'] is List) {
      items = (json['items'] as List)
          .map((i) => OrderItem.fromBackendJson(i as Map<String, dynamic>))
          .toList();
    }

    // ── Payments ───────────────────────────────────────────
    List<OrderPaymentModel> payments = [];
    if (json['payments'] is List) {
      payments = (json['payments'] as List)
          .map((p) => OrderPaymentModel.fromJson(p as Map<String, dynamic>))
          .toList();
    }

    // ── Detail sub-objects ────────────────────────────────
    OnlineOrderDetail? onlineDetail;
    TakeawayOrderDetail? takeawayDetail;
    DineInOrderDetail? dineInDetail;

    if (json['online_detail'] is Map<String, dynamic>) {
      onlineDetail = OnlineOrderDetail.fromJson(json['online_detail'] as Map<String, dynamic>);
    }
    if (json['takeaway_detail'] is Map<String, dynamic>) {
      takeawayDetail = TakeawayOrderDetail.fromJson(json['takeaway_detail'] as Map<String, dynamic>);
    }
    if (json['dine_in_detail'] is Map<String, dynamic>) {
      dineInDetail = DineInOrderDetail.fromJson(json['dine_in_detail'] as Map<String, dynamic>);
    }

    return OrderModel(
      id: json['id']?.toString() ?? '',
      orderNumber: json['order_number']?.toString() ?? json['orderNumber']?.toString() ?? '',
      type: parsedType,
      status: parsedStatus,
      items: items,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      subtotalOverride: double.tryParse(json['subtotal']?.toString() ?? '0') ?? 0.0,
      discountPercentage: double.tryParse(json['discount_percentage']?.toString() ?? '0') ?? 0.0,
      discountAmount: double.tryParse(json['discount_amount']?.toString() ?? '0') ?? 0.0,
      taxAmount: double.tryParse(json['tax_amount']?.toString() ?? '0') ?? 0.0,
      grandTotalOverride: double.tryParse(json['grand_total']?.toString() ?? '0') ?? 0.0,
      paymentStatus: json['payment_status']?.toString() ?? 'UNPAID',
      isPaid: json['is_paid'] == true || json['payment_status'] == 'PAID',
      isHeld: json['is_held'] == true,
      payments: payments,
      kitchenTicketSent: json['kitchen_ticket_sent'] == true,
      cookingTimeMinutes: (json['cooking_time_minutes'] as num?)?.toInt(),
      estimatedReadyAt: json['estimated_ready_at'] != null
          ? DateTime.tryParse(json['estimated_ready_at'].toString())
          : null,
      rejectionReason: json['rejection_reason']?.toString(),
      onlineDetail: onlineDetail,
      takeawayDetail: takeawayDetail,
      dineInDetail: dineInDetail,
      shiftId: json['shift_id']?.toString() ?? json['shiftId']?.toString(),
    );
  }
}
