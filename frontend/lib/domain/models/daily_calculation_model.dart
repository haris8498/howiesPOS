class DailyExpenseItemModel {
  final String? id;
  final String itemName;
  final String category;
  final double amount;
  final String? receiptNumber;
  final String? notes;

  const DailyExpenseItemModel({
    this.id,
    required this.itemName,
    this.category = 'Supplies',
    required this.amount,
    this.receiptNumber,
    this.notes,
  });

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'item_name': itemName,
      'category': category,
      'amount': amount,
      if (receiptNumber != null && receiptNumber!.isNotEmpty) 'receipt_number': receiptNumber,
      if (notes != null && notes!.isNotEmpty) 'notes': notes,
    };
  }

  factory DailyExpenseItemModel.fromJson(Map<String, dynamic> json) {
    return DailyExpenseItemModel(
      id: json['id']?.toString(),
      itemName: json['item_name']?.toString() ?? '',
      category: json['category']?.toString() ?? 'Supplies',
      amount: double.tryParse(json['amount']?.toString() ?? '0') ?? 0.0,
      receiptNumber: json['receipt_number']?.toString(),
      notes: json['notes']?.toString(),
    );
  }
}

class DailyLiveSummaryModel {
  final String date;
  final String shiftDate;
  final DateTime? openedAt;
  final String status;
  final double startingCash;
  final double totalChangeCash;
  final bool hasActiveSession;
  final double totalGrossSales;
  final double totalCashSales;
  final double totalCardSales;
  final double totalOnlineSales;
  final double totalDiscounts;
  final double totalTax;
  final int totalOrdersCount;
  final int dineInCount;
  final int takeawayCount;
  final int onlineCount;
  final String? shiftId;
  final String? sessionId;

  const DailyLiveSummaryModel({
    required this.date,
    String? shiftDate,
    this.openedAt,
    this.status = 'OPEN',
    this.startingCash = 0.0,
    this.totalChangeCash = 0.0,
    this.hasActiveSession = false,
    required this.totalGrossSales,
    required this.totalCashSales,
    required this.totalCardSales,
    required this.totalOnlineSales,
    required this.totalDiscounts,
    required this.totalTax,
    required this.totalOrdersCount,
    required this.dineInCount,
    required this.takeawayCount,
    required this.onlineCount,
    this.shiftId,
    this.sessionId,
  }) : shiftDate = shiftDate ?? date;

  factory DailyLiveSummaryModel.fromJson(Map<String, dynamic> json) {
    final rawDate = json['shift_date']?.toString() ?? json['date']?.toString() ?? '';
    final rawStatus = json['status']?.toString() ?? (json['has_active_session'] == true ? 'OPEN' : 'CLOSED');
    final openedAt = json['opened_at'] != null ? DateTime.tryParse(json['opened_at'].toString()) : null;

    return DailyLiveSummaryModel(
      date: rawDate,
      shiftDate: rawDate,
      openedAt: openedAt,
      status: rawStatus,
      startingCash: double.tryParse(json['starting_cash']?.toString() ?? '0') ?? 0.0,
      totalChangeCash: double.tryParse(json['total_change_cash']?.toString() ?? '0') ?? 0.0,
      hasActiveSession: json['has_active_session'] == true,
      totalGrossSales: double.tryParse(json['total_gross_sales']?.toString() ?? '0') ?? 0.0,
      totalCashSales: double.tryParse(json['total_cash_sales']?.toString() ?? '0') ?? 0.0,
      totalCardSales: double.tryParse(json['total_card_sales']?.toString() ?? '0') ?? 0.0,
      totalOnlineSales: double.tryParse(json['total_online_sales']?.toString() ?? '0') ?? 0.0,
      totalDiscounts: double.tryParse(json['total_discounts']?.toString() ?? '0') ?? 0.0,
      totalTax: double.tryParse(json['total_tax']?.toString() ?? '0') ?? 0.0,
      totalOrdersCount: int.tryParse(json['total_orders_count']?.toString() ?? '0') ?? 0,
      dineInCount: int.tryParse(json['dine_in_count']?.toString() ?? '0') ?? 0,
      takeawayCount: int.tryParse(json['takeaway_count']?.toString() ?? '0') ?? 0,
      onlineCount: int.tryParse(json['online_count']?.toString() ?? '0') ?? 0,
      shiftId: json['shift_id']?.toString() ?? json['session_id']?.toString(),
      sessionId: json['session_id']?.toString() ?? json['shift_id']?.toString(),
    );
  }

  factory DailyLiveSummaryModel.empty() {
    return DailyLiveSummaryModel(
      date: DateTime.now().toIso8601String().split('T')[0],
      shiftDate: DateTime.now().toIso8601String().split('T')[0],
      status: 'CLOSED',
      startingCash: 0.0,
      totalChangeCash: 0.0,
      hasActiveSession: false,
      totalGrossSales: 0.0,
      totalCashSales: 0.0,
      totalCardSales: 0.0,
      totalOnlineSales: 0.0,
      totalDiscounts: 0.0,
      totalTax: 0.0,
      totalOrdersCount: 0,
      dineInCount: 0,
      takeawayCount: 0,
      onlineCount: 0,
      shiftId: null,
      sessionId: null,
    );
  }
}

