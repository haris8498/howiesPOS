import '../../core/network/api_client.dart';
import '../receipt_printer_service.dart';

class OrdersApiService {
  final ApiClient _apiClient;

  OrdersApiService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  /// GET /api/orders
  Future<List<Map<String, dynamic>>> listOrders({
    String? orderType,
    String? orderSource,
    String? status,
    String? paymentStatus,
    bool? isPaid,
    bool? isHeld,
    String? tableId,
    String? customerId,
    String? search,
    int? limit,
    int? offset,
  }) async {
    final params = <String, dynamic>{};
    if (orderType != null) params['order_type'] = orderType;
    if (orderSource != null) params['order_source'] = orderSource;
    if (status != null) params['status'] = status;
    if (paymentStatus != null) params['payment_status'] = paymentStatus;
    if (isPaid != null) params['is_paid'] = isPaid;
    if (isHeld != null) params['is_held'] = isHeld;
    if (tableId != null) params['table_id'] = tableId;
    if (customerId != null) params['customer_id'] = customerId;
    if (search != null) params['search'] = search;
    if (limit != null) params['limit'] = limit;
    if (offset != null) params['offset'] = offset;

    final response = await _apiClient.get('orders', queryParameters: params);
    if (response is Map<String, dynamic> && response['data'] is List) {
      return (response['data'] as List).cast<Map<String, dynamic>>();
    }
    return [];
  }

  /// GET /api/orders/:id
  Future<Map<String, dynamic>> getOrderById(String id) async {
    final response = await _apiClient.get('orders/$id');
    if (response is Map<String, dynamic> && response['data'] is Map) {
      return response['data'] as Map<String, dynamic>;
    }
    throw ApiException('Order not found with id: $id');
  }

  /// POST /api/orders
  Future<Map<String, dynamic>> createOrder(Map<String, dynamic> dto) async {
    final response = await _apiClient.post('orders', body: dto);
    if (response is Map<String, dynamic> && response['data'] is Map) {
      final data = response['data'] as Map<String, dynamic>;
      final orderId = data['id']?.toString();
      final orderNumber = data['order_number']?.toString();
      final tokenNumber = data['token_number']?.toString();
      await ReceiptPrinterService.unmarkOrderKitchenReceiptPrinted(
        orderId: orderId,
        orderNumber: orderNumber,
        tokenNumber: tokenNumber,
      );
      return data;
    }
    throw const ApiException('Failed to create order');
  }

  /// PATCH /api/orders/:id
  Future<Map<String, dynamic>> updateOrder(String id, Map<String, dynamic> dto) async {
    final response = await _apiClient.patch('orders/$id', body: dto);
    if (response is Map<String, dynamic> && response['data'] is Map) {
      final data = response['data'] as Map<String, dynamic>;
      // If items or order structure were modified, reset kitchen receipt print lock so updated KOT can be printed once
      if (dto.containsKey('items') || dto.containsKey('status') || dto.containsKey('subtotal') || dto.containsKey('grand_total')) {
        await ReceiptPrinterService.unmarkOrderKitchenReceiptPrinted(
          orderId: id,
          orderNumber: data['order_number']?.toString(),
          tokenNumber: data['token_number']?.toString(),
        );
      }
      return data;
    }
    throw const ApiException('Failed to update order');
  }

  /// PATCH /api/orders/:id/status
  Future<Map<String, dynamic>> updateOrderStatus(
    String id, {
    required String status,
    String? rejectionReason,
  }) async {
    final body = <String, dynamic>{'status': status};
    if (rejectionReason != null) body['rejection_reason'] = rejectionReason;

    final response = await _apiClient.patch('orders/$id/status', body: body);
    if (response is Map<String, dynamic> && response['data'] is Map) {
      return response['data'] as Map<String, dynamic>;
    }
    throw const ApiException('Failed to update order status');
  }

  /// POST /api/orders/:id/cancel-item
  Future<Map<String, dynamic>> cancelOrderItem(
    String orderId, {
    required String itemId,
    int? cancelQuantity,
    String? reason,
    String? cancelledBy,
  }) async {
    final body = <String, dynamic>{
      'item_id': itemId,
      if (cancelQuantity != null && cancelQuantity > 0) 'cancel_quantity': cancelQuantity,
      'reason': ?reason,
      'cancelled_by': ?cancelledBy,
    };
    final response = await _apiClient.post('orders/$orderId/cancel-item', body: body);
    if (response is Map<String, dynamic> && response['data'] is Map) {
      final data = response['data'] as Map<String, dynamic>;
      // Reset kitchen receipt print lock so kitchen ticket with cancelled items can be printed once
      await ReceiptPrinterService.unmarkOrderKitchenReceiptPrinted(
        orderId: orderId,
        orderNumber: data['order_number']?.toString(),
        tokenNumber: data['token_number']?.toString(),
      );
      return data;
    }
    throw const ApiException('Failed to cancel order item');
  }

  /// POST /api/orders/:id/items (D-05 SYNC-032)
  Future<List<Map<String, dynamic>>> appendOrderItems(String orderId, List<Map<String, dynamic>> items) async {
    final response = await _apiClient.post('orders/$orderId/items', body: {'items': items});
    if (response is Map<String, dynamic> && response['data'] is List) {
      return (response['data'] as List).cast<Map<String, dynamic>>();
    }
    return [];
  }

  /// POST /api/orders/:id/items/:itemId/void (D-05 SYNC-032)
  Future<Map<String, dynamic>> voidOrderItem(
    String orderId,
    String itemId, {
    String? voidedBy,
    String? reason,
  }) async {
    final body = <String, dynamic>{
      'voided_by': ?voidedBy,
      'reason': ?reason,
    };
    final response = await _apiClient.post('orders/$orderId/items/$itemId/void', body: body);
    if (response is Map<String, dynamic> && response['data'] is Map) {
      return response['data'] as Map<String, dynamic>;
    }
    return {};
  }

  /// DELETE /api/orders/:id
  Future<void> deleteOrder(String id) async {
    await _apiClient.delete('orders/$id');
  }
}
