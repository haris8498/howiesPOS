import 'package:uuid/uuid.dart';

/// Pure helper to calculate updated table order items after item cancellations.
///
/// Implements partial and full cancellation UI state mapping:
/// - If cancelQty >= current item quantity: marks whole item cancelled.
/// - If 0 < cancelQty < current item quantity: splits into active remaining item
///   and new cancelled item.
/// - If cancelQty <= 0: keeps item unchanged.
List<Map<String, dynamic>> applyTableItemCancellations({
  required List<Map<String, dynamic>> currentOrderItems,
  required Map<String, int> cancelQuantities,
  required String reason,
  required String cancelledBy,
  Map<String, String>? splitItemIds,
}) {
  final result = <Map<String, dynamic>>[];

  for (final item in currentOrderItems) {
    if (item['is_cancelled'] == true || item['is_cancelled'] == 1) {
      result.add(item);
      continue;
    }

    final itemId = item['id']?.toString() ?? '';
    final cancelQty = cancelQuantities[itemId] ?? 0;

    if (cancelQty <= 0) {
      result.add(item);
      continue;
    }

    final currentQty = (item['quantity'] as num?)?.toInt() ??
        int.tryParse(item['quantity']?.toString() ?? '1') ??
        1;

    final price = (item['price'] is num)
        ? (item['price'] as num).toDouble()
        : (double.tryParse(item['price']?.toString() ?? '0') ?? 0.0);

    if (cancelQty >= currentQty) {
      // Full line cancellation
      final copy = Map<String, dynamic>.from(item);
      copy['is_cancelled'] = true;
      copy['cancel_reason'] = reason;
      copy['cancelled_by'] = cancelledBy;
      result.add(copy);
    } else {
      // Partial cancellation: split into remaining active + cancelled entry
      final remainingQty = currentQty - cancelQty;
      final activeCopy = Map<String, dynamic>.from(item);
      activeCopy['quantity'] = remainingQty;
      activeCopy['is_cancelled'] = false;
      if (activeCopy.containsKey('total') || activeCopy['total'] != null) {
        activeCopy['total'] = price * remainingQty;
      }
      result.add(activeCopy);

      final splitCopy = Map<String, dynamic>.from(item);
      final splitId = splitItemIds?[itemId] ?? const Uuid().v7();
      splitCopy['id'] = splitId;
      splitCopy['quantity'] = cancelQty;
      splitCopy['is_cancelled'] = true;
      splitCopy['cancel_reason'] = reason;
      splitCopy['cancelled_by'] = cancelledBy;
      if (splitCopy.containsKey('total') || splitCopy['total'] != null) {
        splitCopy['total'] = price * cancelQty;
      }
      result.add(splitCopy);
    }
  }

  return result;
}

/// Computes the table bill over active (non-cancelled) order items.
double calculateTableBill(List<Map<String, dynamic>> orderItems) {
  double total = 0.0;
  for (final item in orderItems) {
    if (item['is_cancelled'] != true && item['is_cancelled'] != 1) {
      final qty = (item['quantity'] as num?)?.toDouble() ?? 1.0;
      final price = (item['price'] is num)
          ? (item['price'] as num).toDouble()
          : (double.tryParse(item['price']?.toString() ?? '0') ?? 0.0);
      total += (qty * price);
    }
  }
  return total;
}
