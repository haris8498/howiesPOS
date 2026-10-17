import '../models/menu_item.dart';

/// Abstract contract for Menu catalog and items persistence
abstract class IMenuRepository {
  Future<List<MenuItem>> getAllMenuItems();
  Future<List<MenuItem>> getMenuItemsByCategory(String category);
  Future<MenuItem?> getMenuItemById(String id);
  Future<MenuItem> saveMenuItem(MenuItem item);
  Future<void> updateItemAvailability(String id, bool isAvailable);
  Future<void> deleteMenuItem(String id);
}
