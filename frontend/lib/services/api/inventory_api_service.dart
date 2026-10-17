import '../../core/network/api_client.dart';

class InventoryApiService {
  final ApiClient _apiClient;

  InventoryApiService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  /// GET /api/inventory/items
  Future<List<Map<String, dynamic>>> listItems({
    String? category,
    String? search,
    bool? lowStockOnly,
  }) async {
    final params = <String, dynamic>{};
    if (category != null && category.isNotEmpty && category != 'All') {
      params['category'] = category;
    }
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (lowStockOnly != null) params['low_stock_only'] = lowStockOnly;

    final response = await _apiClient.get('inventory/items', queryParameters: params);
    if (response is Map<String, dynamic> && response['data'] is List) {
      return (response['data'] as List)
          .map((i) => i is Map<String, dynamic> ? i : Map<String, dynamic>.from(i as Map))
          .toList();
    }
    return [];
  }

  /// GET /api/inventory/items/low-stock
  Future<List<Map<String, dynamic>>> getLowStockItems() async {
    final response = await _apiClient.get('inventory/items/low-stock');
    if (response is Map<String, dynamic> && response['data'] is List) {
      return (response['data'] as List)
          .map((i) => i is Map<String, dynamic> ? i : Map<String, dynamic>.from(i as Map))
          .toList();
    }
    return [];
  }

  /// GET /api/inventory/items/:id
  Future<Map<String, dynamic>> getItemById(String id) async {
    final response = await _apiClient.get('inventory/items/$id');
    if (response is Map<String, dynamic> && response['data'] is Map) {
      return Map<String, dynamic>.from(response['data'] as Map);
    }
    throw ApiException('Inventory item not found with id: $id');
  }

  /// POST /api/inventory/items
  Future<Map<String, dynamic>> createItem(Map<String, dynamic> dto) async {
    final response = await _apiClient.post('inventory/items', body: dto);
    if (response is Map<String, dynamic> && response['data'] is Map) {
      return Map<String, dynamic>.from(response['data'] as Map);
    }
    throw const ApiException('Failed to create inventory item');
  }

  /// PATCH /api/inventory/items/:id
  Future<Map<String, dynamic>> updateItem(String id, Map<String, dynamic> dto) async {
    final response = await _apiClient.patch('inventory/items/$id', body: dto);
    if (response is Map<String, dynamic> && response['data'] is Map) {
      return Map<String, dynamic>.from(response['data'] as Map);
    }
    throw const ApiException('Failed to update inventory item');
  }

  /// DELETE /api/inventory/items/:id
  Future<void> deleteItem(String id) async {
    await _apiClient.delete('inventory/items/$id');
  }

  /// POST /api/inventory/stock-in
  Future<Map<String, dynamic>> stockIn({
    required String itemId,
    required double quantity,
    double? costImpact,
    String? reason,
    String? supplierName,
  }) async {
    final body = <String, dynamic>{
      'item_id': itemId,
      'quantity': quantity,
    };
    if (costImpact != null) body['cost_impact'] = costImpact;
    if (reason != null) body['reason'] = reason;
    if (supplierName != null) body['supplier_name'] = supplierName;

    final response = await _apiClient.post('inventory/stock-in', body: body);
    if (response is Map<String, dynamic> && response['data'] is Map) {
      return Map<String, dynamic>.from(response['data'] as Map);
    }
    throw const ApiException('Failed to process stock in');
  }

  /// POST /api/inventory/stock-out
  Future<Map<String, dynamic>> stockOut({
    required String itemId,
    required double quantity,
    String movementType = 'stockOut',
    String? reason,
  }) async {
    final body = <String, dynamic>{
      'item_id': itemId,
      'quantity': quantity,
      'movement_type': movementType,
    };
    if (reason != null) body['reason'] = reason;

    final response = await _apiClient.post('inventory/stock-out', body: body);
    if (response is Map<String, dynamic> && response['data'] is Map) {
      return Map<String, dynamic>.from(response['data'] as Map);
    }
    throw const ApiException('Failed to process stock out');
  }

  /// GET /api/inventory/movements
  Future<List<Map<String, dynamic>>> listMovements({
    String? itemId,
    String? movementType,
  }) async {
    final params = <String, dynamic>{};
    if (itemId != null) params['item_id'] = itemId;
    if (movementType != null) params['movement_type'] = movementType;

    final response = await _apiClient.get('inventory/movements', queryParameters: params);
    if (response is Map<String, dynamic> && response['data'] is List) {
      return (response['data'] as List)
          .map((i) => i is Map<String, dynamic> ? i : Map<String, dynamic>.from(i as Map))
          .toList();
    }
    return [];
  }
}
