/// TakeawayOrderDetail — corresponds to `takeaway_order_details` table.
/// Covers: Walk-in counter pickup orders placed at POS.
/// Has a unique token number for kitchen display. Customer is optional.
class TakeawayOrderDetail {
  final String id;
  final String orderId;

  // ── Kitchen Token ─────────────────────────────────────────
  /// Unique token shown on Kitchen Display System (KDS)
  final String tokenNumber;

  // ── Customer (optional for anonymous walk-ins) ────────────
  final String? customerId;
  final String customerName;
  final String customerPhone;

  // ── Counter Staff ─────────────────────────────────────────
  final String servedBy;

  const TakeawayOrderDetail({
    required this.id,
    required this.orderId,
    required this.tokenNumber,
    this.customerId,
    this.customerName = 'Walk-in Customer',
    this.customerPhone = '',
    this.servedBy = 'Cashier',
  });

  factory TakeawayOrderDetail.fromJson(Map<String, dynamic> json) {
    return TakeawayOrderDetail(
      id: json['id'] as String,
      orderId: json['order_id'] as String,
      tokenNumber: (json['token_number'] as String?) ?? '',
      customerId: json['customer_id'] as String?,
      customerName: (json['customer_name'] as String?) ?? 'Walk-in Customer',
      customerPhone: (json['customer_phone'] as String?) ?? '',
      servedBy: (json['served_by'] as String?) ?? 'Cashier',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'order_id': orderId,
        'token_number': tokenNumber,
        if (customerId != null) 'customer_id': customerId,
        'customer_name': customerName,
        'customer_phone': customerPhone,
        'served_by': servedBy,
      };

  TakeawayOrderDetail copyWith({
    String? id,
    String? orderId,
    String? tokenNumber,
    String? customerId,
    String? customerName,
    String? customerPhone,
    String? servedBy,
  }) {
    return TakeawayOrderDetail(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      tokenNumber: tokenNumber ?? this.tokenNumber,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      servedBy: servedBy ?? this.servedBy,
    );
  }
}
