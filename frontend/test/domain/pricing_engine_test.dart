import 'package:flutter_test/flutter_test.dart';
import 'package:hungry_howies_pos/domain/models/menu_item.dart';
import 'package:hungry_howies_pos/domain/models/order_model.dart';
import 'package:hungry_howies_pos/domain/services/pricing_engine.dart';

void main() {
  group('PricingEngine Domain Tests', () {
    const testPizza = MenuItem(
      id: 'p1',
      name: 'Howie Special Pizza',
      category: 'Pizza',
      description: 'Pepperoni & Cheese',
      basePrice: 15.00,
      imageUrl: 'https://example.com/pizza.jpg',
    );

    const pricingEngine = PricingEngine(
      policy: PricingPolicy(
        taxPercentage: 10.0,
        serviceChargePercentage: 5.0,
        standardDeliveryFee: 4.00,
        sizePriceModifiers: {
          'Medium': 2.00,
          'Large': 5.00,
          'Extra Large': 8.00,
        },
        toppingUnitPrice: 1.50,
      ),
    );

    test('calculates correct unit price with size and toppings', () {
      final unitPrice = pricingEngine.calculateItemUnitPrice(
        item: testPizza,
        selectedSize: 'Large', // +5.00
        extraToppings: ['Extra Cheese', 'Mushrooms'], // +3.00
      );

      // Base 15 + Size 5 + Toppings 3 = 23.00
      expect(unitPrice, equals(23.00));
    });

    test('calculates Dine-In order totals with tax and service charge', () {
      final cart = [
        const OrderItem(
          item: testPizza,
          quantity: 2,
          selectedSize: 'Medium', // 15 + 2 = 17 * 2 = 34.00
          extraToppings: [],
        ),
      ];

      final breakdown = pricingEngine.calculateOrderTotals(
        items: cart,
        orderType: OrderType.dineIn,
        discountAmount: 4.00,
      );

      // Subtotal: 34.00
      expect(breakdown.subtotal, equals(34.00));
      // Discount: 4.00
      expect(breakdown.discountAmount, equals(4.00));
      // Taxable: 30.00
      expect(breakdown.taxableSubtotal, equals(30.00));
      // Tax 10% of 30: 3.00
      expect(breakdown.taxAmount, equals(3.00));
      // Service Charge 5% of 30: 1.50
      expect(breakdown.serviceChargeAmount, equals(1.50));
      // Delivery fee: 0.0
      expect(breakdown.deliveryFee, equals(0.0));
      // Grand total: 30 + 3 + 1.5 = 34.50
      expect(breakdown.grandTotal, equals(34.50));
    });

    test('calculates Delivery order totals with delivery fee and zero tax / service charge', () {
      final cart = [
        const OrderItem(
          item: testPizza,
          quantity: 1,
          selectedSize: 'Large', // 15 + 5 = 20.00
          extraToppings: [],
        ),
      ];

      final breakdown = pricingEngine.calculateOrderTotals(
        items: cart,
        orderType: OrderType.delivery,
        discountAmount: 0.0,
      );

      // Subtotal: 20.00
      expect(breakdown.subtotal, equals(20.00));
      // Tax is ONLY for Dine-In, so 0.0 for Delivery
      expect(breakdown.taxAmount, equals(0.0));
      // Service charge on delivery: 0.0
      expect(breakdown.serviceChargeAmount, equals(0.0));
      // Delivery fee: 4.00
      expect(breakdown.deliveryFee, equals(4.00));
      // Grand total: 20 + 0 + 4 = 24.00
      expect(breakdown.grandTotal, equals(24.00));
    });

    test('calculates Takeaway order totals with zero tax and zero delivery fee', () {
      final cart = [
        const OrderItem(
          item: testPizza,
          quantity: 1,
          selectedSize: 'Large', // 20.00
          extraToppings: [],
        ),
      ];

      final breakdown = pricingEngine.calculateOrderTotals(
        items: cart,
        orderType: OrderType.takeAway,
        discountAmount: 0.0,
      );

      expect(breakdown.subtotal, equals(20.00));
      expect(breakdown.taxAmount, equals(0.0));
      expect(breakdown.serviceChargeAmount, equals(0.0));
      expect(breakdown.deliveryFee, equals(0.0));
      expect(breakdown.grandTotal, equals(20.00));
    });

    test('calculates percentage discount accurately across subtotal and total bill', () {
      final cart = [
        const OrderItem(
          item: testPizza,
          quantity: 2,
          selectedSize: 'Large', // 20.00 * 2 = 40.00
          extraToppings: [],
        ),
      ];

      // 15% discount on 40.00 = 6.00 discount
      final breakdown = pricingEngine.calculateOrderTotals(
        items: cart,
        orderType: OrderType.takeAway,
        discountPercentage: 15.0,
      );

      expect(breakdown.subtotal, equals(40.00));
      expect(breakdown.discountPercentage, equals(15.0));
      expect(breakdown.discountAmount, equals(6.00));
      expect(breakdown.taxableSubtotal, equals(34.00));
      expect(breakdown.grandTotal, equals(34.00));
    });
  });
}
