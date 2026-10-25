import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/app_colors.dart';
import '../../../data/auth_repository.dart';
import '../../../data/daily_calculation_repository.dart';

enum FloatActionMode { keepSame, addCash, withdrawCash, setExact }

class StartingCashDialog extends ConsumerStatefulWidget {
  final bool isDismissible;
  final VoidCallback? onSessionStarted;

  const StartingCashDialog({
    super.key,
    this.isDismissible = false,
    this.onSessionStarted,
  });

  static Future<bool?> show(
    BuildContext context, {
    bool isDismissible = false,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: isDismissible,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (ctx) => StartingCashDialog(
        isDismissible: isDismissible,
      ),
    );
  }

  @override
  ConsumerState<StartingCashDialog> createState() => _StartingCashDialogState();
}

class _StartingCashDialogState extends ConsumerState<StartingCashDialog> {
  final _amountController = TextEditingController(text: '0');
  FloatActionMode _mode = FloatActionMode.keepSame;
  String? _errorMessage;
  bool _isSubmitting = false;

  final List<int> _quickPresets = [1000, 2000, 5000, 10000, 20000, 30000];

  @override
  void initState() {
    super.initState();
    // Default to keepSame if baseline exists, else setExact
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final calcState = ref.read(dailyCalculationProvider);
      final baseline = calcState.totalChangeCash > 0 ? calcState.totalChangeCash : calcState.startingCash;
      if (baseline <= 0) {
        setState(() {
          _mode = FloatActionMode.setExact;
          _amountController.text = '5000';
        });
      }
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _setPreset(int amount) {
    _amountController.text = amount.toString();
    setState(() => _errorMessage = null);
  }

  double get _inputAmount => double.tryParse(_amountController.text.trim()) ?? 0.0;

  double _computeFinalFloat(double baseline) {
    switch (_mode) {
      case FloatActionMode.keepSame:
        return baseline;
      case FloatActionMode.addCash:
        return baseline + _inputAmount;
      case FloatActionMode.withdrawCash:
        return (baseline - _inputAmount).clamp(0.0, double.infinity);
      case FloatActionMode.setExact:
        return _inputAmount.clamp(0.0, double.infinity);
    }
  }

  Future<void> _submit(double baseline) async {
    final finalFloat = _computeFinalFloat(baseline);

    if (_mode == FloatActionMode.setExact && _inputAmount <= 0 && baseline <= 0) {
      setState(() => _errorMessage = 'Please enter a valid starting cash amount.');
      return;
    }

    if (_mode == FloatActionMode.withdrawCash && _inputAmount > baseline) {
      setState(() => _errorMessage = 'Cannot withdraw more than current baseline (PKR ${baseline.toStringAsFixed(0)}).');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final authState = ref.read(authProvider);
    final cashierId = authState.currentUser.id;
    final cashierName = authState.currentUser.fullName;

    String? adjustmentType;
    double? adjustmentAmount;

    if (_mode == FloatActionMode.addCash) {
      adjustmentType = 'ADD';
      adjustmentAmount = _inputAmount;
    } else if (_mode == FloatActionMode.withdrawCash) {
      adjustmentType = 'SUBTRACT';
      adjustmentAmount = _inputAmount;
    } else if (_mode == FloatActionMode.setExact) {
      adjustmentType = 'SET';
      adjustmentAmount = finalFloat;
    } else {
      adjustmentType = 'SET';
      adjustmentAmount = baseline;
    }

    final success = await ref.read(dailyCalculationProvider.notifier).startSession(
      startingCash: finalFloat,
      adjustmentType: adjustmentType,
      adjustmentAmount: adjustmentAmount,
      cashierId: cashierId,
      cashierName: cashierName,
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        widget.onSessionStarted?.call();
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text('Total Starting Float set to PKR ${finalFloat.toStringAsFixed(0)}! Register is Open.'),
              ],
            ),
            backgroundColor: const Color(0xFF16A34A),
          ),
        );
      } else {
        final calcState = ref.read(dailyCalculationProvider);
        if (calcState.isShiftConflict) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: const [
                  Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 28),
                  SizedBox(width: 10),
                  Text('Active Shift Exists', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              content: const Text(
                'You already have an active shift. Please close the current shift before opening a new one.',
                style: TextStyle(fontSize: 14),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Dismiss', style: TextStyle(color: AppColors.textSecondary)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryRed,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.of(context).pop(false);
                    context.go('/sales/daily-calculation');
                  },
                  child: const Text('Go to Shift Closing'),
                ),
              ],
            ),
          );
        }
        setState(() => _errorMessage = calcState.errorMessage ?? 'Failed to register starting cash. Please try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final calcState = ref.watch(dailyCalculationProvider);
    final baseline = calcState.totalChangeCash > 0
        ? calcState.totalChangeCash
        : (calcState.startingCash > 0 ? calcState.startingCash : calcState.liveSummary.startingCash);

    final finalFloat = _computeFinalFloat(baseline);
    final screenHeight = MediaQuery.of(context).size.height;

    return PopScope(
      canPop: widget.isDismissible,
      child: Dialog(
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 520,
            maxHeight: screenHeight * 0.90,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Header (Fixed at top)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: const BoxDecoration(
                  gradient: AppColors.brandGradient,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.point_of_sale_rounded, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'SHIFT OPENING & ROLLING STARTING CASH',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 13.5,
                              letterSpacing: 0.5,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Cumulative change cash float stored in database',
                            style: TextStyle(color: Colors.white70, fontSize: 10.5),
                          ),
                        ],
                      ),
                    ),
                    if (widget.isDismissible)
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                        onPressed: () => Navigator.of(context).pop(false),
                      ),
                  ],
                ),
              ),

              // 2. Scrollable Body
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(18.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Baseline Float Banner
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF14B8A6).withValues(alpha: 0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'STORED PERMANENT CASH FLOAT IN DB',
                                  style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w800, fontSize: 10, letterSpacing: 0.5),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'PKR ${baseline.toStringAsFixed(0)}',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: const [
                                  Icon(Icons.storage_rounded, color: Colors.white, size: 13),
                                  SizedBox(width: 4),
                                  Text(
                                    'PREVIOUS BASE',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 9.5),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Action Mode Selector (4 Options)
                      const Text(
                        'SELECT FLOAT ACTION FOR THIS SHIFT:',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 10.5, letterSpacing: 0.3),
                      ),
                      const SizedBox(height: 6),

                      Row(
                        children: [
                          _buildModeChip(
                            title: 'Keep Stored',
                            subtitle: 'Rs. 0 Change',
                            mode: FloatActionMode.keepSame,
                            icon: Icons.lock_outline_rounded,
                            color: const Color(0xFF0D9488),
                            isDark: isDark,
                          ),
                          const SizedBox(width: 6),
                          _buildModeChip(
                            title: '+ Add Cash',
                            subtitle: 'Increase Float',
                            mode: FloatActionMode.addCash,
                            icon: Icons.add_circle_outline_rounded,
                            color: const Color(0xFF16A34A),
                            isDark: isDark,
                          ),
                          const SizedBox(width: 6),
                          _buildModeChip(
                            title: '- Withdraw',
                            subtitle: 'Decrease Float',
                            mode: FloatActionMode.withdrawCash,
                            icon: Icons.remove_circle_outline_rounded,
                            color: const Color(0xFFDC2626),
                            isDark: isDark,
                          ),
                          const SizedBox(width: 6),
                          _buildModeChip(
                            title: 'Set Total',
                            subtitle: 'Override',
                            mode: FloatActionMode.setExact,
                            icon: Icons.edit_note_rounded,
                            color: const Color(0xFF2563EB),
                            isDark: isDark,
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // Input Field when mode != keepSame
                      if (_mode != FloatActionMode.keepSame) ...[
                        Text(
                          _mode == FloatActionMode.addCash
                              ? 'ENTER CASH AMOUNT TO ADD (+ PKR)'
                              : (_mode == FloatActionMode.withdrawCash
                                  ? 'ENTER CASH AMOUNT TO WITHDRAW (- PKR)'
                                  : 'ENTER EXACT NEW STARTING CASH (PKR)'),
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 10.5, letterSpacing: 0.3),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _amountController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                          autofocus: true,
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            color: _mode == FloatActionMode.withdrawCash ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                          ),
                          decoration: InputDecoration(
                            prefixText: _mode == FloatActionMode.addCash ? '+ PKR ' : (_mode == FloatActionMode.withdrawCash ? '- PKR ' : 'PKR '),
                            prefixStyle: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                              color: _mode == FloatActionMode.withdrawCash ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                            ),
                            hintText: '0',
                            filled: true,
                            fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: _mode == FloatActionMode.withdrawCash ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                                width: 2,
                              ),
                            ),
                          ),
                          onChanged: (_) => setState(() => _errorMessage = null),
                        ),
                        const SizedBox(height: 8),

                        // Quick Presets
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _quickPresets.map((amt) {
                            return InkWell(
                              onTap: () => _setPreset(amt),
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.3)),
                                ),
                                child: Text(
                                  '+Rs. $amt',
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 12),
                      ],

                      if (_errorMessage != null) ...[
                        Text(
                          _errorMessage!,
                          style: const TextStyle(color: AppColors.danger, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                      ],

                      // Live Calculation Preview Box
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.calculate_rounded, color: Color(0xFF16A34A), size: 18),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'RESULTING TOTAL STARTING FLOAT:',
                                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 10, color: Color(0xFF15803D)),
                                    ),
                                    Text(
                                      _mode == FloatActionMode.keepSame
                                          ? 'Retaining previous stored PKR ${baseline.toStringAsFixed(0)}'
                                          : (_mode == FloatActionMode.addCash
                                              ? 'PKR ${baseline.toStringAsFixed(0)} + PKR ${_inputAmount.toStringAsFixed(0)}'
                                              : (_mode == FloatActionMode.withdrawCash
                                                  ? 'PKR ${baseline.toStringAsFixed(0)} - PKR ${_inputAmount.toStringAsFixed(0)}'
                                                  : 'Directly set to PKR ${finalFloat.toStringAsFixed(0)}')),
                                      style: TextStyle(fontSize: 9.5, color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Text(
                              'PKR ${finalFloat.toStringAsFixed(0)}',
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF16A34A)),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF16A34A),
                            foregroundColor: Colors.white,
                            elevation: 3,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: _isSubmitting ? null : () => _submit(baseline),
                          icon: _isSubmitting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Icon(Icons.check_circle_outline_rounded, size: 18),
                          label: Text(
                            _isSubmitting
                                ? 'OPENING REGISTER...'
                                : 'CONFIRM & OPEN REGISTER (PKR ${finalFloat.toStringAsFixed(0)})',
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5, letterSpacing: 0.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeChip({
    required String title,
    required String subtitle,
    required FloatActionMode mode,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    final isSelected = _mode == mode;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _mode = mode;
            if (mode == FloatActionMode.keepSame) {
              _amountController.text = '0';
            }
            _errorMessage = null;
          });
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: isDark ? 0.25 : 0.12)
                : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC)),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? color : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 18, color: isSelected ? color : (isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary)),
              const SizedBox(height: 4),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                  color: isSelected ? color : (isDark ? Colors.white : AppColors.textPrimary),
                ),
              ),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 8.5,
                  color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
