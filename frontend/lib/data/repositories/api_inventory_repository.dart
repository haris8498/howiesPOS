import '../../domain/models/inventory_item.dart';
import '../../domain/repositories/inventory_repository.dart';
import '../../services/api/inventory_api_service.dart';
import '../../services/mock_api_service.dart';

class ApiInventoryRepository implements IInventoryRepository {
  final InventoryApiService _inventoryApiService;
  final List<InventoryItem> _localItems = [];
  final List<StockMovement> _localMovements = [];

  ApiInventoryRepository({InventoryApiService? inventoryApiService})
      : _inventoryApiService = inventoryApiService ?? InventoryApiService() {
    _localItems.addAll(MockApiService.getInitialInventory());
    _localMovements.addAll(MockApiService.getInitialMovements());
  }

  @override
  Future<List<InventoryItem>> getAllInventoryItems() async {
    try {
      final jsonList = await _inventoryApiService.listItems();
      if (jsonList.isNotEmpty) {
        final items = jsonList.map((j) => InventoryItem.fromBackendJson(j)).toList();
        _localItems.clear();
        _localItems.addAll(items);
        return items;
      }
    } catch (_) {}
    return List.unmodifiable(_localItems);
  }

  @override
  Future<InventoryItem?> getInventoryItemById(String id) async {
    try {
      final json = await _inventoryApiService.getItemById(id);
      return InventoryItem.fromBackendJson(json);
    } catch (_) {
      try {
        return _localItems.firstWhere((i) => i.id == id);
      } catch (_) {
        return null;
      }
    }
  }

  @override
  Future<List<StockMovement>> getStockMovements() async {
    try {
      final jsonList = await _inventoryApiService.listMovements();
      if (jsonList.isNotEmpty) {
        final movements = jsonList.map((j) => StockMovement.fromBackendJson(j)).toList();
        _localMovements.clear();
        _localMovements.addAll(movements);
        return movements;
      }
    } catch (_) {}
    return List.unmodifiable(_localMovements);
  }

  @override
  Future<void> saveInventoryItem(InventoryItem item) async {
    try {
      final dto = {
        'name': item.name,
        'category': item.category,
        'sku_code': item.skuCode,
        'current_stock': item.currentStock,
        'min_threshold': item.minThreshold,
        'unit': item.unit,
        'cost_per_unit': item.costPerUnit,
        'supplier_name': item.supplierName,
      };

      if (item.id.isNotEmpty && !item.id.startsWith('temp_') && !item.id.startsWith('inv_') && !item.id.startsWith('item_')) {
        await _inventoryApiService.updateItem(item.id, dto);
      } else {
        await _inventoryApiService.createItem(dto);
      }
    } catch (_) {}

    final index = _localItems.indexWhere((i) => i.id == item.id);
    if (index >= 0) {
      _localItems[index] = item;
    } else {
      _localItems.add(item);
    }
  }

  @override
  Future<void> recordStockMovement(StockMovement movement) async {
    try {
      if (movement.type == StockMovementType.stockIn) {
        await _inventoryApiService.stockIn(
          itemId: movement.itemId,
          quantity: movement.quantity,
          reason: movement.reason,
          costImpact: movement.costImpact,
        );
      } else {
        await _inventoryApiService.stockOut(
          itemId: movement.itemId,
          quantity: movement.quantity,
          reason: movement.reason,
        );
      }
    } catch (_) {}

    _localMovements.insert(0, movement);
  }

  @override
  Future<void> deductStockByItemName(String itemName, double quantity, String reason) async {
    final index = _localItems.indexWhere(
      (i) => i.name.toLowerCase() == itemName.toLowerCase(),
    );

    if (index >= 0) {
      final item = _localItems[index];
      try {
        await _inventoryApiService.stockOut(
          itemId: item.id,
          quantity: quantity,
          reason: reason,
        );
      } catch (_) {}

      final newStock = (item.currentStock - quantity) > 0 ? (item.currentStock - quantity) : 0.0;
      _localItems[index] = item.copyWith(
        currentStock: newStock,
        usedStock: item.usedStock + quantity,
      );
    }
  }
}
