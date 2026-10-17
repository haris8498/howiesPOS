/// OnlineOrderDetail — corresponds to `online_order_details` table.
/// Covers: POS-placed delivery, Website orders, Mobile App orders.
/// Always has a customer name, phone, delivery address, and delivery fee.
class OnlineOrderDetail {
  final String id;
  final String orderId;

  // ── Order Source ──────────────────────────────────────────
  /// 'POS' | 'Website' | 'MobileApp'
  final String orderSource;

  // ── Customer Snapshot (denormalised for receipt integrity) ─
  final String? customerId;
  final String customerName;
  final String customerPhone;

  // ── Delivery ───────────────────────────────────────────────
  final String deliveryAddress;
  final double deliveryFee;

  const OnlineOrderDetail({
    required this.id,
    required this.orderId,
    this.orderSource = 'POS',
    this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.deliveryAddress,
    this.deliveryFee = 0.0,
  });

  factory OnlineOrderDetail.fromJson(Map<String, dynamic> json) {
    return OnlineOrderDetail(
      id: json['id'] as String,
      orderId: json['order_id'] as String,
      orderSource: (json['order_source'] as String?) ?? 'POS',
      customerId: json['customer_id'] as String?,
      customerName: (json['customer_name'] as String?) ?? '',
      customerPhone: (json['customer_phone'] as String?) ?? '',
      deliveryAddress: (json['delivery_address'] as String?) ?? '',
      deliveryFee: _toDouble(json['delivery_fee']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'order_id': orderId,
        'order_source': orderSource,
        if (customerId != null) 'customer_id': customerId,
        'customer_name': customerName,
        'customer_phone': customerPhone,
        'delivery_address': deliveryAddress,
        'delivery_fee': deliveryFee,
      };

  OnlineOrderDetail copyWith({
    String? id,
    String? orderId,
    String? orderSource,
    String? customerId,
    String? customerName,
    String? customerPhone,
    String? deliveryAddress,
    double? deliveryFee,
  }) {
    return OnlineOrderDetail(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      orderSource: orderSource ?? this.orderSource,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      deliveryFee: deliveryFee ?? this.deliveryFee,
    );
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }
}
