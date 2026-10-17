import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../domain/models/expense_model.dart';
import '../services/api/api_providers.dart';
import '../services/api/expenses_api_service.dart';

class ExpenseState {
  final List<ExpenseRecord> expenses;
  final bool isLoading;

  const ExpenseState({
    required this.expenses,
    this.isLoading = false,
  });

  double get totalExpense => expenses.fold(0.0, (sum, e) => sum + e.amount);

  ExpenseState copyWith({
    List<ExpenseRecord>? expenses,
    bool? isLoading,
  }) {
    return ExpenseState(
      expenses: expenses ?? this.expenses,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class ExpenseNotifier extends StateNotifier<ExpenseState> {
  final ExpensesApiService _expensesApiService;

  ExpenseNotifier({ExpensesApiService? expensesApiService})
      : _expensesApiService = expensesApiService ?? ExpensesApiService(),
        super(const ExpenseState(
          expenses: [],
        )) {
    loadExpenses();
  }

  Future<void> loadExpenses() async {
    state = state.copyWith(isLoading: true);
    try {
      final jsonList = await _expensesApiService.listExpenses();
      final list = jsonList.map((j) => ExpenseRecord.fromBackendJson(j)).toList();
      state = state.copyWith(expenses: list, isLoading: false);
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<ExpenseRecord> addExpense({
    required String title,
    required ExpenseCategory category,
    required double amount,
    required String recordedBy,
    DateTime? date,
  }) async {
    final effectiveDate = date ?? DateTime.now();
    final localRecord = ExpenseRecord(
      id: const Uuid().v4(),
      title: title,
      category: category,
      amount: amount,
      date: effectiveDate,
      recordedBy: recordedBy,
    );

    try {
      final res = await _expensesApiService.createExpense(
        title: title,
        category: localRecord.toCreateDto()['category']?.toString() ?? 'Honor Expenses',
        amount: amount,
        date: effectiveDate.toIso8601String().split('T')[0],
        recordedBy: recordedBy,
      );
      final created = ExpenseRecord.fromBackendJson(res);
      state = state.copyWith(
        expenses: [
          created,
          ...state.expenses.where((e) => e.id != created.id && e.id != localRecord.id),
        ],
      );
      return created;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [ExpenseNotifier.addExpense failed to persist in DB]: $e');
      }
      rethrow;
    }
  }

  Future<void> deleteExpense(String id) async {
    await _expensesApiService.deleteExpense(id);
    state = state.copyWith(expenses: state.expenses.where((e) => e.id != id).toList());
  }
}

final expenseProvider = StateNotifierProvider<ExpenseNotifier, ExpenseState>((ref) {
  final expensesApi = ref.watch(expensesApiServiceProvider);
  return ExpenseNotifier(expensesApiService: expensesApi);
});
