import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/models/daily_calculation_model.dart';
import '../services/api/api_providers.dart';
import '../services/api/daily_calculation_api_service.dart';
import 'table_repository.dart';
import 'takeaway_repository.dart';
import 'delivery_repository.dart';
import 'pos_repository.dart';
import '../features/reports/reports_providers.dart';

class DailyCalculationState {
  final DailyLiveSummaryModel liveSummary;
  final List<DailyCalculationRecordModel> historyList;
  final DailyCalculationRecordModel? selectedRecord;
  final bool hasActiveSession;
  final double totalChangeCash;
  final double startingCash;
  final List<DailyExpenseItemModel> activeShiftExpenses;
  final double draftCashCounted;
  final double draftCashSubmitted;
  final double draftCashSkimming;
  final String draftClosingNotes;
  final bool isLoading;
  final bool isSubmitting;
  final String? errorMessage;
  final String? successMessage;

  const DailyCalculationState({
    required this.liveSummary,
    this.historyList = const [],
    this.selectedRecord,
    this.hasActiveSession = true, // Default to true until checked
    this.totalChangeCash = 0.0,
    this.startingCash = 0.0,
    this.activeShiftExpenses = const [],
    this.draftCashCounted = 0.0,
    this.draftCashSubmitted = 0.0,
    this.draftCashSkimming = 0.0,
    this.draftClosingNotes = '',
    this.isLoading = false,
    this.isSubmitting = false,
    this.errorMessage,
    this.successMessage,
  });

  DailyCalculationState copyWith({
    DailyLiveSummaryModel? liveSummary,
    List<DailyCalculationRecordModel>? historyList,
    DailyCalculationRecordModel? selectedRecord,
    bool? hasActiveSession,
    double? totalChangeCash,
    double? startingCash,
    List<DailyExpenseItemModel>? activeShiftExpenses,
    double? draftCashCounted,
    double? draftCashSubmitted,
    double? draftCashSkimming,
    String? draftClosingNotes,
    bool? isLoading,
    bool? isSubmitting,
    String? errorMessage,
    String? successMessage,
    bool clearSelected = false,
    bool clearMessages = false,
  }) {
    return DailyCalculationState(
      liveSummary: liveSummary ?? this.liveSummary,
      historyList: historyList ?? this.historyList,
      selectedRecord: clearSelected ? null : (selectedRecord ?? this.selectedRecord),
      hasActiveSession: hasActiveSession ?? this.hasActiveSession,
      totalChangeCash: totalChangeCash ?? this.totalChangeCash,
      startingCash: startingCash ?? this.startingCash,
      activeShiftExpenses: activeShiftExpenses ?? this.activeShiftExpenses,
      draftCashCounted: draftCashCounted ?? this.draftCashCounted,
      draftCashSubmitted: draftCashSubmitted ?? this.draftCashSubmitted,
      draftCashSkimming: draftCashSkimming ?? this.draftCashSkimming,
      draftClosingNotes: draftClosingNotes ?? this.draftClosingNotes,
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearMessages ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearMessages ? null : (successMessage ?? this.successMessage),
    );
  }
}

class DailyCalculationNotifier extends StateNotifier<DailyCalculationState> {
  final DailyCalculationApiService _apiService;
  final Ref _ref;

  DailyCalculationNotifier({
    required DailyCalculationApiService apiService,
    required Ref ref,
  })  : _apiService = apiService,
        _ref = ref,
        super(DailyCalculationState(
          liveSummary: DailyLiveSummaryModel.empty(),
        )) {
    checkActiveSession();
    fetchLiveSummary();
  }

  /// Check if active shift session exists or Starting Cash is needed
  Future<bool> checkActiveSession({String? cashierId}) async {
    try {
      final res = await _apiService.getActiveSession(cashierId: cashierId);
      final hasActive = res['has_active_session'] == true;
      final changeCash = double.tryParse(res['total_change_cash']?.toString() ?? '0') ?? 0.0;
      final startCash = double.tryParse(res['starting_cash']?.toString() ?? '0') ?? 0.0;

      final session = res['session'];
      List<DailyExpenseItemModel> loadedExpenses = state.activeShiftExpenses;
      if (session != null && session['expense_items'] is List) {
        loadedExpenses = (session['expense_items'] as List).map((i) {
          return DailyExpenseItemModel(
            id: i['id']?.toString(),
            itemName: i['item_name']?.toString() ?? '',
            category: i['category']?.toString() ?? 'Kitchen Supplies',
            amount: double.tryParse(i['amount']?.toString() ?? '0') ?? 0.0,
            receiptNumber: i['receipt_number']?.toString(),
            notes: i['notes']?.toString(),
          );
        }).toList();
      }

      state = state.copyWith(
        hasActiveSession: hasActive,
        totalChangeCash: changeCash,
        startingCash: startCash,
        activeShiftExpenses: loadedExpenses,
      );
      return hasActive;
    } catch (_) {
      return true;
    }
  }

