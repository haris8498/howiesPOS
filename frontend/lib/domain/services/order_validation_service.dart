import '../../core/errors/failures.dart';
import '../../core/result/result.dart';
import '../models/order_model.dart';

/// Pure Domain Service for validating order parameters before creation or checkout
class OrderValidationService {
  const OrderValidationService();

  /// Validate cart state and order parameters
  Result<bool, OrderFailure> validateOrderForCheckout({
    required List<OrderItem> cartItems,
    required OrderType orderType,
    String? tableId,
    String? customerName,
    String? customerPhone,
    String? deliveryAddress,
    PaymentMethod? paymentMethod,
  }) {
    // 1. Cart non-empty validation
    if (cartItems.isEmpty) {
      return const Result.failure(OrderFailure('Order cart cannot be empty.'));
    }

    // 2. Validate line items quantity
    for (final item in cartItems) {
      if (item.quantity <= 0) {
        return Result.failure(OrderFailure('Invalid quantity for ${item.item.name}. Must be at least 1.'));
      }
    }

    // 3. Payment method must be provided
    if (paymentMethod == null) {
      return const Result.failure(OrderFailure('Payment method must be selected to complete checkout.'));
    }

    // 4. Dine-in specific validation
    if (orderType == OrderType.dineIn && (tableId == null || tableId.trim().isEmpty)) {
      // Allowed in quick dine-in or soft warning, but if table is required:
      // return const Result.failure(OrderFailure('Table must be assigned for Dine-In order.'));
    }

    // 5. Delivery specific validation (handles both new 'online' and legacy 'delivery' type)
    if (orderType == OrderType.online || orderType == OrderType.delivery) {
      if (deliveryAddress == null || deliveryAddress.trim().isEmpty) {
        return const Result.failure(OrderFailure('Delivery street address is required for Delivery orders.'));
      }
    }

    return const Result.success(true);
  }
}
