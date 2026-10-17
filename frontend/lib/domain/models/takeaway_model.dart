import 'order_model.dart';

class TakeawayOrder {
  final String id;
  final String tokenNumber;
  final String customerName;
  final String customerPhone;
  final String itemsSummary;
  final double subtotal;
  final double discountPercentage;
  final double discountAmount;
  final double taxAmount;
  final double grandTotal;
  final DateTime createdAt;
  final String status; // 'In Kitchen', 'Ready for Pickup', 'Completed'
  final bool isPaid;
  final bool isBillPrinted;
  final List<OrderItem> items;

  const TakeawayOrder({
    required this.id,
    required this.tokenNumber,
    required this.customerName,
    required this.customerPhone,
    required this.itemsSummary,
    required this.subtotal,
    this.discountPercentage = 0.0,
    this.discountAmount = 0.0,
    required this.taxAmount,
    required this.grandTotal,
    required this.createdAt,
    this.status = 'In Kitchen',
    this.isPaid = false,
    this.isBillPrinted = false,
    this.items = const [],
  });

  TakeawayOrder copyWith({
    String? id,
    String? tokenNumber,
    String? customerName,
    String? customerPhone,
    String? itemsSummary,
    double? subtotal,
    double? discountPercentage,
    double? discountAmount,
    double? taxAmount,
    double? grandTotal,
    DateTime? createdAt,
    String? status,
    bool? isPaid,
    bool? isBillPrinted,
    List<OrderItem>? items,
  }) {
    return TakeawayOrder(
      id: id ?? this.id,
      tokenNumber: tokenNumber ?? this.tokenNumber,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      itemsSummary: itemsSummary ?? this.itemsSummary,
      subtotal: subtotal ?? this.subtotal,
      discountPercentage: discountPercentage ?? this.discountPercentage,
      discountAmount: discountAmount ?? this.discountAmount,
      taxAmount: taxAmount ?? this.taxAmount,
      grandTotal: grandTotal ?? this.grandTotal,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      isPaid: isPaid ?? this.isPaid,
      isBillPrinted: isBillPrinted ?? this.isBillPrinted,
      items: items ?? this.items,
    );
  }
}
