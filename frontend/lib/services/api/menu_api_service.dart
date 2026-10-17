import '../../core/network/api_client.dart';

class MenuApiService {
  final ApiClient _apiClient;

  MenuApiService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  // ----------------------------------------------------
  // CATEGORIES
  // ----------------------------------------------------

  /// GET /api/menu/categories
  Future<List<Map<String, dynamic>>> listCategories() async {
    final response = await _apiClient.get('menu/categories');
    if (response is Map<String, dynamic> && response['data'] is List) {
      return (response['data'] as List).cast<Map<String, dynamic>>();
    }
    return [];
  }

  /// POST /api/menu/categories
  Future<Map<String, dynamic>> createCategory(Map<String, dynamic> dto) async {
    final response = await _apiClient.post('menu/categories', body: dto);
    if (response is Map<String, dynamic> && response['data'] is Map) {
      return response['data'] as Map<String, dynamic>;
    }
    throw const ApiException('Failed to create menu category');
  }

  /// PATCH /api/menu/categories/:id
  Future<Map<String, dynamic>> updateCategory(String id, Map<String, dynamic> dto) async {
    final response = await _apiClient.patch('menu/categories/$id', body: dto);
    if (response is Map<String, dynamic> && response['data'] is Map) {
      return response['data'] as Map<String, dynamic>;
    }
    throw const ApiException('Failed to update menu category');
  }

  /// DELETE /api/menu/categories/:id
  Future<void> deleteCategory(String id) async {
    await _apiClient.delete('menu/categories/$id');
  }

  // ----------------------------------------------------
  // MENU ITEMS
  // ----------------------------------------------------

  /// GET /api/menu/items
  Future<List<Map<String, dynamic>>> listItems({
    String? categoryId,
    String? search,
    bool? isAvailable,
    bool? isVeg,
    bool? isSpicy,
  }) async {
    final params = <String, dynamic>{};
    if (categoryId != null && categoryId.isNotEmpty && categoryId != 'All') {
      params['category_id'] = categoryId;
    }
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (isAvailable != null) params['is_available'] = isAvailable;
    if (isVeg != null) params['is_veg'] = isVeg;
    if (isSpicy != null) params['is_spicy'] = isSpicy;

    final response = await _apiClient.get('menu/items', queryParameters: params);
    if (response is Map<String, dynamic> && response['data'] is List) {
      return (response['data'] as List).cast<Map<String, dynamic>>();
    }
    return [];
  }

  /// GET /api/menu/items/:id
  Future<Map<String, dynamic>> getItemById(String id) async {
    final response = await _apiClient.get('menu/items/$id');
    if (response is Map<String, dynamic> && response['data'] is Map) {
      return response['data'] as Map<String, dynamic>;
    }
    throw ApiException('Menu item not found with id: $id');
  }

  /// POST /api/menu/items
  Future<Map<String, dynamic>> createItem(Map<String, dynamic> dto) async {
    final response = await _apiClient.post('menu/items', body: dto);
    if (response is Map<String, dynamic> && response['data'] is Map) {
      return response['data'] as Map<String, dynamic>;
    }
    throw const ApiException('Failed to create menu item');
  }

  /// PATCH /api/menu/items/:id
  Future<Map<String, dynamic>> updateItem(String id, Map<String, dynamic> dto) async {
    final response = await _apiClient.patch('menu/items/$id', body: dto);
    if (response is Map<String, dynamic> && response['data'] is Map) {
      return response['data'] as Map<String, dynamic>;
    }
    throw const ApiException('Failed to update menu item');
  }

  /// PATCH /api/menu/items/:id/availability
  Future<Map<String, dynamic>> updateAvailability(String id, bool isAvailable) async {
    final response = await _apiClient.patch(
      'menu/items/$id/availability',
      body: {'is_available': isAvailable},
    );
    if (response is Map<String, dynamic> && response['data'] is Map) {
      return response['data'] as Map<String, dynamic>;
    }
    throw const ApiException('Failed to update item availability');
  }

  /// DELETE /api/menu/items/:id
  Future<void> deleteItem(String id) async {
    await _apiClient.delete('menu/items/$id');
  }

