import re

path = 'c:/flutter/Howies POS/frontend/lib/features/online_orders/online_orders_screen.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Add _showAssignRiderBeforeBill before _showCustomerBillDialog
assign_rider_code = """
  // Assign Rider Modal
  void _showAssignRiderBeforeBill(BuildContext context, OnlineOrderModel order, bool isDark, {bool showBillAfter = true}) {
    final riders = ref.read(deliveryProvider).riders;
    
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Assign Rider to Order #${order.orderNumber}',
            style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          content: SizedBox(
            width: 400,
            child: riders.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Center(child: Text('No riders available. Please add riders in Delivery Module.')),
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
                          child: Icon(Icons.delivery_dining, color: Colors.white, size: 18),
                        ),
                        title: Text(r.name, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                        subtitle: Text(r.isClockedIn ? 'On Duty' : 'Off Duty', style: TextStyle(color: r.isClockedIn ? const Color(0xFF22C55E) : Colors.grey, fontSize: 11)),
                        trailing: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          onPressed: () {
                            ref.read(onlineOrdersProvider.notifier).assignRider(order.id, r.name);
                            Navigator.pop(dialogContext);
                            if (showBillAfter) {
                              final updatedOrder = order.copyWith(riderName: r.name);
                              _showCustomerBillDialog(context, updatedOrder, isDark);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Rider ${r.name} assigned to Order #${order.orderNumber}')),
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
                    _showCustomerBillDialog(context, order, isDark);
                 }
              },
              child: const Text('Skip / Cancel', style: TextStyle(color: Colors.grey)),
            ),
          ],
        );
      },
    );
  }

  // 2. Customer Bill Dialog (KOT & Billing Combo)
"""

content = content.replace("  // 2. Customer Bill Dialog (KOT & Billing Combo)", assign_rider_code)

# 2. Update the Customer Bill button to call _showAssignRiderBeforeBill
content = content.replace("onPressed: () => _showCustomerBillDialog(context, order, isDark),", "onPressed: () => _showAssignRiderBeforeBill(context, order, isDark),")

# 3. Update the "Change Rider" button
old_change_rider = """ElevatedButton.icon(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Assign/Change Rider coming soon!')),
                                );
                              },"""

new_change_rider = """ElevatedButton.icon(
                              onPressed: () => _showAssignRiderBeforeBill(context, order, isDark, showBillAfter: false),"""

content = content.replace(old_change_rider, new_change_rider)

# 4. Add Rider display to invoice preview
old_invoice_row = """                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Order: ${order.orderNumber}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primaryRed)),
                                Text('Customer: ${order.customerName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              ],
                            ),"""

new_invoice_row = """                            Row(
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
                              ),"""

content = content.replace(old_invoice_row, new_invoice_row)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
