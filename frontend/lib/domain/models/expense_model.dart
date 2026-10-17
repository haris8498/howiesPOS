enum ExpenseCategory { utilities, staffSalaries, stockPurchases, maintenance, marketing, honorExpenses, miscellaneous }

class ExpenseRecord {
  final String id;
  final String title;
  final ExpenseCategory category;
  final double amount;
  final DateTime date;
  final String recordedBy;

  const ExpenseRecord({
    required this.id,
    required this.title,
    required this.category,
    required this.amount,
    required this.date,
    required this.recordedBy,
  });

  factory ExpenseRecord.fromBackendJson(Map<String, dynamic> json) {
    ExpenseCategory parsedCategory = ExpenseCategory.miscellaneous;
    final catStr = json['category']?.toString().toLowerCase() ?? '';
    if (catStr.contains('honor') || catStr.contains('owner')) {
      parsedCategory = ExpenseCategory.honorExpenses;
    } else if (catStr.contains('utilit')) {
      parsedCategory = ExpenseCategory.utilities;
    } else if (catStr.contains('salar') || catStr.contains('staff') || catStr.contains('payroll')) {
      parsedCategory = ExpenseCategory.staffSalaries;
    } else if (catStr.contains('stock') || catStr.contains('purchas') || catStr.contains('invent')) {
      parsedCategory = ExpenseCategory.stockPurchases;
    } else if (catStr.contains('maint')) {
      parsedCategory = ExpenseCategory.maintenance;
    } else if (catStr.contains('market') || catStr.contains('ad')) {
      parsedCategory = ExpenseCategory.marketing;
    }

    DateTime parsedDate = DateTime.now();
    if (json['date'] != null) {
      final str = json['date'].toString();
      final datePart = str.split('T')[0];
      final d = DateTime.tryParse(datePart);
      if (d != null) {
        parsedDate = d;
      } else {
        parsedDate = DateTime.tryParse(str) ?? DateTime.now();
      }
    }

    return ExpenseRecord(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      category: parsedCategory,
      amount: double.tryParse(json['amount']?.toString() ?? '0') ?? 0.0,
      date: parsedDate,
      recordedBy: json['recorded_by']?.toString() ?? 'Store Manager',
    );
  }

  Map<String, dynamic> toCreateDto() {
    String catStr = 'Miscellaneous';
    switch (category) {
      case ExpenseCategory.honorExpenses:
        catStr = 'Honor Expenses';
        break;
      case ExpenseCategory.utilities:
        catStr = 'Utilities';
        break;
      case ExpenseCategory.staffSalaries:
        catStr = 'Staff Salaries';
        break;
      case ExpenseCategory.stockPurchases:
        catStr = 'Stock Purchases';
        break;
      case ExpenseCategory.maintenance:
        catStr = 'Maintenance';
        break;
      case ExpenseCategory.marketing:
        catStr = 'Marketing';
        break;
      case ExpenseCategory.miscellaneous:
        catStr = 'Miscellaneous';
        break;
    }

    return {
      'title': title,
      'category': catStr,
      'amount': amount,
      'date': date.toIso8601String().split('T')[0],
      'recorded_by': recordedBy,
    };
  }
}
