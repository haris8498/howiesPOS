import 'package:intl/intl.dart';

/// Supported Currency Codes in the POS system
enum CurrencyCode {
  pkr('PKR', 'PKR ', true),
  usd('USD', 'PKR ', false);

  final String code;
  final String symbol;
  final bool isPrefixWithSpace;

  const CurrencyCode(this.code, this.symbol, this.isPrefixWithSpace);
}

/// Immutable Money value object for precise monetary calculations.
/// Stores amounts with standard double/cent precision and encapsulates formatting.
class Money {
  final double amount;
  final CurrencyCode currency;

  const Money(this.amount, {this.currency = CurrencyCode.pkr});

  static const Money zero = Money(0.0);

  Money operator +(Money other) {
    _assertSameCurrency(other);
    return Money(amount + other.amount, currency: currency);
  }

  Money operator -(Money other) {
    _assertSameCurrency(other);
    final result = amount - other.amount;
    return Money(result > 0 ? result : 0.0, currency: currency);
  }

  Money operator *(num multiplier) {
    return Money(amount * multiplier, currency: currency);
  }

  void _assertSameCurrency(Money other) {
    if (currency != other.currency) {
      throw ArgumentError('Cannot perform arithmetic between ${currency.code} and ${other.currency.code}');
    }
  }

  /// Format money consistently for UI presentation
  String format({bool showDecimals = false}) {
    final formatter = NumberFormat(showDecimals ? '#,##0.00' : '#,##0');
    final formattedNum = formatter.format(amount);
    if (currency == CurrencyCode.pkr) {
      return 'PKR $formattedNum';
    } else {
      return 'PKR $formattedNum';
    }
  }

  @override
  String toString() => format(showDecimals: true);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Money && runtimeType == other.runtimeType && amount == other.amount && currency == other.currency;

  @override
  int get hashCode => amount.hashCode ^ currency.hashCode;
}
