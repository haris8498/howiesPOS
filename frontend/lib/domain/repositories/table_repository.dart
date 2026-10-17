import '../models/restaurant_table.dart';

/// Abstract contract for Table floor plan and occupancy management
abstract class ITableRepository {
  Future<List<RestaurantTable>> getAllTables();
  Future<RestaurantTable?> getTableById(String id);
  Future<void> updateTableStatus(String tableId, TableStatus status, {String? activeOrderId});
  Future<void> updateTableBill(String tableId, double billAmount, List<Map<String, dynamic>> orderItems);
  Future<void> freeTable(String tableId);
  Future<void> transferTable(String fromTableId, String toTableId);
  Future<void> saveTable(RestaurantTable table);
  Future<void> deleteTable(String tableId);
  Future<List<WaitlistEntry>> getWaitlist();
  Future<void> addWaitlistEntry(WaitlistEntry entry);
  Future<void> removeWaitlistEntry(String id);
}
