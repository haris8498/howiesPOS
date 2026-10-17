import 'package:uuid/uuid.dart';
import '../../domain/models/inventory_item.dart';
import '../../domain/repositories/inventory_repository.dart';
import '../../services/mock_api_service.dart';

/// In-Memory implementation of IInventoryRepository
class InMemoryInventoryRepository implements IInventoryRepository {
  List<InventoryItem> _items = [];
  final List<StockMovement> _movements = [];

  InMemoryInventoryRepository() {
    _items = List.from(MockApiService.getInitialInventory());
    _movements.addAll(MockApiService.getInitialMovements());
  }

  @override
  Future<List<InventoryItem>> getAllInventoryItems() async => List.unmodifiable(_items);

  @override
  Future<InventoryItem?> getInventoryItemById(String id) async {
    final index = _items.indexWhere((i) => i.id == id);
    return index >= 0 ? _items[index] : null;
  }

  @override
  Future<List<StockMovement>> getStockMovements() async => List.unmodifiable(_movements);

  @override
  Future<void> saveInventoryItem(InventoryItem item) async {
    final index = _items.indexWhere((i) => i.id == item.id);
    if (index >= 0) {
      _items[index] = item;
    } else {
      _items.add(item);
    }
  }

  @override
  Future<void> recordStockMovement(StockMovement movement) async {
    _movements.insert(0, movement);
  }

  @override
  Future<void> deductStockByItemName(String itemName, double quantity, String reason) async {
    final trimmed = itemName.trim().toLowerCase();
    final index = _items.indexWhere((i) => i.name.trim().toLowerCase().contains(trimmed) || trimmed.contains(i.name.trim().toLowerCase()));

    if (index >= 0) {
      final current = _items[index];
      final newUsed = current.usedStock + quantity;
      final newStock = (current.initialStock - newUsed) > 0 ? (current.initialStock - newUsed) : 0.0;

      _items[index] = current.copyWith(
        usedStock: newUsed,
        currentStock: newStock,
      );

      _movements.insert(
        0,
        StockMovement(
          id: const Uuid().v4(),
          itemId: current.id,
          itemName: current.name,
          type: StockMovementType.saleAutoDeduction,
          quantity: quantity,
          unit: current.unit,
          reason: reason,
          timestamp: DateTime.now(),
          costImpact: quantity * current.costPerUnit,
        ),
      );
    }
  }
}
