import 'order_model.dart';

enum DeliveryStatus {
  pending,
  accepted,
  preparing,
  readyForDispatch,
  outForDelivery,
  delivered,
  cancelled,
}

class DeliveryRider {
  final String id;
  final String name;
  final String phone;
  final bool isAvailable;
  final bool isClockedIn;
  final int activeDeliveriesCount;
  final int totalCompletedDeliveries;
  final double avgDeliveryTimeMins;
  final double rating;

  const DeliveryRider({
    required this.id,
    required this.name,
    required this.phone,
    this.isAvailable = true,
    this.isClockedIn = true,
    this.activeDeliveriesCount = 0,
    this.totalCompletedDeliveries = 48,
    this.avgDeliveryTimeMins = 22.5,
    this.rating = 4.8,
  });

  DeliveryRider copyWith({
    bool? isAvailable,
    bool? isClockedIn,
    int? activeDeliveriesCount,
    int? totalCompletedDeliveries,
  }) {
    return DeliveryRider(
      id: id,
      name: name,
      phone: phone,
      isAvailable: isAvailable ?? this.isAvailable,
      isClockedIn: isClockedIn ?? this.isClockedIn,
      activeDeliveriesCount: activeDeliveriesCount ?? this.activeDeliveriesCount,
      totalCompletedDeliveries: totalCompletedDeliveries ?? this.totalCompletedDeliveries,
      avgDeliveryTimeMins: avgDeliveryTimeMins,
      rating: rating,
    );
  }

  factory DeliveryRider.fromBackendJson(Map<String, dynamic> json) {
    return DeliveryRider(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      isAvailable: json['is_available'] == true,
      isClockedIn: json['is_clocked_in'] == true,
      activeDeliveriesCount: (json['active_deliveries_count'] as num?)?.toInt() ?? 0,
      totalCompletedDeliveries: (json['total_completed_deliveries'] as num?)?.toInt() ?? 0,
      avgDeliveryTimeMins: double.tryParse(json['avg_delivery_time_mins']?.toString() ?? '22.5') ?? 22.5,
      rating: double.tryParse(json['rating']?.toString() ?? '5.0') ?? 5.0,
    );
  }
}

class DeliveryOrder {
  final String id;
  final String orderId;
  final String orderNumber;
  final String customerName;
  final String customerPhone;
  final String deliveryAddress;
  final double deliveryCharge;
  final double totalAmount;
  final String itemsSummary;
  final String paymentStatus; // 'UNPAID', 'PAID'
  final String paymentMethod;
  final DeliveryStatus status;
  final String? riderId;
  final String? riderName;
  final DateTime createdAt;
  final DateTime estimatedDeliveryTime;
  final String orderSource; // 'Online Orders', 'Direct Delivery'
  final bool isBillPrinted;
  final List<OrderItem> items;

  const DeliveryOrder({
    required this.id,
    required this.orderId,
    required this.orderNumber,
    required this.customerName,
    required this.customerPhone,
    required this.deliveryAddress,
    this.deliveryCharge = 150.0,
    this.totalAmount = 1449.0,
    this.itemsSummary = '1x Classic Fajita Pizza (Medium), 2x Fresh Lime',
    this.paymentStatus = 'UNPAID',
    this.paymentMethod = 'Cash on Delivery',
    required this.status,
    this.riderId,
    this.riderName,
    required this.createdAt,
    required this.estimatedDeliveryTime,
    this.orderSource = 'Direct Delivery',
    this.isBillPrinted = false,
    this.items = const [],
  });

  DeliveryOrder copyWith({
    DeliveryStatus? status,
    String? riderId,
    String? riderName,
    String? paymentStatus,
    String? paymentMethod,
    double? totalAmount,
    String? itemsSummary,
    String? orderSource,
    String? customerName,
    String? customerPhone,
    String? deliveryAddress,
    double? deliveryCharge,
    bool? isBillPrinted,
    List<OrderItem>? items,
  }) {
    return DeliveryOrder(
      id: id,
      orderId: orderId,
      orderNumber: orderNumber,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      deliveryCharge: deliveryCharge ?? this.deliveryCharge,
      totalAmount: totalAmount ?? this.totalAmount,
      itemsSummary: itemsSummary ?? this.itemsSummary,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      status: status ?? this.status,
      riderId: riderId ?? this.riderId,
      riderName: riderName ?? this.riderName,
      createdAt: createdAt,
      estimatedDeliveryTime: estimatedDeliveryTime,
      orderSource: orderSource ?? this.orderSource,
      isBillPrinted: isBillPrinted ?? this.isBillPrinted,
      items: items ?? this.items,
    );
  }

