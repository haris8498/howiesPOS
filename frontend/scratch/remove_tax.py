import re

path = 'c:/flutter/Howies POS/frontend/lib/features/online_orders/online_orders_screen.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Update liveGrandTotal calculation
content = content.replace("final liveGrandTotal = (order.subtotal - order.discountAmount + order.taxAmount + currentFee);", "final liveGrandTotal = (order.subtotal - order.discountAmount + currentFee);")

# 2. Remove Tax from the Bill UI
old_tax_block1 = """                            if (order.taxAmount > 0) ...[
                              const SizedBox(height: 2),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Tax:', style: TextStyle(fontSize: 12)),
                                  Text('+PKR ${order.taxAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                ],
                              ),
                            ],"""
content = content.replace(old_tax_block1, "")

old_tax_block2 = """                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Tax:', style: TextStyle(fontSize: 12)),
                                Text('PKR ${order.taxAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              ],
                            ),"""
content = content.replace(old_tax_block2, "")

old_tax_block3 = """                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Tax:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                    Text('PKR ${order.taxAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12)),
                                  ],
                                ),
                                const SizedBox(height: 4),"""
content = content.replace(old_tax_block3, "")

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
