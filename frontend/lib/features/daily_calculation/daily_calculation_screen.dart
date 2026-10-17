import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../config/app_colors.dart';
import '../../data/auth_repository.dart';
import '../../data/daily_calculation_repository.dart';
import 'widgets/starting_cash_dialog.dart';

class DailyCalculationScreen extends ConsumerStatefulWidget {
  const DailyCalculationScreen({super.key});

  @override
  ConsumerState<DailyCalculationScreen> createState() => _DailyCalculationScreenState();
}

class _DailyCalculationScreenState extends ConsumerState<DailyCalculationScreen> {
  final _cashSubmittedController = TextEditingController();
  final _totalCashController = TextEditingController();
  final _cashSkimmingController = TextEditingController();
  final _closingNotesController = TextEditingController();

  double get _cashCounted => double.tryParse(_cashSubmittedController.text.trim()) ?? 0.0;
  double get _cashSubmitted => double.tryParse(_totalCashController.text.trim()) ?? 0.0;
  double get _cashSkimming => double.tryParse(_cashSkimmingController.text.trim()) ?? 0.0;
  double get _totalExpenses {
    final expenses = ref.read(dailyCalculationProvider).activeShiftExpenses;
    return expenses.fold(0.0, (sum, item) => sum + item.amount);
  }

  bool get _isSkimmingMatched => (_cashSkimming - _totalExpenses).abs() < 0.5;
  bool _isRevenueMatched(double systemCashSales) => (_cashSubmitted - (systemCashSales - _totalExpenses)).abs() < 1.0;
  bool _isCountedMatched(double expectedCounted) => (_cashCounted - expectedCounted).abs() < 1.0;

  bool _isReconciliationComplete(double systemCashSales, double startingCash) {
    final expectedCounted = startingCash + systemCashSales;
    final hasEnteredInput = _cashSubmittedController.text.trim().isNotEmpty ||
        _totalCashController.text.trim().isNotEmpty ||
        _cashSubmitted > 0 ||
        _cashCounted > 0;
    return _isSkimmingMatched &&
        _isRevenueMatched(systemCashSales) &&
        _isCountedMatched(expectedCounted) &&
        hasEnteredInput;
  }


