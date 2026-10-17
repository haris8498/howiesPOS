import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/app_colors.dart';
import '../../data/inventory_repository.dart';
import '../../data/pos_repository.dart';
import '../../data/table_repository.dart';
import '../../domain/models/menu_item.dart';
import '../../domain/models/order_model.dart';
import '../../domain/models/restaurant_table.dart';
import '../../shared/widgets/glass_card.dart';
import '../../shared/widgets/status_badge.dart';
import '../../services/receipt_printer_service.dart';

class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final posState = ref.watch(posProvider);
    final posNotifier = ref.read(posProvider.notifier);
    final tableState = ref.watch(tableProvider);

    final categories = posState.categories.isNotEmpty
        ? posState.categories
        : const ['All', 'Pizza', 'Burgers', 'Deals', 'Fries', 'Drinks', 'Desserts', 'Addons'];

    final filteredItems = posState.menuItems.where((item) {
      final matchesCategory = posState.selectedCategory == 'All' || item.category == posState.selectedCategory;
      final matchesSearch = item.name.toLowerCase().contains(posState.searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();


    return Row(
      children: [
        // Left Side: Categories Sidebar (Light Theme)
        Container(
          width: 190,
          color: AppColors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.all(14.0),
                child: Text(
                  'EXPLORE CATEGORIES',
                  style: TextStyle(
                    color: AppColors.primaryRed,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final cat = categories[index];
                    final isSelected = posState.selectedCategory == cat;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      child: Material(
                        color: isSelected ? AppColors.primaryRed : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        clipBehavior: Clip.antiAlias,
                        child: ListTile(
                          dense: true,
                          title: Text(
                            cat,
                            style: TextStyle(
                              color: isSelected ? Colors.white : AppColors.textPrimary,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                          onTap: () => posNotifier.setCategory(cat),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),

        // Center: Search & Products Grid (White UI)
        Expanded(
          child: Container(
            color: AppColors.offWhite,
            child: Column(
              children: [
                // Top Action & Order Type Selector Button
                Container(
                  padding: const EdgeInsets.all(12),
                  color: AppColors.white,
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: posNotifier.setSearchQuery,
                          decoration: InputDecoration(
                            hintText: 'Search Pizza, Burgers, Deals, Fries, Drinks...',
                            prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primaryRed),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      _searchController.clear();
                                      posNotifier.setSearchQuery('');
                                    },
                                  )
                                : null,
                            contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Tables Button
                      ElevatedButton.icon(
                        icon: const Icon(Icons.table_restaurant_rounded, size: 18),
                        label: Text(posState.selectedTable == null ? 'Tables' : 'Table: ${posState.selectedTable!.name}'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryRed,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        onPressed: () => _showSelectTableDialog(context, ref, tableState),
                      ),
                      const SizedBox(width: 8),
                      // Order Type Launcher Button
                      OutlinedButton.icon(
                        icon: const Icon(Icons.swap_calls_rounded, size: 16),
                        label: Text('Type: ${posState.selectedOrderType.name.toUpperCase()}'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primaryRed,
                          side: const BorderSide(color: AppColors.primaryRed),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        onPressed: () => _showOrderTypeSelectionModal(context, ref, posNotifier),
                      ),
                    ],
                  ),
                ),

                // Product Cards Grid
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(14),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 220,
                      childAspectRatio: 0.78,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: filteredItems.length,
                    itemBuilder: (context, index) {
                      final item = filteredItems[index];
                      return GlassCard(
                        padding: const EdgeInsets.all(10),
                        onTap: () => _showAddToCartModal(context, ref, item),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                item.imageUrl,
                                height: 100,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  height: 100,
                                  color: AppColors.offWhite,
                                  child: const Icon(Icons.local_pizza_rounded, color: AppColors.primaryRed, size: 36),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                if (item.isVeg)
                                  const Padding(
                                    padding: EdgeInsets.only(right: 4),
                                    child: StatusBadge(label: 'VEG', color: AppColors.vegGreen),
                                  ),
                                if (item.isSpicy)
                                  const StatusBadge(label: 'HOT', color: AppColors.spicyOrange),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            const Spacer(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'PKR ${item.basePrice.toStringAsFixed(0)}',
                                  style: const TextStyle(color: AppColors.primaryRed, fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: const BoxDecoration(
                                    color: AppColors.primaryRed,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.add, color: Colors.white, size: 14),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),

        // Right Side: Cart & Bill Summary (Toast POS White Layout)
        Container(
          width: 360,
          color: AppColors.white,
          child: Column(
            children: [
              // Order Header & Contextual Details
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.borderGray)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'ORDER CART',
                              style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            const SizedBox(width: 8),
                            if (posState.selectedOrderType == OrderType.takeAway)
                              StatusBadge(label: 'TOKEN TK-${posState.takeAwayTokenCounter}', color: AppColors.primaryRed),
                          ],
                        ),
                        if (posState.currentCart.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                            onPressed: () {
                              posNotifier.clearCart();
                            },
                            tooltip: 'Clear Cart',
                          ),
                      ],
                    ),

                    // Contextual Inputs based on Order Type
                    if (posState.selectedOrderType == OrderType.dineIn) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.table_restaurant_rounded, size: 14),
                              label: Text(posState.selectedTable == null ? 'Select Table' : posState.selectedTable!.name),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: posState.selectedTable == null ? AppColors.offWhite : AppColors.success,
                                foregroundColor: posState.selectedTable == null ? AppColors.textPrimary : Colors.white,
                                minimumSize: const Size.fromHeight(36),
                              ),
                              onPressed: () => _showSelectTableDialog(context, ref, tableState),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.offWhite,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.borderGray),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.person_rounded, size: 14, color: AppColors.textSecondary),
                                const SizedBox(width: 4),
                                Text('${posState.guestCount} Guests', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ] else if (posState.selectedOrderType == OrderType.delivery) ...[
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () => _showDeliveryAddressModal(context, posNotifier),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.offWhite,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.borderGray),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.location_on_rounded, color: AppColors.primaryRed, size: 16),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  posState.deliveryAddress ?? 'Set Customer Delivery Address',
                                  style: TextStyle(
                                    color: posState.deliveryAddress != null ? AppColors.textPrimary : AppColors.textMuted,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Icon(Icons.edit, size: 14, color: AppColors.textSecondary),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Cart Items List
              Expanded(
                child: posState.currentCart.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.shopping_cart_outlined, color: AppColors.textMuted, size: 44),
                            SizedBox(height: 10),
                            Text('Cart is empty', style: TextStyle(color: AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.bold)),
                            Text('Select items from product grid', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(10),
                        itemCount: posState.currentCart.length,
                        separatorBuilder: (context, index) => const Divider(height: 10),
                        itemBuilder: (context, index) {
                          final item = posState.currentCart[index];
                          return Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item.item.name, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
                                    Text('${item.selectedSize} • ${item.selectedCrust}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                                    Text('PKR ${item.unitPrice.toStringAsFixed(0)} x ${item.quantity}', style: const TextStyle(color: AppColors.primaryRed, fontSize: 12, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline, color: AppColors.textSecondary, size: 18),
                                    onPressed: () => posNotifier.updateQuantity(index, item.quantity - 1),
                                  ),
                                  Text('${item.quantity}', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle_outline, color: AppColors.primaryRed, size: 18),
                                    onPressed: () => posNotifier.updateQuantity(index, item.quantity + 1),
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
              ),

              // Summary Calculations & Action Buttons
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: AppColors.offWhite,
                  border: Border(top: BorderSide(color: AppColors.borderGray)),
                ),
                child: Column(
                  children: [
                    _buildDiscountControls(context, posState, posNotifier),
                    const SizedBox(height: 8),
                    _buildSummaryRow('Subtotal', 'PKR ${posState.subtotal.toStringAsFixed(0)}'),
                    if (posState.effectiveDiscountAmount > 0)
                      _buildSummaryRow(
                        'Discount (${posState.effectiveDiscountPercentage.toStringAsFixed(0)}%)',
                        '-PKR ${posState.effectiveDiscountAmount.toStringAsFixed(0)}',
                        isDiscount: true,
                      ),
                    if (posState.selectedOrderType == OrderType.dineIn || posState.selectedOrderType == OrderType.quickOrder)
                      _buildSummaryRow('Dine-In Tax (${posState.taxPercentage}%)', 'PKR ${posState.taxAmount.toStringAsFixed(0)}'),
                    if (posState.selectedOrderType == OrderType.dineIn || posState.selectedOrderType == OrderType.quickOrder)
                      _buildSummaryRow('Service Charge (${posState.serviceChargePercentage}%)', 'PKR ${posState.serviceChargeAmount.toStringAsFixed(0)}'),
                    if (posState.selectedOrderType == OrderType.delivery || posState.selectedOrderType == OrderType.online)
                      _buildSummaryRow('Delivery Fee', 'PKR ${posState.deliveryFee.toStringAsFixed(0)}'),
                    const Divider(height: 14),
                    _buildSummaryRow('GRAND TOTAL', 'PKR ${posState.grandTotal.toStringAsFixed(0)}', isTotal: true),
                    const SizedBox(height: 8),

                    // KOT Trigger & Hold/Split Row
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.soup_kitchen_rounded, color: AppColors.primaryRed, size: 14),
                            label: const Text('Send KOT'),
                            onPressed: posState.currentCart.isEmpty
                                ? null
                                : () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Kitchen Order Ticket (KOT) sent to KDS terminal!'),
                                        backgroundColor: AppColors.primaryRed,
                                      ),
                                    );
                                  },
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.pause_circle_outline_rounded, size: 14),
                            label: const Text('Hold'),
                            onPressed: posState.currentCart.isEmpty ? null : () => posNotifier.holdOrder(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryRed,
                        minimumSize: const Size.fromHeight(44),
                      ),
                      onPressed: posState.currentCart.isEmpty ? null : () => _showPaymentModal(context, ref, posState),
                      child: const Text('PAYMENT & GENERATE BILL', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDiscountControls(BuildContext context, PosState posState, PosNotifier posNotifier) {
    final discountPresets = [0.0, 5.0, 10.0, 15.0, 20.0, 25.0];
    final currentPct = posState.effectiveDiscountPercentage;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderGray),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.percent_rounded, size: 14, color: AppColors.success),
                  SizedBox(width: 4),
                  Text('Discount (%):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.textPrimary)),
                ],
              ),
              InkWell(
                onTap: () => _showCustomDiscountDialog(context, posState, posNotifier),
                child: Text(
                  currentPct > 0 ? '${currentPct.toStringAsFixed(0)}% OFF (Tap to Edit)' : 'Custom %',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: currentPct > 0 ? AppColors.success : AppColors.primaryRed,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: discountPresets.map((pct) {
                final isSelected = (currentPct - pct).abs() < 0.01;
                return Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: InkWell(
                    onTap: () => posNotifier.applyDiscountPercentage(pct),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.success : AppColors.offWhite,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isSelected ? AppColors.success : AppColors.borderGray,
                        ),
                      ),
                      child: Text(
                        '${pct.toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  void _showCustomDiscountDialog(BuildContext context, PosState posState, PosNotifier posNotifier) {
    final controller = TextEditingController(text: posState.effectiveDiscountPercentage > 0 ? posState.effectiveDiscountPercentage.toStringAsFixed(0) : '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.percent_rounded, color: AppColors.success),
            SizedBox(width: 8),
            Text('Set Discount in %', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter discount percentage to apply on customer bill:',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Discount Percentage',
                suffixText: '%',
                hintText: 'e.g. 10, 15, 25',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Subtotal: PKR ${posState.subtotal.toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              posNotifier.applyDiscountPercentage(0.0);
              Navigator.pop(context);
            },
            child: const Text('Clear (0%)', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            onPressed: () {
              final parsed = double.tryParse(controller.text.trim()) ?? 0.0;
              posNotifier.applyDiscountPercentage(parsed);
              Navigator.pop(context);
            },
            child: const Text('Apply Discount'),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isDiscount = false, bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isTotal ? AppColors.textPrimary : AppColors.textSecondary,
              fontSize: isTotal ? 14 : 11,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: isDiscount ? AppColors.success : (isTotal ? AppColors.primaryRed : AppColors.textPrimary),
              fontSize: isTotal ? 16 : 11,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _showOrderTypeSelectionModal(BuildContext context, WidgetRef ref, PosNotifier notifier) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Order Type'),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTypeCard(
                title: 'Dine In',
                subtitle: 'Table Selection, Guest Count, Waiter & KOT Ticket',
                icon: Icons.restaurant_rounded,
                color: AppColors.success,
                onTap: () {
                  notifier.setOrderType(OrderType.dineIn);
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 10),
              _buildTypeCard(
                title: 'Take Away',
                subtitle: 'Quick Order Billing & Token Number Generation',
                icon: Icons.shopping_bag_rounded,
                color: AppColors.primaryRed,
                onTap: () {
                  notifier.setOrderType(OrderType.takeAway);
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 10),
              _buildTypeCard(
                title: 'Delivery',
                subtitle: 'Customer Address, Delivery Fee & Rider Dispatch',
                icon: Icons.two_wheeler_rounded,
                color: AppColors.gold,
                onTap: () {
                  notifier.setOrderType(OrderType.delivery);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.offWhite,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.borderGray),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
                  Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddToCartModal(BuildContext context, WidgetRef ref, MenuItem item) {
    String selectedSize = item.availableSizes.isNotEmpty ? item.availableSizes.first : 'Regular';
    String selectedOption = item.availableCrustsOrBuns.isNotEmpty ? item.availableCrustsOrBuns.first : 'Original';

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.name, style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
              Text(item.description, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              const SizedBox(height: 16),
              const Text('SELECT SIZE:', style: TextStyle(color: AppColors.primaryRed, fontSize: 12, fontWeight: FontWeight.bold)),
              Wrap(
                spacing: 8,
                children: item.availableSizes.map((s) => ChoiceChip(
                  label: Text(s),
                  selected: selectedSize == s,
                  selectedColor: AppColors.primaryRed,
                  onSelected: (val) => setModalState(() => selectedSize = s),
                )).toList(),
              ),
              const SizedBox(height: 12),
              const Text('CRUST / BUN / OPTION:', style: TextStyle(color: AppColors.primaryRed, fontSize: 12, fontWeight: FontWeight.bold)),
              Wrap(
                spacing: 8,
                children: item.availableCrustsOrBuns.map((c) => ChoiceChip(
                  label: Text(c),
                  selected: selectedOption == c,
                  selectedColor: AppColors.primaryRed,
                  onSelected: (val) => setModalState(() => selectedOption = c),
                )).toList(),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                onPressed: () {
                  ref.read(posProvider.notifier).addToCart(item, size: selectedSize, crust: selectedOption);
                  Navigator.pop(context);
                },
                child: const Text('ADD TO ORDER CART'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSelectTableDialog(BuildContext context, WidgetRef ref, dynamic tableState) {
    String selectedFilter = 'All';
    final filters = ['All', 'Family Hall', 'Hall', 'Office', 'Free', 'Occupied', 'Reserved'];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final List<RestaurantTable> allTables = List<RestaurantTable>.from(tableState.tables);
          final filteredList = allTables.where((t) {
            if (selectedFilter == 'All') return true;
            if (selectedFilter == 'Family Hall') return t.section == 'Family Hall';
            if (selectedFilter == 'Hall') return t.section == 'Hall';
            if (selectedFilter == 'Office') return t.section == 'Office';
            if (selectedFilter == 'Free') return t.status == TableStatus.available;
            if (selectedFilter == 'Occupied') return t.status == TableStatus.occupied;
            if (selectedFilter == 'Reserved') return t.status == TableStatus.reserved;
            return true;
          }).toList();

          return AlertDialog(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Select Table', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                Text('${filteredList.length} Tables', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
              ],
            ),
            content: SizedBox(
              width: 520,
              height: 440,
              child: Column(
                children: [
                  // Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: filters.map((f) {
                        final isSel = selectedFilter == f;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6, bottom: 10),
                          child: ChoiceChip(
                            label: Text(f, style: TextStyle(fontSize: 12, color: isSel ? Colors.white : AppColors.textPrimary, fontWeight: FontWeight.bold)),
                            selected: isSel,
                            selectedColor: AppColors.primaryRed,
                            onSelected: (_) => setDialogState(() => selectedFilter = f),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Tables Grid
                  Expanded(
                    child: filteredList.isEmpty
                        ? const Center(child: Text('No tables match selected filter', style: TextStyle(color: AppColors.textMuted)))
                        : GridView.builder(
                            itemCount: filteredList.length,
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 4,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                              childAspectRatio: 1.0,
                            ),
                            itemBuilder: (context, index) {
                              final t = filteredList[index];
                              Color statusColor;
                              Color statusBgColor;
                              String statusText;

                              switch (t.status) {
                                case TableStatus.available:
                                  statusColor = const Color(0xFF2E7D32);
                                  statusBgColor = const Color(0xFFEBF7ED);
                                  statusText = 'FREE';
                                  break;
                                case TableStatus.occupied:
                                  statusColor = const Color(0xFFD32F2F);
                                  statusBgColor = const Color(0xFFFDF0F0);
                                  statusText = 'OCCUPIED';
                                  break;
                                case TableStatus.reserved:
                                  statusColor = const Color(0xFFD97706);
                                  statusBgColor = const Color(0xFFFFFBEB);
                                  statusText = 'RESERVED';
                                  break;
                              }

                              final bool hasBill = t.status == TableStatus.occupied && t.currentBillAmount > 0;

                              return InkWell(
                                onTap: () {
                                  ref.read(posProvider.notifier).setSelectedTable(t);
                                  Navigator.pop(context);
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: statusBgColor,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: statusColor, width: 1.8),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Text(
                                        t.name,
                                        style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 12),
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 3),
                                      if (hasBill)
                                        Text(
                                          'Bill: PKR ${t.currentBillAmount.toStringAsFixed(0)}',
                                          style: const TextStyle(color: AppColors.primaryRed, fontSize: 10, fontWeight: FontWeight.bold),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        )
                                      else
                                        Text(
                                          '${t.capacity} Seats',
                                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
                                        ),
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: statusColor,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          statusText,
                                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                                        ),
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
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showDeliveryAddressModal(BuildContext context, PosNotifier notifier) {
    showDialog(
      context: context,
      builder: (context) => _DeliveryAddressDialog(notifier: notifier),
    );
  }

  void _showPaymentModal(BuildContext context, WidgetRef ref, PosState posState) {
    PaymentMethod selectedPayment = PaymentMethod.cash;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text('Process Payment & Print Receipts'),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Bill Breakdown Card
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.offWhite,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.borderGray),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Subtotal:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          Text('PKR ${posState.subtotal.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      if (posState.effectiveDiscountAmount > 0) ...[
                        const SizedBox(height: 3),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Discount (${posState.effectiveDiscountPercentage.toStringAsFixed(0)}%):', style: const TextStyle(fontSize: 12, color: AppColors.success, fontWeight: FontWeight.bold)),
                            Text('-PKR ${posState.effectiveDiscountAmount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, color: AppColors.success, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                      if (posState.selectedOrderType == OrderType.dineIn || posState.selectedOrderType == OrderType.quickOrder) ...[
                        const SizedBox(height: 3),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Dine-In Tax (${posState.taxPercentage}%):', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            Text('PKR ${posState.taxAmount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ],
                      if (posState.selectedOrderType == OrderType.delivery || posState.selectedOrderType == OrderType.online) ...[
                        const SizedBox(height: 3),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Delivery Fee:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            Text('PKR ${posState.deliveryFee.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ],
                      const Divider(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('TOTAL BILL DUE:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                          Text(
                            'PKR ${posState.grandTotal.toStringAsFixed(0)}',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.primaryRed),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              RadioGroup<PaymentMethod>(
                groupValue: selectedPayment,
                onChanged: (val) {
                  if (val != null) setModalState(() => selectedPayment = val);
                },
                child: Column(
                  children: const [
                    RadioListTile<PaymentMethod>(
                      title: Text('Cash Payment'),
                      secondary: Icon(Icons.payments_rounded, color: AppColors.success),
                      value: PaymentMethod.cash,
                    ),
                    RadioListTile<PaymentMethod>(
                      title: Text('Card Terminal (Credit / Debit)'),
                      secondary: Icon(Icons.credit_card_rounded, color: AppColors.primaryRed),
                      value: PaymentMethod.card,
                    ),
                    RadioListTile<PaymentMethod>(
                      title: Text('Bank Direct Transfer'),
                      secondary: Icon(Icons.account_balance_rounded, color: AppColors.gold),
                      value: PaymentMethod.bankTransfer,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
              onPressed: () async {
                final order = await ref.read(posProvider.notifier).processOrderCheckout(selectedPayment);
                ref.read(inventoryProvider.notifier).triggerAutoDeductionForOrder(order.items);
                if (context.mounted) {
                  Navigator.pop(context);

                  // Physical Thermal Print to Attached Laptop Printer
                  await ReceiptPrinterService.printReceipt(
                    context: context,
                    receipt: ReceiptData.fromOrderModel(
                      order: order,
                      type: ReceiptType.customerReceipt,
                      paymentMethod: selectedPayment.name.toUpperCase(),
                      tenderedAmount: order.grandTotal,
                    ),
                  );
                }
              },
              child: const Text('CONFIRM PAYMENT & PRINT'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeliveryAddressDialog extends StatefulWidget {
  final PosNotifier notifier;
  const _DeliveryAddressDialog({required this.notifier});

  @override
  State<_DeliveryAddressDialog> createState() => _DeliveryAddressDialogState();
}

class _DeliveryAddressDialogState extends State<_DeliveryAddressDialog> {
  late final TextEditingController nameCtrl;
  late final TextEditingController phoneCtrl;
  late final TextEditingController addrCtrl;

  @override
  void initState() {
    super.initState();
    nameCtrl = TextEditingController(text: 'Robert Miller');
    phoneCtrl = TextEditingController(text: '+1 555-234-5678');
    addrCtrl = TextEditingController(text: '742 Evergreen Terrace, Metroville');
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    phoneCtrl.dispose();
    addrCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Delivery Customer & Address'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Customer Name')),
          const SizedBox(height: 10),
          TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Phone Number')),
          const SizedBox(height: 10),
          TextField(controller: addrCtrl, decoration: const InputDecoration(labelText: 'Delivery Street Address')),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            widget.notifier.setCustomerDetails(name: nameCtrl.text, phone: phoneCtrl.text, address: addrCtrl.text);
            Navigator.pop(context);
          },
          child: const Text('SAVE DELIVERY INFO'),
        ),
      ],
    );
  }
}
