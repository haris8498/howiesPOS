import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/app_colors.dart';
import '../../data/auth_repository.dart';
import '../../data/expense_repository.dart';
import '../../data/role_rights_repository.dart';
import '../../domain/models/expense_model.dart';
import '../../domain/models/user_role.dart';
import '../../services/expense_export_service.dart';
import '../../shared/widgets/glass_card.dart';

class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
  DateTime? _selectedDate = DateTime.now();

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatDate(DateTime dt) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${dt.day.toString().padLeft(2, '0')} ${months[dt.month - 1]} ${dt.year}';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(expenseProvider.notifier).loadExpenses();
    });
  }

  @override
  Widget build(BuildContext context) {
    final expState = ref.watch(expenseProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Filter expenses by selected date if set
    final filteredExpenses = expState.expenses.where((e) {
      if (_selectedDate == null) return true;
      return _isSameDay(e.date, _selectedDate!);
    }).toList();

    final filteredTotal = filteredExpenses.fold(0.0, (sum, e) => sum + e.amount);

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // Calendar & Action Bar Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'EXPENSE MANAGEMENT & P&L LOG',
                    style: TextStyle(
                      color: isDark ? Colors.white : AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _selectedDate == null
                        ? 'Showing expenses for ALL DATES'
                        : 'Filter by calendar date: ${_formatDate(_selectedDate!)}',
                    style: TextStyle(
                      color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  // 1. Export Excel (.CSV) Button (Direct Action)
                  InkWell(
                    onTap: () async {
                      final listToExport = filteredExpenses.isNotEmpty ? filteredExpenses : expState.expenses;

                      if (listToExport.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('No expense records available to export!'), backgroundColor: AppColors.danger),
                        );
                        return;
                      }

                      final success = await ExpenseExportService.exportToExcelCsv(
                        expenses: listToExport,
                        selectedDate: _selectedDate,
                      );

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(success ? 'Expense Excel (.CSV) exported successfully!' : 'Failed to export Excel file.'),
                            backgroundColor: success ? const Color(0xFF16A34A) : AppColors.danger,
                          ),
                        );
                      }
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF107C41),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF107C41).withValues(alpha: 0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.table_chart_rounded, size: 17, color: Colors.white),
                          SizedBox(width: 6),
                          Text(
                            'EXPORT EXCEL',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // 2. Export PDF Button (Direct Action)
                  InkWell(
                    onTap: () async {
                      final listToExport = filteredExpenses.isNotEmpty ? filteredExpenses : expState.expenses;

                      if (listToExport.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('No expense records available to export!'), backgroundColor: AppColors.danger),
                        );
                        return;
                      }

                      final success = await ExpenseExportService.exportToPdf(
                        expenses: listToExport,
                        selectedDate: _selectedDate,
                      );

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(success ? 'Expense PDF report generated successfully!' : 'Failed to generate PDF report.'),
                            backgroundColor: success ? const Color(0xFF16A34A) : AppColors.danger,
                          ),
                        );
                      }
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE11D48),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFE11D48).withValues(alpha: 0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.picture_as_pdf_rounded, size: 17, color: Colors.white),
                          SizedBox(width: 6),
                          Text(
                            'EXPORT PDF',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // 3. Add Expense Record Button
                  Builder(
                    builder: (context) {
                      final role = ref.watch(authProvider).currentUser.role;
                      final canAddExpense = ref.watch(roleRightsProvider).isActionGranted(
                        role,
                        'expenses_add',
                        defaultIfMissing: role != UserRole.cashier,
                      );
                      if (!canAddExpense) return const SizedBox.shrink();

                      return ElevatedButton.icon(
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Add Expense Record'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryRed,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => _showAddExpenseModal(context, ref),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Top Calendar / Date Selector Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryRed.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.calendar_month_rounded, color: AppColors.primaryRed, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  _selectedDate == null
                      ? 'Selected Date: All Dates'
                      : 'Selected Date: ${_formatDate(_selectedDate!)}',
                  style: TextStyle(
                    color: isDark ? Colors.white : AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(width: 14),
                // Open Calendar Date Picker Button
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setState(() {
                        _selectedDate = picked;
                      });
                    }
                  },
                  icon: const Icon(Icons.edit_calendar_rounded, size: 16, color: AppColors.primaryRed),
                  label: const Text('Pick Date', style: TextStyle(fontSize: 12, color: AppColors.primaryRed, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.primaryRed),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
                const Spacer(),
                // Quick Date Filter Chips
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Today'),
                      selected: _selectedDate != null && _isSameDay(_selectedDate!, DateTime.now()),
                      onSelected: (_) {
                        setState(() {
                          _selectedDate = DateTime.now();
                        });
                      },
                      selectedColor: AppColors.primaryRed,
                      labelStyle: TextStyle(
                        color: _selectedDate != null && _isSameDay(_selectedDate!, DateTime.now()) ? Colors.white : (isDark ? Colors.white : AppColors.textPrimary),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    ChoiceChip(
                      label: const Text('Yesterday'),
                      selected: _selectedDate != null && _isSameDay(_selectedDate!, DateTime.now().subtract(const Duration(days: 1))),
                      onSelected: (_) {
                        setState(() {
                          _selectedDate = DateTime.now().subtract(const Duration(days: 1));
                        });
                      },
                      selectedColor: AppColors.primaryRed,
                      labelStyle: TextStyle(
                        color: _selectedDate != null && _isSameDay(_selectedDate!, DateTime.now().subtract(const Duration(days: 1))) ? Colors.white : (isDark ? Colors.white : AppColors.textPrimary),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    ChoiceChip(
                      label: const Text('All Dates'),
                      selected: _selectedDate == null,
                      onSelected: (_) {
                        setState(() {
                          _selectedDate = null;
                        });
                      },
                      selectedColor: AppColors.primaryRed,
                      labelStyle: TextStyle(
                        color: _selectedDate == null ? Colors.white : (isDark ? Colors.white : AppColors.textPrimary),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // 2-Column Table Header & List Content
          Expanded(
            child: GlassCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  // 2-Column Header Bar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                      border: Border(
                        bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                    ),
                    child: Row(
                      children: [
                        // Column 1 Title Header
                        Expanded(
                          flex: 3,
                          child: Text(
                            'EXPENSES & DESCRIPTION',
                            style: TextStyle(
                              color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        // Column 2 Title Header
                        Expanded(
                          flex: 2,
                          child: Text(
                            'PRICE / AMOUNT (RS)',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Expense Records 2-Column List View
                  Expanded(
                    child: expState.isLoading && filteredExpenses.isEmpty
                        ? const Center(
                            child: CircularProgressIndicator(color: AppColors.primaryRed),
                          )
                        : filteredExpenses.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Icon(Icons.receipt_rounded, size: 48, color: AppColors.textMuted),
                                    SizedBox(height: 12),
                                    Text(
                                      'No expense records found for selected date',
                                      style: TextStyle(color: AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.separated(
                            itemCount: filteredExpenses.length,
                            separatorBuilder: (_, _) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final item = filteredExpenses[index];
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                child: Row(
                                  children: [
                                    // Column 1: Expense details
                                    Expanded(
                                      flex: 3,
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: AppColors.danger.withValues(alpha: 0.1),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(Icons.receipt_rounded, color: AppColors.danger, size: 20),
                                          ),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  item.title,
                                                  style: TextStyle(
                                                    color: isDark ? Colors.white : AppColors.textPrimary,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14.5,
                                                  ),
                                                ),
                                                const SizedBox(height: 3),
                                                Text(
                                                  'Category: ${item.category.name.toUpperCase()} • Date: ${_formatDate(item.date)} • Logged by: ${item.recordedBy}',
                                                  style: TextStyle(
                                                    color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                                                    fontSize: 11.5,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Column 2: Price / Amount
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        '-PKR ${item.amount.toStringAsFixed(0)}',
                                        textAlign: TextAlign.right,
                                        style: const TextStyle(
                                          color: AppColors.danger,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),

                  // Bottom Total Amount Bar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFFEF2F2),
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                      border: Border(
                        top: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFFCA5A5), width: 1.5),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.account_balance_wallet_rounded, color: AppColors.danger, size: 22),
                            const SizedBox(width: 10),
                            Text(
                              _selectedDate == null
                                  ? 'TOTAL EXPENSES (ALL DATES):'
                                  : 'TOTAL EXPENSES (${_formatDate(_selectedDate!)}):',
                              style: const TextStyle(
                                color: AppColors.danger,
                                fontWeight: FontWeight.w900,
                                fontSize: 13.5,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'PKR ${filteredTotal.toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: AppColors.danger,
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                          ),
                        ),
                      ],
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

  void _showAddExpenseModal(BuildContext context, WidgetRef ref) {
    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    ExpenseCategory category = ExpenseCategory.honorExpenses;
    DateTime recordDate = _selectedDate ?? DateTime.now();
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryRed.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.add_card_rounded, color: AppColors.primaryRed, size: 20),
                ),
                const SizedBox(width: 10),
                const Text('Log Store Expense', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: titleCtrl,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Expense Description *',
                      hintText: 'e.g. Owner Personal Draw / Honorarium',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Amount (PKR) *',
                      hintText: 'e.g. 1500',
                      prefixText: 'PKR ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<ExpenseCategory>(
                    initialValue: category,
                    decoration: const InputDecoration(
                      labelText: 'Expense Category',
                      border: OutlineInputBorder(),
                    ),
                    items: ExpenseCategory.values
                        .map((c) => DropdownMenuItem(
                              value: c,
                              child: Text(
                                c == ExpenseCategory.honorExpenses
                                    ? 'HONOR EXPENSES'
                                    : c.name.toUpperCase(),
                                style: TextStyle(
                                  fontWeight: c == ExpenseCategory.honorExpenses
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: c == ExpenseCategory.honorExpenses
                                      ? AppColors.primaryRed
                                      : null,
                                ),
                              ),
                            ))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() => category = val);
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Date: ${_formatDate(recordDate)}',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
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
                              setModalState(() {
                                recordDate = picked;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
                onPressed: isSaving
                    ? null
                    : () async {
                        final title = titleCtrl.text.trim();
                        final amount = double.tryParse(amountCtrl.text.trim());

                        if (title.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please enter an expense description.'),
                              backgroundColor: AppColors.danger,
                            ),
                          );
                          return;
                        }

                        if (amount == null || amount <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please enter a valid amount greater than 0.'),
                              backgroundColor: AppColors.danger,
                            ),
                          );
                          return;
                        }

                        setModalState(() => isSaving = true);

                        try {
                          await ref.read(expenseProvider.notifier).addExpense(
                                title: title,
                                category: category,
                                amount: amount,
                                recordedBy: 'Store Manager',
                                date: recordDate,
                              );

                          if (context.mounted) {
                            Navigator.pop(context);

                            // Make sure screen date matches so the user immediately sees it
                            if (_selectedDate != null && !_isSameDay(_selectedDate!, recordDate)) {
                              setState(() {
                                _selectedDate = recordDate;
                              });
                            }

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("Expense '$title' added successfully in honor expenses!"),
                                backgroundColor: const Color(0xFF16A34A),
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            setModalState(() => isSaving = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("Failed to log expense: $e"),
                                backgroundColor: AppColors.danger,
                              ),
                            );
                          }
                        }
                      },
                child: isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('SAVE EXPENSE', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }
}
