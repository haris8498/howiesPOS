import re

path = 'c:/flutter/Howies POS/frontend/lib/data/expense_repository.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Remove Mock Initialization
content = content.replace("expenses: MockApiService.getInitialExpenses(),", "expenses: [],")
content = content.replace("super(ExpenseState(", "super(const ExpenseState(")

# 2. Fix loadExpenses
old_load = """  Future<void> loadExpenses() async {
    state = state.copyWith(isLoading: true);
    try {
      final jsonList = await _expensesApiService.listExpenses();
      if (jsonList.isNotEmpty) {
        final list = jsonList.map((j) => ExpenseRecord.fromBackendJson(j)).toList();
        state = state.copyWith(expenses: list, isLoading: false);
        return;
      }
    } catch (_) {}
    state = state.copyWith(isLoading: false);
  }"""
new_load = """  Future<void> loadExpenses() async {
    state = state.copyWith(isLoading: true);
    try {
      final jsonList = await _expensesApiService.listExpenses();
      final list = jsonList.map((j) => ExpenseRecord.fromBackendJson(j)).toList();
      state = state.copyWith(expenses: list, isLoading: false);
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }"""
content = content.replace(old_load, new_load)

# 3. Fix addExpense
old_add = """    try {
      final res = await _expensesApiService.createExpense(
        title: title,
        category: record.toCreateDto()['category']?.toString() ?? 'Miscellaneous',
        amount: amount,
        date: effectiveDate.toIso8601String().split('T')[0],
        note: note,
        recordedBy: recordedBy,
      );
      final created = ExpenseRecord.fromBackendJson(res);
      state = state.copyWith(expenses: [created, ...state.expenses]);
    } catch (_) {
      state = state.copyWith(expenses: [record, ...state.expenses]);
    }"""
new_add = """    final res = await _expensesApiService.createExpense(
      title: title,
      category: record.toCreateDto()['category']?.toString() ?? 'Miscellaneous',
      amount: amount,
      date: effectiveDate.toIso8601String().split('T')[0],
      note: note,
      recordedBy: recordedBy,
    );
    final created = ExpenseRecord.fromBackendJson(res);
    state = state.copyWith(expenses: [created, ...state.expenses]);"""
content = content.replace(old_add, new_add)

# 4. Fix deleteExpense
old_delete = """  Future<void> deleteExpense(String id) async {
    try {
      await _expensesApiService.deleteExpense(id);
    } catch (_) {}
    state = state.copyWith(expenses: state.expenses.where((e) => e.id != id).toList());
  }"""
new_delete = """  Future<void> deleteExpense(String id) async {
    await _expensesApiService.deleteExpense(id);
    state = state.copyWith(expenses: state.expenses.where((e) => e.id != id).toList());
  }"""
content = content.replace(old_delete, new_delete)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
