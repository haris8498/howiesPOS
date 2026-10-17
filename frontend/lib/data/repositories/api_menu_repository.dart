import '../../domain/models/menu_item.dart';
import '../../domain/repositories/menu_repository.dart';
import '../../services/api/menu_api_service.dart';
import '../../services/mock_api_service.dart';

class ApiMenuRepository implements IMenuRepository {
  final MenuApiService _menuApiService;
  final List<MenuItem> _localCache = [];

  ApiMenuRepository({MenuApiService? menuApiService})
      : _menuApiService = menuApiService ?? MenuApiService() {
    _localCache.addAll(MockApiService.getInitialMenuItems());
  }

  @override
  Future<List<MenuItem>> getAllMenuItems() async {
    try {
      final jsonList = await _menuApiService.listItems();
      if (jsonList.isNotEmpty) {
        final items = jsonList.map((j) => MenuItem.fromBackendJson(j)).toList();
        _localCache.clear();
        _localCache.addAll(items);
        return items;
      }
    } catch (_) {}
    return List.unmodifiable(_localCache);
  }

  @override
  Future<List<MenuItem>> getMenuItemsByCategory(String category) async {
    if (category.toLowerCase() == 'all') return getAllMenuItems();
    try {
      final jsonList = await _menuApiService.listItems();
      if (jsonList.isNotEmpty) {
        final items = jsonList.map((j) => MenuItem.fromBackendJson(j)).toList();
        return items.where((i) => i.category.toLowerCase() == category.toLowerCase()).toList();
      }
    } catch (_) {}
    return _localCache.where((i) => i.category.toLowerCase() == category.toLowerCase()).toList();
  }

  @override
  Future<MenuItem?> getMenuItemById(String id) async {
    try {
      final json = await _menuApiService.getItemById(id);
      return MenuItem.fromBackendJson(json);
    } catch (_) {
      try {
        return _localCache.firstWhere((i) => i.id == id);
      } catch (_) {
        return null;
      }
    }
  }

  @override
  Future<MenuItem> saveMenuItem(MenuItem item) async {
    try {
      final dto = {
        'name': item.name,
        'category_id': item.category,
        'description': item.description,
        'base_price': item.basePrice,
        'image_url': item.imageUrl,
        'is_veg': item.isVeg,
        'is_spicy': item.isSpicy,
        'is_available': item.isAvailable,
      };

      if (item.id.isNotEmpty && !item.id.startsWith('temp_') && !item.id.startsWith('p') && !item.id.startsWith('b')) {
        final res = await _menuApiService.updateItem(item.id, dto);
        final updated = MenuItem.fromBackendJson(res);
        final index = _localCache.indexWhere((i) => i.id == item.id);
        if (index >= 0) _localCache[index] = updated;
        return updated;
      } else {
        final res = await _menuApiService.createItem(dto);
        final created = MenuItem.fromBackendJson(res);
        _localCache.insert(0, created);
        return created;
      }
    } catch (_) {
      final index = _localCache.indexWhere((i) => i.id == item.id);
      if (index >= 0) {
        _localCache[index] = item;
      } else {
        _localCache.insert(0, item);
      }
      return item;
    }
  }

  @override
  Future<void> updateItemAvailability(String id, bool isAvailable) async {
    try {
      await _menuApiService.updateAvailability(id, isAvailable);
    } catch (_) {}

    final index = _localCache.indexWhere((i) => i.id == id);
    if (index >= 0) {
      _localCache[index] = _localCache[index].copyWith(isAvailable: isAvailable);
    }
  }

  @override
  Future<void> deleteMenuItem(String id) async {
    try {
      await _menuApiService.deleteItem(id);
    } catch (_) {}
    _localCache.removeWhere((i) => i.id == id);
  }
}
