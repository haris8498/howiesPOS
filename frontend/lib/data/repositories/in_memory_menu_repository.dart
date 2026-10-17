import '../../domain/models/menu_item.dart';
import '../../domain/repositories/menu_repository.dart';
import '../../services/mock_api_service.dart';

/// In-Memory implementation of IMenuRepository
class InMemoryMenuRepository implements IMenuRepository {
  List<MenuItem> _items = [];

  InMemoryMenuRepository() {
    _items = List.from(MockApiService.getInitialMenuItems());
  }

  @override
  Future<List<MenuItem>> getAllMenuItems() async => List.unmodifiable(_items);

  @override
  Future<List<MenuItem>> getMenuItemsByCategory(String category) async {
    if (category.toLowerCase() == 'all') return getAllMenuItems();
    return _items.where((i) => i.category.toLowerCase() == category.toLowerCase()).toList();
  }

  @override
  Future<MenuItem?> getMenuItemById(String id) async {
    final index = _items.indexWhere((i) => i.id == id);
    return index >= 0 ? _items[index] : null;
  }

  @override
  Future<MenuItem> saveMenuItem(MenuItem item) async {
    final index = _items.indexWhere((i) => i.id == item.id);
    if (index >= 0) {
      _items[index] = item;
    } else {
      _items.insert(0, item);
    }
    return item;
  }

  @override
  Future<void> updateItemAvailability(String id, bool isAvailable) async {
    final index = _items.indexWhere((i) => i.id == id);
    if (index >= 0) {
      _items[index] = _items[index].copyWith(isAvailable: isAvailable);
    }
  }

  @override
  Future<void> deleteMenuItem(String id) async {
    _items.removeWhere((i) => i.id == id);
  }
}
