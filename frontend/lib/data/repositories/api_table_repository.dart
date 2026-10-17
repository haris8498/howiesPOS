import '../../domain/models/restaurant_table.dart';
import '../../domain/repositories/table_repository.dart';
import '../../services/api/tables_api_service.dart';

class ApiTableRepository implements ITableRepository {
  final TablesApiService _tablesApiService;
  final List<RestaurantTable> _localCache = [];
  final List<WaitlistEntry> _waitlist = [];

  ApiTableRepository({TablesApiService? tablesApiService})
      : _tablesApiService = tablesApiService ?? TablesApiService();

  @override
  Future<List<RestaurantTable>> getAllTables() async {
    try {
      final jsonList = await _tablesApiService.listTables();
      final tables = jsonList.map((j) => RestaurantTable.fromBackendJson(j)).toList();
      _localCache.clear();
      _localCache.addAll(tables);
      return tables;
    } catch (_) {}
    return List.unmodifiable(_localCache);
  }

  @override
  Future<RestaurantTable?> getTableById(String id) async {
    try {
      final json = await _tablesApiService.getTableById(id);
      return RestaurantTable.fromBackendJson(json);
    } catch (_) {
      try {
        return _localCache.firstWhere((t) => t.id == id);
      } catch (_) {
        return null;
      }
    }
  }

  @override
  Future<void> updateTableStatus(String tableId, TableStatus status, {String? activeOrderId}) async {
    try {
      await _tablesApiService.updateTableStatus(
        tableId,
        status: status.name,
        activeOrderId: activeOrderId,
      );
    } catch (_) {}

    final index = _localCache.indexWhere((t) => t.id == tableId);
    if (index >= 0) {
      _localCache[index] = _localCache[index].copyWith(
        status: status,
        activeOrderId: status == TableStatus.occupied ? activeOrderId ?? _localCache[index].activeOrderId : null,
      );
    }
  }

  @override
  Future<void> updateTableBill(String tableId, double billAmount, List<Map<String, dynamic>> orderItems) async {
    try {
      await _tablesApiService.updateTableStatus(
        tableId,
        status: 'occupied',
        currentBillAmount: billAmount,
      );
    } catch (_) {}

    final index = _localCache.indexWhere((t) => t.id == tableId);
    if (index >= 0) {
      _localCache[index] = _localCache[index].copyWith(
        currentBillAmount: billAmount,
        status: TableStatus.occupied,
        currentOrderItems: orderItems,
      );
    }
  }

  @override
  Future<void> freeTable(String tableId) async {
    try {
      await _tablesApiService.releaseTable(tableId);
    } catch (_) {
      await updateTableStatus(tableId, TableStatus.available);
    }

    final index = _localCache.indexWhere((t) => t.id == tableId);
    if (index >= 0) {
      _localCache[index] = _localCache[index].copyWith(
        status: TableStatus.available,
        currentBillAmount: 0.0,
        activeOrderId: null,
        currentCustomerCount: 0,
        currentOrderItems: [],
      );
    }
  }

  @override
  Future<void> transferTable(String fromTableId, String toTableId) async {
    try {
      await _tablesApiService.transferTable(fromTableId: fromTableId, toTableId: toTableId);
    } catch (_) {}

    final fromIndex = _localCache.indexWhere((t) => t.id == fromTableId);
    final toIndex = _localCache.indexWhere((t) => t.id == toTableId);

    if (fromIndex >= 0 && toIndex >= 0) {
      final fromTable = _localCache[fromIndex];
      _localCache[toIndex] = _localCache[toIndex].copyWith(
        status: TableStatus.occupied,
        currentBillAmount: fromTable.currentBillAmount,
        activeOrderId: fromTable.activeOrderId,
        currentCustomerCount: fromTable.currentCustomerCount,
        occupiedSince: fromTable.occupiedSince,
        currentOrderItems: fromTable.currentOrderItems,
      );
      _localCache[fromIndex] = fromTable.copyWith(
        status: TableStatus.available,
        currentBillAmount: 0.0,
        activeOrderId: null,
        currentCustomerCount: 0,
        currentOrderItems: [],
      );
    }
  }

  @override
  Future<void> saveTable(RestaurantTable table) async {
    try {
      final dto = {
        'table_number': table.tableNumber,
        'name': table.name,
        'capacity': table.capacity,
        'section': table.section,
        'status': table.status.name,
      };
      if (table.id.isNotEmpty && !table.id.startsWith('temp_') && !table.id.startsWith('t')) {
        await _tablesApiService.updateTable(table.id, dto);
      } else {
        await _tablesApiService.createTable(dto);
      }
    } catch (_) {}

    final index = _localCache.indexWhere((t) => t.id == table.id);
    if (index >= 0) {
      _localCache[index] = table;
    } else {
      _localCache.add(table);
    }
  }

  @override
  Future<void> deleteTable(String tableId) async {
    try {
      await _tablesApiService.deleteTable(tableId);
    } catch (_) {}
    _localCache.removeWhere((t) => t.id == tableId);
  }

  @override
  Future<List<WaitlistEntry>> getWaitlist() async => List.unmodifiable(_waitlist);

  @override
  Future<void> addWaitlistEntry(WaitlistEntry entry) async {
    _waitlist.add(entry);
  }

  @override
  Future<void> removeWaitlistEntry(String id) async {
    _waitlist.removeWhere((e) => e.id == id);
  }
}