class DailyCalculationRecordModel {
  final String id;
  final DateTime date;
  final String shiftName;
  final String cashierId;
  final String cashierName;
  final double startingCash;
  final double totalChangeCash;
  final double cashSubmitted;
  final double totalCash;
  final double cashSkimming;
  final double totalGrossSales;
  final double totalCashSales;
  final double totalCardSales;
  final double totalOnlineSales;
  final double totalDiscounts;
  final double totalTax;
  final int totalOrdersCount;
  final int dineInCount;
  final int takeawayCount;
  final int onlineCount;
  final double openingFloat;
  final double totalCashSubmitted;
  final double totalCashExpenses;
  final double expectedCashInHand;
  final double varianceAmount;
  final String status;
  final String? closingNotes;
  final DateTime submittedAt;
  final DateTime? createdAt;
  final List<DailyExpenseItemModel> expenseItems;

  const DailyCalculationRecordModel({
    required this.id,
    required this.date,
    required this.shiftName,
    required this.cashierId,
    required this.cashierName,
    this.startingCash = 0.0,
    this.totalChangeCash = 0.0,
    this.cashSubmitted = 0.0,
    this.totalCash = 0.0,
    this.cashSkimming = 0.0,
    required this.totalGrossSales,
    required this.totalCashSales,
    required this.totalCardSales,
    required this.totalOnlineSales,
    required this.totalDiscounts,
    required this.totalTax,
    required this.totalOrdersCount,
    required this.dineInCount,
    required this.takeawayCount,
    required this.onlineCount,
    required this.openingFloat,
    required this.totalCashSubmitted,
    required this.totalCashExpenses,
    required this.expectedCashInHand,
    required this.varianceAmount,
    required this.status,
    this.closingNotes,
    required this.submittedAt,
    this.createdAt,
    this.expenseItems = const [],
  });

  factory DailyCalculationRecordModel.fromJson(Map<String, dynamic> json) {
    final rawExpenses = json['expense_items'] as List<dynamic>? ?? [];
    return DailyCalculationRecordModel(
      id: json['id']?.toString() ?? '',
      date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
      shiftName: json['shift_name']?.toString() ?? 'Full Day',
      cashierId: json['cashier_id']?.toString() ?? '',
      cashierName: json['cashier_name']?.toString() ?? '',
      startingCash: double.tryParse(json['starting_cash']?.toString() ?? '0') ?? 0.0,
      totalChangeCash: double.tryParse(json['total_change_cash']?.toString() ?? '0') ?? 0.0,
      cashSubmitted: double.tryParse(json['cash_submitted']?.toString() ?? json['total_cash_submitted']?.toString() ?? '0') ?? 0.0,
      totalCash: double.tryParse(json['total_cash']?.toString() ?? '0') ?? 0.0,
      cashSkimming: double.tryParse(json['cash_skimming']?.toString() ?? '0') ?? 0.0,
      totalGrossSales: double.tryParse(json['total_gross_sales']?.toString() ?? '0') ?? 0.0,
      totalCashSales: double.tryParse(json['total_cash_sales']?.toString() ?? '0') ?? 0.0,
      totalCardSales: double.tryParse(json['total_card_sales']?.toString() ?? '0') ?? 0.0,
      totalOnlineSales: double.tryParse(json['total_online_sales']?.toString() ?? '0') ?? 0.0,
      totalDiscounts: double.tryParse(json['total_discounts']?.toString() ?? '0') ?? 0.0,
      totalTax: double.tryParse(json['total_tax']?.toString() ?? '0') ?? 0.0,
      totalOrdersCount: int.tryParse(json['total_orders_count']?.toString() ?? '0') ?? 0,
      dineInCount: int.tryParse(json['dine_in_count']?.toString() ?? '0') ?? 0,
      takeawayCount: int.tryParse(json['takeaway_count']?.toString() ?? '0') ?? 0,
      onlineCount: int.tryParse(json['online_count']?.toString() ?? '0') ?? 0,
      openingFloat: double.tryParse(json['opening_float']?.toString() ?? json['starting_cash']?.toString() ?? '0') ?? 0.0,
      totalCashSubmitted: double.tryParse(json['total_cash_submitted']?.toString() ?? json['cash_submitted']?.toString() ?? '0') ?? 0.0,
      totalCashExpenses: double.tryParse(json['total_cash_expenses']?.toString() ?? '0') ?? 0.0,
      expectedCashInHand: double.tryParse(json['expected_cash_in_hand']?.toString() ?? '0') ?? 0.0,
      varianceAmount: double.tryParse(json['variance_amount']?.toString() ?? '0') ?? 0.0,
      status: json['status']?.toString() ?? 'SUBMITTED',
      closingNotes: json['closing_notes']?.toString(),
      submittedAt: DateTime.tryParse(json['submitted_at']?.toString() ?? json['created_at']?.toString() ?? '') ?? DateTime.now(),
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      expenseItems: rawExpenses.map((e) {
        if (e is Map) {
          return DailyExpenseItemModel.fromJson(Map<String, dynamic>.from(e));
        }
        return const DailyExpenseItemModel(itemName: '', amount: 0);
      }).toList(),
    );
  }
}
