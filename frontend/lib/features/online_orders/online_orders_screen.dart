import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../config/app_colors.dart';
import '../../config/feature_flags.dart';
import '../../core/database/app_database.dart';
import '../../core/sync/sync_providers.dart';
import '../../data/auth_repository.dart';
import '../../data/delivery_repository.dart';
import '../../data/online_orders_repository.dart';
import '../../data/role_rights_repository.dart';
import '../../domain/models/online_order_model.dart';
import '../../domain/models/order_model.dart';
import '../../domain/models/user_role.dart';
import '../../services/api/api_providers.dart';
import '../../services/receipt_printer_service.dart';
import '../../shared/widgets/refund_order_dialog.dart';

class OnlineOrdersScreen extends ConsumerStatefulWidget {
  const OnlineOrdersScreen({super.key});

  @override
  ConsumerState<OnlineOrdersScreen> createState() => _OnlineOrdersScreenState();
}

class _OnlineOrdersScreenState extends ConsumerState<OnlineOrdersScreen> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _expandedOrderIds = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleOrderExpansion(String orderId) {
    setState(() {
      if (_expandedOrderIds.contains(orderId)) {
        _expandedOrderIds.remove(orderId);
      } else {
        _expandedOrderIds.add(orderId);
      }
    });
  }

  void _toggleAllOrders(List<OnlineOrderModel> orders) {
    setState(() {
      if (_expandedOrderIds.length == orders.length) {
        _expandedOrderIds.clear();
      } else {
        _expandedOrderIds.clear();
        _expandedOrderIds.addAll(orders.map((o) => o.id));
      }
    });
  }


  // 0. Accept Order Dialog with Custom Delivery Charges & Bill Calculation Preview
  void _showAcceptOrderDialog(BuildContext context, OnlineOrderModel order, bool isDark) {
    double currentFee = order.deliveryFee;
    final feeController = TextEditingController(text: currentFee.toStringAsFixed(2));
    final quickFees = [0.0, 2.0, 2.5, 3.0, 4.0, 5.0];

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final liveGrandTotal = (order.subtotal - order.discountAmount + currentFee);

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 480),
                padding: const EdgeInsets.all(22),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.success.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 22),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'ACCEPT ONLINE ORDER',
                                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 0.5),
                                  ),
                                  Text(
                                    order.orderNumber,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primaryRed),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 20),
                            onPressed: () => Navigator.pop(dialogContext),
                          ),
                        ],
                      ),
                      const Divider(height: 20),

                      // Customer Summary
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.person_outline_rounded, size: 16, color: AppColors.textSecondary),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    '${order.customerName} • ${order.customerPhone}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.location_on_outlined, size: 16, color: AppColors.textSecondary),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    order.customerAddress,
                                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Delivery Charges Setup Box
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.delivery_dining_rounded, size: 18, color: Color(0xFF2563EB)),
                                    SizedBox(width: 6),
                                    Text(
                                      'Set Delivery Charges / Fee:',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E40AF)),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'PKR ${currentFee.toStringAsFixed(2)}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1E40AF)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Editable text input with decrement / increment buttons
                            Row(
                              children: [
                                // - $0.50 button
                                InkWell(
                                  onTap: () {
                                    if (currentFee >= 0.50) {
                                      setDialogState(() {
                                        currentFee -= 0.50;
                                        feeController.text = currentFee.toStringAsFixed(2);
                                      });
                                    } else {
                                      setDialogState(() {
                                        currentFee = 0.0;
                                        feeController.text = currentFee.toStringAsFixed(2);
                                      });
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.4)),
                                    ),
                                    child: const Icon(Icons.remove, size: 18, color: Color(0xFF2563EB)),
                                  ),
                                ),

                                const SizedBox(width: 8),

                                // Text input field
                                Expanded(
                                  child: Container(
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFF2563EB), width: 1.5),
                                    ),
                                    child: TextField(
                                      controller: feeController,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      decoration: const InputDecoration(
                                        prefixText: 'PKR ',
                                        prefixStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF2563EB)),
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                        isDense: true,
                                      ),
                                      onChanged: (val) {
                                        final parsed = double.tryParse(val.replaceAll('PKR ', '').trim()) ?? 0.0;
                                        setDialogState(() {
                                          currentFee = parsed >= 0 ? parsed : 0.0;
                                        });
                                      },
                                    ),
                                  ),
                                ),

                                const SizedBox(width: 8),

                                // + $0.50 button
                                InkWell(
                                  onTap: () {
                                    setDialogState(() {
                                      currentFee += 0.50;
                                      feeController.text = currentFee.toStringAsFixed(2);
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.4)),
                                    ),
                                    child: const Icon(Icons.add, size: 18, color: Color(0xFF2563EB)),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 10),

                            // Quick Chips Presets
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: quickFees.map((fee) {
                                final isSelected = (currentFee == fee);
                                return InkWell(
                                  onTap: () {
                                    setDialogState(() {
                                      currentFee = fee;
                                      feeController.text = fee.toStringAsFixed(2);
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: isSelected ? const Color(0xFF2563EB) : (isDark ? const Color(0xFF1E293B) : Colors.white),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF2563EB).withValues(alpha: 0.3),
                                      ),
                                    ),
                                    child: Text(
                                      fee == 0.0 ? 'Free (PKR 0)' : 'PKR ${fee.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isSelected ? Colors.white : const Color(0xFF1E40AF),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Bill Summary Breakdown Preview (Updates Live!)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'TOTAL BILL BREAKDOWN',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 0.5, color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Items Subtotal (${order.items.length} items):', style: const TextStyle(fontSize: 12)),
                                Text('PKR ${order.subtotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Delivery Fee:', style: TextStyle(fontSize: 12, color: Color(0xFF2563EB), fontWeight: FontWeight.w600)),
                                Text(
                                  '+PKR ${currentFee.toStringAsFixed(2)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF2563EB)),
                                ),
                              ],
                            ),

                            if (order.discountAmount > 0) ...[
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Discount:', style: TextStyle(fontSize: 12, color: AppColors.success)),
                                  Text('-PKR ${order.discountAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.success)),
                                ],
                              ),
                            ],
                            const Divider(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('GRAND TOTAL:', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                                Text(
                                  'PKR ${liveGrandTotal.toStringAsFixed(2)}',
                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.success),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Dialog Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                ref.read(onlineOrdersProvider.notifier).acceptOrder(order.id, deliveryFee: currentFee);
                                Navigator.pop(dialogContext);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Order ${order.orderNumber} accepted (Fee: PKR ${currentFee.toStringAsFixed(2)}, Total: PKR ${liveGrandTotal.toStringAsFixed(2)})! Kitchen & Bill options ready.'),
                                    backgroundColor: AppColors.success,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                              icon: const Icon(Icons.check_rounded, size: 16, color: AppColors.success),
                              label: const Text('Accept Only', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 11)),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppColors.success),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),

                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Edit Delivery Fee Dialog for Accepted Orders
  void _showEditDeliveryFeeDialog(BuildContext context, OnlineOrderModel order, bool isDark) {
    double currentFee = order.deliveryFee;
    final feeController = TextEditingController(text: currentFee.toStringAsFixed(2));
    final quickFees = [0.0, 2.0, 2.5, 3.0, 4.0, 5.0];

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final liveGrandTotal = (order.subtotal - order.discountAmount + currentFee);

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 440),
                padding: const EdgeInsets.all(20),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.delivery_dining_rounded, color: Color(0xFF2563EB), size: 22),
                              const SizedBox(width: 8),
                              Text(
                                'EDIT DELIVERY FEE (${order.orderNumber})',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () => Navigator.pop(dialogContext),
                          ),
                        ],
                      ),
                      const Divider(),
                      const SizedBox(height: 10),

                      // Input with +/-
                      Row(
                        children: [
                          InkWell(
                            onTap: () {
                              if (currentFee >= 0.50) {
                                setDialogState(() {
                                  currentFee -= 0.50;
                                  feeController.text = currentFee.toStringAsFixed(2);
                                });
                              } else {
                                setDialogState(() {
                                  currentFee = 0.0;
                                  feeController.text = currentFee.toStringAsFixed(2);
                                });
                              }
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.4)),
                              ),
                              child: const Icon(Icons.remove, size: 18, color: Color(0xFF2563EB)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              height: 42,
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFF2563EB), width: 1.5),
                              ),
                              child: TextField(
                                controller: feeController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                decoration: const InputDecoration(
                                  prefixText: 'PKR ',
                                  prefixStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF2563EB)),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                  isDense: true,
                                ),
                                onChanged: (val) {
                                  final parsed = double.tryParse(val.replaceAll('PKR ', '').trim()) ?? 0.0;
                                  setDialogState(() {
                                    currentFee = parsed >= 0 ? parsed : 0.0;
                                  });
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () {
                              setDialogState(() {
                                currentFee += 0.50;
                                feeController.text = currentFee.toStringAsFixed(2);
                              });
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.4)),
                              ),
                              child: const Icon(Icons.add, size: 18, color: Color(0xFF2563EB)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: quickFees.map((fee) {
                          final isSelected = (currentFee == fee);
                          return InkWell(
                            onTap: () {
                              setDialogState(() {
                                currentFee = fee;
                                feeController.text = fee.toStringAsFixed(2);
                              });
                            },
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFF2563EB) : (isDark ? const Color(0xFF1E293B) : Colors.white),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF2563EB).withValues(alpha: 0.3),
                                ),
                              ),
                              child: Text(
                                fee == 0.0 ? 'Free (PKR 0)' : 'PKR ${fee.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? Colors.white : const Color(0xFF1E40AF),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),

                      // Updated Total Preview
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Updated Total Bill:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            Text(
                              'PKR ${liveGrandTotal.toStringAsFixed(2)}',
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.success),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            ref.read(onlineOrdersProvider.notifier).updateDeliveryFee(order.id, currentFee);
                            Navigator.pop(dialogContext);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Delivery fee updated to PKR ${currentFee.toStringAsFixed(2)}! (New Total: PKR ${liveGrandTotal.toStringAsFixed(2)})'),
                                backgroundColor: const Color(0xFF2563EB),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          icon: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                          label: const Text('UPDATE DELIVERY FEE & BILL', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // 1. Kitchen Ticket (KOT) Dialog with Interactive Cooking Timer
  void _showKitchenReceiptDialog(BuildContext context, OnlineOrderModel order, bool isDark) {
    final screenContext = context;
    int cookingMinutes = order.cookingTimeMinutes ?? 25;
    final cookingController = TextEditingController(text: '$cookingMinutes');
    final timeStr = DateFormat('hh:mm a').format(order.createdAt);
    final quickTimers = [10, 15, 20, 25, 30, 45, 60];

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final readyAtTime = DateFormat('hh:mm a').format(DateTime.now().add(Duration(minutes: cookingMinutes)));

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 480),
                padding: const EdgeInsets.all(20),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.soup_kitchen_rounded, color: Color(0xFFD97706), size: 22),
                              SizedBox(width: 8),
                              Text(
                                'KITCHEN TICKET (KOT)',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () => Navigator.pop(dialogContext),
                          ),
                        ],
                      ),
                      const Divider(),
                      const SizedBox(height: 8),

                      // Cooking Time Input & Presets Box
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD97706).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFD97706).withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.timer_rounded, size: 16, color: Color(0xFFD97706)),
                                SizedBox(width: 6),
                                Text(
                                  'Set Estimated Cooking Time (Timer):',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF92400E)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            Row(
                              children: [
                                // - Button
                                InkWell(
                                  onTap: () {
                                    if (cookingMinutes > 5) {
                                      setDialogState(() {
                                        cookingMinutes -= 5;
                                        cookingController.text = '$cookingMinutes';
                                      });
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFFD97706).withValues(alpha: 0.4)),
                                    ),
                                    child: const Icon(Icons.remove, size: 16, color: Color(0xFFD97706)),
                                  ),
                                ),

                                const SizedBox(width: 8),

                                // Numeric Input Field
                                Expanded(
                                  child: SizedBox(
                                    height: 38,
                                    child: TextField(
                                      controller: cookingController,
                                      keyboardType: TextInputType.number,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFFD97706)),
                                      decoration: InputDecoration(
                                        isDense: true,
                                        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                                        suffixText: 'mins',
                                        suffixStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFD97706)),
                                        filled: true,
                                        fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: const BorderSide(color: Color(0xFFD97706), width: 1.2),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: const BorderSide(color: Color(0xFFD97706), width: 2),
                                        ),
                                      ),
                                      onChanged: (val) {
                                        final parsed = int.tryParse(val.trim());
                                        if (parsed != null && parsed > 0 && parsed <= 300) {
                                          setDialogState(() => cookingMinutes = parsed);
                                        }
                                      },
                                    ),
                                  ),
                                ),

                                const SizedBox(width: 8),

                                // + Button
                                InkWell(
                                  onTap: () {
                                    if (cookingMinutes < 180) {
                                      setDialogState(() {
                                        cookingMinutes += 5;
                                        cookingController.text = '$cookingMinutes';
                                      });
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFFD97706).withValues(alpha: 0.4)),
                                    ),
                                    child: const Icon(Icons.add, size: 16, color: Color(0xFFD97706)),
                                  ),
                                ),

                                const SizedBox(width: 12),

                                // Ready By calculation preview
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: AppColors.success.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.alarm_on_rounded, size: 15, color: AppColors.success),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Ready By: $readyAtTime',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.success),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 8),

                            // Quick preset chips
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: quickTimers.map((mins) {
                                final isSel = cookingMinutes == mins;
                                return InkWell(
                                  onTap: () {
                                    setDialogState(() {
                                      cookingMinutes = mins;
                                      cookingController.text = '$mins';
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isSel ? const Color(0xFFD97706) : (isDark ? const Color(0xFF1E293B) : Colors.white),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: isSel ? const Color(0xFFD97706) : AppColors.borderGray),
                                    ),
                                    child: Text(
                                      '$mins min',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                                        color: isSel ? Colors.white : AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Thermal Ticket Preview Box
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Center(
                              child: Text(
                                'HUNGRY HOWIE\'S KITCHEN (ONLINE)',
                                style: TextStyle(
                                  color: isDark ? Colors.white : AppColors.textPrimary,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Order: ${order.orderNumber}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppColors.primaryRed)),
                                Text('Ordered: $timeStr', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text('Customer: ${order.customerName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            Text('Phone: ${order.customerPhone}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                            const Divider(height: 16),

                            // Prominent Cooking Time Ticket Header Box
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFD97706).withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFD97706), width: 1.2),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.timer_rounded, size: 16, color: Color(0xFFD97706)),
                                          const SizedBox(width: 6),
                                          Text(
                                            'COOKING TIME: $cookingMinutes MINS',
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFFB45309)),
                                          ),
                                        ],
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFD97706),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          'KITCHEN ETA',
                                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Start: ${DateFormat('hh:mm a').format(DateTime.now())}',
                                        style: TextStyle(fontSize: 10.5, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF78350F)),
                                      ),
                                      Text(
                                        'Ready By: $readyAtTime',
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFFB45309)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            const Text('ITEMS TO PREPARE:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFD97706))),
                            const SizedBox(height: 8),
                            ...order.items.map((item) => Padding(
                                  padding: const EdgeInsets.only(bottom: 6.0),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('${item.quantity}x ', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: AppColors.primaryRed)),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('${item.itemName} (${item.size})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                            if (item.toppings.isNotEmpty)
                                              Text('Toppings: ${item.toppings.join(', ')}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                            if (item.specialInstructions != null)
                                              Text('Note: ${item.specialInstructions}', style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xFFD97706))),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                )),
                            if (order.notes != null && order.notes!.isNotEmpty) ...[
                              const Divider(height: 14),
                              Text('Order Instructions: ${order.notes}', style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xFFB45309))),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Print Button
                      FutureBuilder<bool>(
                        future: ReceiptPrinterService.isKitchenReceiptPrinted(order.orderNumber),
                        builder: (context, snapshot) {
                          final isPrinted = snapshot.data ?? false;
                          if (isPrinted) {
                            return Column(
                              children: [
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                  margin: const EdgeInsets.only(bottom: 10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF2F2),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFFCA5A5)),
                                  ),
                                  child: Row(
                                    children: const [
                                      Icon(Icons.check_circle_rounded, color: Color(0xFFDC2626), size: 16),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Online kitchen ticket has already been printed once.',
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF991B1B)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: null,
                                    icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                                    label: const Text('ALREADY PRINTED (BLOCKED)'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.grey.shade400,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }

                          return SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                ref.read(onlineOrdersProvider.notifier).setCookingTime(order.id, cookingMinutes);
                                Navigator.pop(dialogContext);

                                // Physical Thermal Print to Attached Laptop Printer
                                await ReceiptPrinterService.printReceipt(
                                  context: screenContext,
                                  receipt: ReceiptData.fromOnlineOrder(
                                    order: order,
                                    type: ReceiptType.kitchenKot,
                                  ),
                                );
                              },
                              icon: const Icon(Icons.print_rounded, size: 16),
                              label: Text('PRINT KITCHEN TICKET ($cookingMinutes MINS)'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFD97706),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Assign Rider Modal (Compulsory before Customer / Dispatch Bill)
  void _showAssignRiderBeforeBill(BuildContext context, OnlineOrderModel order, bool isDark, {bool showBillAfter = true}) {
    // If rider is already assigned and user clicked Customer Bill, go directly to bill dialog
    if (showBillAfter && order.riderName != null && order.riderName!.trim().isNotEmpty) {
      _showCustomerBillDialog(context, order, isDark);
      return;
    }

    final riders = ref.read(deliveryProvider).riders;
    
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.two_wheeler_rounded, color: Color(0xFF2563EB), size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Assign Rider to Order #${order.orderNumber}',
                  style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: riders.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Center(child: Text('No riders available. Please add and mark riders ON DUTY in Delivery Fleet.')),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: riders.length,
                    separatorBuilder: (ctx, i) => const Divider(height: 1),
                    itemBuilder: (ctx, i) {
                      final r = riders[i];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: r.isClockedIn ? const Color(0xFF22C55E) : Colors.grey,
                          child: const Icon(Icons.delivery_dining, color: Colors.white, size: 18),
                        ),
                        title: Text(r.name, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                        subtitle: Text(r.isClockedIn ? 'On Duty' : 'Off Duty', style: TextStyle(color: r.isClockedIn ? const Color(0xFF22C55E) : Colors.grey, fontSize: 11)),
                        trailing: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          onPressed: !r.isClockedIn
                              ? null
                              : () {
                                  ref.read(onlineOrdersProvider.notifier).assignRider(order.id, r.name);
                                  Navigator.pop(dialogContext);
                                  if (showBillAfter) {
                                    final updatedOrder = order.copyWith(riderName: r.name);
                                    _showCustomerBillDialog(context, updatedOrder, isDark);
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Rider ${r.name} assigned to Order #${order.orderNumber}!'),
                                        backgroundColor: const Color(0xFF16A34A),
                                      ),
                                    );
                                  }
                                },
                          child: const Text('Assign'),
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                if (showBillAfter) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('⚠️ Rider assignment is compulsory before printing the Bill / Dispatching.'),
                      backgroundColor: Color(0xFFD97706),
                    ),
                  );
                }
              },
              child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  // 2. Customer Pre-Bill Dialog with Estimated Shipping / Delivery Time
  void _showCustomerBillDialog(BuildContext context, OnlineOrderModel order, bool isDark) {
    int deliveryMinutes = order.estimatedDeliveryMinutes ?? 35;
    final quickDeliveryOptions = [20, 30, 35, 45, 60, 75];

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final expectedArrival = DateFormat('hh:mm a').format(DateTime.now().add(Duration(minutes: deliveryMinutes)));

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 480),
                padding: const EdgeInsets.all(20),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.description_rounded, color: Color(0xFF2563EB), size: 22),
                              SizedBox(width: 8),
                              Text(
                                'CUSTOMER ORDER BILL & SHIPPING',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () => Navigator.pop(dialogContext),
                          ),
                        ],
                      ),
                      const Divider(),
                      const SizedBox(height: 8),

                      // Shipping & Delivery Time Setup Box
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.two_wheeler_rounded, size: 18, color: Color(0xFF2563EB)),
                                SizedBox(width: 6),
                                Text(
                                  'Estimated Delivery / Shipping Time:',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1E40AF)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            Row(
                              children: [
                                // - Button
                                InkWell(
                                  onTap: () {
                                    if (deliveryMinutes > 10) {
                                      setDialogState(() => deliveryMinutes -= 5);
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.4)),
                                    ),
                                    child: const Icon(Icons.remove, size: 16, color: Color(0xFF2563EB)),
                                  ),
                                ),

                                const SizedBox(width: 8),

                                // Delivery Time Display Box
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFF2563EB), width: 1.5),
                                  ),
                                  child: Text(
                                    '$deliveryMinutes mins',
                                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF2563EB)),
                                  ),
                                ),

                                const SizedBox(width: 8),

                                // + Button
                                InkWell(
                                  onTap: () {
                                    if (deliveryMinutes < 180) {
                                      setDialogState(() => deliveryMinutes += 5);
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.4)),
                                    ),
                                    child: const Icon(Icons.add, size: 16, color: Color(0xFF2563EB)),
                                  ),
                                ),

                                const SizedBox(width: 12),

                                // Expected Arrival Banner
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: AppColors.success.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.location_on_rounded, size: 15, color: AppColors.success),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Arrives: $expectedArrival',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.success),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 8),

                            // Quick preset chips
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: quickDeliveryOptions.map((mins) {
                                final isSel = deliveryMinutes == mins;
                                return InkWell(
                                  onTap: () => setDialogState(() => deliveryMinutes = mins),
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isSel ? const Color(0xFF2563EB) : (isDark ? const Color(0xFF1E293B) : Colors.white),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: isSel ? const Color(0xFF2563EB) : AppColors.borderGray),
                                    ),
                                    child: Text(
                                      '$mins min',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                                        color: isSel ? Colors.white : AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Customer Invoice Preview
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFBFDBFE)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Center(
                              child: Text(
                                'HUNGRY HOWIE\'S PIZZA',
                                style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimary, fontWeight: FontWeight.w900, fontSize: 15),
                              ),
                            ),
                            const Center(
                              child: Text('Online Delivery Customer Invoice', style: TextStyle(fontSize: 11, color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Order: ${order.orderNumber}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primaryRed)),
                                Text('Customer: ${order.customerName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              ],
                            ),
                            if (order.riderName != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text('Assigned Rider: ${order.riderName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF2E7D32))),
                              ),
                            const SizedBox(height: 4),
                            Text('Phone: ${order.customerPhone}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                            Text('Address: ${order.customerAddress}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                            const Divider(height: 16),

                            // Prominent Delivery / Ship Time Banner on Invoice
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFF2563EB), width: 1.2),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.local_shipping_rounded, size: 16, color: Color(0xFF2563EB)),
                                          const SizedBox(width: 6),
                                          Text(
                                            'SHIP TIME: $deliveryMinutes MINS',
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF1E40AF)),
                                          ),
                                        ],
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF2563EB),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          'DISPATCH ETA',
                                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Dispatch: ${DateFormat('hh:mm a').format(DateTime.now())}',
                                        style: TextStyle(fontSize: 10.5, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF1E3A8A)),
                                      ),
                                      Text(
                                        'Est. Arrival: $expectedArrival',
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF1E40AF)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            ...order.items.map((item) => Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('${item.quantity}x ${item.itemName} (${item.size})', style: const TextStyle(fontSize: 12)),
                                      Text('PKR ${item.totalPrice.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                    ],
                                  ),
                                )),
                            const Divider(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Subtotal:', style: TextStyle(fontSize: 12)),
                                Text('PKR ${order.subtotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              ],
                            ),
                            if (order.discountAmount > 0) ...[
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Discount (${order.discountPercentage > 0 ? "${order.discountPercentage.toStringAsFixed(0)}%" : "Flat"}):',
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF16A34A), fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    '-PKR ${order.discountAmount.toStringAsFixed(2)}',
                                    style: const TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                ],
                              ),
                            ],
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Delivery Fee:', style: TextStyle(fontSize: 12)),
                                Text('PKR ${order.deliveryFee.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              ],
                            ),

                            const Divider(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('TOTAL BILL:', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                                Text('PKR ${order.grandTotal.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.w900, fontSize: 18)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            ref.read(onlineOrdersProvider.notifier).setDeliveryTime(order.id, deliveryMinutes);
                            Navigator.pop(dialogContext);

                            // Physical Thermal Print to Attached Laptop Printer
                            await ReceiptPrinterService.printReceipt(
                              context: context,
                              receipt: ReceiptData.fromOnlineOrder(
                                order: order,
                                type: ReceiptType.customerReceipt,
                              ),
                            );
                          },
                          icon: const Icon(Icons.print_rounded, size: 16),
                          label: const Text('PRINT CUSTOMER BILL'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // 3. Full Bill & Pay Settlement Dialog (Using consistent FULL BILL & CASH CALCULATOR)
  void _showFullBillAndPayDialog(BuildContext context, OnlineOrderModel order, bool isDark) {
    if (order.isPaid || order.status == OnlineOrderStatus.completed) {
      _showOnlineOrdersFinalPaidReceiptDialog(context, order, order.grandTotal, 0.0, isDark);
      return;
    }

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (dialogContext) {
        return _OnlineOrdersFullBillCalculatorDialog(
          parentContext: context,
          ref: ref,
          order: order,
          isDark: isDark,
        );
      },
    );
  }

  void _showRejectDialog(BuildContext context, OnlineOrderModel order) {
    final reasonController = TextEditingController();
    final quickReasons = [
      'Item out of stock',
      'Delivery address outside service zone',
      'Kitchen at maximum capacity',
      'Riders unavailable in area',
      'Customer unreachable by phone',
    ];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.cancel_rounded, color: AppColors.danger, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Reject Online Order',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        Text(
                          'Order ${order.orderNumber} • ${order.customerName}',
                          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 500,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Please provide a rejection reason. This message will be recorded and communicated to the customer:',
                      style: TextStyle(fontSize: 13, color: AppColors.textPrimary, height: 1.4),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Quick Reasons:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: quickReasons.map((reason) {
                        final isSelected = reasonController.text == reason;
                        return ChoiceChip(
                          label: Text(reason, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : AppColors.textPrimary)),
                          selected: isSelected,
                          selectedColor: AppColors.danger,
                          backgroundColor: AppColors.lightGray,
                          showCheckmark: false,
                          onSelected: (selected) {
                            setDialogState(() {
                              reasonController.text = selected ? reason : '';
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: reasonController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Enter rejection reason or write custom notes here...',
                        hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                        filled: true,
                        fillColor: AppColors.offWhite,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.borderGray),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    final reason = reasonController.text.trim();
                    if (reason.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please select or type a rejection reason.'),
                          backgroundColor: AppColors.danger,
                        ),
                      );
                      return;
                    }
                    ref.read(onlineOrdersProvider.notifier).rejectOrder(order.id, reason);
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Order ${order.orderNumber} rejected successfully.'),
                        backgroundColor: AppColors.danger,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  icon: const Icon(Icons.send_rounded, size: 16, color: Colors.white),
                  label: const Text('Submit Rejection', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.danger,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onlineOrdersProvider);
    final notifier = ref.read(onlineOrdersProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final filteredOrders = state.filteredOrders;
    final allExpanded = filteredOrders.isNotEmpty && _expandedOrderIds.length >= filteredOrders.length;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Header (Responsive to prevent RenderFlex overflow)
            LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 960;

                final titleWidget = Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: AppColors.brandGradient,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.cloud_download_rounded, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Online Orders Module',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Super Admin Portal • Live customer orders review, accept & reject dispatch control',
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                );

                final statsWidget = Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildStatCard('Pending', state.pendingCount, AppColors.warning, Icons.pending_actions_rounded),
                    _buildStatCard('Accepted', state.acceptedCount, const Color(0xFF2563EB), Icons.check_circle_outline_rounded),
                    _buildStatCard('Completed', state.completedCount, AppColors.success, Icons.task_alt_rounded),
                    _buildStatCard('Rejected', state.rejectedCount, AppColors.danger, Icons.cancel_outlined),
                  ],
                );

                if (isCompact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      titleWidget,
                      const SizedBox(height: 12),
                      statsWidget,
                    ],
                  );
                }

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: titleWidget),
                    const SizedBox(width: 16),
                    statsWidget,
                  ],
                );
              },
            ),

            const SizedBox(height: 16),

            // Controls Bar: Search, Status Filters & Expand/Collapse All Toggle
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? const Color(0xFF334155) : AppColors.borderGray),
              ),
              child: Row(
                children: [
                  // Filter Chips & Toggle in Horizontal Scroll to eliminate any overflow
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip('All (${state.orders.length})', 'all', state.activeFilter, notifier),
                          const SizedBox(width: 8),
                          _buildFilterChip('Pending (${state.pendingCount})', 'pending', state.activeFilter, notifier),
                          const SizedBox(width: 8),
                          _buildFilterChip('Accepted (${state.acceptedCount})', 'accepted', state.activeFilter, notifier),
                          const SizedBox(width: 8),
                          _buildFilterChip('Completed (${state.completedCount})', 'completed', state.activeFilter, notifier),
                          const SizedBox(width: 8),
                          _buildFilterChip('Rejected (${state.rejectedCount})', 'rejected', state.activeFilter, notifier),
                          const SizedBox(width: 14),
                          // Expand / Collapse All Button
                          OutlinedButton.icon(
                            onPressed: () => _toggleAllOrders(filteredOrders),
                            icon: Icon(
                              allExpanded ? Icons.unfold_less_rounded : Icons.unfold_more_rounded,
                              size: 16,
                              color: AppColors.textSecondary,
                            ),
                            label: Text(
                              allExpanded ? 'Collapse All' : 'Expand All',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              side: BorderSide(color: isDark ? const Color(0xFF334155) : AppColors.borderGray),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 16),

                  // Search Field
                  SizedBox(
                    width: 260,
                    height: 38,
                    child: TextField(
                      controller: _searchController,
                      onChanged: notifier.setSearchQuery,
                      decoration: InputDecoration(
                        hintText: 'Search by name, phone...',
                        hintStyle: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                        prefixIcon: const Icon(Icons.search, size: 16, color: AppColors.textSecondary),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 14),
                                onPressed: () {
                                  _searchController.clear();
                                  notifier.setSearchQuery('');
                                },
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F172A) : AppColors.offWhite,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : AppColors.borderGray),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : AppColors.borderGray),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Order List
            Expanded(
              child: filteredOrders.isEmpty
                  ? _buildEmptyState(isDark)
                  : ListView.separated(
                      itemCount: filteredOrders.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 14),
                      itemBuilder: (context, index) {
                        final order = filteredOrders[index];
                        final isExpanded = _expandedOrderIds.contains(order.id);
                        return _buildOrderCard(context, order, isExpanded, isDark);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, int count, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text('$title: ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
          Text('$count', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String key, String activeKey, OnlineOrdersNotifier notifier) {
    final isSelected = key == activeKey;
    return InkWell(
      onTap: () => notifier.setFilter(key),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryRed : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildOrderCard(BuildContext context, OnlineOrderModel order, bool isExpanded, bool isDark) {
    final isPending = order.status == OnlineOrderStatus.pending;
    final isAccepted = order.status == OnlineOrderStatus.accepted;
    final isCompleted = order.status == OnlineOrderStatus.completed;
    final isRejected = order.status == OnlineOrderStatus.rejected;

    final timeString = DateFormat('hh:mm a').format(order.createdAt);
    final minutesAgo = DateTime.now().difference(order.createdAt).inMinutes;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isPending
              ? AppColors.warning.withValues(alpha: 0.6)
              : isCompleted
                  ? AppColors.success.withValues(alpha: 0.5)
                  : isAccepted
                      ? const Color(0xFF2563EB).withValues(alpha: 0.4)
                      : isDark
                          ? const Color(0xFF334155)
                          : AppColors.borderGray,
          width: (isPending || isCompleted) ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Order Header (Clickable to Expand / Collapse)
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _toggleOrderExpansion(order.id),
              borderRadius: isExpanded
                  ? const BorderRadius.vertical(top: Radius.circular(13))
                  : BorderRadius.circular(13),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF0F172A).withValues(alpha: 0.5)
                      : (isPending
                          ? AppColors.warning.withValues(alpha: 0.05)
                          : (isCompleted ? AppColors.success.withValues(alpha: 0.05) : AppColors.offWhite)),
                  borderRadius: isExpanded
                      ? const BorderRadius.vertical(top: Radius.circular(13))
                      : BorderRadius.circular(13),
                  border: isExpanded
                      ? Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : AppColors.borderGray))
                      : null,
                ),
                child: Row(
                  children: [
                    // Order Number
                    Text(
                      order.orderNumber,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primaryRed),
                    ),
                    const SizedBox(width: 10),

                    // Time badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : AppColors.lightGray,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.access_time_rounded, size: 13, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            '$timeString ($minutesAgo min ago)',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),

                    if (order.cookingTimeMinutes != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD97706).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFD97706).withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.timer_rounded, size: 13, color: Color(0xFFD97706)),
                            const SizedBox(width: 4),
                            Text(
                              '${order.cookingTimeMinutes}m Cook',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
                            ),
                          ],
                        ),
                      ),
                    ],

                    if (order.estimatedDeliveryMinutes != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.moped_rounded, size: 13, color: Color(0xFF2563EB)),
                            const SizedBox(width: 4),
                            Text(
                              '${order.estimatedDeliveryMinutes}m Delivery',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E40AF)),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(width: 12),

                    // Compact Summary when Collapsed
                    if (!isExpanded) ...[
                      Expanded(
                        child: Row(
                          children: [
                            const Icon(Icons.person_outline_rounded, size: 15, color: AppColors.textSecondary),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                order.customerName,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '• ${order.customerPhone}',
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '• ${order.items.length} item(s)',
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'PKR ${order.grandTotal.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primaryRed),
                            ),
                          ],
                        ),
                      ),
                    ] else
                      const Spacer(),

                    // Status Badge
                    _buildStatusBadge(order.status),

                    const SizedBox(width: 10),

                    // Expand / Collapse Chevron Indicator
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: isDark ? const Color(0xFF334155) : AppColors.borderGray),
                      ),
                      child: Icon(
                        isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Collapsible Body Section
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            crossFadeState: isExpanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            secondChild: const SizedBox.shrink(),
            firstChild: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Customer Details & Order Items Section
                Padding(
                  padding: const EdgeInsets.all(18.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. User Info (Name, Phone, Address)
                      Expanded(
                        flex: 4,
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0F172A) : AppColors.offWhite,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: isDark ? const Color(0xFF334155) : AppColors.borderGray),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.person_pin_circle_rounded, size: 18, color: AppColors.primaryRed),
                                  SizedBox(width: 6),
                                  Text(
                                    'Customer Information',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                  ),
                                ],
                              ),
                              const Divider(height: 16, thickness: 0.8),

                              // Name
                              _buildInfoRow(
                                icon: Icons.person_rounded,
                                label: 'Name',
                                value: order.customerName,
                                isBold: true,
                              ),
                              const SizedBox(height: 8),

                              // Phone
                              _buildInfoRow(
                                icon: Icons.phone_rounded,
                                label: 'Phone',
                                value: order.customerPhone,
                                trailing: InkWell(
                                  onTap: () {
                                    Clipboard.setData(ClipboardData(text: order.customerPhone));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Phone copied: ${order.customerPhone}'),
                                        duration: const Duration(seconds: 1),
                                      ),
                                    );
                                  },
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 4.0),
                                    child: Icon(Icons.copy_rounded, size: 14, color: AppColors.textSecondary),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),

                              // Address
                              _buildInfoRow(
                                icon: Icons.location_on_rounded,
                                label: 'Address',
                                value: order.customerAddress,
                              ),

                              if (order.estimatedDeliveryMinutes != null) ...[
                                const SizedBox(height: 8),
                                _buildInfoRow(
                                  icon: Icons.moped_rounded,
                                  label: 'Shipping Time',
                                  value: '${order.estimatedDeliveryMinutes} mins (${DateFormat('hh:mm a').format(order.estimatedDeliveryAt ?? DateTime.now().add(Duration(minutes: order.estimatedDeliveryMinutes!)))})',
                                  isBold: true,
                                ),
                              ],

                              if (order.notes != null && order.notes!.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.brandYellow.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Icon(Icons.note_alt_outlined, size: 14, color: Color(0xFF854D0E)),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          'Note: ${order.notes}',
                                          style: const TextStyle(fontSize: 11, color: Color(0xFF854D0E), fontWeight: FontWeight.w500),
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

                      const SizedBox(width: 18),

                      // 2. Ordered Items
                      Expanded(
                        flex: 5,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Items Summary',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 8),
                            ...order.items.map((item) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8.0),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryRed.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          '${item.quantity}x',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            color: AppColors.primaryRed,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${item.itemName} (${item.size})',
                                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                            ),
                                            if (item.toppings.isNotEmpty)
                                              Text(
                                                'Toppings: ${item.toppings.join(', ')}',
                                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                              ),
                                            if (item.specialInstructions != null)
                                              Text(
                                                'Note: ${item.specialInstructions}',
                                                style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppColors.textSecondary),
                                              ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        'PKR ${item.totalPrice.toStringAsFixed(2)}',
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                )),
                          ],
                        ),
                      ),

                      const SizedBox(width: 18),

                      // 3. Payment & Total Breakdown
                      Expanded(
                        flex: 3,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0F172A) : AppColors.offWhite,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: isDark ? const Color(0xFF334155) : AppColors.borderGray),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Subtotal:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                  Text('PKR ${order.subtotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Text('Delivery Fee:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                      if (isAccepted) ...[
                                        const SizedBox(width: 4),
                                        InkWell(
                                          onTap: () => _showEditDeliveryFeeDialog(context, order, isDark),
                                          child: const Icon(Icons.edit_rounded, size: 13, color: Color(0xFF2563EB)),
                                        ),
                                      ],
                                    ],
                                  ),
                                  Text('PKR ${order.deliveryFee.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12)),
                                ],
                              ),
                              const SizedBox(height: 4),

                              const Divider(height: 14, thickness: 0.8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Grand Total:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                                  Text(
                                    'PKR ${order.grandTotal.toStringAsFixed(2)}',
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryRed),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: (order.isPaid || isCompleted) ? AppColors.success.withValues(alpha: 0.1) : AppColors.warning.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      (order.isPaid || isCompleted) ? Icons.check_circle_rounded : Icons.money_rounded,
                                      size: 12,
                                      color: (order.isPaid || isCompleted) ? AppColors.success : const Color(0xFFB45309),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      (order.isPaid || isCompleted) ? 'Paid' : 'Cash On Delivery',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: (order.isPaid || isCompleted) ? AppColors.success : const Color(0xFFB45309),
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
                ),

                // Rejection Reason Banner if Rejected
                if (isRejected && order.rejectionReason != null)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(18, 0, 18, 14),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.danger.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, color: AppColors.danger, size: 18),
                        const SizedBox(width: 8),
                        const Text('Rejection Reason: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.danger)),
                        Expanded(
                          child: Text(
                            order.rejectionReason!,
                            style: const TextStyle(fontSize: 12, color: AppColors.danger),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Action Buttons Bar (For Pending, Accepted, OR Completed Orders)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A).withValues(alpha: 0.3) : AppColors.lightGray.withValues(alpha: 0.4),
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(13)),
                    border: Border(top: BorderSide(color: isDark ? const Color(0xFF334155) : AppColors.borderGray)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Left Side Status Text / Summary
                      if (isCompleted)
                        Row(
                          children: [
                            const Icon(Icons.task_alt_rounded, color: AppColors.success, size: 18),
                            const SizedBox(width: 6),
                            Text(
                              'Order Completed & Final Bill Settled',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white70 : AppColors.success,
                              ),
                            ),
                          ],
                        )
                      else if (isAccepted)
                        Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, color: Color(0xFF2563EB), size: 18),
                            const SizedBox(width: 6),
                            Text(
                              'Order Accepted • Ready for Kitchen & Billing',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white70 : const Color(0xFF2563EB),
                              ),
                            ),
                          ],
                        )
                      else if (isRejected)
                        Row(
                          children: [
                            const Icon(Icons.cancel_rounded, color: AppColors.danger, size: 18),
                            const SizedBox(width: 6),
                            const Text(
                              'Order Rejected',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.danger),
                            ),
                          ],
                        )
                      else
                        const Row(
                          children: [
                            Icon(Icons.pending_actions_rounded, color: Color(0xFFB45309), size: 18),
                            SizedBox(width: 6),
                            Text(
                              'Action Required: Review & Accept/Reject',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFB45309)),
                            ),
                          ],
                        ),

                      // Right Side Action Buttons
                      if (isPending) ...[
                        Builder(
                          builder: (context) {
                            final role = ref.watch(authProvider).currentUser.role;
                            final canAccept = ref.watch(roleRightsProvider).isActionGranted(
                              role,
                              'online_orders_accept',
                              defaultIfMissing: role != UserRole.cashier,
                            );
                            if (!canAccept) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'Awaiting Manager/Admin Review',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                                ),
                              );
                            }

                            return Row(
                              children: [
                                // Reject Button
                                OutlinedButton.icon(
                                  onPressed: () => _showRejectDialog(context, order),
                                  icon: const Icon(Icons.close_rounded, size: 16, color: AppColors.danger),
                                  label: const Text('Reject Order', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold)),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: AppColors.danger),
                                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Accept Button
                                ElevatedButton.icon(
                                  onPressed: () => _showAcceptOrderDialog(context, order, isDark),
                                  icon: const Icon(Icons.check_rounded, size: 18, color: Colors.white),
                                  label: const Text('Accept Order', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.success,
                                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ] else if (isAccepted || isCompleted) ...[
                        // Receipt / KOT / Bill Buttons
                        Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          children: [
                            // 1. Kitchen (KOT)
                            OutlinedButton.icon(
                              onPressed: () => _showKitchenReceiptDialog(context, order, isDark),
                              icon: const Icon(Icons.soup_kitchen_rounded, size: 16, color: Color(0xFFD97706)),
                              label: const Text(
                                'Kitchen (KOT)',
                                style: TextStyle(fontSize: 12, color: Color(0xFFD97706), fontWeight: FontWeight.bold),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFFD97706), width: 1.5),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              ),
                            ),

                            // 2. Customer Bill
                            OutlinedButton.icon(
                              onPressed: () => _showAssignRiderBeforeBill(context, order, isDark),
                              icon: const Icon(Icons.description_rounded, size: 16, color: Color(0xFF2563EB)),
                              label: const Text(
                                'Customer Bill',
                                style: TextStyle(fontSize: 12, color: Color(0xFF2563EB), fontWeight: FontWeight.bold),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              ),
                            ),

                            if (order.isPaid || isCompleted) ...[
                              Builder(
                                builder: (ctx) {
                                  final isOnline = ref.watch(connectivityNotifierProvider).isOnline;
                                  return Tooltip(
                                    message: isOnline ? '' : 'Refund requires an internet connection',
                                    child: ElevatedButton.icon(
                                      onPressed: isOnline
                                          ? () => _handleRefundOnlineOrder(context, order)
                                          : null,
                                      icon: const Icon(Icons.assignment_return_rounded, size: 16, color: Colors.white),
                                      label: Text(
                                        isOnline ? 'Refund Order' : 'Refund requires an internet connection',
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFFDC2626),
                                        disabledBackgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                        disabledForegroundColor: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                                        elevation: 2,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ] else ...[
                              // 3. Receive Payment
                              ElevatedButton.icon(
                                onPressed: () => _showFullBillAndPayDialog(context, order, isDark),
                                icon: const Icon(Icons.attach_money_rounded, size: 16, color: Colors.white),
                                label: Text(
                                  'Receive Payment (PKR ${order.grandTotal.toStringAsFixed(0)})',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2E7D32), // Green
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                ),
                              ),
                            ],

                            // 4. Change Rider
                            ElevatedButton.icon(
                              onPressed: () => _showAssignRiderBeforeBill(context, order, isDark, showBillAfter: false),
                              icon: const Icon(Icons.person_add_alt_1_rounded, size: 16, color: Colors.white),
                              label: const Text(
                                'Change Rider',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryRed,
                                elevation: 2,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Handle Online Order Refund (Supervisor PIN protected)
  Future<void> _handleRefundOnlineOrder(
    BuildContext context,
    OnlineOrderModel order,
  ) async {
    final isOnline = ref.read(connectivityNotifierProvider).isOnline;
    if (!isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Refund requires an internet connection'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final ordersApiService = ref.read(ordersApiServiceProvider);
    final result = await RefundOrderDialog.show(
      context,
      orderId: order.id,
      orderNumber: order.orderNumber,
      grandTotal: order.grandTotal,
      ordersApiService: ordersApiService,
    );

    if (result != null && context.mounted) {
      if (FeatureFlags.offlineFirstEnabled) {
        try {
          final db = ref.read(appDatabaseProvider);
          await (db.update(db.localOrders)..where((t) => t.id.equals(order.id)))
              .write(const LocalOrdersCompanion(status: Value('cancelled')));
        } catch (_) {}
      }

      await ref.read(onlineOrdersProvider.notifier).loadOnlineOrders();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order #${order.orderNumber} has been successfully refunded.'),
            backgroundColor: const Color(0xFF16A34A),
          ),
        );
      }
    }
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    bool isBold = false,
    Widget? trailing,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Text('$label: ', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }

  Widget _buildStatusBadge(OnlineOrderStatus status) {
    Color bg;
    Color fg;
    String text;
    IconData icon;

    switch (status) {
      case OnlineOrderStatus.pending:
        bg = AppColors.warning.withValues(alpha: 0.15);
        fg = const Color(0xFFB45309);
        text = 'PENDING ACTION';
        icon = Icons.hourglass_top_rounded;
        break;
      case OnlineOrderStatus.accepted:
        bg = const Color(0xFF2563EB).withValues(alpha: 0.15);
        fg = const Color(0xFF2563EB);
        text = 'ACCEPTED';
        icon = Icons.check_circle_rounded;
        break;
      case OnlineOrderStatus.completed:
        bg = AppColors.success.withValues(alpha: 0.15);
        fg = AppColors.success;
        text = 'COMPLETED';
        icon = Icons.task_alt_rounded;
        break;
      case OnlineOrderStatus.rejected:
        bg = AppColors.danger.withValues(alpha: 0.15);
        fg = AppColors.danger;
        text = 'REJECTED';
        icon = Icons.cancel_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: fg),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_rounded, size: 64, color: isDark ? Colors.white24 : AppColors.textMuted),
          const SizedBox(height: 12),
          Text(
            'No Online Orders Found',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : AppColors.textPrimary),
          ),
          const SizedBox(height: 6),
          const Text(
            'Change filters or wait for new incoming customer orders.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Online Orders Full Bill & Cash Calculator Dialog
// ---------------------------------------------------------------------------
class _OnlineOrdersFullBillCalculatorDialog extends StatefulWidget {
  final BuildContext parentContext;
  final WidgetRef ref;
  final OnlineOrderModel order;
  final bool isDark;

  const _OnlineOrdersFullBillCalculatorDialog({
    required this.parentContext,
    required this.ref,
    required this.order,
    required this.isDark,
  });

  @override
  State<_OnlineOrdersFullBillCalculatorDialog> createState() => _OnlineOrdersFullBillCalculatorDialogState();
}

class _OnlineOrdersFullBillCalculatorDialogState extends State<_OnlineOrdersFullBillCalculatorDialog> {
  final TextEditingController _cashController = TextEditingController();
  double _cashGiven = 5000.0;

  @override
  void initState() {
    super.initState();
    final defaultAmount = widget.order.grandTotal > 5000 ? widget.order.grandTotal : 5000.0;
    _cashGiven = defaultAmount;
    _cashController.text = defaultAmount.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _cashController.dispose();
    super.dispose();
  }

  void _setCash(double amount) {
    setState(() {
      _cashGiven = amount;
      _cashController.text = amount.toStringAsFixed(0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final netTotal = widget.order.grandTotal;
    final changeReturn = _cashGiven - netTotal;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: widget.isDark ? const Color(0xFF0F172A) : Colors.white,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 460),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.calculate_rounded, color: Color(0xFF16A34A), size: 24),
                      SizedBox(width: 8),
                      Text(
                        'FULL BILL & CASH CALCULATOR',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 8),

              // CASH CALCULATOR INPUT
              Text(
                'CASH CALCULATOR & TENDERED AMOUNT',
                style: TextStyle(
                  color: widget.isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),

              // Quick Cash Preset Chips
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildQuickCashChip('Exact', netTotal),
                  _buildQuickCashChip('PKR 1000', 1000),
                  _buildQuickCashChip('PKR 2000', 2000),
                  _buildQuickCashChip('PKR 5000', 5000),
                  _buildQuickCashChip('PKR 10000', 10000),
                ],
              ),

              const SizedBox(height: 12),

              // Cash Input Field
              TextField(
                controller: _cashController,
                keyboardType: TextInputType.number,
                style: TextStyle(
                  color: widget.isDark ? Colors.white : AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                decoration: InputDecoration(
                  labelText: 'Customer Cash Received (PKR)',
                  prefixText: 'PKR ',
                  prefixStyle: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryRed, fontSize: 16),
                  filled: true,
                  fillColor: widget.isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF16A34A), width: 2),
                  ),
                ),
                onChanged: (val) {
                  setState(() {
                    _cashGiven = double.tryParse(val) ?? 0.0;
                  });
                },
              ),

              const SizedBox(height: 12),

              // Live Change / Remaining Result Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: changeReturn >= 0 ? const Color(0xFFEBF7ED) : const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: changeReturn >= 0 ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          changeReturn >= 0 ? Icons.price_check_rounded : Icons.warning_amber_rounded,
                          color: changeReturn >= 0 ? const Color(0xFF16A34A) : AppColors.danger,
                          size: 24,
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              changeReturn >= 0 ? 'RETURN CHANGE TO CUSTOMER:' : 'REMAINING BALANCE SHORT:',
                              style: TextStyle(
                                color: changeReturn >= 0 ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              changeReturn >= 0
                                  ? 'PKR ${_cashGiven.toStringAsFixed(0)} - PKR ${netTotal.toStringAsFixed(0)}'
                                  : 'Need more cash from customer',
                              style: TextStyle(
                                color: changeReturn >= 0 ? const Color(0xFF166534) : const Color(0xFF991B1B),
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Text(
                      'PKR ${changeReturn >= 0 ? changeReturn.toStringAsFixed(0) : (-changeReturn).toStringAsFixed(0)}',
                      style: TextStyle(
                        color: changeReturn >= 0 ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Action Buttons: Mark as Tender & Pay Now
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context); // Close calculator dialog
                        showDialog(
                          context: widget.parentContext,
                          barrierColor: Colors.black.withValues(alpha: 0.8),
                          builder: (tenderContext) => _OnlineOrdersPaymentTenderDialog(
                            parentContext: widget.parentContext,
                            ref: widget.ref,
                            order: widget.order,
                            isDark: widget.isDark,
                          ),
                        );
                      },
                      icon: const Icon(Icons.account_balance_wallet_rounded, size: 16),
                      label: const Text('Mark as Tender'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        widget.ref.read(onlineOrdersProvider.notifier).completeOrder(widget.order.id, paymentMethod: PaymentMethod.cash);
                        widget.ref.read(deliveryProvider.notifier).updatePaymentStatus('del_${widget.order.id}', 'PAID', paymentMethod: 'Cash on Delivery');
                        Navigator.pop(context);

                        // Show Final Paid Receipt Dialog with Cash & Change Details
                        _showOnlineOrdersFinalPaidReceiptDialog(
                          widget.parentContext,
                          widget.order,
                          _cashGiven,
                          changeReturn >= 0 ? changeReturn : 0.0,
                          widget.isDark,
                        );
                      },
                      icon: const Icon(Icons.send_rounded, size: 16),
                      label: const Text('Pay Now'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickCashChip(String label, double amount) {
    final isSelected = (_cashGiven - amount).abs() < 1;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: const Color(0xFF16A34A),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : (widget.isDark ? Colors.white : AppColors.textPrimary),
        fontWeight: FontWeight.bold,
        fontSize: 12,
      ),
      backgroundColor: widget.isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
      onSelected: (_) => _setCash(amount),
    );
  }
}

// ---------------------------------------------------------------------------
// Online Orders Payment Tender / Multi-Tender Information Dialog
// ---------------------------------------------------------------------------
class _OnlineOrdersPaymentTenderDialog extends StatefulWidget {
  final BuildContext parentContext;
  final WidgetRef ref;
  final OnlineOrderModel order;
  final bool isDark;

  const _OnlineOrdersPaymentTenderDialog({
    required this.parentContext,
    required this.ref,
    required this.order,
    required this.isDark,
  });

  @override
  State<_OnlineOrdersPaymentTenderDialog> createState() => _OnlineOrdersPaymentTenderDialogState();
}

class _OnlineOrdersPaymentTenderDialogState extends State<_OnlineOrdersPaymentTenderDialog> {
  bool _foreignCurrency = false;
  late TextEditingController _cashController;
  late TextEditingController _creditController;

  // Machine / Bank Rows
  late TextEditingController _bankAmountController;
  String _bankCardType = 'Bank Transfer';
  final TextEditingController _bankCardNoController = TextEditingController();
  final TextEditingController _bankHolderController = TextEditingController();

  late TextEditingController _easyPaisaAmountController;
  String _easyPaisaType = 'EasyPaisa';
  final TextEditingController _easyPaisaCardNoController = TextEditingController();
  final TextEditingController _easyPaisaHolderController = TextEditingController();

  late TextEditingController _jazzCashAmountController;
  String _jazzCashType = 'JazzCash';
  final TextEditingController _jazzCashCardNoController = TextEditingController();
  final TextEditingController _jazzCashHolderController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cashController = TextEditingController(text: '0.00');
    _creditController = TextEditingController(text: '0.00');
    _bankAmountController = TextEditingController(text: '0.00');
    _easyPaisaAmountController = TextEditingController(text: '0.00');
    _jazzCashAmountController = TextEditingController(text: '0.00');
  }

  @override
  void dispose() {
    _cashController.dispose();
    _creditController.dispose();
    _bankAmountController.dispose();
    _bankCardNoController.dispose();
    _bankHolderController.dispose();
    _easyPaisaAmountController.dispose();
    _easyPaisaCardNoController.dispose();
    _easyPaisaHolderController.dispose();
    _jazzCashAmountController.dispose();
    _jazzCashCardNoController.dispose();
    _jazzCashHolderController.dispose();
    super.dispose();
  }

  double get _totalPayment {
    final cash = double.tryParse(_cashController.text) ?? 0.0;
    final credit = double.tryParse(_creditController.text) ?? 0.0;
    final bank = double.tryParse(_bankAmountController.text) ?? 0.0;
    final easyPaisa = double.tryParse(_easyPaisaAmountController.text) ?? 0.0;
    final jazzCash = double.tryParse(_jazzCashAmountController.text) ?? 0.0;
    return cash + credit + bank + easyPaisa + jazzCash;
  }

  double get _change {
    return _totalPayment - widget.order.grandTotal;
  }

  void _completePayment({bool printReceipt = true}) {
    widget.ref.read(onlineOrdersProvider.notifier).completeOrder(widget.order.id, paymentMethod: PaymentMethod.cash);
    widget.ref.read(deliveryProvider.notifier).updatePaymentStatus('del_${widget.order.id}', 'PAID', paymentMethod: 'Tender Settled');
    Navigator.pop(context);

    ScaffoldMessenger.of(widget.parentContext).showSnackBar(
      SnackBar(
        content: Text('Payment of PKR ${_totalPayment.toStringAsFixed(0)} tendered for ${widget.order.orderNumber} (${widget.order.customerName})! Order completed.'),
        backgroundColor: const Color(0xFF16A34A),
      ),
    );

    if (printReceipt) {
      _showOnlineOrdersFinalPaidReceiptDialog(
        widget.parentContext,
        widget.order,
        _totalPayment > 0 ? _totalPayment : widget.order.grandTotal,
        _change > 0 ? _change : 0.0,
        widget.isDark,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final totalPayment = _totalPayment;
    final change = _change;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFE8F1EC),
      clipBehavior: Clip.antiAlias,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 820, maxHeight: 680),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Top Window Title Bar (Payment Tender)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFD3E4DB),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.payments_rounded, color: Color(0xFF16A34A), size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Payment Tender - Order ${widget.order.orderNumber}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // 2. Section Header Bar (Payment Information)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              color: isDark ? const Color(0xFF334155) : const Color(0xFFB5D7C7),
              child: const Text(
                'Payment Information',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Color(0xFF064E3B),
                ),
              ),
            ),

            // 3. Main Form Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Form: Bill Amount & Foreign Currency
                    Row(
                      children: [
                        const SizedBox(
                          width: 120,
                          child: Text(
                            'Bill Amount',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                            ),
                            alignment: Alignment.centerRight,
                            child: Text(
                              widget.order.grandTotal.toStringAsFixed(2),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                color: Color(0xFF16A34A),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Row(
                          children: [
                            Checkbox(
                              value: _foreignCurrency,
                              onChanged: (val) => setState(() => _foreignCurrency = val ?? false),
                              activeColor: const Color(0xFF16A34A),
                            ),
                            const Text('Foreign Currency', style: TextStyle(fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Cash Payment & Credit Payment Inputs
                    Row(
                      children: [
                        const SizedBox(
                          width: 120,
                          child: Text(
                            'Cash Payment',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                        Expanded(
                          child: _buildNumericField(_cashController, isDark, onExact: () {
                            setState(() => _cashController.text = widget.order.grandTotal.toStringAsFixed(2));
                          }),
                        ),
                        const SizedBox(width: 20),
                        const SizedBox(
                          width: 110,
                          child: Text(
                            'Credit Payment',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                        Expanded(
                          child: _buildNumericField(_creditController, isDark, onExact: () {
                            setState(() => _creditController.text = widget.order.grandTotal.toStringAsFixed(2));
                          }),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Machine / Bank Tender Grid
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                      ),
                      child: Column(
                        children: [
                          // Table Header
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF334155) : const Color(0xFFD6E9DF),
                              borderRadius: const BorderRadius.only(topLeft: Radius.circular(7), topRight: Radius.circular(7)),
                            ),
                            child: const Row(
                              children: [
                                Expanded(flex: 3, child: Text('Machine/Bank', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A)))),
                                SizedBox(width: 8),
                                Expanded(flex: 2, child: Text('Amount', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A)))),
                                SizedBox(width: 8),
                                Expanded(flex: 2, child: Text('Card Type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A)))),
                                SizedBox(width: 8),
                                Expanded(flex: 2, child: Text('Card No', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A)))),
                                SizedBox(width: 8),
                                Expanded(flex: 3, child: Text('Card Holder Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A)))),
                              ],
                            ),
                          ),

                          // Table Rows
                          _buildBankRow('Bank Transfer', _bankAmountController, _bankCardType, (v) => setState(() => _bankCardType = v!), _bankCardNoController, _bankHolderController, isDark),
                          const Divider(height: 1),
                          _buildBankRow('EASY PAISA', _easyPaisaAmountController, _easyPaisaType, (v) => setState(() => _easyPaisaType = v!), _easyPaisaCardNoController, _easyPaisaHolderController, isDark),
                          const Divider(height: 1),
                          _buildBankRow('JAZZ CASH', _jazzCashAmountController, _jazzCashType, (v) => setState(() => _jazzCashType = v!), _jazzCashCardNoController, _jazzCashHolderController, isDark),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 4. Bottom Summary & Action Bar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFD3E4DB),
                border: Border(top: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFB5D7C7))),
              ),
              child: Row(
                children: [
                  // Total Payment
                  const Text('Total Payment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(width: 8),
                  Container(
                    width: 110,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                    ),
                    alignment: Alignment.centerRight,
                    child: Text(
                      totalPayment.toStringAsFixed(2),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Change
                  const Text('Change', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(width: 8),
                  Container(
                    width: 110,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                    ),
                    alignment: Alignment.centerRight,
                    child: Text(
                      change.toStringAsFixed(2),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: change >= 0 ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                      ),
                    ),
                  ),

                  const Spacer(),

                  // Quick Keypad Icon Button
                  IconButton(
                    tooltip: 'Exact Amount',
                    icon: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E40AF),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.keyboard_alt_rounded, color: Colors.white, size: 18),
                    ),
                    onPressed: () {
                      setState(() {
                        _cashController.text = widget.order.grandTotal.toStringAsFixed(2);
                      });
                    },
                  ),
                  const SizedBox(width: 6),

                  // Save Tender Button
                  ElevatedButton.icon(
                    onPressed: () => _completePayment(printReceipt: false),
                    icon: const Icon(Icons.save_rounded, size: 16),
                    label: const Text('SAVE'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Print & Finish Button
                  ElevatedButton.icon(
                    onPressed: () => _completePayment(printReceipt: true),
                    icon: const Icon(Icons.receipt_long_rounded, size: 16),
                    label: const Text('PRINT & FINISH'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
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

  Widget _buildNumericField(TextEditingController controller, bool isDark, {required VoidCallback onExact}) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 38,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
            ),
            child: TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                isDense: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
        ),
        const SizedBox(width: 6),
        InkWell(
          onTap: onExact,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF16A34A).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF16A34A)),
            ),
            child: const Text('Exact', style: TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.bold, fontSize: 11)),
          ),
        ),
      ],
    );
  }

  Widget _buildBankRow(
    String machineName,
    TextEditingController amountCtrl,
    String selectedType,
    ValueChanged<String?> onTypeChanged,
    TextEditingController cardNoCtrl,
    TextEditingController holderCtrl,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              machineName,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Container(
              height: 32,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : Colors.white,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
              ),
              child: TextField(
                controller: amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                  isDense: true,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : Colors.white,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedType,
                  isDense: true,
                  items: ['Bank Transfer', 'EasyPaisa', 'JazzCash', 'Visa', 'MasterCard']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 11))))
                      .toList(),
                  onChanged: onTypeChanged,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Container(
              height: 32,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : Colors.white,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
              ),
              child: TextField(
                controller: cardNoCtrl,
                style: const TextStyle(fontSize: 11),
                decoration: const InputDecoration(
                  hintText: 'Txn / Card #',
                  hintStyle: TextStyle(fontSize: 10, color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                  isDense: true,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Container(
              height: 32,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : Colors.white,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
              ),
              child: TextField(
                controller: holderCtrl,
                style: const TextStyle(fontSize: 11),
                decoration: const InputDecoration(
                  hintText: 'Holder / Account Name',
                  hintStyle: TextStyle(fontSize: 10, color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                  isDense: true,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Online Orders Final Paid Receipt Dialog
// ---------------------------------------------------------------------------
void _showOnlineOrdersFinalPaidReceiptDialog(
  BuildContext context,
  OnlineOrderModel order,
  double cashGiven,
  double changeReturned,
  bool isDark,
) {
  showDialog(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.75),
    builder: (dialogContext) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: 420,
            maxHeight: MediaQuery.of(context).size.height * 0.88,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.verified_rounded, color: Color(0xFF16A34A), size: 24),
                        SizedBox(width: 8),
                        Text(
                          'FULL BILL RECEIPT (PAID)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () => Navigator.pop(dialogContext),
                    ),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 8),

                // Receipt Body
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Text(
                          "HUNGRY HOWIES",
                          style: TextStyle(
                            color: isDark ? Colors.white : AppColors.textPrimary,
                            fontWeight: FontWeight.w900,
                            fontSize: 17,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF16A34A).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'ONLINE ORDER • FINAL PAID RECEIPT',
                            style: TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.w900, fontSize: 10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Divider(),

                      // Order Number & Customer
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Order #:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? Colors.white : AppColors.textPrimary)),
                            Text(order.orderNumber, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Color(0xFF16A34A))),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Customer:', style: TextStyle(fontSize: 11.5, color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary)),
                            Text('${order.customerName} (${order.customerPhone})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                          ],
                        ),
                      ),
                      const Divider(),
                      const SizedBox(height: 4),

                      // Items List
                      ...order.items.map((item) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryRed.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${item.quantity}×',
                                    style: const TextStyle(color: AppColors.primaryRed, fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    item.itemName,
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white : AppColors.textPrimary),
                                  ),
                                ),
                                Text(
                                  'PKR ${item.totalPrice.toStringAsFixed(0)}',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: isDark ? Colors.white : AppColors.textPrimary),
                                ),
                              ],
                            ),
                          )),

                      const SizedBox(height: 6),
                      const Divider(),
                      const SizedBox(height: 4),

                      // Total Bill
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('TOTAL BILL:', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                          Text(
                            'PKR ${order.grandTotal.toStringAsFixed(0)}',
                            style: const TextStyle(color: AppColors.primaryRed, fontWeight: FontWeight.w900, fontSize: 18),
                          ),
                        ],
                      ),

                      // Cash Returned — only show if > 0
                      if (changeReturned > 0) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEBF7ED),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'CASH RETURNED:',
                                style: TextStyle(color: Color(0xFF15803D), fontWeight: FontWeight.w900, fontSize: 12),
                              ),
                              Text(
                                'PKR ${changeReturned.toStringAsFixed(0)}',
                                style: const TextStyle(color: Color(0xFF15803D), fontWeight: FontWeight.w900, fontSize: 16),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.pop(dialogContext);

                      // Physical Thermal Print to Attached Laptop Printer
                      await ReceiptPrinterService.printReceipt(
                        context: context,
                        receipt: ReceiptData.fromOnlineOrder(
                          order: order,
                          type: ReceiptType.customerReceipt,
                          paymentMethod: order.paymentMethod.name.toUpperCase(),
                          tenderedAmount: cashGiven > 0 ? cashGiven : order.grandTotal,
                          changeReturned: changeReturned,
                        ),
                      );
                    },
                    icon: const Icon(Icons.print_rounded, size: 16),
                    label: const Text('PRINT RECEIPT & FINISH'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
