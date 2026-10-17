import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/app_colors.dart';
import '../../data/kitchen_repository.dart';
import '../../domain/models/order_model.dart';
import '../../shared/widgets/glass_card.dart';
import '../../shared/widgets/status_badge.dart';

class KitchenScreen extends ConsumerWidget {
  const KitchenScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kitchenState = ref.watch(kitchenProvider);
    final kitchenNotifier = ref.read(kitchenProvider.notifier);

    final filters = ['All', 'Accepted', 'Preparing', 'Ready'];

    final filteredOrders = kitchenState.kitchenOrders.where((o) {
      if (kitchenState.activeFilter == 'All') return o.status != OrderStatus.served;
      if (kitchenState.activeFilter == 'Accepted') return o.status == OrderStatus.accepted;
      if (kitchenState.activeFilter == 'Preparing') return o.status == OrderStatus.preparing;
      if (kitchenState.activeFilter == 'Ready') return o.status == OrderStatus.ready;
      return true;
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header & Station Filter Bar
          Row(
            children: [
              const Icon(Icons.soup_kitchen_rounded, color: AppColors.primaryRed, size: 26),
              const SizedBox(width: 10),
              const Text('KITCHEN DISPLAY SYSTEM (KDS)', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
              const Spacer(),
              Wrap(
                spacing: 8,
                children: filters.map((f) {
                  final isSelected = kitchenState.activeFilter == f;
                  return ChoiceChip(
                    label: Text(f),
                    selected: isSelected,
                    selectedColor: AppColors.primaryRed,
                    onSelected: (_) => kitchenNotifier.setFilter(f),
                  );
                }).toList(),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // KDS Order Tickets Grid (Light Theme White Cards)
          Expanded(
            child: filteredOrders.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.check_circle_outline_rounded, color: AppColors.success, size: 60),
                        SizedBox(height: 12),
                        Text('All Kitchen Orders Cleared!', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                        Text('Incoming order tickets from POS will appear here live', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                      ],
                    ),
                  )
                : GridView.builder(
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 320,
                      childAspectRatio: 0.85,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                    ),
                    itemCount: filteredOrders.length,
                    itemBuilder: (context, index) {
                      final order = filteredOrders[index];
                      final elapsedMins = DateTime.now().difference(order.createdAt).inMinutes;

                      Color statusColor;
                      OrderStatus nextStatus;
                      String actionBtnText;

                      switch (order.status) {
                        case OrderStatus.newOrder:
                        case OrderStatus.accepted:
                          statusColor = AppColors.warning;
                          nextStatus = OrderStatus.preparing;
                          actionBtnText = 'START PREPARING';
                          break;
                        case OrderStatus.preparing:
                          statusColor = AppColors.spicyOrange;
                          nextStatus = OrderStatus.ready;
                          actionBtnText = 'MARK AS READY';
                          break;
                        case OrderStatus.ready:
                          statusColor = AppColors.success;
                          nextStatus = OrderStatus.served;
                          actionBtnText = 'SERVED / PICKED UP';
                          break;
                        default:
                          statusColor = AppColors.textMuted;
                          nextStatus = OrderStatus.served;
                          actionBtnText = 'DONE';
                      }

                      return GlassCard(
                        borderColor: statusColor,
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Ticket Header
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  order.orderNumber,
                                  style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                                StatusBadge(label: '${elapsedMins}m elapsed', color: elapsedMins > 15 ? AppColors.danger : AppColors.warning),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              order.tableName ?? 'Type: ${order.type.name.toUpperCase()}',
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                            ),
                            const Divider(height: 14),

                            // Items List
                            Expanded(
                              child: ListView.builder(
                                itemCount: order.items.length,
                                itemBuilder: (context, i) {
                                  final item = order.items[i];
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 6.0),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('${item.quantity}x ', style: const TextStyle(color: AppColors.primaryRed, fontWeight: FontWeight.bold)),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(item.item.name, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
                                              Text('${item.selectedSize} • ${item.selectedCrust}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),


                            const SizedBox(height: 8),

                            // Workflow Action Button
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: statusColor,
                                minimumSize: const Size.fromHeight(40),
                              ),
                              onPressed: () => kitchenNotifier.updateOrderStatus(order.id, nextStatus),
                              child: Text(actionBtnText, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                          ],
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
