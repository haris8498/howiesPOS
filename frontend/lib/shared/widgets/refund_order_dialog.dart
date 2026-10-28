import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';
import '../../services/api/orders_api_service.dart';

/// Dialog prompting for supervisor credentials to authorize order refunds.
/// Reuses the existing manager-approval dialog pattern from D-03.
class RefundOrderDialog extends StatefulWidget {
  final String orderId;
  final String orderNumber;
  final double grandTotal;
  final OrdersApiService ordersApiService;

  const RefundOrderDialog({
    super.key,
    required this.orderId,
    required this.orderNumber,
    required this.grandTotal,
    required this.ordersApiService,
  });

  /// Static helper to display the refund dialog and return response payload if refunded.
  static Future<Map<String, dynamic>?> show(
    BuildContext context, {
    required String orderId,
    required String orderNumber,
    required double grandTotal,
    required OrdersApiService ordersApiService,
  }) {
    return showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => RefundOrderDialog(
        orderId: orderId,
        orderNumber: orderNumber,
        grandTotal: grandTotal,
        ordersApiService: ordersApiService,
      ),
    );
  }

  @override
  State<RefundOrderDialog> createState() => _RefundOrderDialogState();
}

class _RefundOrderDialogState extends State<RefundOrderDialog> {
  final _pinController = TextEditingController();
  final _reasonController = TextEditingController(text: 'Customer Request');

  String _selectedRefundMethod = 'original';
  bool _isSubmitting = false;
  String? _errorMessage;

  final List<String> _presetReasons = [
    'Customer Request',
    'Order Mistake',
    'Quality Issue',
    'Item Unavailable',
    'Order Delay Remedy',
  ];

  @override
  void dispose() {
    _pinController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _handleRefund() async {
    final pin = _pinController.text.trim();
    final reason = _reasonController.text.trim();

    if (pin.isEmpty) {
      setState(() {
        _errorMessage = 'Supervisor PIN is required.';
      });
      return;
    }

    if (reason.isEmpty) {
      setState(() {
        _errorMessage = 'Refund reason is required.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final response = await widget.ordersApiService.refundOrder(
        widget.orderId,
        supervisorPin: pin,
        reason: reason,
        refundMethod: _selectedRefundMethod,
      );

      if (!mounted) return;
      Navigator.of(context).pop(response);
    } on UnauthorizedException {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Supervisor approval failed';
        _isSubmitting = false;
      });
    } on ForbiddenException {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Supervisor approval failed';
        _isSubmitting = false;
      });
    } on ValidationException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _isSubmitting = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        if (e.statusCode == 401 || e.statusCode == 403) {
          _errorMessage = 'Supervisor approval failed';
        } else {
          _errorMessage = e.message;
        }
        _isSubmitting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Refund failed: $e';
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFDC2626).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.assignment_return_rounded, color: Color(0xFFDC2626), size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Supervisor Approval Required',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Refund Order #${widget.orderNumber}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFDC2626).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 16, color: Color(0xFFDC2626)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Refunding order #${widget.orderNumber} for PKR ${widget.grandTotal.toStringAsFixed(0)}. This will reverse the payment, mark the order as refunded, and log an entry in the audit ledger.',
                        style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Refund Method:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Original Payment', style: TextStyle(fontSize: 11)),
                    selected: _selectedRefundMethod == 'original',
                    selectedColor: const Color(0xFFDC2626),
                    labelStyle: TextStyle(
                      color: _selectedRefundMethod == 'original' ? Colors.white : null,
                    ),
                    onSelected: (sel) {
                      if (sel) setState(() => _selectedRefundMethod = 'original');
                    },
                  ),
                  ChoiceChip(
                    label: const Text('Cash', style: TextStyle(fontSize: 11)),
                    selected: _selectedRefundMethod == 'cash',
                    selectedColor: const Color(0xFFDC2626),
                    labelStyle: TextStyle(
                      color: _selectedRefundMethod == 'cash' ? Colors.white : null,
                    ),
                    onSelected: (sel) {
                      if (sel) setState(() => _selectedRefundMethod = 'cash');
                    },
                  ),
                  ChoiceChip(
                    label: const Text('Card', style: TextStyle(fontSize: 11)),
                    selected: _selectedRefundMethod == 'card',
                    selectedColor: const Color(0xFFDC2626),
                    labelStyle: TextStyle(
                      color: _selectedRefundMethod == 'card' ? Colors.white : null,
                    ),
                    onSelected: (sel) {
                      if (sel) setState(() => _selectedRefundMethod = 'card');
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _pinController,
                obscureText: true,
                autofocus: true,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Supervisor PIN',
                  prefixIcon: Icon(Icons.lock),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onSubmitted: (_) => _handleRefund(),
              ),
              const SizedBox(height: 14),
              const Text(
                'Refund Reason:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: _presetReasons.map((r) {
                  final isSelected = _reasonController.text == r;
                  return ChoiceChip(
                    label: Text(r, style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : null)),
                    selected: isSelected,
                    selectedColor: const Color(0xFFDC2626),
                    onSelected: (sel) {
                      if (sel) setState(() => _reasonController.text = r);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _reasonController,
                decoration: const InputDecoration(
                  labelText: 'Reason Details',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, size: 16, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(null),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFDC2626),
            foregroundColor: Colors.white,
          ),
          onPressed: _isSubmitting ? null : _handleRefund,
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Verify & Refund'),
        ),
      ],
    );
  }
}
