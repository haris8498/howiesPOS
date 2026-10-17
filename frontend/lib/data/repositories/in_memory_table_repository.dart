import '../../domain/models/restaurant_table.dart';
import '../../domain/repositories/table_repository.dart';
import '../../services/mock_api_service.dart';

/// In-Memory implementation of ITableRepository
class InMemoryTableRepository implements ITableRepository {
  List<RestaurantTable> _tables = [];
  final List<WaitlistEntry> _waitlist = [];

  InMemoryTableRepository() {
    _tables = List.from(MockApiService.getInitialTables());
  }

  @override
  Future<List<RestaurantTable>> getAllTables() async => List.unmodifiable(_tables);

  @override
  Future<RestaurantTable?> getTableById(String id) async {
    final index = _tables.indexWhere((t) => t.id == id);
    return index >= 0 ? _tables[index] : null;
  }

  @override
  Future<void> updateTableStatus(String tableId, TableStatus status, {String? activeOrderId}) async {
    final index = _tables.indexWhere((t) => t.id == tableId);
    if (index >= 0) {
      _tables[index] = _tables[index].copyWith(
        status: status,
        activeOrderId: status == TableStatus.occupied ? activeOrderId ?? _tables[index].activeOrderId : null,
      );
    }
  }

  @override
  Future<void> updateTableBill(String tableId, double billAmount, List<Map<String, dynamic>> orderItems) async {
    final index = _tables.indexWhere((t) => t.id == tableId);
    if (index >= 0) {
      _tables[index] = _tables[index].copyWith(
        currentBillAmount: billAmount,
        currentOrderItems: orderItems,
        status: TableStatus.occupied,
        occupiedSince: _tables[index].occupiedSince ?? DateTime.now(),
      );
    }
  }

  @override
  Future<void> freeTable(String tableId) async {
    final index = _tables.indexWhere((t) => t.id == tableId);
    if (index >= 0) {
      _tables[index] = _tables[index].copyWith(
        status: TableStatus.available,
        activeOrderId: null,
        currentBillAmount: 0.0,
        currentOrderItems: const [],
      );
    }
  }

  @override
  Future<void> transferTable(String fromTableId, String toTableId) async {
    final fromIndex = _tables.indexWhere((t) => t.id == fromTableId);
    final toIndex = _tables.indexWhere((t) => t.id == toTableId);

    if (fromIndex >= 0 && toIndex >= 0) {
      final fromTable = _tables[fromIndex];
      _tables[toIndex] = _tables[toIndex].copyWith(
        status: TableStatus.occupied,
        activeOrderId: fromTable.activeOrderId,
        currentBillAmount: fromTable.currentBillAmount,
        currentOrderItems: fromTable.currentOrderItems,
        occupiedSince: fromTable.occupiedSince,
      );
      _tables[fromIndex] = fromTable.copyWith(
        status: TableStatus.available,
        activeOrderId: null,
        currentBillAmount: 0.0,
        currentOrderItems: const [],
      );
    }
  }

  @override
  Future<void> saveTable(RestaurantTable table) async {
    final index = _tables.indexWhere((t) => t.id == table.id);
    if (index >= 0) {
      _tables[index] = table;
    } else {
      _tables.add(table);
    }
  }

  @override
  Future<void> deleteTable(String tableId) async {
    _tables.removeWhere((t) => t.id == tableId);
  }

  @override
  Future<List<WaitlistEntry>> getWaitlist() async => List.unmodifiable(_waitlist);

  @override
  Future<void> addWaitlistEntry(WaitlistEntry entry) async {
    _waitlist.add(entry);
  }

  @override
  Future<void> removeWaitlistEntry(String id) async {
    _waitlist.removeWhere((w) => w.id == id);
  }
}
