import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/models/inventory_item.dart';
import '../domain/models/order_model.dart';
import '../services/api/api_providers.dart';
import '../services/api/inventory_api_service.dart';

class InventoryState {
  final List<InventoryItem> items;
  final List<StockMovement> movements;
  final String selectedCategory;
  final bool isLoading;

  const InventoryState({
    required this.items,
    this.movements = const [],
    this.selectedCategory = 'All',
    this.isLoading = false,
  });

  double get totalStockValue => items.fold(0.0, (sum, item) => sum + item.totalStockValue);
  double get totalUsedStockValue => items.fold(0.0, (sum, item) => sum + item.usedStockValue);
  double get totalRemainingQuantity => items.fold(0.0, (sum, item) => sum + item.currentStock);
  double get totalUsedQuantity => items.fold(0.0, (sum, item) => sum + item.usedStock);
  int get lowStockCount => items.where((item) => item.isLowStock).length;
  
  double get todayConsumptionCost => movements
      .where((m) => m.type == StockMovementType.saleAutoDeduction || m.type == StockMovementType.stockOut)
      .fold(0.0, (sum, m) => sum + m.costImpact);
      
  double get totalWastageCost => movements
      .where((m) => m.type == StockMovementType.wastage)
      .fold(0.0, (sum, m) => sum + m.costImpact);

