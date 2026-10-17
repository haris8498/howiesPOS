import '../models/menu_item.dart';
import '../models/order_model.dart';

/// Configurable tax and fee policy for the restaurant
class PricingPolicy {
  final double dineInTaxPercentage;
  final double taxPercentage;
  final double serviceChargePercentage;
  final double standardDeliveryFee;
  final Map<String, double> sizePriceModifiers;
  final double toppingUnitPrice;

  const PricingPolicy({
    this.dineInTaxPercentage = 0.0,
    this.taxPercentage = 0.0,
    this.serviceChargePercentage = 0.0,
    this.standardDeliveryFee = 4.99,
    this.sizePriceModifiers = const {
      'Regular': 0.0,
      'Medium': 2.0,
      'Large': 5.0,
      'Extra Large': 8.0,
      'Single Patty': 0.0,
      'Double Patty': 3.5,
    },
    this.toppingUnitPrice = 1.50,
  });

  /// Effective dine-in tax rate (%): uses taxPercentage if set, otherwise dineInTaxPercentage
  double get effectiveDineInTaxRate => taxPercentage > 0 ? taxPercentage : dineInTaxPercentage;
}

/// Breakdown of all calculated totals for an order or cart
class PriceBreakdown {
  final double subtotal;
  final double discountPercentage;
  final double discountAmount;
  final double taxableSubtotal;
  final double taxAmount;
  final double serviceChargeAmount;
  final double deliveryFee;
  final double grandTotal;

  const PriceBreakdown({
    required this.subtotal,
    this.discountPercentage = 0.0,
    required this.discountAmount,
    required this.taxableSubtotal,
    required this.taxAmount,
    required this.serviceChargeAmount,
    required this.deliveryFee,
    required this.grandTotal,
  });
}

/// Pure Domain Pricing Engine that executes all financial calculations
/// independently of Flutter widgets or Riverpod state.
class PricingEngine {
  final PricingPolicy policy;

  const PricingEngine({this.policy = const PricingPolicy()});

  /// Calculate unit price for a single menu item with size and toppings
  double calculateItemUnitPrice({
    required MenuItem item,
    String selectedSize = 'Large',
    List<String> extraToppings = const [],
  }) {
    double price = item.basePrice;
    final sizeAdjustment = policy.sizePriceModifiers[selectedSize] ?? 0.0;
    price += sizeAdjustment;
    price += extraToppings.length * policy.toppingUnitPrice;
    return price;
  }

  /// Calculate total line price for an order item
  double calculateLineTotal(OrderItem orderItem) {
    final unitPrice = calculateItemUnitPrice(
      item: orderItem.item,
      selectedSize: orderItem.selectedSize,
      extraToppings: orderItem.extraToppings,
    );
    return unitPrice * orderItem.quantity;
  }

  /// Compute full price breakdown for a cart or order
  PriceBreakdown calculateOrderTotals({
    required List<OrderItem> items,
    required OrderType orderType,
    double discountPercentage = 0.0,
    double discountAmount = 0.0,
    double? customDeliveryFee,
    double? customDineInTaxPercentage,
  }) {
    final subtotal = items.fold<double>(
      0.0,
      (sum, item) => sum + calculateLineTotal(item),
    );

    double effectivePercentage = discountPercentage;
    double effectiveDiscount = discountAmount;

    if (discountPercentage > 0) {
      effectiveDiscount = subtotal * (discountPercentage / 100);
    } else if (discountAmount > 0 && subtotal > 0) {
      effectivePercentage = (discountAmount / subtotal) * 100;
    }

    if (effectiveDiscount > subtotal) {
      effectiveDiscount = subtotal;
    }

    final taxableSubtotal = (subtotal - effectiveDiscount) > 0 ? (subtotal - effectiveDiscount) : 0.0;

    final isDineIn = orderType == OrderType.dineIn || orderType == OrderType.quickOrder;

    // Dine In Tax applies ONLY to Dine-In orders
    final taxRate = customDineInTaxPercentage ?? policy.effectiveDineInTaxRate;
    final taxAmount = isDineIn ? taxableSubtotal * (taxRate / 100) : 0.0;

    final serviceChargeAmount = isDineIn
        ? taxableSubtotal * (policy.serviceChargePercentage / 100)
        : 0.0;

    final deliveryFee =
        (orderType == OrderType.online || orderType == OrderType.delivery)
            ? (customDeliveryFee ?? policy.standardDeliveryFee)
            : 0.0;

    final grandTotal = taxableSubtotal + taxAmount + serviceChargeAmount + deliveryFee;

    return PriceBreakdown(
      subtotal: subtotal,
      discountPercentage: effectivePercentage,
      discountAmount: effectiveDiscount,
      taxableSubtotal: taxableSubtotal,
      taxAmount: taxAmount,
      serviceChargeAmount: serviceChargeAmount,
      deliveryFee: deliveryFee,
      grandTotal: grandTotal,
    );
  }
}
