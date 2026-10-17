/// DineInOrderDetail — corresponds to `dine_in_order_details` table.
/// Covers: Table service inside the restaurant.
/// Requires a table assignment. Tracks guest count and waiter.
class DineInOrderDetail {
  final String id;
  final String orderId;

  // ── Table Assignment ──────────────────────────────────────
  final String tableId;
  final int guestCount;

  // ── Staff ─────────────────────────────────────────────────
  final String waiterName;

  // ── Dine In Tax ───────────────────────────────────────────
  final double dineInTax;

  const DineInOrderDetail({
    required this.id,
    required this.orderId,
    required this.tableId,
    this.guestCount = 1,
    this.waiterName = 'Cashier',
    this.dineInTax = 0.0,
  });

  factory DineInOrderDetail.fromJson(Map<String, dynamic> json) {
    return DineInOrderDetail(
      id: json['id']?.toString() ?? '',
      orderId: json['order_id']?.toString() ?? '',
      tableId: json['table_id']?.toString() ?? '',
      guestCount: (json['guest_count'] as int?) ?? 1,
      waiterName: (json['waiter_name'] as String?) ?? 'Cashier',
      dineInTax: double.tryParse(json['dine_in_tax']?.toString() ?? '0') ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'order_id': orderId,
        'table_id': tableId,
        'guest_count': guestCount,
        'waiter_name': waiterName,
        'dine_in_tax': dineInTax,
      };

  DineInOrderDetail copyWith({
    String? id,
    String? orderId,
    String? tableId,
    int? guestCount,
    String? waiterName,
    double? dineInTax,
  }) {
    return DineInOrderDetail(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      tableId: tableId ?? this.tableId,
      guestCount: guestCount ?? this.guestCount,
      waiterName: waiterName ?? this.waiterName,
      dineInTax: dineInTax ?? this.dineInTax,
    );
  }
}
