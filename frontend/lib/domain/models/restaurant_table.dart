enum TableStatus { available, occupied, reserved }

class RestaurantTable {
  final String id;
  final String tableNumber;
  final String name;
  final int capacity;
  final int currentCustomerCount;
  final double currentBillAmount;
  final double dineInTax;
  final double discountAmount;
  final double discountPercentage;
  final TableStatus status;
  final String section; // Main Hall, VIP Lounge, Outdoor Terrace, Express Bar
  final String? activeOrderId;
  final String? activeOrderNumber;
  final DateTime? occupiedSince;
  final String? reservedCustomerName;
  final DateTime? reservationTime;
  // Stores the current order items as a list of maps: {name, category, price, imagePath, quantity}
  final List<Map<String, dynamic>> currentOrderItems;

  const RestaurantTable({
    required this.id,
    required this.tableNumber,
    required this.name,
    required this.capacity,
    this.currentCustomerCount = 0,
    this.currentBillAmount = 0.0,
    this.dineInTax = 0.0,
    this.discountAmount = 0.0,
    this.discountPercentage = 0.0,
    required this.status,
    required this.section,
    this.activeOrderId,
    this.activeOrderNumber,
    this.occupiedSince,
    this.reservedCustomerName,
    this.reservationTime,
    this.currentOrderItems = const [],
  });

  int get occupancyDurationMinutes {
    if (occupiedSince == null) return 0;
    return DateTime.now().difference(occupiedSince!).inMinutes;
  }

  RestaurantTable copyWith({
    String? id,
    String? tableNumber,
    String? name,
    int? capacity,
    int? currentCustomerCount,
    double? currentBillAmount,
    double? dineInTax,
    double? discountAmount,
    double? discountPercentage,
    TableStatus? status,
    String? section,
    String? activeOrderId,
    String? activeOrderNumber,
    DateTime? occupiedSince,
    String? reservedCustomerName,
    DateTime? reservationTime,
    List<Map<String, dynamic>>? currentOrderItems,
  }) {
    return RestaurantTable(
      id: id ?? this.id,
      tableNumber: tableNumber ?? this.tableNumber,
      name: name ?? this.name,
      capacity: capacity ?? this.capacity,
      currentCustomerCount: currentCustomerCount ?? this.currentCustomerCount,
      currentBillAmount: currentBillAmount ?? this.currentBillAmount,
      dineInTax: dineInTax ?? this.dineInTax,
      discountAmount: discountAmount ?? this.discountAmount,
      discountPercentage: discountPercentage ?? this.discountPercentage,
      status: status ?? this.status,
      section: section ?? this.section,
      activeOrderId: activeOrderId ?? this.activeOrderId,
      activeOrderNumber: activeOrderNumber ?? this.activeOrderNumber,
      occupiedSince: occupiedSince ?? this.occupiedSince,
      reservedCustomerName: reservedCustomerName ?? this.reservedCustomerName,
      reservationTime: reservationTime ?? this.reservationTime,
      currentOrderItems: currentOrderItems ?? this.currentOrderItems,
    );
  }

