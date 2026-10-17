import '../models/order_model.dart';

/// Ingredient requirement definition for a menu item recipe
class RecipeIngredientRequirement {
  final String ingredientNameMatch;
  final double quantityPerUnit;
  final String unit;

  const RecipeIngredientRequirement({
    required this.ingredientNameMatch,
    required this.quantityPerUnit,
    required this.unit,
  });
}

/// Pure domain service defining recipe bill of materials (BOM) resolution
class RecipeService {
  const RecipeService();

  /// Resolve raw ingredient requirements for an ordered item
  List<RecipeIngredientRequirement> getRequirementsForOrderItem(OrderItem orderItem) {
    final cat = orderItem.item.category.toLowerCase();
    final name = orderItem.item.name.toLowerCase();
    final requirements = <RecipeIngredientRequirement>[];

    if (cat.contains('pizza')) {
      double doughQty = 0.25; // kg
      double cheeseQty = 0.15; // kg
      double sauceQty = 0.08; // kg

      if (orderItem.selectedSize == 'Medium') {
        doughQty = 0.35;
        cheeseQty = 0.20;
      } else if (orderItem.selectedSize == 'Large') {
        doughQty = 0.45;
        cheeseQty = 0.28;
      } else if (orderItem.selectedSize == 'Extra Large') {
        doughQty = 0.60;
        cheeseQty = 0.35;
      }

      requirements.add(RecipeIngredientRequirement(ingredientNameMatch: 'Pizza Dough Flour', quantityPerUnit: doughQty, unit: 'kg'));
      requirements.add(RecipeIngredientRequirement(ingredientNameMatch: 'Mozzarella Cheese Blend', quantityPerUnit: cheeseQty, unit: 'kg'));
      requirements.add(RecipeIngredientRequirement(ingredientNameMatch: 'Signature Pizza Sauce', quantityPerUnit: sauceQty, unit: 'kg'));

      if (name.contains('meat') || name.contains('pepperoni')) {
        requirements.add(const RecipeIngredientRequirement(ingredientNameMatch: 'Spicy Pepperoni Slices', quantityPerUnit: 0.10, unit: 'kg'));
      }
    } else if (cat.contains('burger')) {
      requirements.add(const RecipeIngredientRequirement(ingredientNameMatch: 'Sesame & Brioche Buns', quantityPerUnit: 1.0, unit: 'pcs'));
      requirements.add(const RecipeIngredientRequirement(ingredientNameMatch: 'Angus Beef Patties', quantityPerUnit: 1.0, unit: 'pcs'));
    } else if (cat.contains('fries')) {
      requirements.add(const RecipeIngredientRequirement(ingredientNameMatch: 'Frozen Potato Fries', quantityPerUnit: 0.20, unit: 'kg'));
      requirements.add(const RecipeIngredientRequirement(ingredientNameMatch: 'Cajun Seasoning Mix', quantityPerUnit: 0.02, unit: 'kg'));
    } else if (cat.contains('drink') || cat.contains('beverage')) {
      requirements.add(const RecipeIngredientRequirement(ingredientNameMatch: 'Pepsi & Soft Drinks Cans', quantityPerUnit: 1.0, unit: 'cans'));
    }

    return requirements;
  }
}

/// Domain engine for executing stock deductions against inventory item lists
class StockDeductionEngine {
  final RecipeService recipeService;

  const StockDeductionEngine({this.recipeService = const RecipeService()});

  /// Calculate updated inventory items and movement ledger records for a batch of order items
  Map<String, double> calculateTotalIngredientRequirements(List<OrderItem> orderItems) {
    final totals = <String, double>{};

    for (final orderItem in orderItems) {
      final reqs = recipeService.getRequirementsForOrderItem(orderItem);
      for (final req in reqs) {
        final totalNeeded = req.quantityPerUnit * orderItem.quantity;
        totals[req.ingredientNameMatch] = (totals[req.ingredientNameMatch] ?? 0.0) + totalNeeded;
      }
    }

    return totals;
  }
}
