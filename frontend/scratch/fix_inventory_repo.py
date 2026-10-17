import re

path = 'c:/flutter/Howies POS/frontend/lib/data/inventory_repository.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Fix addStockItem
old_add_item = """  Future<void> addStockItem(InventoryItem item) async {
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
      final created = InventoryItem.fromBackendJson(res);
      state = state.copyWith(items: [...state.items, created]);
    } catch (_) {
      state = state.copyWith(items: [...state.items, item]);
    }
  }"""

new_add_item = """  Future<void> addStockItem(InventoryItem item) async {
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
    final created = InventoryItem.fromBackendJson(res);
    state = state.copyWith(items: [...state.items, created]);
  }"""

content = content.replace(old_add_item, new_add_item)

# Fix addStockMovement
old_add_movement = """    if (type == StockMovementType.stockIn) {
      newCurrentStock += quantity;
      try {
        await _inventoryApiService.stockIn(
          itemId: itemId,
          quantity: quantity,
          reason: reason,
          costImpact: quantity * item.costPerUnit,
        );
      } catch (_) {}
    } else {
      newCurrentStock = (newCurrentStock - quantity) > 0 ? (newCurrentStock - quantity) : 0.0;
      newUsedStock += quantity;
      try {
        await _inventoryApiService.stockOut(
          itemId: itemId,
          quantity: quantity,
          movementType: type.name,
          reason: reason,
        );
      } catch (_) {}
    }"""

new_add_movement = """    if (type == StockMovementType.stockIn) {
      newCurrentStock += quantity;
      await _inventoryApiService.stockIn(
        itemId: itemId,
        quantity: quantity,
        reason: reason,
        costImpact: quantity * item.costPerUnit,
      );
    } else {
      newCurrentStock = (newCurrentStock - quantity) > 0 ? (newCurrentStock - quantity) : 0.0;
      newUsedStock += quantity;
      await _inventoryApiService.stockOut(
        itemId: itemId,
        quantity: quantity,
        movementType: type.name,
        reason: reason,
      );
    }"""

content = content.replace(old_add_movement, new_add_movement)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