  factory RestaurantTable.fromBackendJson(Map<String, dynamic> json) {
    TableStatus parsedStatus = TableStatus.available;
    final statusStr = json['status']?.toString().toLowerCase() ?? '';
    if (statusStr == 'occupied') {
      parsedStatus = TableStatus.occupied;
    } else if (statusStr == 'reserved') {
      parsedStatus = TableStatus.reserved;
    }

    double parsedDineInTax = 0.0;
    double parsedDiscountAmount = 0.0;
    double parsedDiscountPercentage = 0.0;
    List<Map<String, dynamic>> orderItems = [];

    if (json['current_order_items'] is List && (json['current_order_items'] as List).isNotEmpty) {
      orderItems = (json['current_order_items'] as List)
          .map((i) {
            final itemMap = Map<String, dynamic>.from(i as Map);
            return {
              'id': itemMap['id']?.toString() ?? '',
              'name': itemMap['name'] ?? itemMap['item_name'] ?? 'Item',
              'quantity': (itemMap['quantity'] as num?)?.toInt() ?? 1,
              'price': double.tryParse(itemMap['price']?.toString() ?? itemMap['unit_price']?.toString() ?? '0') ?? 0.0,
              'selected_size': itemMap['selected_size'] ?? 'Regular',
              'selected_crust': itemMap['selected_crust'] ?? 'Original',
              'extra_toppings': itemMap['extra_toppings'],
              'notes': itemMap['notes'],
              'category': itemMap['category'] ?? 'General',
              'is_cancelled': itemMap['is_cancelled'] == true || itemMap['is_cancelled'] == 1,
              'cancel_reason': itemMap['cancel_reason']?.toString(),
              'cancelled_at': itemMap['cancelled_at']?.toString(),
              'cancelled_by': itemMap['cancelled_by']?.toString(),
            };
          })
          .toList();
    } else if (json['order_items'] is List && (json['order_items'] as List).isNotEmpty) {
      orderItems = (json['order_items'] as List).map((i) {
        final itemMap = Map<String, dynamic>.from(i as Map);
        return {
          'id': itemMap['id']?.toString() ?? '',
          'name': itemMap['item_name'] ?? itemMap['name'] ?? 'Item',
          'quantity': (itemMap['quantity'] as num?)?.toInt() ?? 1,
          'price': double.tryParse(itemMap['unit_price']?.toString() ?? itemMap['price']?.toString() ?? '0') ?? 0.0,
          'selected_size': itemMap['selected_size'] ?? 'Regular',
          'selected_crust': itemMap['selected_crust'] ?? 'Original',
          'extra_toppings': itemMap['extra_toppings'],
          'notes': itemMap['notes'],
          'category': 'General',
          'is_cancelled': itemMap['is_cancelled'] == true || itemMap['is_cancelled'] == 1,
          'cancel_reason': itemMap['cancel_reason']?.toString(),
          'cancelled_at': itemMap['cancelled_at']?.toString(),
          'cancelled_by': itemMap['cancelled_by']?.toString(),
        };
      }).toList();
    } else if (json['orders'] is List && (json['orders'] as List).isNotEmpty) {
      final activeOrder = (json['orders'] as List).first as Map<String, dynamic>;
      if (activeOrder['dine_in_detail'] is Map) {
        final dDetail = activeOrder['dine_in_detail'] as Map<String, dynamic>;
        parsedDineInTax = double.tryParse(dDetail['dine_in_tax']?.toString() ?? '0') ?? 0.0;
      }
      if (parsedDineInTax == 0.0 && activeOrder['tax_amount'] != null) {
        parsedDineInTax = double.tryParse(activeOrder['tax_amount']?.toString() ?? '0') ?? 0.0;
      }
      parsedDiscountAmount = double.tryParse(activeOrder['discount_amount']?.toString() ?? '0') ?? 0.0;
      parsedDiscountPercentage = double.tryParse(activeOrder['discount_percentage']?.toString() ?? '0') ?? 0.0;
      if (activeOrder['order_items'] is List) {
        orderItems = (activeOrder['order_items'] as List).map((i) {
          final itemMap = i as Map<String, dynamic>;
          return {
            'id': itemMap['id']?.toString() ?? '',
            'name': itemMap['item_name']?.toString() ?? 'Item',
            'quantity': (itemMap['quantity'] as num?)?.toInt() ?? 1,
            'price': double.tryParse(itemMap['unit_price']?.toString() ?? '0') ?? 0.0,
            'category': 'General',
            'is_cancelled': itemMap['is_cancelled'] == true || itemMap['is_cancelled'] == 1,
            'cancel_reason': itemMap['cancel_reason']?.toString(),
            'cancelled_at': itemMap['cancelled_at']?.toString(),
            'cancelled_by': itemMap['cancelled_by']?.toString(),
          };
        }).toList();
      }
    }

    if (json['dine_in_tax'] != null) {
      parsedDineInTax = double.tryParse(json['dine_in_tax']?.toString() ?? '$parsedDineInTax') ?? parsedDineInTax;
    }
    if (json['discount_amount'] != null) {
      parsedDiscountAmount = double.tryParse(json['discount_amount']?.toString() ?? '$parsedDiscountAmount') ?? parsedDiscountAmount;
    }
    if (json['discount_percentage'] != null) {
      parsedDiscountPercentage = double.tryParse(json['discount_percentage']?.toString() ?? '$parsedDiscountPercentage') ?? parsedDiscountPercentage;
    }

    final bool isTableOccupied = parsedStatus == TableStatus.occupied;

    return RestaurantTable(
      id: json['id']?.toString() ?? '',
      tableNumber: json['table_number']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      capacity: (json['capacity'] as num?)?.toInt() ?? 4,
      currentCustomerCount: isTableOccupied ? ((json['current_customer_count'] as num?)?.toInt() ?? 0) : 0,
      currentBillAmount: isTableOccupied ? (double.tryParse(json['current_bill_amount']?.toString() ?? '0') ?? 0.0) : 0.0,
      dineInTax: isTableOccupied ? parsedDineInTax : 0.0,
      discountAmount: isTableOccupied ? parsedDiscountAmount : 0.0,
      discountPercentage: isTableOccupied ? parsedDiscountPercentage : 0.0,
      status: parsedStatus,
      section: json['section']?.toString() ?? 'Main Hall',
      activeOrderId: isTableOccupied ? json['active_order_id']?.toString() : null,
      activeOrderNumber: isTableOccupied ? (json['active_order_number']?.toString() ?? json['order_number']?.toString()) : null,
      occupiedSince: isTableOccupied && json['occupied_since'] != null
          ? DateTime.tryParse(json['occupied_since'].toString())
          : null,
      reservedCustomerName: json['reserved_customer_name']?.toString(),
      reservationTime: json['reservation_time'] != null
          ? DateTime.tryParse(json['reservation_time'].toString())
          : null,
      currentOrderItems: isTableOccupied ? orderItems : const [],
    );
  }
}

class WaitlistEntry {
  final String id;
  final String customerName;
  final String phone;
  final int partySize;
  final DateTime arrivalTime;
  final String notes;

  const WaitlistEntry({
    required this.id,
    required this.customerName,
    required this.phone,
    required this.partySize,
    required this.arrivalTime,
    this.notes = '',
  });
}
