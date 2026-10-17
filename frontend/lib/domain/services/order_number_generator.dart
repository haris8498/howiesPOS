import 'package:intl/intl.dart';

/// Abstract Contract for Order and Token numbering
abstract class IOrderNumberGenerator {
  /// Generates a unique, chronological order number (e.g. HH-260925-1042)
  String generateOrderNumber();

  /// Generates a takeaway token sequence string (e.g. TK-101)
  String generateTakeawayToken({int? currentCounter});

  /// Generates a unique UUID identifier
  String generateUniqueId();
}

/// Robust Default Implementation of Order Number Generator.
/// Generates chronological, collision-resistant order numbers based on daily sequence and timestamp.
class OrderNumberGenerator implements IOrderNumberGenerator {
  int _dailySequence = 1000;

  OrderNumberGenerator({int initialSequence = 1000}) : _dailySequence = initialSequence;

  @override
  String generateOrderNumber() {
    _dailySequence++;
    final datePrefix = DateFormat('yyMMdd').format(DateTime.now());
    return 'HH-$datePrefix-$_dailySequence';
  }

  @override
  String generateTakeawayToken({int? currentCounter}) {
    final counter = currentCounter ?? (_dailySequence % 1000 + 100);
    return 'TK-$counter';
  }

  @override
  String generateUniqueId() {
    return 'ord_${DateTime.now().microsecondsSinceEpoch}';
  }
}
