import 'package:flutter_test/flutter_test.dart';

/// Pure logic helper representing the calculation verified in _PaymentTenderDialog
Map<String, dynamic> calculatePaymentSettlement({
  required double billAmount,
  required double cashTendered,
  required double cardTendered,
  double bankTendered = 0.0,
  double easyPaisaTendered = 0.0,
  double jazzCashTendered = 0.0,
}) {
  final totalPayment = cashTendered + cardTendered + bankTendered + easyPaisaTendered + jazzCashTendered;
  final change = totalPayment - billAmount;

  // MNY-02: Underpayment guard
  final isUnderpaid = billAmount > 0.001 && totalPayment < (billAmount - 0.01);
  if (isUnderpaid) {
    return {
      'isUnderpaid': true,
      'totalPayment': totalPayment,
      'billAmount': billAmount,
      'payments': <Map<String, dynamic>>[],
    };
  }

  final changeDue = change > 0 ? change : 0.0;
  // MNY-03: Scope change returned strictly to cash tendered so net cash matches physical drawer
  final netCash = (cashTendered - changeDue).clamp(0.0, cashTendered);

  final List<Map<String, dynamic>> payments = [];
  if (cashTendered > 0) {
    payments.add({
      'payment_method': 'cash',
      'amount': netCash,
      'tendered_amount': cashTendered,
      'change_returned': changeDue,
    });
  }
  if (cardTendered > 0) {
    payments.add({
      'payment_method': 'card',
      'amount': cardTendered,
      'tendered_amount': cardTendered,
      'change_returned': 0.0,
    });
  }

  return {
    'isUnderpaid': false,
    'totalPayment': totalPayment,
    'billAmount': billAmount,
    'changeDue': changeDue,
    'payments': payments,
  };
}

void main() {
  group('MNY-02 & MNY-03: Payment Tender Settlement Logic Tests', () {
    test('MNY-02: Underpayment is flagged and rejected when total payment is less than bill amount', () {
      final result = calculatePaymentSettlement(
        billAmount: 5000.0,
        cashTendered: 500.0,
        cardTendered: 0.0,
      );

      expect(result['isUnderpaid'], isTrue);
      expect((result['payments'] as List).isEmpty, isTrue);
    });

    test('MNY-02: Exact payment is accepted without underpayment flag', () {
      final result = calculatePaymentSettlement(
        billAmount: 5000.0,
        cashTendered: 5000.0,
        cardTendered: 0.0,
      );

      expect(result['isUnderpaid'], isFalse);
      final payments = result['payments'] as List<Map<String, dynamic>>;
      expect(payments.length, 1);
      expect(payments[0]['amount'], 5000.0);
      expect(payments[0]['change_returned'], 0.0);
    });

    test('MNY-03: Split payment with cash overpayment calculates net cash properly and does not overstate drawer', () {
      // Bill: 2,000. Card: 1,500. Cash note: 1,000. Total tendered: 2,500. Change: 500.
      final result = calculatePaymentSettlement(
        billAmount: 2000.0,
        cashTendered: 1000.0,
        cardTendered: 1500.0,
      );

      expect(result['isUnderpaid'], isFalse);
      expect(result['changeDue'], 500.0);

      final payments = result['payments'] as List<Map<String, dynamic>>;
      expect(payments.length, 2);

      final cashPayment = payments.firstWhere((p) => p['payment_method'] == 'cash');
      final cardPayment = payments.firstWhere((p) => p['payment_method'] == 'card');

      // Net cash must be 500 (1000 tendered - 500 change returned)
      expect(cashPayment['amount'], 500.0);
      expect(cashPayment['tendered_amount'], 1000.0);
      expect(cashPayment['change_returned'], 500.0);

      expect(cardPayment['amount'], 1500.0);
      expect(cardPayment['tendered_amount'], 1500.0);

      // Total recognized revenue across tenders must equal exact bill amount
      final totalRecognized = (cashPayment['amount'] as double) + (cardPayment['amount'] as double);
      expect(totalRecognized, 2000.0);
    });

    test('MNY-03: Pure cash overpayment correctly records net cash and change returned', () {
      final result = calculatePaymentSettlement(
        billAmount: 1450.0,
        cashTendered: 2000.0,
        cardTendered: 0.0,
      );

      expect(result['isUnderpaid'], isFalse);
      expect(result['changeDue'], 550.0);

      final payments = result['payments'] as List<Map<String, dynamic>>;
      expect(payments.length, 1);
      expect(payments[0]['amount'], 1450.0);
      expect(payments[0]['tendered_amount'], 2000.0);
      expect(payments[0]['change_returned'], 550.0);
    });
  });
}