  // ----------------------------------------------------
  // SIZES
  // ----------------------------------------------------

  /// GET /api/menu/items/:itemId/sizes
  Future<List<Map<String, dynamic>>> listSizes(String itemId) async {
    final response = await _apiClient.get('menu/items/$itemId/sizes');
    if (response is Map<String, dynamic> && response['data'] is List) {
      return (response['data'] as List).cast<Map<String, dynamic>>();
    }
    return [];
  }

  /// POST /api/menu/items/:itemId/sizes
  Future<Map<String, dynamic>> createSize(String itemId, Map<String, dynamic> dto) async {
    final response = await _apiClient.post('menu/items/$itemId/sizes', body: dto);
    return response['data'] as Map<String, dynamic>? ?? {};
  }

  /// PATCH /api/menu/sizes/:id
  Future<Map<String, dynamic>> updateSize(String id, Map<String, dynamic> dto) async {
    final response = await _apiClient.patch('menu/sizes/$id', body: dto);
    return response['data'] as Map<String, dynamic>? ?? {};
  }

  /// DELETE /api/menu/sizes/:id
  Future<void> deleteSize(String id) async {
    await _apiClient.delete('menu/sizes/$id');
  }

  // ----------------------------------------------------
  // OPTIONS
  // ----------------------------------------------------

  /// GET /api/menu/items/:itemId/options
  Future<List<Map<String, dynamic>>> listOptions(String itemId) async {
    final response = await _apiClient.get('menu/items/$itemId/options');
    if (response is Map<String, dynamic> && response['data'] is List) {
      return (response['data'] as List).cast<Map<String, dynamic>>();
    }
    return [];
  }

  /// POST /api/menu/items/:itemId/options
  Future<Map<String, dynamic>> createOption(String itemId, Map<String, dynamic> dto) async {
    final response = await _apiClient.post('menu/items/$itemId/options', body: dto);
    return response['data'] as Map<String, dynamic>? ?? {};
  }

  /// PATCH /api/menu/options/:id
  Future<Map<String, dynamic>> updateOption(String id, Map<String, dynamic> dto) async {
    final response = await _apiClient.patch('menu/options/$id', body: dto);
    return response['data'] as Map<String, dynamic>? ?? {};
  }

  /// DELETE /api/menu/options/:id
  Future<void> deleteOption(String id) async {
    await _apiClient.delete('menu/options/$id');
  }

  // ----------------------------------------------------
  // DEALS
  // ----------------------------------------------------

  /// GET /api/menu/deals
  Future<List<Map<String, dynamic>>> listDeals({String? search, bool? isAvailable}) async {
    final params = <String, dynamic>{};
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (isAvailable != null) params['is_available'] = isAvailable;

    final response = await _apiClient.get('menu/deals', queryParameters: params);
    if (response is Map<String, dynamic> && response['data'] is List) {
      return (response['data'] as List).cast<Map<String, dynamic>>();
    }
    return [];
  }

  /// GET /api/menu/deals/:id
  Future<Map<String, dynamic>> getDealById(String id) async {
    final response = await _apiClient.get('menu/deals/$id');
    if (response is Map<String, dynamic> && response['data'] is Map) {
      return response['data'] as Map<String, dynamic>;
    }
    throw ApiException('Deal not found with id: $id');
  }

  /// POST /api/menu/deals
  Future<Map<String, dynamic>> createDeal(Map<String, dynamic> dto) async {
    final response = await _apiClient.post('menu/deals', body: dto);
    if (response is Map<String, dynamic> && response['data'] is Map) {
      return response['data'] as Map<String, dynamic>;
    }
    throw const ApiException('Failed to create deal');
  }

  /// PATCH /api/menu/deals/:id
  Future<Map<String, dynamic>> updateDeal(String id, Map<String, dynamic> dto) async {
    final response = await _apiClient.patch('menu/deals/$id', body: dto);
    if (response is Map<String, dynamic> && response['data'] is Map) {
      return response['data'] as Map<String, dynamic>;
    }
    throw const ApiException('Failed to update deal');
  }

  /// DELETE /api/menu/deals/:id
  Future<void> deleteDeal(String id) async {
    await _apiClient.delete('menu/deals/$id');
  }
}