  /// Add an expense item to active shift (persisted to database & Riverpod)
  Future<void> addShiftExpense({
    required String itemName,
    required double amount,
    String category = 'Kitchen Supplies',
    String? receiptNumber,
    String? notes,
    String? cashierId,
  }) async {
    try {
      final res = await _apiService.addActiveExpense({
        'item_name': itemName,
        'category': category,
        'amount': amount,
        if (receiptNumber != null) 'receipt_number': receiptNumber,
        if (notes != null) 'notes': notes,
        if (cashierId != null) 'cashier_id': cashierId,
      });

      final newItem = DailyExpenseItemModel(
        id: res['id']?.toString(),
        itemName: itemName,
        category: category,
        amount: amount,
        receiptNumber: receiptNumber,
        notes: notes,
      );

      state = state.copyWith(
        activeShiftExpenses: [...state.activeShiftExpenses, newItem],
      );
    } catch (_) {
      final newItem = DailyExpenseItemModel(
        itemName: itemName,
        category: category,
        amount: amount,
        receiptNumber: receiptNumber,
        notes: notes,
      );
      state = state.copyWith(
        activeShiftExpenses: [...state.activeShiftExpenses, newItem],
      );
    }
  }

  /// Remove an expense item from active shift (deleted from database & Riverpod)
  Future<void> removeShiftExpense(int index) async {
    if (index < 0 || index >= state.activeShiftExpenses.length) return;
    final item = state.activeShiftExpenses[index];
    final updatedList = List<DailyExpenseItemModel>.from(state.activeShiftExpenses)..removeAt(index);
    state = state.copyWith(activeShiftExpenses: updatedList);

    if (item.id != null && item.id!.isNotEmpty) {
      try {
        await _apiService.deleteActiveExpense(item.id!);
      } catch (_) {}
    }
  }

  /// Keep draft input fields synchronized across screen navigation
  void updateDraftInputs({
    double? cashCounted,
    double? cashSubmitted,
    double? cashSkimming,
    String? closingNotes,
  }) {
    state = state.copyWith(
      draftCashCounted: cashCounted ?? state.draftCashCounted,
      draftCashSubmitted: cashSubmitted ?? state.draftCashSubmitted,
      draftCashSkimming: cashSkimming ?? state.draftCashSkimming,
      draftClosingNotes: closingNotes ?? state.draftClosingNotes,
    );
  }

  void clearDraftInputs() {
    state = state.copyWith(
      activeShiftExpenses: [],
      draftCashCounted: 0.0,
      draftCashSubmitted: 0.0,
      draftCashSkimming: 0.0,
      draftClosingNotes: '',
    );
  }

