import 'package:flutter/material.dart';

/// Centralized catalog and helper for menu items with flavors / sauces / styles.
class MenuFlavorRegistry {
  static final Map<String, List<String>> _flavorCatalog = {
    'classic_pizza': [
      'Fajita Pizza',
      'Chicken Tikka',
      'Malai Boti',
      'Sausage Chesse',
      'Hot & Spicy',
      'Tandoori Bonfire',
    ],
    'modern_pizza': [
      'Ring Pizza',
      'Crown Crust',
      'Peperoni Passion',
      'Doner Kebab',
      'Kebab Stuffer',
      'Cheese Stick',
      'Chicken Stuffer',
    ],
    'special_pizza': [
      'Arabic Crispy',
      'Hungry Cheese Gold Pizza',
    ],
    'mojito': [
      'Blue Berry',
      'Blue Lagoon',
      'Green Apple',
      'Strawberry',
      'Watermelon',
      'Passion Fruit',
    ],
    'smoothie': [
      'Mango',
      'Banana',
      'Strawberry',
      'Peach',
    ],
    'shake': [
      'Chocolate',
      'Vanilla',
      'Strawberry',
      'Oreo',
      'Mango',
      'KitKat',
    ],
    'cold_coffee': [
      'Strawberry',
      'Caramel',
      'Vanilla',
      'Mocha',
      'Dark Chocolate',
    ],
    'mocktail': [
      'Pink Lady',
      'Pina Colada',
      'Zinga Lady',
      'Pineapple (with coconut)',
      'Amazon Blast',
      'Blue Lady Colada',
    ],
    'ice_cream': [
      'Kulfa',
      'Mango',
      'Vanilla',
      'Chocolate',
      'Strawberry',
    ],
    'wings': [
      'Crispy Plain',
      'Peri-Peri',
      'Honey BBQ',
      'Buffalo Hot',
    ],
    'steak': [
      'Tarragon',
      'Mushroom',
      'Twin Steak',
      'Smoked BBQ',
      'Hot Shot Jalapeno',
    ],
  };

  /// Returns available flavors for an item if it requires flavor selection, or empty list if none.
  static List<String> getFlavorsForItem(String rawName, {String? category}) {
    final name = rawName.trim().toLowerCase();
    final cat = (category ?? '').trim().toLowerCase();

    // If the item name already contains a flavor formatted with a hyphen in brackets (e.g. (Small - Fajita)), return empty
    if (RegExp(r'\([^)]+-[^)]+\)').hasMatch(rawName)) {
      return [];
    }

    // 1. Pizza Flavors
    final isPizza = cat.contains('pizza') || name.contains('pizza');
    if (isPizza) {
      if (name.contains('classic')) {
        // If already specifies a flavor in name, skip
        final flavors = _flavorCatalog['classic_pizza']!;
        if (flavors.any((f) => name.contains(f.toLowerCase()))) return [];
        return flavors;
      }
      if (name.contains('modern') || name.contains('modren')) {
        final flavors = _flavorCatalog['modern_pizza']!;
        if (flavors.any((f) => name.contains(f.toLowerCase()))) return [];
        return flavors;
      }
      if (name.contains('special')) {
        final flavors = _flavorCatalog['special_pizza']!;
        if (flavors.any((f) => name.contains(f.toLowerCase()))) return [];
        return flavors;
      }
      // Generic pizza item
      return _flavorCatalog['classic_pizza']!;
    }

    // 2. Mojitos
    if (cat.contains('mojito') || name.contains('mojito')) {
      final flavors = _flavorCatalog['mojito']!;
      if (flavors.any((f) => name.contains(f.toLowerCase()))) return [];
      return flavors;
    }

    // 3. Smoothies
    if (cat.contains('smoothie') || name.contains('smoothie')) {
      final flavors = _flavorCatalog['smoothie']!;
      if (flavors.any((f) => name.contains(f.toLowerCase()))) return [];
      return flavors;
    }

    // 4. Shakes
    if (cat.contains('shake') || name.contains('shake')) {
      final flavors = _flavorCatalog['shake']!;
      if (flavors.any((f) => name.contains(f.toLowerCase()))) return [];
      return flavors;
    }

    // 5. Cold Coffee / Iced Latte
    if (cat.contains('cold-coffee') || cat.contains('cold coffee') || name.contains('iced latte')) {
      final flavors = _flavorCatalog['cold_coffee']!;
      if (flavors.any((f) => name.contains(f.toLowerCase()))) return [];
      return flavors;
    }

    // 6. Mocktails
    if (cat.contains('mocktail') || name.contains('mocktail')) {
      final flavors = _flavorCatalog['mocktail']!;
      if (flavors.any((f) => name.contains(f.toLowerCase()))) return [];
      return flavors;
    }

    // 7. Ice Cream
    if (cat.contains('ice cream') || cat.contains('ice-cream') || name.contains('ice cream')) {
      final flavors = _flavorCatalog['ice_cream']!;
      if (flavors.any((f) => name.contains(f.toLowerCase()))) return [];
      return flavors;
    }

    // 8. Wings
    if (name.contains('wings')) {
      final flavors = _flavorCatalog['wings']!;
      if (flavors.any((f) => name.contains(f.toLowerCase()))) return [];
      return flavors;
    }

    // 9. Generic Chicken Steak
    if (name == 'chicken steak' || name == 'grilled steak') {
      return _flavorCatalog['steak']!;
    }

    return [];
  }

  /// Formats an item title by embedding the flavor into the existing brackets or appending it.
  /// E.g. "Classic Pizza's (Small)" + "Fajita Pizza" -> "Classic Pizza's (Small - Fajita Pizza)"
  /// E.g. "Mojito" + "Blue Lagoon" -> "Mojito (Blue Lagoon)"
  static String formatItemWithFlavor(String originalName, String selectedFlavor) {
    final cleanFlavor = selectedFlavor.trim();
    if (cleanFlavor.isEmpty) return originalName;

    // Check if originalName already has parentheses e.g. (Small), (Medium), (6pcs)
    final sizeRegex = RegExp(r'\(([^)]+)\)$');
    final match = sizeRegex.firstMatch(originalName.trim());

    if (match != null) {
      final innerText = match.group(1)!.trim();
      // If already has hyphen with flavor, don't double append
      if (innerText.contains('-')) {
        return originalName;
      }
      final newInner = '$innerText - $cleanFlavor';
      return originalName.trim().replaceRange(match.start, match.end, '($newInner)');
    }

    // No existing brackets: append flavor in brackets
    return '${originalName.trim()} ($cleanFlavor)';
  }

  /// Helper icon for flavor chips
  static IconData getFlavorIcon(String flavor) {
    final flv = flavor.toLowerCase();
    if (flv.contains('fajita') || flv.contains('spicy') || flv.contains('hot') || flv.contains('peri')) {
      return Icons.local_fire_department_rounded;
    }
    if (flv.contains('tikka') || flv.contains('bbq') || flv.contains('boti') || flv.contains('kebab')) {
      return Icons.outdoor_grill_rounded;
    }
    if (flv.contains('cheese') || flv.contains('stuffer') || flv.contains('crown')) {
      return Icons.star_rounded;
    }
    if (flv.contains('kulfa') || flv.contains('vanilla') || flv.contains('chocolate') || flv.contains('oreo')) {
      return Icons.icecream_rounded;
    }
    if (flv.contains('berry') || flv.contains('apple') || flv.contains('mango') || flv.contains('peach') || flv.contains('melon')) {
      return Icons.eco_rounded;
    }
    return Icons.check_circle_outline_rounded;
  }
}
