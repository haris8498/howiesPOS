import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/app_colors.dart';
import '../../data/customer_repository.dart';
import '../../shared/widgets/glass_card.dart';
import '../../shared/widgets/status_badge.dart';

class CustomersScreen extends ConsumerWidget {
  const CustomersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final custState = ref.watch(customerProvider);

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('CUSTOMER CRM & LOYALTY PROGRAM', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
              StatusBadge(label: '10 Points per PKR 100 Spent', color: AppColors.gold, icon: Icons.stars_rounded),
            ],
          ),

          const SizedBox(height: 16),

          Expanded(
            child: ListView.builder(
              itemCount: custState.customers.length,
              itemBuilder: (context, index) {
                final customer = custState.customers[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: GlassCard(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: const BoxDecoration(
                            color: AppColors.offWhite,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.person_rounded, color: AppColors.primaryRed, size: 26),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(customer.fullName, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
                                  const SizedBox(width: 8),
                                  if (customer.hasBirthdayOffer)
                                    const StatusBadge(label: 'BIRTHDAY 20% OFF', color: AppColors.spicyOrange, icon: Icons.cake_rounded),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text('Phone: ${customer.phone} • Email: ${customer.email}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                              Text('Address: ${customer.address}', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.stars_rounded, color: AppColors.gold, size: 16),
                                const SizedBox(width: 4),
                                Text('${customer.loyaltyPoints} PTS', style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 16)),
                              ],
                            ),
                            Text('${customer.totalOrdersCount} Lifetime Orders', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                            Text('Total Spent: PKR ${customer.totalSpent.toStringAsFixed(0)}', style: const TextStyle(color: AppColors.primaryRed, fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
