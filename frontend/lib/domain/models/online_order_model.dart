import 'order_model.dart';

enum OnlineOrderStatus {
  pending,
  accepted,
  completed,
  rejected,
}

class OnlineOrderItemModel {
  final String itemName;
  final int quantity;
  final double unitPrice;
  final String size;
  final List<String> toppings;
  final String? specialInstructions;

  const OnlineOrderItemModel({
    required this.itemName,
    required this.quantity,
    required this.unitPrice,
    this.size = 'Large',
    this.toppings = const [],
    this.specialInstructions,
  });

  double get totalPrice => unitPrice * quantity;

  OnlineOrderItemModel copyWith({
    String? itemName,
    int? quantity,
    double? unitPrice,
    String? size,
    List<String>? toppings,
    String? specialInstructions,
  }) {
    return OnlineOrderItemModel(
      itemName: itemName ?? this.itemName,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      size: size ?? this.size,
      toppings: toppings ?? this.toppings,
      specialInstructions: specialInstructions ?? this.specialInstructions,
    );
  }
}

class OnlineOrderModel {
  final String id;
  final String orderNumber;
  final String customerName;
  final String customerPhone;
  final String customerAddress;
  final List<OnlineOrderItemModel> items;
  final double deliveryFee;
  final double discountAmount;
  final double discountPercentage;
  final double taxAmount;
  final PaymentMethod paymentMethod;
  final bool isPaid;
  final OnlineOrderStatus status;
  final String? rejectionReason;
  final DateTime createdAt;
  final String? notes;
  final int? cookingTimeMinutes;
  final DateTime? estimatedReadyAt;
  final int? estimatedDeliveryMinutes;
  final DateTime? estimatedDeliveryAt;
  final String? orderSource;
  final String? riderName;

  const OnlineOrderModel({
    required this.id,
    required this.orderNumber,
    required this.customerName,
    required this.customerPhone,
    required this.customerAddress,
    required this.items,
    this.deliveryFee = 2.50,
    this.discountAmount = 0.0,
    this.discountPercentage = 0.0,
    this.taxAmount = 1.80,
    this.paymentMethod = PaymentMethod.cash,
    this.isPaid = false,
    this.status = OnlineOrderStatus.pending,
    this.rejectionReason,
    required this.createdAt,
    this.notes,
    this.cookingTimeMinutes,
    this.estimatedReadyAt,
    this.estimatedDeliveryMinutes,
    this.estimatedDeliveryAt,
    this.orderSource,
    this.riderName,
  });

  double get subtotal => items.fold(0.0, (sum, i) => sum + i.totalPrice);
  double get grandTotal => (subtotal - discountAmount + taxAmount + deliveryFee);

  OnlineOrderModel copyWith({
    String? id,
    String? orderNumber,
    String? customerName,
    String? customerPhone,
    String? customerAddress,
    List<OnlineOrderItemModel>? items,
    double? deliveryFee,
    double? discountAmount,
    double? discountPercentage,
    double? taxAmount,
    PaymentMethod? paymentMethod,
    bool? isPaid,
    OnlineOrderStatus? status,
    String? rejectionReason,
    DateTime? createdAt,
    String? notes,
    int? cookingTimeMinutes,
    DateTime? estimatedReadyAt,
    int? estimatedDeliveryMinutes,
    DateTime? estimatedDeliveryAt,
    String? orderSource,
    String? riderName,
  }) {
    return OnlineOrderModel(
      id: id ?? this.id,
      orderNumber: orderNumber ?? this.orderNumber,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      customerAddress: customerAddress ?? this.customerAddress,
      items: items ?? this.items,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      discountAmount: discountAmount ?? this.discountAmount,
      discountPercentage: discountPercentage ?? this.discountPercentage,
      taxAmount: taxAmount ?? this.taxAmount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      isPaid: isPaid ?? this.isPaid,
      status: status ?? this.status,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      createdAt: createdAt ?? this.createdAt,
      notes: notes ?? this.notes,
      cookingTimeMinutes: cookingTimeMinutes ?? this.cookingTimeMinutes,
      estimatedReadyAt: estimatedReadyAt ?? this.estimatedReadyAt,
      estimatedDeliveryMinutes: estimatedDeliveryMinutes ?? this.estimatedDeliveryMinutes,
      estimatedDeliveryAt: estimatedDeliveryAt ?? this.estimatedDeliveryAt,
      orderSource: orderSource ?? this.orderSource,
      riderName: riderName ?? this.riderName,
    );
  }
}
