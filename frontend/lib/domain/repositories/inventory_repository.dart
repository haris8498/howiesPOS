import '../models/inventory_item.dart';

/// Abstract contract for Inventory catalog, transactions, and movements
abstract class IInventoryRepository {
  Future<List<InventoryItem>> getAllInventoryItems();
  Future<InventoryItem?> getInventoryItemById(String id);
  Future<List<StockMovement>> getStockMovements();
  Future<void> saveInventoryItem(InventoryItem item);
  Future<void> recordStockMovement(StockMovement movement);
  Future<void> deductStockByItemName(String itemName, double quantity, String reason);
}