  factory DeliveryOrder.fromBackendJson(Map<String, dynamic> json) {
    DeliveryStatus parsedStatus = DeliveryStatus.pending;
    final statusStr = (json['dispatch_status'] ?? json['status'])?.toString().toLowerCase() ?? '';
    if (statusStr == 'accepted') {
      parsedStatus = DeliveryStatus.accepted;
    } else if (statusStr == 'preparing') {
      parsedStatus = DeliveryStatus.preparing;
    } else if (statusStr.contains('ready') || statusStr.contains('dispatch')) {
      parsedStatus = DeliveryStatus.readyForDispatch;
    } else if (statusStr.contains('out') || statusStr.contains('transit')) {
      parsedStatus = DeliveryStatus.outForDelivery;
    } else if (statusStr == 'delivered' || statusStr == 'completed') {
      parsedStatus = DeliveryStatus.delivered;
    } else if (statusStr == 'cancelled') {
      parsedStatus = DeliveryStatus.cancelled;
    }

    final onlineDetail = json['online_order_detail'] as Map<String, dynamic>? ?? json['online_detail'] as Map<String, dynamic>?;
    final order = (onlineDetail != null && onlineDetail['order'] is Map<String, dynamic>)
        ? (onlineDetail['order'] as Map<String, dynamic>)
        : (json['order'] as Map<String, dynamic>? ?? json);
    final rider = json['rider'] as Map<String, dynamic>?;

    String summary = 'Delivery Order';
    final List<OrderItem> parsedItems = [];
    final itemsList = (order['order_items'] is List)
        ? (order['order_items'] as List)
        : (json['order_items'] is List ? json['order_items'] as List : null);
    if (itemsList != null && itemsList.isNotEmpty) {
      summary = itemsList.map((i) => '${i['quantity']}x ${i['item_name']}').join(', ');
      for (final itemJson in itemsList) {
        if (itemJson is Map<String, dynamic>) {
          parsedItems.add(OrderItem.fromBackendJson(itemJson));
        }
      }
    }

    final customerName = (onlineDetail != null ? onlineDetail['customer_name']?.toString() : null) ??
        order['customer_name']?.toString() ??
        json['customer_name']?.toString() ??
        'POS Customer';

    final customerPhone = (onlineDetail != null ? onlineDetail['customer_phone']?.toString() : null) ??
        order['customer_phone']?.toString() ??
        json['customer_phone']?.toString() ??
        '';

    final deliveryAddress = (onlineDetail != null ? onlineDetail['delivery_address']?.toString() : null) ??
        order['delivery_address']?.toString() ??
        json['delivery_address']?.toString() ??
        '';

    final deliveryFee = double.tryParse((onlineDetail != null ? onlineDetail['delivery_fee']?.toString() : null) ??
        order['delivery_fee']?.toString() ??
        '150') ?? 150.0;

    final orderSource = (onlineDetail != null ? onlineDetail['order_source']?.toString() : null) ??
        order['order_source']?.toString() ??
        json['order_source']?.toString() ??
        'POS';

    return DeliveryOrder(
      id: json['id']?.toString() ?? '',
      orderId: order['id']?.toString() ?? json['order_id']?.toString() ?? json['id']?.toString() ?? '',
      orderNumber: order['order_number']?.toString() ?? json['order_number']?.toString() ?? 'HH-DEL',
      customerName: customerName,
      customerPhone: customerPhone,
      deliveryAddress: deliveryAddress,
      deliveryCharge: deliveryFee,
      totalAmount: double.tryParse(order['grand_total']?.toString() ?? json['grand_total']?.toString() ?? '0') ?? 0.0,
      itemsSummary: summary,
      paymentStatus: order['payment_status']?.toString() ?? json['payment_status']?.toString() ?? 'UNPAID',
      paymentMethod: order['payment_method']?.toString() ?? json['payment_method']?.toString() ?? 'Cash on Delivery',
      status: parsedStatus,
      riderId: json['rider_id']?.toString() ?? rider?['id']?.toString(),
      riderName: rider?['name']?.toString(),
      createdAt: order['created_at'] != null
          ? DateTime.tryParse(order['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      estimatedDeliveryTime: json['estimated_delivery_time'] != null
          ? DateTime.tryParse(json['estimated_delivery_time'].toString()) ?? DateTime.now().add(const Duration(minutes: 30))
          : DateTime.now().add(const Duration(minutes: 30)),
      orderSource: orderSource,
      items: parsedItems,
    );
  }
}
