import 'package:flutter/material.dart';
import '../../core/security/offline_auth_service.dart';

/// Supervisor approval data attached to outbox mutation payloads per D-03 / Tasks 4 & 7.
class ManagerApproval {
  final String managerId;
  final String managerUsername;
  final String deviceId;
  final String approvedAt;
  final String reason;

  const ManagerApproval({
    required this.managerId,
    required this.managerUsername,
    required this.deviceId,
    required this.approvedAt,
    required this.reason,
  });

  Map<String, dynamic> toJson() => {
    'manager_id': managerId,
    'manager_username': managerUsername,
    'device_id': deviceId,
    'approved_at': approvedAt,
    'reason': reason,
  };

  factory ManagerApproval.fromJson(Map<String, dynamic> json) => ManagerApproval(
    managerId: json['manager_id']?.toString() ?? json['managerId']?.toString() ?? '',
    managerUsername: json['manager_username']?.toString() ?? json['managerUsername']?.toString() ?? '',
    deviceId: json['device_id']?.toString() ?? json['deviceId']?.toString() ?? 'POS-P1',
    approvedAt: json['approved_at']?.toString() ?? json['approvedAt']?.toString() ?? DateTime.now().toIso8601String(),
    reason: json['reason']?.toString() ?? 'Manager Discount Approval',
  );
}

/// Dialog prompting for manager credentials to authorize cashier discounts (D-03 / Task 7).
class ManagerApprovalDialog extends StatefulWidget {
  final OfflineAuthService offlineAuthService;
  final String deviceId;
  final String actionTitle;
  final double discountAmount;
  final double discountPercentage;

  const ManagerApprovalDialog({
    super.key,
    required this.offlineAuthService,
    this.deviceId = 'POS-P1',
    this.actionTitle = 'Discount Approval',
    this.discountAmount = 0.0,
    this.discountPercentage = 0.0,
  });

  /// Static helper to display the dialog and return [ManagerApproval] if verified.
  static Future<ManagerApproval?> show(
    BuildContext context, {
    required OfflineAuthService offlineAuthService,
    String deviceId = 'POS-P1',
    String actionTitle = 'Discount Approval',
    double discountAmount = 0.0,
    double discountPercentage = 0.0,
  }) {
    return showDialog<ManagerApproval>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ManagerApprovalDialog(
        offlineAuthService: offlineAuthService,
        deviceId: deviceId,
        actionTitle: actionTitle,
        discountAmount: discountAmount,
        discountPercentage: discountPercentage,
      ),
    );
  }

  @override
  State<ManagerApprovalDialog> createState() => _ManagerApprovalDialogState();
}

class _ManagerApprovalDialogState extends State<ManagerApprovalDialog> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _reasonController = TextEditingController(text: 'Customer Goodwill');

  bool _isVerifying = false;
  String? _errorMessage;

  final List<String> _presetReasons = [
    'Customer Goodwill',
    'VIP Customer',
    'Store Promotion',
    'Manager Discretion',
    'Order Delay Remedy',
  ];

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _handleVerify() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();
    final reason = _reasonController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = 'Manager username and password/PIN are required.';
      });
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      final result = await widget.offlineAuthService.verifyManagerCredential(
        username,
        password,
      );

      if (!mounted) return;

      if (result.isSuccess && result.credential != null) {
        final approval = ManagerApproval(
          managerId: result.credential!.userId,
          managerUsername: result.credential!.username,
          deviceId: widget.deviceId,
          approvedAt: DateTime.now().toIso8601String(),
          reason: reason.isNotEmpty ? reason : 'Manager Discount Approval',
        );
        Navigator.of(context).pop(approval);
      } else {
        setState(() {
          _errorMessage = result.errorMessage ?? 'Invalid manager credential.';
          _isVerifying = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Verification failed: $e';
        _isVerifying = false;
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
              color: const Color(0xFFD97706).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.security, color: Color(0xFFD97706), size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Manager Approval Required',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  widget.actionTitle,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 16, color: Color(0xFFD97706)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.discountPercentage > 0
                            ? 'Applying ${widget.discountPercentage.toStringAsFixed(0)}% discount (-PKR ${widget.discountAmount.toStringAsFixed(0)}). This override is logged to the server audit ledger.'
                            : 'Applying PKR ${widget.discountAmount.toStringAsFixed(0)} discount. This override is logged to the server audit ledger.',
                        style: const TextStyle(fontSize: 12, color: Color(0xFFD97706)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Manager Username / ID',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Manager Password / PIN',
                  prefixIcon: Icon(Icons.lock),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onSubmitted: (_) => _handleVerify(),
              ),
              const SizedBox(height: 12),
              const Text('Approval Reason:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: _presetReasons.map((r) {
                  final isSelected = _reasonController.text == r;
                  return ChoiceChip(
                    label: Text(r, style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : null)),
                    selected: isSelected,
                    selectedColor: const Color(0xFFD97706),
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
                  labelText: 'Custom Reason',
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
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, size: 16, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(fontSize: 12, color: Colors.red),
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
          onPressed: _isVerifying ? null : () => Navigator.of(context).pop(null),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFD97706),
            foregroundColor: Colors.white,
          ),
          onPressed: _isVerifying ? null : _handleVerify,
          child: _isVerifying
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Verify & Approve'),
        ),
      ],
    );
  }
}