  InventoryState copyWith({
    List<InventoryItem>? items,
    List<StockMovement>? movements,
    String? selectedCategory,
    bool? isLoading,
  }) {
    return InventoryState(
      items: items ?? this.items,
      movements: movements ?? this.movements,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class InventoryNotifier extends StateNotifier<InventoryState> {
  final InventoryApiService _inventoryApiService;

  InventoryNotifier({InventoryApiService? inventoryApiService})
      : _inventoryApiService = inventoryApiService ?? InventoryApiService(),
        super(const InventoryState(
          items: [],
          movements: [],
        )) {
    loadInventoryData();
  }

  Future<void> loadInventoryData() async {
    state = state.copyWith(isLoading: true);
    try {
      final itemsJson = await _inventoryApiService.listItems();
      List<InventoryItem> items = [];
      if (itemsJson.isNotEmpty) {
        items = itemsJson.map((j) => InventoryItem.fromBackendJson(j)).toList();
      }

      final movJson = await _inventoryApiService.listMovements();
      List<StockMovement> movements = [];
      if (movJson.isNotEmpty) {
        movements = movJson.map((j) => StockMovement.fromBackendJson(j)).toList();
      }

      state = state.copyWith(
        items: items,
        movements: movements,
        isLoading: false,
      );
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> refresh() async {
    await loadInventoryData();
  }

  void setCategory(String category) {
    state = state.copyWith(selectedCategory: category);
  }

  Future<bool> addStockItem(InventoryItem item) async {
    try {
      final res = await _inventoryApiService.createItem({
        'name': item.name,
        'category': item.category,
        'sku_code': item.skuCode,
        'initial_stock': item.initialStock,
        'current_stock': item.currentStock,
        'min_threshold': item.minThreshold,
        'unit': item.unit,
        'cost_per_unit': item.costPerUnit,
        'supplier_name': item.supplierName,
      });
      if (res.isNotEmpty) {
        // Re-sync with database to ensure new IDs, generated movements, and calculations match DB exactly
        await loadInventoryData();
        return true;
      }
    } catch (_) {
      await loadInventoryData();
      return false;
    }
    return false;
  }

  /// Automatically restocks existing item if found by name, or creates a new item & category if missing.
  Future<bool> addOrUpdateStock({
    required String itemName,
    required String category,
    required double quantity,
    required String unit,
    required double costPerUnit,
    required String supplierName,
    required String reason,
    double? minThreshold,
  }) async {
    final trimmedName = itemName.trim();
    if (trimmedName.isEmpty) return false;

    final existingIndex = state.items.indexWhere(
      (i) => i.name.trim().toLowerCase() == trimmedName.toLowerCase(),
    );

    if (existingIndex >= 0) {
      final existingItem = state.items[existingIndex];
      if (minThreshold != null && minThreshold > 0 && minThreshold != existingItem.minThreshold) {
        await updateThreshold(existingItem.id, minThreshold);
      }
      return await addStockMovement(
        itemId: existingItem.id,
        type: StockMovementType.stockIn,
        quantity: quantity,
        reason: reason.isNotEmpty ? reason : 'Restock / Inward Arrival',
      );
    } else {
      final skuCode = 'SKU-${(state.items.length + 101).toString()}';
      final effectiveMinThreshold = minThreshold != null && minThreshold > 0
          ? minThreshold
          : (quantity * 0.2).clamp(5.0, 50.0);

      final newItem = InventoryItem(
        id: '',
        skuCode: skuCode,
        name: trimmedName,
        category: category.isNotEmpty ? category : 'General',
        initialStock: quantity,
        usedStock: 0.0,
        currentStock: quantity,
        minThreshold: effectiveMinThreshold,
        unit: unit.isNotEmpty ? unit : 'units',
        costPerUnit: costPerUnit,
        supplierName: supplierName.isNotEmpty ? supplierName : 'Direct Supplier',
        lastRestockedDate: DateTime.now(),
      );

      return await addStockItem(newItem);
    }
  }

  Future<bool> addStockMovement({
    required String itemId,
    required StockMovementType type,
    required double quantity,
    required String reason,
    String? category,
  }) async {
    final itemIndex = state.items.indexWhere((i) => i.id == itemId);
    if (itemIndex == -1) return false;

    final item = state.items[itemIndex];
    if (type != StockMovementType.stockIn && item.currentStock < quantity) {
      return false;
    }

    try {
      if (type == StockMovementType.stockIn) {
        final res = await _inventoryApiService.stockIn(
          itemId: itemId,
          quantity: quantity,
          reason: reason,
          costImpact: quantity * item.costPerUnit,
        );
        if (res.isNotEmpty && res['item'] != null) {
          final updatedItem = InventoryItem.fromBackendJson(res['item']);
          final updatedMov = res['movement'] != null ? StockMovement.fromBackendJson(res['movement']) : null;
          final updatedItems = List<InventoryItem>.from(state.items);
          updatedItems[itemIndex] = updatedItem;
          state = state.copyWith(
            items: updatedItems,
            movements: updatedMov != null ? [updatedMov, ...state.movements] : state.movements,
          );
          return true;
        }
      } else {
        final res = await _inventoryApiService.stockOut(
          itemId: itemId,
          quantity: quantity,
          movementType: type == StockMovementType.wastage ? 'wastage' : (type == StockMovementType.saleAutoDeduction ? 'saleAutoDeduction' : 'stockOut'),
          reason: reason,
        );
        if (res.isNotEmpty && res['item'] != null) {
          final updatedItem = InventoryItem.fromBackendJson(res['item']);
          final updatedMov = res['movement'] != null ? StockMovement.fromBackendJson(res['movement']) : null;
          final updatedItems = List<InventoryItem>.from(state.items);
          updatedItems[itemIndex] = updatedItem;
          state = state.copyWith(
            items: updatedItems,
            movements: updatedMov != null ? [updatedMov, ...state.movements] : state.movements,
          );
          return true;
        }
      }
    } catch (_) {
      // Re-sync with database if anything throws
      await loadInventoryData();
      return false;
    }
    return false;
  }

  Future<void> triggerAutoDeductionForOrder(List<OrderItem> items) async {
    for (final orderItem in items) {
      final matchingItem = state.items.firstWhere(
        (inv) =>
            inv.name.toLowerCase().contains(orderItem.item.name.toLowerCase()) ||
            orderItem.item.name.toLowerCase().contains(inv.name.toLowerCase()),
        orElse: () => state.items.isNotEmpty
            ? state.items.first
            : const InventoryItem(
                id: '',
                name: '',
                category: '',
                currentStock: 0,
                unit: '',
                minThreshold: 0,
                costPerUnit: 0,
                usedStock: 0,
                supplierName: '',
              ),
      );

      if (matchingItem.id.isNotEmpty) {
        await addStockMovement(
          itemId: matchingItem.id,
          type: StockMovementType.saleAutoDeduction,
          quantity: orderItem.quantity.toDouble(),
          reason: 'Auto Deduction (Order #${orderItem.item.name})',
        );
      }
    }
  }

  Future<void> updateThreshold(String itemId, double newThreshold) async {
    try {
      await _inventoryApiService.updateItem(itemId, {'min_threshold': newThreshold});
      final updated = state.items.map((i) {
        if (i.id == itemId) return i.copyWith(minThreshold: newThreshold);
        return i;
      }).toList();
      state = state.copyWith(items: updated);
    } catch (_) {
      await loadInventoryData();
    }
  }

  Future<bool> deleteStockItem(String itemId) async {
    try {
      await _inventoryApiService.deleteItem(itemId);
      final updated = state.items.where((i) => i.id != itemId).toList();
      state = state.copyWith(items: updated);
      return true;
    } catch (_) {
      await loadInventoryData();
      return false;
    }
  }
}

final inventoryProvider = StateNotifierProvider<InventoryNotifier, InventoryState>((ref) {
  final inventoryApi = ref.read(inventoryApiServiceProvider);
  return InventoryNotifier(inventoryApiService: inventoryApi);
});