  @override
  void initState() {
    super.initState();
    final state = ref.read(dailyCalculationProvider);
    if (state.draftCashCounted > 0) _cashSubmittedController.text = state.draftCashCounted.toStringAsFixed(0);
    if (state.draftCashSubmitted > 0) _totalCashController.text = state.draftCashSubmitted.toStringAsFixed(0);
    if (state.draftCashSkimming > 0) _cashSkimmingController.text = state.draftCashSkimming.toStringAsFixed(0);
    if (state.draftClosingNotes.isNotEmpty) _closingNotesController.text = state.draftClosingNotes;

    _cashSubmittedController.addListener(_onDraftFieldsChanged);
    _totalCashController.addListener(_onDraftFieldsChanged);
    _cashSkimmingController.addListener(_onDraftFieldsChanged);
    _closingNotesController.addListener(_onDraftFieldsChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkSessionAndFetch();
    });
  }

  void _onDraftFieldsChanged() {
    ref.read(dailyCalculationProvider.notifier).updateDraftInputs(
      cashCounted: double.tryParse(_cashSubmittedController.text.trim()) ?? 0.0,
      cashSubmitted: double.tryParse(_totalCashController.text.trim()) ?? 0.0,
      cashSkimming: double.tryParse(_cashSkimmingController.text.trim()) ?? 0.0,
      closingNotes: _closingNotesController.text.trim(),
    );
    setState(() {});
  }

  Future<void> _checkSessionAndFetch() async {
    final authState = ref.read(authProvider);
    final cashierId = authState.currentUser.id;
    await ref.read(dailyCalculationProvider.notifier).fetchLiveSummary(cashierId: cashierId);
    final hasSession = await ref.read(dailyCalculationProvider.notifier).checkActiveSession(cashierId: cashierId);

    if (!hasSession && mounted) {
      StartingCashDialog.show(context, isDismissible: false);
    }
  }

  @override
  void dispose() {
    _cashSubmittedController.removeListener(_onDraftFieldsChanged);
    _totalCashController.removeListener(_onDraftFieldsChanged);
    _cashSkimmingController.removeListener(_onDraftFieldsChanged);
    _closingNotesController.removeListener(_onDraftFieldsChanged);
    _cashSubmittedController.dispose();
    _totalCashController.dispose();
    _cashSkimmingController.dispose();
    _closingNotesController.dispose();
    super.dispose();
  }

  void _addExpenseItem() {
    final nameController = TextEditingController();
    final amountController = TextEditingController();
    final receiptController = TextEditingController();
    String category = 'Kitchen Supplies';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryRed.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.shopping_cart_checkout_rounded, color: AppColors.primaryRed, size: 22),
                ),
                const SizedBox(width: 12),
                const Text('Add Cash Expense / Item', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            content: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Item Name / Description *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      hintText: 'e.g., Fresh Vegetables, Ice Bags, Rider Fuel',
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Category', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: category,
                                  isExpanded: true,
                                  items: const [
                                    DropdownMenuItem(value: 'Kitchen Supplies', child: Text('Kitchen Supplies')),
                                    DropdownMenuItem(value: 'Store Utilities', child: Text('Store Utilities')),
                                    DropdownMenuItem(value: 'Rider Fuel / Delivery', child: Text('Rider Fuel / Delivery')),
                                    DropdownMenuItem(value: 'Maintenance', child: Text('Maintenance')),
                                    DropdownMenuItem(value: 'Miscellaneous', child: Text('Miscellaneous')),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) setDialogState(() => category = val);
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Amount (PKR) *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 6),
                            TextField(
                              controller: amountController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                              decoration: InputDecoration(
                                hintText: '0.00',
                                filled: true,
                                fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryRed,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () async {
                  final name = nameController.text.trim();
                  final amount = double.tryParse(amountController.text.trim()) ?? 0.0;
                  if (name.isNotEmpty && amount > 0) {
                    final authState = ref.read(authProvider);
                    await ref.read(dailyCalculationProvider.notifier).addShiftExpense(
                      itemName: name,
                      category: category,
                      amount: amount,
                      receiptNumber: receiptController.text.trim().isNotEmpty ? receiptController.text.trim() : null,
                      cashierId: authState.currentUser.id,
                    );
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                    }
                  }
                },
                child: const Text('Add Expense'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _submitCalculation(DailyCalculationState calcState) async {
    final live = calcState.liveSummary;

    final double startingCash = calcState.startingCash > 0 ? calcState.startingCash : live.startingCash;
    final double expectedCounted = startingCash + live.totalCashSales;

    if (_cashSubmittedController.text.trim().isEmpty && _totalCashController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter at least Cash Counted or Cash Submitted before submitting.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }


    if (!_isCountedMatched(expectedCounted)) {
      final diff = (expectedCounted - _cashCounted).abs();
      final diffMsg = _cashCounted < expectedCounted
          ? 'Short by PKR ${diff.toStringAsFixed(0)}'
          : 'Excess of PKR ${diff.toStringAsFixed(0)}';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Rule 3 Error: Cash Counted (PKR ${_cashCounted.toStringAsFixed(0)}) must equal System Cash Sales (PKR ${live.totalCashSales.toStringAsFixed(0)}) + Starting Cash (PKR ${startingCash.toStringAsFixed(0)}) = PKR ${expectedCounted.toStringAsFixed(0)}. ($diffMsg)',
          ),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    if (!_isSkimmingMatched) {
      final diff = (_cashSkimming - _totalExpenses).abs();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Rule 1 Error: Cash Skimming (PKR ${_cashSkimming.toStringAsFixed(0)}) must equal Total Expenses (PKR ${_totalExpenses.toStringAsFixed(0)}). Difference: PKR ${diff.toStringAsFixed(0)}',
          ),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    if (!_isRevenueMatched(live.totalCashSales)) {
      final expectedSubmitted = live.totalCashSales - _totalExpenses;
      final diff = (_cashSubmitted - expectedSubmitted).abs();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Rule 2 Error: Cash Submitted (PKR ${_cashSubmitted.toStringAsFixed(0)}) must equal Cash Revenue (PKR ${live.totalCashSales.toStringAsFixed(0)}) - Expenses (PKR ${_totalExpenses.toStringAsFixed(0)}) = PKR ${expectedSubmitted.toStringAsFixed(0)}. Difference: PKR ${diff.toStringAsFixed(0)}',
          ),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF16A34A), size: 28),
            const SizedBox(width: 10),
            const Text('Confirm Daily Close & Submission', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'All calculation rules are verified. Submitting will record shift calculation into PostgreSQL database, reset occupied tables, and refresh the portal.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Column(
                children: [
                  _buildConfirmRow('Total Change Cash:', 'PKR ${calcState.totalChangeCash.toStringAsFixed(0)}'),
                  _buildConfirmRow('1. Cash Counted:', 'PKR ${_cashCounted.toStringAsFixed(0)}'),
                  _buildConfirmRow('2. Cash Submitted:', 'PKR ${_cashSubmitted.toStringAsFixed(0)}'),
                  _buildConfirmRow('3. Cash Skimming:', 'PKR ${_cashSkimming.toStringAsFixed(0)}'),
                  _buildConfirmRow('Total Shift Expenses:', 'PKR ${_totalExpenses.toStringAsFixed(0)}'),
                  _buildConfirmRow('Expected Cash Submitted (Revenue - Expense):', 'PKR ${(live.totalCashSales - _totalExpenses).toStringAsFixed(0)}'),
                  _buildConfirmRow('System Cash Revenue:', 'PKR ${live.totalCashSales.toStringAsFixed(0)}'),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '✓ Double-entry verification passed: Skimming == Expenses and Cash Submitted == Revenue - Expenses.',
              style: TextStyle(fontSize: 11, color: Color(0xFF16A34A), fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('CONFIRM & CLOSE SHIFT', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final authState = ref.read(authProvider);
    final cashierId = authState.currentUser.id;
    final cashierName = authState.currentUser.fullName;

    final record = await ref.read(dailyCalculationProvider.notifier).submitDailyCalculation(
      cashSubmitted: _cashCounted,
      totalCash: _cashSubmitted,
      cashSkimming: _cashSkimming,
      startingCash: calcState.startingCash,
      expenseItems: calcState.activeShiftExpenses,
      closingNotes: _closingNotesController.text.trim(),
      cashierId: cashierId,
      cashierName: cashierName,
    );

    if (record != null && mounted) {
      _cashSubmittedController.clear();
      _totalCashController.clear();
      _cashSkimmingController.clear();
      _closingNotesController.clear();
      ref.read(dailyCalculationProvider.notifier).clearDraftInputs();

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 28),
              const SizedBox(width: 10),
              const Text('Daily Shift Closed Successfully', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Daily calculation for ${DateFormat('dd MMMM yyyy').format(record.date)} has been stored in PostgreSQL database.'),
              const SizedBox(height: 12),
              const Text('The portal is refreshed. When starting the next shift, you will be prompted for Starting Cash float.'),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                // Open Starting cash dialog for next session
                StartingCashDialog.show(context, isDismissible: false);
              },
              child: const Text('START NEXT SHIFT'),
            ),
          ],
        ),
      );
    } else if (mounted) {
      final errorMsg = ref.read(dailyCalculationProvider).errorMessage ?? 'Failed to close shift. Please ensure reconciliation fields are balanced.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg),
          backgroundColor: AppColors.danger,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }


  Widget _buildConfirmRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF1E3A8A))),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1E3A8A))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final calcState = ref.watch(dailyCalculationProvider);
    final live = calcState.liveSummary;

    // Expected Cash = Starting Cash + System Cash Sales - Cash Skimming - Cash Expenses
    final double startingCash = calcState.startingCash > 0 ? calcState.startingCash : live.startingCash;
    final double totalChangeCash = calcState.totalChangeCash > 0 ? calcState.totalChangeCash : startingCash;
    final double expectedCash = startingCash + live.totalCashSales - _cashSkimming - _totalExpenses;

    // Rule 3: Expected Cash Counted = System Cash Sales + Starting Cash Float
    final double expectedCashCounted = startingCash + live.totalCashSales;
    final double countedDiff = _cashCounted - expectedCashCounted;
    final bool isCountedBalanced = _cashCounted > 0 && _isCountedMatched(expectedCashCounted);
    final bool hasEnteredCounted = _cashSubmittedController.text.trim().isNotEmpty;
    final bool isCountedError = !isCountedBalanced;

    String? countedHelperText;
    if (isCountedBalanced) {
      countedHelperText = '✓ Perfect Match: Cash Sales (${live.totalCashSales.toStringAsFixed(0)}) + Start Float (${startingCash.toStringAsFixed(0)}) = PKR ${expectedCashCounted.toStringAsFixed(0)}';
    } else if (hasEnteredCounted && _cashCounted > 0) {
      if (countedDiff < 0) {
        countedHelperText = '⚠️ Short by PKR ${countedDiff.abs().toStringAsFixed(0)} (Expected: PKR ${expectedCashCounted.toStringAsFixed(0)})';
      } else {
        countedHelperText = '⚠️ Cash Excess: Over by PKR ${countedDiff.toStringAsFixed(0)} (Expected: PKR ${expectedCashCounted.toStringAsFixed(0)})';
      }
    } else {
      countedHelperText = '⚠️ Expected: PKR ${expectedCashCounted.toStringAsFixed(0)} (Cash Sales ${live.totalCashSales.toStringAsFixed(0)} + Start Float ${startingCash.toStringAsFixed(0)})';
    }

    // Rule 2: Expected Cash Submitted = System Cash Sales - Total Expenses
    final double expectedCashSubmitted = (live.totalCashSales - _totalExpenses).clamp(0.0, double.infinity);
    final double submittedDiff = _cashSubmitted - expectedCashSubmitted;
    final bool isSubmittedBalanced = _cashSubmitted > 0 && _isRevenueMatched(live.totalCashSales);
    final bool hasEnteredSubmitted = _totalCashController.text.trim().isNotEmpty;
    final bool isSubmittedError = !isSubmittedBalanced;

    String? submittedHelperText;
    if (isSubmittedBalanced) {
      submittedHelperText = '✓ Perfect Match: Revenue (${live.totalCashSales.toStringAsFixed(0)}) - Expenses (${_totalExpenses.toStringAsFixed(0)}) = PKR ${expectedCashSubmitted.toStringAsFixed(0)}';
    } else if (hasEnteredSubmitted && _cashSubmitted > 0) {
      if (submittedDiff < 0) {
        submittedHelperText = '⚠️ Short by PKR ${submittedDiff.abs().toStringAsFixed(0)} (Expected: PKR ${expectedCashSubmitted.toStringAsFixed(0)})';
      } else {
        submittedHelperText = '⚠️ Excess by PKR ${submittedDiff.toStringAsFixed(0)} (Expected: PKR ${expectedCashSubmitted.toStringAsFixed(0)})';
      }
    } else {
      submittedHelperText = '⚠️ Expected: PKR ${expectedCashSubmitted.toStringAsFixed(0)} (Revenue ${live.totalCashSales.toStringAsFixed(0)} - Expenses ${_totalExpenses.toStringAsFixed(0)})';
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: calcState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(22.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Header Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.primaryRed.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.calculate_rounded, color: AppColors.primaryRed, size: 26),
                          ),
                          const SizedBox(width: 14),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'DAILY CALCULATION & CASH MANAGEMENT',
                                style: TextStyle(
                                  color: isDark ? Colors.white : AppColors.textPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Shift date: ${DateFormat('EEEE, dd MMMM yyyy').format(DateTime.tryParse(live.date) ?? DateTime.now())}  •  Cashier Shift',
                                style: TextStyle(
                                  color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF2563EB),
                              side: const BorderSide(color: Color(0xFF2563EB)),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () => StartingCashDialog.show(context, isDismissible: true),
                            icon: const Icon(Icons.edit_note_rounded, size: 16),
                            label: const Text('Adjust Starting Cash', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                          ),
                          const SizedBox(width: 10),
                          IconButton(
                            icon: const Icon(Icons.refresh_rounded, color: AppColors.primaryRed),
                            tooltip: 'Refresh Live Metrics',
                            onPressed: () {
                              final authState = ref.read(authProvider);
                              ref.read(dailyCalculationProvider.notifier).fetchLiveSummary(cashierId: authState.currentUser.id);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // 2. TOP PROMINENT CARD: Total Change Cash Available
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF047857), Color(0xFF10B981)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF10B981).withValues(alpha: 0.25),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 32),
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'TOTAL CHANGE CASH AVAILABLE',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'PKR ${totalChangeCash.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 28,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Starting Cash Float: PKR ${startingCash.toStringAsFixed(0)}  •  Ready for Customer Change & Returns',
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: const [
                              Icon(Icons.lock_open_rounded, color: Colors.white, size: 14),
                              SizedBox(width: 6),
                              Text(
                                'REGISTER ACTIVE',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),

                  // 3. THREE MANDATORY CASHIER INPUT FIELDS
                  Text(
                    'CASHIER CLOSING COUNT & DRAWER RECONCILIATION',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : AppColors.textPrimary,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Field 1: Cash Counted (with dynamic red/green border & deficit message)
                      Expanded(
                        child: _buildInputCard(
                          title: '1. Cash Counted *',
                          subtitle: 'Physical cash in drawer (Revenue + Start)',
                          controller: _cashSubmittedController,
                          icon: Icons.calculate_rounded,
                          iconColor: const Color(0xFF2563EB),
                          bgColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                          isDark: isDark,
                          isValid: isCountedBalanced,
                          isError: isCountedError,
                          helperText: countedHelperText,
                          helperColor: isCountedBalanced ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Field 2: Cash Submitted
                      Expanded(
                        child: _buildInputCard(
                          title: '2. Cash Submitted *',
                          subtitle: 'Cash Sub = Revenue - Expense',
                          controller: _totalCashController,
                          icon: Icons.upload_rounded,
                          iconColor: const Color(0xFF16A34A),
                          bgColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                          isDark: isDark,
                          isValid: isSubmittedBalanced,
                          isError: isSubmittedError,
                          helperText: submittedHelperText,
                          helperColor: isSubmittedBalanced ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Field 3: Cash Skimming
                      Expanded(
                        child: _buildInputCard(
                          title: '3. Cash Skimming *',
                          subtitle: 'Mid-shift cash dropped into safe',
                          controller: _cashSkimmingController,
                          icon: Icons.security_rounded,
                          iconColor: const Color(0xFFD97706),
                          bgColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // 4. Financial Reconciliation Summary & Expenses
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left: Live Financial Calculation Box
                      Expanded(
                        flex: 3,
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: isDark ? const Color(0xFF334155) : AppColors.borderGray),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: const [
                                  Text(
                                    'SHIFT CASH RECONCILIATION SUMMARY',
                                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5),
                                  ),
                                  Icon(Icons.analytics_rounded, size: 18, color: Color(0xFF2563EB)),
                                ],
                              ),
                              const Divider(height: 24),

                              _buildSummaryLine('Total Store Revenue (All Tenders):', 'PKR ${live.totalGrossSales.toStringAsFixed(2)}', isDark, isBold: true),
                              _buildSummaryLine('  • Cash Drawer Sales Today:', 'PKR ${live.totalCashSales.toStringAsFixed(2)}', isDark, isGreen: true),
                              if (live.totalCardSales > 0)
                                _buildSummaryLine('  • Card / POS Machine Sales:', 'PKR ${live.totalCardSales.toStringAsFixed(2)}', isDark),
                              if (live.totalOnlineSales > 0)
                                _buildSummaryLine('  • Online / Bank Transfer Sales:', 'PKR ${live.totalOnlineSales.toStringAsFixed(2)}', isDark),
                              const Divider(height: 16),
                              _buildSummaryLine('(+) Starting Cash Float:', 'PKR ${startingCash.toStringAsFixed(2)}', isDark),
                              _buildSummaryLine('(-) Cash Skimming (Safe Drops):', 'PKR ${_cashSkimming.toStringAsFixed(2)}', isDark, isRed: true),
                              _buildSummaryLine('(-) Total Shift Cash Expenses:', 'PKR ${_totalExpenses.toStringAsFixed(2)}', isDark, isRed: true),
                              
                              const Divider(height: 20),

                              _buildSummaryLine(
                                '(=) Expected Cash in Register:',
                                'PKR ${expectedCash.toStringAsFixed(2)}',
                                isDark,
                                isBold: true,
                              ),
                              _buildSummaryLine(
                                'Actual Cash Declared (${_cashSubmitted > 0 ? 'Cash Submitted' : 'Cash Counted'}):',
                                'PKR ${(_cashSubmitted > 0 ? _cashSubmitted : _cashCounted).toStringAsFixed(2)}',
                                isDark,
                                isBold: true,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Right: Itemized Cash Expenses Box
                      Expanded(
                        flex: 2,
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: isDark ? const Color(0xFF334155) : AppColors.borderGray),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'SHIFT EXPENSES',
                                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5),
                                  ),
                                  TextButton.icon(
                                    onPressed: _addExpenseItem,
                                    icon: const Icon(Icons.add_rounded, size: 16, color: AppColors.primaryRed),
                                    label: const Text('Add Expense', style: TextStyle(color: AppColors.primaryRed, fontWeight: FontWeight.bold, fontSize: 11.5)),
                                  ),
                                ],
                              ),
                              const Divider(height: 16),

                              if (calcState.activeShiftExpenses.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 24.0),
                                  child: Center(
                                    child: Text('No cash expenses recorded for this shift.', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                                  ),
                                )
                              else
                                ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: calcState.activeShiftExpenses.length,
                                  separatorBuilder: (_, index) => const Divider(height: 12),
                                  itemBuilder: (ctx, i) {
                                    final item = calcState.activeShiftExpenses[i];
                                    return Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(item.itemName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                              Text(item.category, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
                                            ],
                                          ),
                                        ),
                                        Text('PKR ${item.amount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: AppColors.danger)),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.danger),
                                          onPressed: () {
                                            ref.read(dailyCalculationProvider.notifier).removeShiftExpense(i);
                                          },
                                        ),
                                      ],
                                    );
                                  },
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // 5. LIVE RECONCILIATION AUDIT & VALIDATION CARD
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _isReconciliationComplete(live.totalCashSales, startingCash)
                            ? const Color(0xFF16A34A).withValues(alpha: 0.5)
                            : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        width: _isReconciliationComplete(live.totalCashSales, startingCash) ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: _isReconciliationComplete(live.totalCashSales, startingCash)
                                        ? const Color(0xFF16A34A).withValues(alpha: 0.15)
                                        : const Color(0xFFD97706).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    _isReconciliationComplete(live.totalCashSales, startingCash)
                                        ? Icons.verified_user_rounded
                                        : Icons.rule_folder_rounded,
                                    size: 20,
                                    color: _isReconciliationComplete(live.totalCashSales, startingCash)
                                        ? const Color(0xFF16A34A)
                                        : const Color(0xFFD97706),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'MANDATORY RECONCILIATION VERIFICATION',
                                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5),
                                    ),
                                    Text(
                                      'All 3 reconciliation conditions must be balanced before shift close',
                                      style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: _isReconciliationComplete(live.totalCashSales, startingCash)
                                    ? const Color(0xFF16A34A).withValues(alpha: 0.12)
                                    : const Color(0xFFDC2626).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: _isReconciliationComplete(live.totalCashSales, startingCash)
                                      ? const Color(0xFF16A34A)
                                      : const Color(0xFFDC2626),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _isReconciliationComplete(live.totalCashSales, startingCash)
                                        ? Icons.check_circle_rounded
                                        : Icons.lock_outline_rounded,
                                    size: 14,
                                    color: _isReconciliationComplete(live.totalCashSales, startingCash)
                                        ? const Color(0xFF16A34A)
                                        : const Color(0xFFDC2626),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _isReconciliationComplete(live.totalCashSales, startingCash)
                                        ? 'ALL RULES BALANCED (READY)'
                                        : 'SUBMISSION LOCKED',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 11,
                                      color: _isReconciliationComplete(live.totalCashSales, startingCash)
                                          ? const Color(0xFF16A34A)
                                          : const Color(0xFFDC2626),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),

                        // Three Validation Rule Cards
                        Row(
                          children: [
                            // Rule 1 Card
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: _isSkimmingMatched
                                      ? const Color(0xFF16A34A).withValues(alpha: 0.08)
                                      : const Color(0xFFDC2626).withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _isSkimmingMatched
                                        ? const Color(0xFF16A34A).withValues(alpha: 0.3)
                                        : const Color(0xFFDC2626).withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          _isSkimmingMatched ? Icons.check_circle_rounded : Icons.cancel_rounded,
                                          size: 16,
                                          color: _isSkimmingMatched ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                                        ),
                                        const SizedBox(width: 6),
                                        const Text('Rule 1: Skim == Expense', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _isSkimmingMatched
                                          ? '✓ PKR ${_cashSkimming.toStringAsFixed(0)} == PKR ${_totalExpenses.toStringAsFixed(0)}'
                                          : '✗ Diff: PKR ${(_cashSkimming - _totalExpenses).abs().toStringAsFixed(0)}',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        color: _isSkimmingMatched ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),

                            // Rule 2 Card
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: _isRevenueMatched(live.totalCashSales)
                                      ? const Color(0xFF16A34A).withValues(alpha: 0.08)
                                      : const Color(0xFFDC2626).withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _isRevenueMatched(live.totalCashSales)
                                        ? const Color(0xFF16A34A).withValues(alpha: 0.3)
                                        : const Color(0xFFDC2626).withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          _isRevenueMatched(live.totalCashSales) ? Icons.check_circle_rounded : Icons.cancel_rounded,
                                          size: 16,
                                          color: _isRevenueMatched(live.totalCashSales) ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                                        ),
                                        const SizedBox(width: 6),
                                        const Text('Rule 2: Sub == Revenue - Exp', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _isRevenueMatched(live.totalCashSales)
                                          ? '✓ PKR ${_cashSubmitted.toStringAsFixed(0)} == Revenue - Expenses'
                                          : '✗ Diff: PKR ${(_cashSubmitted - (live.totalCashSales - _totalExpenses)).abs().toStringAsFixed(0)}',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        color: _isRevenueMatched(live.totalCashSales) ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),

                            // Rule 3 Card (Counted == Cash Sales + Float)
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isCountedBalanced
                                      ? const Color(0xFF16A34A).withValues(alpha: 0.08)
                                      : const Color(0xFFDC2626).withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isCountedBalanced
                                        ? const Color(0xFF16A34A).withValues(alpha: 0.3)
                                        : const Color(0xFFDC2626).withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          isCountedBalanced ? Icons.check_circle_rounded : Icons.cancel_rounded,
                                          size: 16,
                                          color: isCountedBalanced ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                                        ),
                                        const SizedBox(width: 6),
                                        const Text('Rule 3: Count == Cash Sales+Float', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      isCountedBalanced
                                          ? '✓ PKR ${_cashCounted.toStringAsFixed(0)} == PKR ${expectedCashCounted.toStringAsFixed(0)}'
                                          : (countedDiff < 0
                                              ? '✗ Short by PKR ${countedDiff.abs().toStringAsFixed(0)}'
                                              : '✗ Over by PKR ${countedDiff.toStringAsFixed(0)}'),
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        color: isCountedBalanced ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 6. Submit Button Bar
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : AppColors.borderGray),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _isReconciliationComplete(live.totalCashSales, startingCash)
                                  ? Icons.check_circle_outline_rounded
                                  : Icons.info_outline_rounded,
                              size: 18,
                              color: _isReconciliationComplete(live.totalCashSales, startingCash)
                                  ? const Color(0xFF16A34A)
                                  : const Color(0xFFD97706),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _isReconciliationComplete(live.totalCashSales, startingCash)
                                  ? 'All calculation rules satisfied. Ready to close daily shift.'
                                  : 'Ensure Counted == Rev+Float, Skimming == Expenses, and Cash Submitted == Revenue - Expenses.',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark ? const Color(0xFFCBD5E1) : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isReconciliationComplete(live.totalCashSales, startingCash)
                                ? const Color(0xFF16A34A)
                                : const Color(0xFF94A3B8),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                            elevation: _isReconciliationComplete(live.totalCashSales, startingCash) ? 4 : 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: calcState.isSubmitting
                              ? null
                              : () => _submitCalculation(calcState),
                          icon: calcState.isSubmitting
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : Icon(
                                  _isReconciliationComplete(live.totalCashSales, startingCash) ? Icons.lock_clock_rounded : Icons.save_rounded,
                                  size: 20,
                                ),
                          label: Text(
                            calcState.isSubmitting
                                ? 'SUBMITTING...'
                                : (_isReconciliationComplete(live.totalCashSales, startingCash)
                                    ? 'SUBMIT DAILY CALCULATION & CLOSE SHIFT'
                                    : 'VERIFY CALCULATIONS TO CLOSE'),
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildInputCard({
    required String title,
    required String subtitle,
    required TextEditingController controller,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required bool isDark,
    bool? isValid,
    bool? isError,
    String? helperText,
    Color? helperColor,
  }) {
    Color borderColor = isDark ? const Color(0xFF334155) : AppColors.borderGray;
    if (isValid == true) {
      borderColor = const Color(0xFF16A34A);
    } else if (isError == true) {
      borderColor = const Color(0xFFDC2626);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: borderColor,
          width: (isValid == true || isError == true) ? 2.0 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (isValid == true ? const Color(0xFF16A34A) : (isError == true ? const Color(0xFFDC2626) : iconColor)).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isValid == true ? Icons.check_circle_rounded : (isError == true ? Icons.warning_amber_rounded : icon),
                  color: isValid == true ? const Color(0xFF16A34A) : (isError == true ? const Color(0xFFDC2626) : iconColor),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
                    Text(subtitle, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
              color: isValid == true ? const Color(0xFF16A34A) : (isError == true ? const Color(0xFFDC2626) : null),
            ),
            decoration: InputDecoration(
              prefixText: 'PKR  ',
              prefixStyle: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: isValid == true ? const Color(0xFF16A34A) : (isError == true ? const Color(0xFFDC2626) : AppColors.textSecondary),
              ),
              hintText: '0.00',
              filled: true,
              fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: borderColor,
                  width: (isValid == true || isError == true) ? 2.0 : 1.0,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: isValid == true ? const Color(0xFF16A34A) : (isError == true ? const Color(0xFFDC2626) : AppColors.primaryRed),
                  width: 2,
                ),
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          if (helperText != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: (helperColor ?? const Color(0xFFDC2626)).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                helperText,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: helperColor ?? const Color(0xFFDC2626),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryLine(String label, String value, bool isDark, {bool isGreen = false, bool isRed = false, bool isBold = false}) {
    Color valColor = isDark ? Colors.white : AppColors.textPrimary;
    if (isGreen) valColor = const Color(0xFF16A34A);
    if (isRed) valColor = const Color(0xFFDC2626);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w500,
              color: isDark ? const Color(0xFFCBD5E1) : AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isBold ? 13.5 : 12,
              fontWeight: isBold ? FontWeight.w900 : FontWeight.w700,
              color: valColor,
            ),
          ),
        ],
      ),
    );
  }
}
