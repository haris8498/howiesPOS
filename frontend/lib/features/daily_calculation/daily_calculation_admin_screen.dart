import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../config/app_colors.dart';
import '../../data/daily_calculation_repository.dart';
import '../../data/expense_repository.dart';
import '../../domain/models/daily_calculation_model.dart';
import '../../domain/models/expense_model.dart';

class DailyCalculationAdminScreen extends ConsumerStatefulWidget {
  const DailyCalculationAdminScreen({super.key});

  @override
  ConsumerState<DailyCalculationAdminScreen> createState() => _DailyCalculationAdminScreenState();
}

class _DailyCalculationAdminScreenState extends ConsumerState<DailyCalculationAdminScreen> {
  DateTimeRange? _selectedDateRange;
  String _activePreset = 'All';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(dailyCalculationProvider.notifier).fetchHistory();
    });
  }

  void _applyPreset(String preset) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    DateTime? start;
    DateTime? end;

    if (preset == 'All') {
      setState(() {
        _activePreset = 'All';
        _selectedDateRange = null;
      });
      ref.read(dailyCalculationProvider.notifier).fetchHistory();
      return;
    } else if (preset == 'Today') {
      start = today;
      end = today;
    } else if (preset == 'Yesterday') {
      final y = today.subtract(const Duration(days: 1));
      start = y;
      end = y;
    } else if (preset == 'This Week') {
      final monday = today.subtract(Duration(days: today.weekday - 1));
      start = monday;
      end = today;
    } else if (preset == 'This Month') {
      start = DateTime(now.year, now.month, 1);
      end = today;
    }

    if (start != null && end != null) {
      setState(() {
        _activePreset = preset;
        _selectedDateRange = DateTimeRange(start: start!, end: end!);
      });
      final startStr = start.toIso8601String().split('T')[0];
      final endStr = end.toIso8601String().split('T')[0];
      ref.read(dailyCalculationProvider.notifier).fetchHistory(startDate: startStr, endDate: endStr);
    }
  }

  void _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _selectedDateRange ??
          DateTimeRange(
            start: DateTime.now().subtract(const Duration(days: 7)),
            end: DateTime.now(),
          ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.primaryRed,
                  onPrimary: Colors.white,
                ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _activePreset = 'Custom';
        _selectedDateRange = picked;
      });
      final start = picked.start.toIso8601String().split('T')[0];
      final end = picked.end.toIso8601String().split('T')[0];
      ref.read(dailyCalculationProvider.notifier).fetchHistory(startDate: start, endDate: end);
    }
  }

  void _showDetailModal(DailyCalculationRecordModel record) {
    final currencyFormatter = NumberFormat('#,##0.00', 'en_US');
    final dateFormatter = DateFormat('dd MMM yyyy, hh:mm a');
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final changeCash = record.totalChangeCash > 0 ? record.totalChangeCash : record.openingFloat;
    final submittedCash = record.cashSubmitted > 0 ? record.cashSubmitted : record.totalCashSubmitted;
    final drawerCash = record.totalCash > 0
        ? record.totalCash
        : (record.totalCashSales + changeCash - record.totalCashExpenses);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryRed.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.analytics_rounded, color: AppColors.primaryRed, size: 22),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Daily Settlement Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                    Text(DateFormat('EEEE, dd MMMM yyyy').format(record.date), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ],
        ),
        content: SizedBox(
          width: 620,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Financial Summary Box
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      _row('Cashier / Submitted By:', record.cashierName),
                      _row('Submitted At:', dateFormatter.format(record.submittedAt)),
                      _row('Total Orders:', '${record.totalOrdersCount} (Dine: ${record.dineInCount} | Take: ${record.takeawayCount} | Online: ${record.onlineCount})'),
                      const Divider(height: 16),
                      _row('Starting Cash (Shift Float):', 'PKR ${currencyFormatter.format(record.startingCash > 0 ? record.startingCash : record.openingFloat)}'),
                      _row('Total Change Cash Available:', 'PKR ${currencyFormatter.format(changeCash)}', color: Colors.teal),
                      const Divider(height: 16),
                      _row('Total Store Revenue:', 'PKR ${currencyFormatter.format(record.totalGrossSales)}', color: const Color(0xFF7C3AED), isBold: true),
                      _row('Cash Sales Collected:', 'PKR ${currencyFormatter.format(record.totalCashSales)}', color: Colors.green, isBold: true),
                      _row('Card & Digital Sales:', 'PKR ${currencyFormatter.format(record.totalCardSales + record.totalOnlineSales)}'),
                      _row('Cash Expenses Used:', '- PKR ${currencyFormatter.format(record.totalCashExpenses)}', color: Colors.orange),
                      const Divider(height: 16),
                      _row('Total Cash in Drawer:', 'PKR ${currencyFormatter.format(drawerCash)}'),
                      _row('Cash Skimming / Safe Drop:', 'PKR ${currencyFormatter.format(record.cashSkimming)}', color: Colors.blueAccent),
                      _row('Cash Submitted to Owner:', 'PKR ${currencyFormatter.format(submittedCash)}', isBold: true, color: AppColors.primaryRed),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Itemized Expenses Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.receipt_long_rounded, size: 18, color: Colors.orange),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Itemized Cash Expenses (${record.expenseItems.length})',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        'Total: PKR ${currencyFormatter.format(record.totalCashExpenses)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.orange),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                if (record.expenseItems.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                    child: const Center(
                      child: Text('No itemized cash expenses entered for this shift.', style: TextStyle(color: Colors.grey, fontSize: 13)),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: record.expenseItems.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, idx) {
                      final exp = record.expenseItems[idx];
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Wrap(
                                    spacing: 8,
                                    runSpacing: 4,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEDE9FE),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          exp.category.isNotEmpty ? exp.category : 'General Expense',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? Colors.purple[200] : const Color(0xFF6B21A8),
                                          ),
                                        ),
                                      ),
                                      if (exp.receiptNumber != null && exp.receiptNumber!.trim().isNotEmpty)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE0F2FE),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.tag_rounded, size: 11, color: isDark ? Colors.lightBlueAccent : const Color(0xFF0369A1)),
                                              const SizedBox(width: 2),
                                              Text(
                                                'Slip #${exp.receiptNumber}',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: isDark ? Colors.lightBlueAccent : const Color(0xFF0369A1),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Text(
                                  'PKR ${currencyFormatter.format(exp.amount)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange, fontSize: 14),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              exp.itemName.isNotEmpty ? exp.itemName : 'Expense item',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                            if (exp.notes != null && exp.notes!.trim().isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.6) : Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(Icons.notes_rounded, size: 13, color: Colors.grey[500]),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        exp.notes!.trim(),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark ? Colors.grey[300] : Colors.grey[700],
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),

                if (record.closingNotes != null && record.closingNotes!.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  const Text('Cashier Closing Notes:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                    child: Text(record.closingNotes!, style: const TextStyle(fontSize: 13)),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: isBold ? FontWeight.bold : FontWeight.w600, color: color)),
        ],
      ),
    );
  }

  Widget _buildPresetPill(String label, bool isDark) {
    final isSelected = _activePreset == label;
    return InkWell(
      onTap: () => _applyPreset(label),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryRed
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected
                ? Colors.white
                : (isDark ? Colors.grey[300] : Colors.grey[700]),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterBar(bool isDark, DateFormat dateFormatter) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildPresetPill('All', isDark),
          _buildPresetPill('Today', isDark),
          _buildPresetPill('Yesterday', isDark),
          _buildPresetPill('This Week', isDark),
          _buildPresetPill('This Month', isDark),
          _buildCustomPill(isDark, dateFormatter),
        ],
      ),
    );
  }

  Widget _buildCustomPill(bool isDark, DateFormat dateFormatter) {
    final isSelected = _activePreset == 'Custom' && _selectedDateRange != null;
    String customLabel = 'Custom Range';
    if (isSelected) {
      final start = _selectedDateRange!.start;
      final end = _selectedDateRange!.end;
      if (start.year == end.year) {
        customLabel = '${DateFormat('dd MMM').format(start)} - ${DateFormat('dd MMM yyyy').format(end)}';
      } else {
        customLabel = '${dateFormatter.format(start)} - ${dateFormatter.format(end)}';
      }
    }

    return InkWell(
      onTap: _pickDateRange,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryRed
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.date_range_rounded,
              size: 13,
              color: isSelected
                  ? Colors.white
                  : (isDark ? Colors.grey[300] : Colors.grey[700]),
            ),
            const SizedBox(width: 4),
            Text(
              customLabel,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.grey[300] : Colors.grey[700]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddExpenseModal(BuildContext context) {
    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    ExpenseCategory category = ExpenseCategory.honorExpenses;
    DateTime recordDate = DateTime.now();

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setModalState) {
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
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.account_balance_wallet_rounded, color: AppColors.primaryRed, size: 20),
                ),
                const SizedBox(width: 10),
                const Text('Add Expense', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
              ],
            ),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: titleCtrl,
                      decoration: InputDecoration(
                        labelText: 'Expense Description *',
                        hintText: 'e.g. Owner Drawings / Repair / Petty Cash',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Amount (PKR) *',
                        prefixText: 'PKR ',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<ExpenseCategory>(
                      initialValue: category,
                      decoration: InputDecoration(
                        labelText: 'Expense Category',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      items: ExpenseCategory.values.map((c) {
                        final label = c == ExpenseCategory.honorExpenses
                            ? 'HONOR EXPENSES'
                            : c.name.toUpperCase();
                        return DropdownMenuItem(value: c, child: Text(label));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() => category = val);
                        }
                      },
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Date: ${DateFormat('dd MMM yyyy').format(recordDate)}',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.calendar_month_rounded, size: 16),
                          label: const Text('Change Date'),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: recordDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                            );
                            if (picked != null) {
                              setModalState(() => recordDate = picked);
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryRed,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () async {
                  final title = titleCtrl.text.trim();
                  final amount = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                  if (title.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter an expense description'), backgroundColor: AppColors.danger),
                    );
                    return;
                  }
                  if (amount <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter a valid amount greater than 0'), backgroundColor: AppColors.danger),
                    );
                    return;
                  }

                  try {
                    await ref.read(expenseProvider.notifier).addExpense(
                          title: title,
                          category: category,
                          amount: amount,
                          recordedBy: 'Admin / Owner',
                          date: recordDate,
                        );
                    if (context.mounted) {
                      Navigator.pop(dialogCtx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("Expense '$title' added and stored in honor expenses successfully!"),
                          backgroundColor: const Color(0xFF16A34A),
                        ),
                      );
                      ref.read(dailyCalculationProvider.notifier).fetchHistory();
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to add expense: $e'), backgroundColor: AppColors.danger),
                      );
                    }
                  }
                },
                child: const Text('SAVE EXPENSE'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dailyCalculationProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currencyFormatter = NumberFormat('#,##0.00', 'en_US');
    final dateFormatter = DateFormat('dd MMM yyyy');

    final totalGrossSales = state.historyList.fold(0.0, (sum, r) => sum + r.totalGrossSales);
    final totalCashSales = state.historyList.fold(0.0, (sum, r) => sum + r.totalCashSales);
    final totalSubmitted = state.historyList.fold(0.0, (sum, r) => sum + (r.cashSubmitted > 0 ? r.cashSubmitted : r.totalCashSubmitted));
    final totalExpenses = state.historyList.fold(0.0, (sum, r) => sum + r.totalCashExpenses);
    final totalSkimming = state.historyList.fold(0.0, (sum, r) => sum + r.cashSkimming);

    final iconWidget = Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.primaryRed.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.analytics_rounded, color: AppColors.primaryRed, size: 24),
    );

    final auditBadge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.visibility_rounded, size: 12, color: Colors.blue),
          SizedBox(width: 4),
          Text(
            'VIEW ONLY AUDIT',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );

    final addExpenseButton = ElevatedButton.icon(
      icon: const Icon(Icons.add_rounded, size: 18),
      label: const Text('Add Expense', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryRed,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 1,
      ),
      onPressed: () => _showAddExpenseModal(context),
    );

    final refreshButton = IconButton(
      icon: const Icon(Icons.refresh_rounded, size: 20),
      tooltip: 'Refresh Records',
      style: IconButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: () => _applyPreset(_activePreset),
    );

    return Scaffold(
      body: Column(
        children: [
          // Header Bar with Responsive Layout to Prevent Any Overflow
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                  width: 1.5,
                ),
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 1060;

                if (isWide) {
                  return Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            iconWidget,
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          'DAILY CALCULATIONS & EOD AUDIT',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: isDark ? Colors.white : AppColors.textPrimary,
                                            letterSpacing: 0.5,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      auditBadge,
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'Date-wise register closures, cashier submissions & itemized expenses',
                                    style: TextStyle(fontSize: 12, color: Colors.grey),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      _buildFilterBar(isDark, dateFormatter),
                      const SizedBox(width: 8),
                      addExpenseButton,
                      const SizedBox(width: 8),
                      refreshButton,
                    ],
                  );
                } else {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          iconWidget,
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        'DAILY CALCULATIONS & EOD AUDIT',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? Colors.white : AppColors.textPrimary,
                                          letterSpacing: 0.5,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    auditBadge,
                                  ],
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'Date-wise register closures, cashier submissions & itemized expenses',
                                  style: TextStyle(fontSize: 11.5, color: Colors.grey),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          addExpenseButton,
                          const SizedBox(width: 8),
                          refreshButton,
                        ],
                      ),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: _buildFilterBar(isDark, dateFormatter),
                      ),
                    ],
                  );
                }
              },
            ),
          ),
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // KPI Cards (Gross Sales & Variance Removed)
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isWide = constraints.maxWidth >= 1050;
                            if (isWide) {
                              return Row(
                                children: [
                                  Expanded(
                                    child: _kpiCard(
                                      title: 'Total Closures',
                                      value: '${state.historyList.length} Days',
                                      icon: Icons.calendar_month_rounded,
                                      color: Colors.blue,
                                      isDark: isDark,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _kpiCard(
                                      title: 'Total Store Revenue',
                                      value: 'PKR ${currencyFormatter.format(totalGrossSales)}',
                                      icon: Icons.monetization_on_rounded,
                                      color: const Color(0xFF7C3AED),
                                      isDark: isDark,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _kpiCard(
                                      title: 'Total Cash Sales',
                                      value: 'PKR ${currencyFormatter.format(totalCashSales)}',
                                      icon: Icons.payments_rounded,
                                      color: Colors.green,
                                      isDark: isDark,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _kpiCard(
                                      title: 'Total Cash Submitted',
                                      value: 'PKR ${currencyFormatter.format(totalSubmitted)}',
                                      icon: Icons.point_of_sale_rounded,
                                      color: AppColors.primaryRed,
                                      isDark: isDark,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _kpiCard(
                                      title: 'Total Skimming',
                                      value: 'PKR ${currencyFormatter.format(totalSkimming)}',
                                      icon: Icons.savings_rounded,
                                      color: Colors.blueAccent,
                                      isDark: isDark,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _kpiCard(
                                      title: 'Total Cash Expenses',
                                      value: 'PKR ${currencyFormatter.format(totalExpenses)}',
                                      icon: Icons.shopping_bag_rounded,
                                      color: Colors.orange,
                                      isDark: isDark,
                                    ),
                                  ),
                                ],
                              );
                            } else {
                              final itemsPerRow = constraints.maxWidth < 600 ? 1 : (constraints.maxWidth < 850 ? 2 : 3);
                              final cardWidth = (constraints.maxWidth - (itemsPerRow - 1) * 12) / itemsPerRow;
                              return Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  SizedBox(
                                    width: cardWidth,
                                    child: _kpiCard(
                                      title: 'Total Closures',
                                      value: '${state.historyList.length} Days',
                                      icon: Icons.calendar_month_rounded,
                                      color: Colors.blue,
                                      isDark: isDark,
                                    ),
                                  ),
                                  SizedBox(
                                    width: cardWidth,
                                    child: _kpiCard(
                                      title: 'Total Store Revenue',
                                      value: 'PKR ${currencyFormatter.format(totalGrossSales)}',
                                      icon: Icons.monetization_on_rounded,
                                      color: const Color(0xFF7C3AED),
                                      isDark: isDark,
                                    ),
                                  ),
                                  SizedBox(
                                    width: cardWidth,
                                    child: _kpiCard(
                                      title: 'Total Cash Sales',
                                      value: 'PKR ${currencyFormatter.format(totalCashSales)}',
                                      icon: Icons.payments_rounded,
                                      color: Colors.green,
                                      isDark: isDark,
                                    ),
                                  ),
                                  SizedBox(
                                    width: cardWidth,
                                    child: _kpiCard(
                                      title: 'Total Cash Submitted',
                                      value: 'PKR ${currencyFormatter.format(totalSubmitted)}',
                                      icon: Icons.point_of_sale_rounded,
                                      color: AppColors.primaryRed,
                                      isDark: isDark,
                                    ),
                                  ),
                                  SizedBox(
                                    width: cardWidth,
                                    child: _kpiCard(
                                      title: 'Total Skimming',
                                      value: 'PKR ${currencyFormatter.format(totalSkimming)}',
                                      icon: Icons.savings_rounded,
                                      color: Colors.blueAccent,
                                      isDark: isDark,
                                    ),
                                  ),
                                  SizedBox(
                                    width: cardWidth,
                                    child: _kpiCard(
                                      title: 'Total Cash Expenses',
                                      value: 'PKR ${currencyFormatter.format(totalExpenses)}',
                                      icon: Icons.shopping_bag_rounded,
                                      color: Colors.orange,
                                      isDark: isDark,
                                    ),
                                  ),
                                ],
                              );
                            }
                          },
                        ),

                        const SizedBox(height: 20),

                        // History Table
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                          ),
                          child: state.historyList.isEmpty
                              ? Container(
                                  padding: const EdgeInsets.symmetric(vertical: 60),
                                  child: const Center(
                                    child: Column(
                                      children: [
                                        Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey),
                                        SizedBox(height: 12),
                                        Text('No daily calculation records found for selected period.', style: TextStyle(color: Colors.grey, fontSize: 15)),
                                      ],
                                    ),
                                  ),
                                )
                              : SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: DataTable(
                                    headingRowColor: WidgetStateProperty.all(
                                      isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                    ),
                                    columns: const [
                                      DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('Cashier', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('Total Revenue', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('Change Cash', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('Cash Sales', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('Cash Submitted', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('Total Cash', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('Skimming', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('Expenses', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                                    ],
                                    rows: state.historyList.map((rec) {
                                      final changeCash = rec.totalChangeCash > 0 ? rec.totalChangeCash : rec.openingFloat;
                                      final submitted = rec.cashSubmitted > 0 ? rec.cashSubmitted : rec.totalCashSubmitted;
                                      final totalCash = rec.totalCash > 0
                                          ? rec.totalCash
                                          : (rec.totalCashSales + changeCash - rec.totalCashExpenses);

                                      return DataRow(
                                        cells: [
                                          DataCell(Text(dateFormatter.format(rec.date), style: const TextStyle(fontWeight: FontWeight.bold))),
                                          DataCell(Text(rec.cashierName)),
                                          DataCell(Text('PKR ${currencyFormatter.format(rec.totalGrossSales)}', style: const TextStyle(color: Color(0xFF7C3AED), fontWeight: FontWeight.bold))),
                                          DataCell(Text('PKR ${currencyFormatter.format(changeCash)}', style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.w600))),
                                          DataCell(Text('PKR ${currencyFormatter.format(rec.totalCashSales)}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w600))),
                                          DataCell(Text('PKR ${currencyFormatter.format(submitted)}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryRed))),
                                          DataCell(Text('PKR ${currencyFormatter.format(totalCash)}')),
                                          DataCell(Text('PKR ${currencyFormatter.format(rec.cashSkimming)}', style: const TextStyle(color: Colors.blueAccent))),
                                          DataCell(Text('PKR ${currencyFormatter.format(rec.totalCashExpenses)}', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.w600))),
                                          DataCell(
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: Colors.green.withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                rec.status,
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.green),
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            ElevatedButton.icon(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: AppColors.primaryRed,
                                                foregroundColor: Colors.white,
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                              ),
                                              icon: const Icon(Icons.visibility_rounded, size: 15),
                                              label: const Text('View Breakdown', style: TextStyle(fontSize: 12)),
                                              onPressed: () => _showDetailModal(rec),
                                            ),
                                          ),
                                        ],
                                      );
                                    }).toList(),
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _kpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 11.5, color: Colors.grey, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Icon(icon, color: color, size: 18),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