  /// Start Shift Session with Starting Cash / Rolling Balance Adjustment
  Future<bool> startSession({
    required double startingCash,
    String? adjustmentType,
    double? adjustmentAmount,
    String? shiftName,
    String? cashierId,
    String? cashierName,
  }) async {
    state = state.copyWith(isSubmitting: true, clearMessages: true);
    try {
      final payload = {
        'starting_cash': startingCash,
        if (adjustmentType != null) 'adjustment_type': adjustmentType,
        if (adjustmentAmount != null) 'adjustment_amount': adjustmentAmount,
        if (shiftName != null) 'shift_name': shiftName,
        if (cashierId != null) 'cashier_id': cashierId,
        if (cashierName != null) 'cashier_name': cashierName,
      };

      final res = await _apiService.startSession(payload);
      final changeCash = double.tryParse(res['total_change_cash']?.toString() ?? '$startingCash') ?? startingCash;
      final actualStartCash = double.tryParse(res['starting_cash']?.toString() ?? '$changeCash') ?? changeCash;

      state = state.copyWith(
        hasActiveSession: true,
        startingCash: actualStartCash,
        totalChangeCash: changeCash,
        isSubmitting: false,
        successMessage: 'Starting cash registered. Register is now open!',
      );

      // Reload Tables, Takeaway, Delivery, POS and Reports for fresh shift
      try {
        await _ref.read(tableProvider.notifier).loadTables();
      } catch (_) {}
      try {
        await _ref.read(takeawayProvider.notifier).loadTakeawayOrders();
      } catch (_) {}
      try {
        await _ref.read(deliveryProvider.notifier).loadDeliveryData();
      } catch (_) {}
      try {
        _ref.read(posProvider.notifier).resetForNewShift();
      } catch (_) {}
      try {
        _ref.invalidate(reportSummaryProvider);
        _ref.invalidate(reportProductsProvider);
      } catch (_) {}

      await fetchLiveSummary();
      return true;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'Failed to start session: $e',
      );
      return false;
    }
  }

  /// Fetch today's live POS metrics
  Future<void> fetchLiveSummary({String? date, String? cashierId}) async {
    state = state.copyWith(isLoading: true, clearMessages: true);
    try {
      final json = await _apiService.getLiveSummary(date: date, cashierId: cashierId);
      final liveSummary = DailyLiveSummaryModel.fromJson(json);
      state = state.copyWith(
        liveSummary: liveSummary,
        totalChangeCash: liveSummary.totalChangeCash > 0 ? liveSummary.totalChangeCash : state.totalChangeCash,
        startingCash: liveSummary.startingCash > 0 ? liveSummary.startingCash : state.startingCash,
        hasActiveSession: liveSummary.hasActiveSession,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load live summary: $e',
      );
    }
  }

  /// Fetch history for Admin
  Future<void> fetchHistory({
    String? startDate,
    String? endDate,
    String? cashierId,
    String? status,
  }) async {
    state = state.copyWith(isLoading: true, clearMessages: true);
    try {
      final jsonList = await _apiService.listDailyCalculations(
        startDate: startDate,
        endDate: endDate,
        cashierId: cashierId,
        status: status,
      );
      final history = jsonList.map((j) => DailyCalculationRecordModel.fromJson(j)).toList();
      state = state.copyWith(
        historyList: history,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load history: $e',
      );
    }
  }

  /// Submit Day Calculation and execute EOD Store Reset
  Future<DailyCalculationRecordModel?> submitDailyCalculation({
    required double cashSubmitted,
    required double totalCash,
    required double cashSkimming,
    double? startingCash,
    List<DailyExpenseItemModel> expenseItems = const [],
    String? closingNotes,
    String? cashierId,
    String? cashierName,
  }) async {
    state = state.copyWith(isSubmitting: true, clearMessages: true);
    try {
      final payload = {
        'cash_submitted': cashSubmitted,
        'total_cash': totalCash,
        'cash_skimming': cashSkimming,
        'total_cash_submitted': cashSubmitted,
        'starting_cash': startingCash ?? state.startingCash,
        'opening_float': startingCash ?? state.startingCash,
        'expense_items': expenseItems.map((e) => e.toJson()).toList(),
        if (closingNotes != null && closingNotes.isNotEmpty) 'closing_notes': closingNotes,
        if (cashierId != null && cashierId.isNotEmpty) 'cashier_id': cashierId,
        if (cashierName != null && cashierName.isNotEmpty) 'cashier_name': cashierName,
      };

      final response = await _apiService.submitDailyCalculation(payload);
      final record = DailyCalculationRecordModel.fromJson(response);

      // Reset Table, Takeaway, Delivery, POS, and Reports
      try {
        await _ref.read(tableProvider.notifier).loadTables();
      } catch (_) {}
      try {
        _ref.read(takeawayProvider.notifier).resetForNewShift();
        await _ref.read(takeawayProvider.notifier).loadTakeawayOrders();
      } catch (_) {}
      try {
        _ref.read(deliveryProvider.notifier).resetForNewShift();
        await _ref.read(deliveryProvider.notifier).loadDeliveryData();
      } catch (_) {}
      try {
        _ref.read(posProvider.notifier).resetForNewShift();
      } catch (_) {}
      try {
        _ref.invalidate(reportSummaryProvider);
        _ref.invalidate(reportProductsProvider);
      } catch (_) {}

      // Mark active session as closed
      state = state.copyWith(
        hasActiveSession: false,
        isSubmitting: false,
        selectedRecord: record,
        totalChangeCash: 0.0,
        startingCash: 0.0,
        successMessage: 'Daily calculation submitted and shift closed successfully!',
      );

      // Refresh live summary
      await fetchLiveSummary();

      return record;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'Failed to submit calculation: $e',
      );
      return null;
    }
  }
}

final dailyCalculationProvider =
    StateNotifierProvider<DailyCalculationNotifier, DailyCalculationState>((ref) {
  final apiService = ref.watch(dailyCalculationApiServiceProvider);
  return DailyCalculationNotifier(
    apiService: apiService,
    ref: ref,
  );
});
