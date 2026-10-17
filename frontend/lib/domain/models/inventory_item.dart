enum StockMovementType { stockIn, stockOut, wastage, saleAutoDeduction }

class InventoryItem {
  final String id;
  final String skuCode;
  final String name;
  final String category; // Dairy, Meat, Bakery, Produce, Packaging, Sauces, Beverages
  final double initialStock;
  final double usedStock;
  final double currentStock;
  final double minThreshold;
  final String unit; // kg, lbs, units, liters, boxes
  final double costPerUnit;
  final String supplierName;
  final DateTime? lastRestockedDate;

  const InventoryItem({
    required this.id,
    this.skuCode = 'SKU-101',
    required this.name,
    required this.category,
    this.initialStock = 100.0,
    this.usedStock = 0.0,
    required this.currentStock,
    required this.minThreshold,
    required this.unit,
    required this.costPerUnit,
    required this.supplierName,
    this.lastRestockedDate,
  });

  bool get isLowStock => currentStock <= minThreshold;
  double get totalStockValue => currentStock * costPerUnit;
  double get usedStockValue => usedStock * costPerUnit;
  double get stockUsagePercentage => (initialStock > 0) ? ((initialStock - currentStock) / initialStock) * 100 : 0.0;

  InventoryItem copyWith({
    String? id,
    String? skuCode,
    String? name,
    String? category,
    double? initialStock,
    double? usedStock,
    double? currentStock,
    double? minThreshold,
    String? unit,
    double? costPerUnit,
    String? supplierName,
    DateTime? lastRestockedDate,
  }) {
    return InventoryItem(
      id: id ?? this.id,
      skuCode: skuCode ?? this.skuCode,
      name: name ?? this.name,
      category: category ?? this.category,
      initialStock: initialStock ?? this.initialStock,
      usedStock: usedStock ?? this.usedStock,
      currentStock: currentStock ?? this.currentStock,
      minThreshold: minThreshold ?? this.minThreshold,
      unit: unit ?? this.unit,
      costPerUnit: costPerUnit ?? this.costPerUnit,
      supplierName: supplierName ?? this.supplierName,
      lastRestockedDate: lastRestockedDate ?? this.lastRestockedDate,
    );
  }

  factory InventoryItem.fromBackendJson(Map<String, dynamic> json) {
    return InventoryItem(
      id: json['id']?.toString() ?? '',
      skuCode: json['sku_code']?.toString() ?? 'SKU-101',
      name: json['name']?.toString() ?? '',
      category: json['category']?.toString() ?? 'General',
      initialStock: double.tryParse(json['initial_stock']?.toString() ?? '0') ?? 0.0,
      usedStock: double.tryParse(json['used_stock']?.toString() ?? '0') ?? 0.0,
      currentStock: double.tryParse(json['current_stock']?.toString() ?? '0') ?? 0.0,
      minThreshold: double.tryParse(json['min_threshold']?.toString() ?? '10') ?? 10.0,
      unit: json['unit']?.toString() ?? 'kg',
      costPerUnit: double.tryParse(json['cost_per_unit']?.toString() ?? '0') ?? 0.0,
      supplierName: json['supplier_name']?.toString() ?? 'Central Depot',
      lastRestockedDate: json['last_restocked_date'] != null
          ? DateTime.tryParse(json['last_restocked_date'].toString())
          : null,
    );
  }
}

class StockMovement {
  final String id;
  final String itemId;
  final String itemName;
  final StockMovementType type;
  final double quantity;
  final String unit;
  final String reason;
  final DateTime timestamp;
  final double costImpact;

  const StockMovement({
    required this.id,
    required this.itemId,
    required this.itemName,
    required this.type,
    required this.quantity,
    required this.unit,
    required this.reason,
    required this.timestamp,
    required this.costImpact,
  });

  factory StockMovement.fromBackendJson(Map<String, dynamic> json) {
    StockMovementType parsedType = StockMovementType.stockIn;
    final typeStr = json['movement_type']?.toString().toLowerCase() ?? '';
    if (typeStr.contains('out')) {
      parsedType = StockMovementType.stockOut;
    } else if (typeStr.contains('wastage') || typeStr.contains('waste')) {
      parsedType = StockMovementType.wastage;
    } else if (typeStr.contains('deduct') || typeStr.contains('sale') || typeStr.contains('auto')) {
      parsedType = StockMovementType.saleAutoDeduction;
    }

    return StockMovement(
      id: json['id']?.toString() ?? '',
      itemId: json['item_id']?.toString() ?? '',
      itemName: json['item_name']?.toString() ?? '',
      type: parsedType,
      quantity: double.tryParse(json['quantity']?.toString() ?? '0') ?? 0.0,
      unit: json['unit']?.toString() ?? 'kg',
      reason: json['reason']?.toString() ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
      costImpact: double.tryParse(json['cost_impact']?.toString() ?? '0') ?? 0.0,
    );
  }
}
