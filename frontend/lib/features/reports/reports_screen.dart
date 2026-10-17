import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../config/app_colors.dart';
import '../../config/app_theme.dart';
import '../../data/auth_repository.dart';
import '../../data/role_rights_repository.dart';
import '../../domain/models/user_role.dart';
import '../../services/report_export_service.dart';
import '../../data/daily_calculation_repository.dart';

import 'reports_providers.dart';

class ProductReportData {
  final String productName;
  final String category;
  final String imagePath;
  final double unitPrice;
  final int unitsSold;
  final double totalRevenue;

  const ProductReportData({
    required this.productName,
    required this.category,
    required this.imagePath,
    required this.unitPrice,
    required this.unitsSold,
    required this.totalRevenue,
  });
}

String _resolveProductImage(String name, String category, String? rawImage) {
  if (rawImage != null && rawImage.trim().isNotEmpty) {
    return rawImage.trim();
  }

  final n = name.toLowerCase();
  final c = category.toLowerCase();

  // 1. Pizzas
  if (n.contains('crown') || n.contains('modern')) return 'assets/images/Modern.png';
  if (n.contains('arabic') || n.contains('cheese gold') || n.contains('special')) return 'assets/images/Special.png';
  if (n.contains('fajita') || n.contains('pizza') || c.contains('pizza')) return 'assets/images/Fajita.png';

  // 2. Steaks
  if (n.contains('steak') || n.contains('tarragon') || n.contains('mushroom') || n.contains('twin') || n.contains('jalapeno') || c.contains('steak')) {
    return 'assets/images/chicken_steak.png';
  }

  // 3. Burgers
  if (n.contains('beef') || n.contains('stacker') || n.contains('smashroom')) return 'assets/images/beef_burger_hero.jpg';
  if (n.contains('chicken burger') || n.contains('zinger') || n.contains('student burger') || n.contains('crispy bbq') || c.contains('burger')) {
    return 'assets/images/chicken_burger_hero.jpg';
  }

  // 4. Broast
  if (n.contains('broast') || n.contains('dajjaj') || c.contains('broast') || c.contains('brost')) return 'assets/images/broast_hero.jpg';

  // 5. Pastas
  if (n.contains('penne') || n.contains('arrabiata')) return 'assets/images/penne.png';
  if (n.contains('parmesan') || n.contains('permission')) return 'assets/images/Permission.png';
  if (n.contains('alfredo') || n.contains('pasta') || c.contains('pasta')) return 'assets/images/pasta_hero.jpg';

  // 6. Paninis
  if (n.contains('panini') || n.contains('sandwich') || c.contains('panini')) return 'assets/images/panini_hero.jpg';

  // 7. Appetizers & Wings
  if (n.contains('nugget')) return 'assets/images/Nuggets.png';
  if (n.contains('peri')) return 'assets/images/peri.png';
  if (n.contains('honey')) return 'assets/images/Honey.png';
  if (n.contains('wing') || c.contains('appetizer')) return 'assets/images/Wings.png';

  // 8. Fries
  if (n.contains('loaded')) return 'assets/images/Loaded.png';
  if (n.contains('mustard')) return 'assets/images/Mustard.png';
  if (n.contains('garlic')) return 'assets/images/Garlic.png';
  if (n.contains('masala')) return 'assets/images/Masala.png';
  if (n.contains('plain') || n.contains('salted') || n.contains('simple') || n.contains('fries') || c.contains('fries')) {
    return 'assets/images/Simple.png';
  }

  // 9. Hot & Cold Coffee
  if (n.contains('capachino') || n.contains('cappuccino')) return 'assets/images/Capachino.png';
  if (n.contains('espresso') || n.contains('expresso')) return 'assets/images/ExpressoDouble.png';
  if (n.contains('strawberry')) return 'assets/images/Strawberry.png';
  if (n.contains('caramel') || n.contains('cerimal')) return 'assets/images/Cerimal.png';
  if (c.contains('coffee')) return 'assets/images/Capachino.png';

  // 10. Desserts, Shakes & Ice Cream
  if (n.contains('pina') || n.contains('colada')) return 'assets/images/pina.png';
  if (n.contains('blueberry') || n.contains('mojito')) return 'assets/images/blueBerry.png';
  if (n.contains('mango')) return 'assets/images/MangoS.png';
  if (n.contains('chocolate')) return 'assets/images/ChocolateI.png';
  if (n.contains('banana')) return 'assets/images/BananaShake.png';
  if (n.contains('kulfa') || n.contains('ice cream') || c.contains('dessert') || c.contains('shake')) {
    return 'assets/images/ice_cream_hero.jpg';
  }

  // 11. Drinks & Soft Drinks
  if (n.contains('lime')) return 'assets/images/FreshLime.png';
  if (n.contains('mint') || n.contains('margarita')) return 'assets/images/Mint.png';
  if (n.contains('coke tin')) return 'assets/images/CokeTin.png';
  if (n.contains('sprite tin')) return 'assets/images/SpriteTin.png';
  if (n.contains('sprite')) return 'assets/images/Sprite.png';
  if (n.contains('water') || n.contains('mineral')) return 'assets/images/Mineral.png';
  if (n.contains('coke') || c.contains('drink') || c.contains('beverage')) return 'assets/images/Coke.png';

  // 12. Toppings & Sauces
  if (n.contains('cheese')) return 'assets/images/Cheese.png';
  if (n.contains('bbq') || n.contains('sauce')) return 'assets/images/BBqSauce.png';
  if (n.contains('mayo')) return 'assets/images/GarlicMayo.png';
  if (n.contains('potato') || n.contains('mesh')) return 'assets/images/MeshPatato.png';
  if (n.contains('jalapeno') || n.contains('jalapino')) return 'assets/images/Jalapino.png';

  // 13. Deals & Combos
  if (n.contains('deal') || n.contains('combo') || c.contains('deal')) return 'assets/images/Special.png';

  return 'assets/images/Fajita.png';
}

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  String _selectedDateFilter = 'This Month';
  DateTime _customSelectedDate = DateTime.now();
  String _selectedProductFilter = 'All Products';
  String _selectedCategoryFilter = 'All Categories';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authState = ref.read(authProvider);
      if (authState.currentUser.role == UserRole.cashier) {
        setState(() {
          _selectedDateFilter = 'Today';
        });
        ref.read(reportFiltersProvider.notifier).state = {'period': 'today'};
      }
    });
  }

  Future<void> _pickCustomDate(BuildContext context, bool isDark) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _customSelectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark
                ? const ColorScheme.dark(
                    primary: AppColors.primaryRed,
                    onPrimary: Colors.white,
                    surface: Color(0xFF1E293B),
                    onSurface: Colors.white,
                  )
                : const ColorScheme.light(
                    primary: AppColors.primaryRed,
                    onPrimary: Colors.white,
                    surface: Colors.white,
                    onSurface: AppColors.textPrimary,
                  ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _customSelectedDate = picked;
        _selectedDateFilter = 'Custom Date';
      });
      final dateFormatted =
          '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      ref.read(reportFiltersProvider.notifier).state = {
        'startDate': dateFormatted,
        'endDate': dateFormatted,
        'period': 'custom',
      };
    }
  }

  String _formatReportDate(dynamic raw) {
    if (raw == null) return '';
    try {
      final dt = DateTime.parse(raw.toString()).toLocal();
      return DateFormat('dd MMM, hh:mm a').format(dt);
    } catch (_) {
      return raw.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark;
    final authState = ref.watch(authProvider);
    final isCashier = authState.currentUser.role == UserRole.cashier;
    final calcState = ref.watch(dailyCalculationProvider);
    final hasActiveSession = calcState.hasActiveSession;
    final activeShiftDate = calcState.selectedRecord != null
        ? DateFormat('dd MMMM yyyy').format(calcState.selectedRecord!.date)
        : DateFormat('dd MMMM yyyy').format(DateTime.now());
    final canExport = ref.watch(roleRightsProvider).isActionGranted(
      authState.currentUser.role,
      'rep_export',
      defaultIfMissing: !isCashier,
    );

    final summaryAsync = ref.watch(reportSummaryProvider);
    final productsAsync = ref.watch(reportProductsProvider);
    final cancelledOrdersAsync = ref.watch(cancelledOrdersProvider);

    return productsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.primaryRed),
      ),
      error: (e, st) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 40),
              const SizedBox(height: 12),
              Text(
                'Error loading reports: $e',
                style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () {
                  ref.invalidate(reportSummaryProvider);
                  ref.invalidate(reportProductsProvider);
                  ref.invalidate(cancelledOrdersProvider);
                },
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Retry Database Fetch'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryRed,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
      data: (productsList) {
        final reportProducts = productsList.map((p) {
          final prodName = p['productName'] ?? '';
          final prodCat = p['category'] ?? 'General';
          final rawImg = p['image_url'] ?? p['imagePath'];
          return ProductReportData(
            productName: prodName,
            category: prodCat,
            unitPrice: (p['unitPrice'] ?? 0).toDouble(),
            unitsSold: p['unitsSold'] ?? 0,
            totalRevenue: (p['totalRevenue'] ?? 0).toDouble(),
            imagePath: _resolveProductImage(prodName, prodCat, rawImg),
          );
        }).toList();

        final categoriesList = ['All Categories', ...reportProducts.map((p) => p.category).toSet()];
        final productNamesList = ['All Products', ...reportProducts.map((p) => p.productName).toSet()];

        final filteredProducts = reportProducts.where((p) {
          final matchesProduct = _selectedProductFilter == 'All Products' || p.productName == _selectedProductFilter;
          final matchesCategory = _selectedCategoryFilter == 'All Categories' || p.category == _selectedCategoryFilter;
          return matchesProduct && matchesCategory;
        }).toList();

        final summary = summaryAsync.value ?? {};
        final totalSalesRevenue = (summary['totalRevenue'] ?? 0).toDouble();
        final totalCashSales = (summary['totalCashSales'] ?? 0).toDouble();
        final totalCardSales = (summary['totalCardSales'] ?? 0).toDouble();
        final totalOnlineSales = (summary['totalOnlineSales'] ?? 0).toDouble();
        final totalSubtotal = (summary['totalSubtotal'] ?? (summary['subtotal'] ?? 0)).toDouble();
        final totalDiscount = (summary['totalDiscount'] ?? (summary['discount_amount'] ?? 0)).toDouble();
        final totalTax = (summary['totalTax'] ?? (summary['tax_amount'] ?? 0)).toDouble();
        final totalUnitsSold = summary['totalUnitsSold'] ?? 0;
        final avgItemPrice = (summary['avgItemPrice'] ?? 0).toDouble();
        final totalExpenses = (summary['totalExpenses'] ?? 0).toDouble();
        final netProfit = (summary['netProfit'] ?? 0).toDouble();

    return Container(
      color: isDark ? const Color(0xFF090D16) : const Color(0xFFF8FAFC),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Banner & Actions Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primaryRed.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.analytics_rounded, color: AppColors.primaryRed, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isCashier ? 'TODAY\'S CASHIER SALES & PRODUCT REPORT' : 'EXECUTIVE SALES & PRODUCT REPORTS',
                          style: TextStyle(
                            color: isDark ? Colors.white : AppColors.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.6,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          isCashier
                              ? 'Live real-time metrics & shift product sales for Today (${DateFormat('EEEE, dd MMMM yyyy').format(DateTime.now())})'
                              : 'Analyze monthly, yearly, daily & product-wise sales reports with live metrics & figures',
                          style: TextStyle(
                            color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                // Actions Row (Refresh & Export Buttons)
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        ref.invalidate(reportSummaryProvider);
                        ref.invalidate(reportProductsProvider);
                        ref.invalidate(cancelledOrdersProvider);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Fetching latest data from database...'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                      icon: const Icon(Icons.refresh_rounded, size: 16, color: AppColors.primaryRed),
                      label: const Text('Refresh Data', style: TextStyle(color: AppColors.primaryRed, fontWeight: FontWeight.bold, fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.primaryRed),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    if (canExport) ...[
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () async {
                          if (filteredProducts.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('No report items available to export!'), backgroundColor: AppColors.danger),
                            );
                            return;
                          }

                          final exportItems = filteredProducts.map((p) {
                            return ReportExportItem(
                              productName: p.productName,
                              category: p.category,
                              unitPrice: p.unitPrice,
                              unitsSold: p.unitsSold,
                              totalRevenue: p.totalRevenue,
                            );
                          }).toList();

                          final success = await ReportExportService.exportToPdf(
                            items: exportItems,
                            periodFilter: isCashier
                                ? 'Today (${DateFormat('dd/MM/yyyy').format(DateTime.now())})'
                                : (_selectedDateFilter == 'Custom Date'
                                    ? 'Custom (${_customSelectedDate.day}/${_customSelectedDate.month}/${_customSelectedDate.year})'
                                    : _selectedDateFilter),
                            categoryFilter: _selectedCategoryFilter,
                            productFilter: _selectedProductFilter,
                            grossSubtotal: totalSubtotal > 0 ? totalSubtotal : totalSalesRevenue,
                            totalDiscount: totalDiscount,
                            totalTax: totalTax,
                          );

                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(success ? 'Sales report PDF exported successfully!' : 'Failed to export sales PDF report.'),
                                backgroundColor: success ? const Color(0xFF16A34A) : AppColors.danger,
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                        label: const Text('Export PDF'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryRed,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () async {
                          if (filteredProducts.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('No report items available to export!'), backgroundColor: AppColors.danger),
                            );
                            return;
                          }

                          final exportItems = filteredProducts.map((p) {
                            return ReportExportItem(
                              productName: p.productName,
                              category: p.category,
                              unitPrice: p.unitPrice,
                              unitsSold: p.unitsSold,
                              totalRevenue: p.totalRevenue,
                            );
                          }).toList();

                          final success = await ReportExportService.exportToExcelCsv(
                            items: exportItems,
                            periodFilter: isCashier
                                ? 'Today_${DateFormat('dd_MM_yyyy').format(DateTime.now())}'
                                : (_selectedDateFilter == 'Custom Date'
                                    ? 'Custom_${_customSelectedDate.day}_${_customSelectedDate.month}_${_customSelectedDate.year}'
                                    : _selectedDateFilter),
                            categoryFilter: _selectedCategoryFilter,
                            productFilter: _selectedProductFilter,
                            grossSubtotal: totalSubtotal > 0 ? totalSubtotal : totalSalesRevenue,
                            totalDiscount: totalDiscount,
                            totalTax: totalTax,
                          );

                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(success ? 'Sales report Excel exported successfully!' : 'Failed to export Excel file.'),
                                backgroundColor: success ? const Color(0xFF16A34A) : AppColors.danger,
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.table_chart_rounded, size: 16, color: Color(0xFF16A34A)),
                        label: const Text('Excel Export', style: TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF16A34A)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Top Filter Bar Card (Date Range, Custom Date Picker & Product Selector)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isCashier ? 'TODAY\'S SHIFT DATE & PRODUCT FILTERS' : 'REPORT CONTROLS & DATE/PRODUCT FILTERS',
                    style: const TextStyle(color: AppColors.primaryRed, fontWeight: FontWeight.w900, fontSize: 11.5, letterSpacing: 0.8),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (isCashier) ...[
                        // Locked to Today's date only for Cashier
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                          decoration: BoxDecoration(
                            color: (hasActiveSession ? AppColors.primaryRed : const Color(0xFF64748B)).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: (hasActiveSession ? AppColors.primaryRed : const Color(0xFF64748B)).withValues(alpha: 0.5), width: 1.5),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(hasActiveSession ? Icons.today_rounded : Icons.lock_clock_rounded, size: 18, color: hasActiveSession ? AppColors.primaryRed : const Color(0xFF64748B)),
                              const SizedBox(width: 8),
                              Text(
                                hasActiveSession
                                    ? 'ACTIVE SHIFT DATE: $activeShiftDate'
                                    : 'SHIFT CLOSED (START NEXT SHIFT TO BEGIN)',
                                style: TextStyle(
                                  color: hasActiveSession ? AppColors.primaryRed : const Color(0xFF64748B),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        // Date Filter Chips for Owner / Manager
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: ['Today', 'Last Year', 'This Month', 'This Year', 'Custom Date'].map((filter) {
                            final isSelected = _selectedDateFilter == filter;
                            return ChoiceChip(
                              label: Text(filter),
                              selected: isSelected,
                              selectedColor: AppColors.primaryRed,
                              labelStyle: TextStyle(
                                color: isSelected ? Colors.white : (isDark ? Colors.white : AppColors.textPrimary),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                              backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              onSelected: (_) async {
                                if (filter == 'Custom Date') {
                                  await _pickCustomDate(context, isDark);
                                } else {
                                  setState(() => _selectedDateFilter = filter);
                                  String periodMap = 'thismonth';
                                  if (filter == 'Today') periodMap = 'today';
                                  if (filter == 'Last Year') periodMap = 'year';
                                  if (filter == 'This Month') periodMap = 'thismonth';
                                  if (filter == 'This Year') periodMap = 'thisyear';
                                  ref.read(reportFiltersProvider.notifier).state = {'period': periodMap};
                                }
                              },
                            );
                          }).toList(),
                        ),

                        if (_selectedDateFilter == 'Custom Date') ...[
                          InkWell(
                            onTap: () => _pickCustomDate(context, isDark),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.primaryRed.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.primaryRed),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.primaryRed),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${_customSelectedDate.day}/${_customSelectedDate.month}/${_customSelectedDate.year}',
                                    style: const TextStyle(color: AppColors.primaryRed, fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.arrow_drop_down_rounded, size: 16, color: AppColors.primaryRed),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],

                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Product Selector Dropdown
                          SizedBox(
                            width: 200,
                            child: DropdownButtonFormField<String>(
                              isExpanded: true,
                              initialValue: productNamesList.contains(_selectedProductFilter) ? _selectedProductFilter : 'All Products',
                              decoration: InputDecoration(
                                labelText: 'Product Filter',
                                labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary, fontSize: 12),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                filled: true,
                                fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                              style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.bold),
                              items: productNamesList
                                  .map((pName) => DropdownMenuItem<String>(
                                        value: pName,
                                        child: Text(pName, overflow: TextOverflow.ellipsis),
                                      ))
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedProductFilter = val);
                              },
                            ),
                          ),

                          const SizedBox(width: 10),

                          // Category Selector Dropdown
                          SizedBox(
                            width: 160,
                            child: DropdownButtonFormField<String>(
                              isExpanded: true,
                              initialValue: categoriesList.contains(_selectedCategoryFilter) ? _selectedCategoryFilter : 'All Categories',
                              decoration: InputDecoration(
                                labelText: 'Category Filter',
                                labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary, fontSize: 12),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                filled: true,
                                fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                              style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.bold),
                              items: categoriesList
                                  .map((cName) => DropdownMenuItem<String>(
                                        value: cName,
                                        child: Text(cName, overflow: TextOverflow.ellipsis),
                                      ))
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedCategoryFilter = val);
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 1. Executive Financial Audit Metrics Row (Gross Subtotal, Discounts, Taxes, Net Revenue)
            Row(
              children: [
                Expanded(
                  child: _buildReportStatCard(
                    title: 'GROSS SUBTOTAL',
                    value: 'PKR ${(totalSubtotal > 0 ? totalSubtotal : totalSalesRevenue).toStringAsFixed(0)}',
                    subtitle: 'Base order menu total',
                    icon: Icons.receipt_long_rounded,
                    iconColor: const Color(0xFF2563EB),
                    bgColor: const Color(0xFFEFF6FF),
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _buildReportStatCard(
                    title: 'TOTAL DISCOUNTS',
                    value: 'PKR ${totalDiscount.toStringAsFixed(0)}',
                    subtitle: 'Special concession granted',
                    icon: Icons.local_offer_rounded,
                    iconColor: const Color(0xFFD97706),
                    bgColor: const Color(0xFFFFFBEB),
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _buildReportStatCard(
                    title: 'TAX COLLECTED',
                    value: 'PKR ${totalTax.toStringAsFixed(0)}',
                    subtitle: 'GST & Dine-In Tax',
                    icon: Icons.account_balance_rounded,
                    iconColor: const Color(0xFF7C3AED),
                    bgColor: const Color(0xFFF5F3FF),
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _buildReportStatCard(
                    title: 'NET REVENUE',
                    value: 'PKR ${totalSalesRevenue.toStringAsFixed(0)}',
                    subtitle: 'Cash: PKR ${totalCashSales.toStringAsFixed(0)}${totalCardSales + totalOnlineSales > 0 ? ' • Digital: PKR ${(totalCardSales + totalOnlineSales).toStringAsFixed(0)}' : ''}',
                    icon: Icons.monetization_on_rounded,
                    iconColor: AppColors.primaryRed,
                    bgColor: AppColors.primaryRed.withValues(alpha: 0.1),
                    isDark: isDark,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // 2. Operational Volume & Profitability Metrics Row
            Row(
              children: [
                Expanded(
                  child: _buildReportStatCard(
                    title: 'UNITS / DISHES SOLD',
                    value: '$totalUnitsSold Units',
                    subtitle: 'Kitchen units prepared',
                    icon: Icons.fastfood_rounded,
                    iconColor: const Color(0xFF16A34A),
                    bgColor: const Color(0xFFEBF7ED),
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _buildReportStatCard(
                    title: 'AVG ITEM PRICE',
                    value: 'PKR ${avgItemPrice.toStringAsFixed(0)}',
                    subtitle: 'Weighted avg / dish',
                    icon: Icons.shopping_bag_rounded,
                    iconColor: const Color(0xFF0284C7),
                    bgColor: const Color(0xFFF0F9FF),
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _buildReportStatCard(
                    title: 'TOTAL EXPENSES',
                    value: 'PKR ${totalExpenses.toStringAsFixed(0)}',
                    subtitle: 'Recorded store costs',
                    icon: Icons.money_off_rounded,
                    iconColor: const Color(0xFFEA580C),
                    bgColor: const Color(0xFFFFF7ED),
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _buildReportStatCard(
                    title: 'ESTIMATED NET PROFIT',
                    value: 'PKR ${netProfit.toStringAsFixed(0)}',
                    subtitle: 'Revenue minus expenses',
                    icon: Icons.trending_up_rounded,
                    iconColor: netProfit >= 0 ? const Color(0xFF059669) : AppColors.danger,
                    bgColor: netProfit >= 0 ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                    isDark: isDark,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Detailed Product Sales Breakdown Table
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Table Top Header Banner
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: const BoxDecoration(
                      gradient: AppColors.brandGradient,
                      borderRadius: BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.table_chart_rounded, color: Colors.white, size: 22),
                            const SizedBox(width: 10),
                            Text(
                              'PRODUCT SALES PERFORMANCE MATRIX — $_selectedDateFilter'.toUpperCase(),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 0.6),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.brandYellow,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${filteredProducts.length} ITEMS',
                            style: const TextStyle(color: AppColors.deepRed, fontSize: 10.5, fontWeight: FontWeight.w900),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Data Table
                  filteredProducts.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(40.0),
                          child: Center(
                            child: Column(
                              children: [
                                const Icon(Icons.search_off_rounded, size: 48, color: AppColors.textMuted),
                                const SizedBox(height: 12),
                                Text(
                                  'No sales records found for $_selectedProductFilter in $_selectedCategoryFilter',
                                  style: TextStyle(color: isDark ? Colors.white : AppColors.textSecondary, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: filteredProducts.length,
                          separatorBuilder: (context, index) => Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                          itemBuilder: (context, index) {
                            final p = filteredProducts[index];
                            final units = p.unitsSold;
                            final revenue = p.totalRevenue;
                            final percentage = totalSalesRevenue > 0 ? (revenue / totalSalesRevenue) * 100 : 0.0;

                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                              child: Row(
                                children: [
                                  // Image Preview
                                  _buildProductThumbnail(p.imagePath),
                                  const SizedBox(width: 14),

                                  // Name & Category
                                  Expanded(
                                    flex: 4,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          p.productName,
                                          style: TextStyle(
                                            color: isDark ? Colors.white : AppColors.textPrimary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            p.category.toUpperCase(),
                                            style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Unit Price
                                  SizedBox(
                                    width: 110,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('UNIT PRICE', style: TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 2),
                                        Text(
                                          'PKR ${p.unitPrice.toStringAsFixed(0)}',
                                          style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Units Sold
                                  SizedBox(
                                    width: 110,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('UNITS SOLD', style: TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 2),
                                        Text(
                                          '$units QTY',
                                          style: const TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.w900, fontSize: 13.5),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Revenue Generated & Share Progress
                                  SizedBox(
                                    width: 180,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          'PKR ${revenue.toStringAsFixed(0)}',
                                          style: const TextStyle(color: AppColors.primaryRed, fontWeight: FontWeight.w900, fontSize: 15),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            Expanded(
                                              child: ClipRRect(
                                                borderRadius: BorderRadius.circular(4),
                                                child: LinearProgressIndicator(
                                                  value: (percentage / 100).clamp(0.0, 1.0),
                                                  backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                                                  color: AppColors.primaryRed,
                                                  minHeight: 6,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              '${percentage.toStringAsFixed(1)}%',
                                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppColors.textPrimary),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Cancelled Orders Section
            _buildCancelledOrdersSection(
              cancelledOrdersAsync: cancelledOrdersAsync,
              isDark: isDark,
              numberFormat: NumberFormat('#,##0.00', 'en_US'),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
      },
    );
  }

  Widget _buildCancelledOrdersSection({
    required AsyncValue<List<Map<String, dynamic>>> cancelledOrdersAsync,
    required bool isDark,
    required NumberFormat numberFormat,
  }) {
    return cancelledOrdersAsync.when(
      loading: () => Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
        child: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => const SizedBox.shrink(),
      data: (orders) {
        final totalCancelledOrders = orders.length;
        final totalCancelledValue = orders.fold<double>(
          0.0,
          (sum, o) => sum + ((o['cancelledValue'] ?? 0) as num).toDouble(),
        );
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primaryRed, AppColors.primaryRed.withValues(alpha: 0.75)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.cancel_outlined, color: Colors.white, size: 22),
                        SizedBox(width: 10),
                        Text(
                          'CANCELLED ORDERS REPORT',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '$totalCancelledOrders ORDERS',
                            style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w900),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '−PKR ${numberFormat.format(totalCancelledValue)} CANCELLED',
                            style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w900),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (orders.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(40),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.check_circle_outline_rounded,
                          size: 48,
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No cancelled orders for this period',
                          style: TextStyle(
                            color: isDark ? const Color(0xFF64748B) : AppColors.textSecondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: orders.length,
                  separatorBuilder: (_, _) => Divider(
                    height: 1,
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                  ),
                  itemBuilder: (ctx, idx) {
                    final order = orders[idx];
                    final cancelledItems =
                        (order['cancelledItems'] as List? ?? []).cast<Map<String, dynamic>>();
                    final activeItems =
                        (order['activeItems'] as List? ?? []).cast<Map<String, dynamic>>();
                    final cancelledValue = ((order['cancelledValue'] ?? 0) as num).toDouble();
                    final grandTotal = ((order['grandTotal'] ?? 0) as num).toDouble();

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryRed.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: AppColors.primaryRed.withValues(alpha: 0.3)),
                                ),
                                child: Text(
                                  order['orderType']?.toString() ?? 'Dine-In',
                                  style: const TextStyle(
                                    color: AppColors.primaryRed,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Order #${order['orderNumber'] ?? '-'}',
                                style: TextStyle(
                                  color: isDark ? Colors.white : AppColors.textPrimary,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  '· ${order['tableOrDetails'] ?? ''}',
                                  style: TextStyle(
                                    color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (order['cancelledAt'] != null || order['createdAt'] != null) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                  decoration: BoxDecoration(
                                    color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(5),
                                    border: Border.all(
                                      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.access_time_rounded,
                                        size: 11,
                                        color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _formatReportDate(order['cancelledAt'] ?? order['createdAt']),
                                        style: TextStyle(
                                          color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              const SizedBox(width: 12),
                              if (cancelledValue > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryRed.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: AppColors.primaryRed.withValues(alpha: 0.3)),
                                  ),
                                  child: Text(
                                    '−PKR ${numberFormat.format(cancelledValue)}',
                                    style: const TextStyle(
                                      color: AppColors.primaryRed,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              const SizedBox(width: 8),
                              Text(
                                'Total: PKR ${numberFormat.format(grandTotal)}',
                                style: TextStyle(
                                  color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              ...cancelledItems.map(
                                (item) => Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF1A0A0A)
                                        : const Color(0xFFFFF5F5),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: AppColors.primaryRed.withValues(alpha: 0.35)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '${item['quantity']}x',
                                        style: const TextStyle(
                                          color: AppColors.primaryRed,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 11,
                                          decoration: TextDecoration.lineThrough,
                                          decorationColor: AppColors.primaryRed,
                                          decorationThickness: 2,
                                        ),
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        '${item['itemName']}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: isDark
                                              ? const Color(0xFF64748B)
                                              : const Color(0xFF94A3B8),
                                          decoration: TextDecoration.lineThrough,
                                          decorationColor: isDark
                                              ? const Color(0xFF64748B)
                                              : const Color(0xFF94A3B8),
                                          decorationThickness: 2,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 5, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryRed.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          'CANCELLED',
                                          style: TextStyle(
                                            color: AppColors.primaryRed,
                                            fontSize: 8,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0.4,
                                          ),
                                        ),
                                      ),
                                      if (item['cancelReason'] != null &&
                                          item['cancelReason'].toString().isNotEmpty &&
                                          item['cancelReason'].toString() != 'Order Cancelled') ...[
                                        const SizedBox(width: 5),
                                        Text(
                                          '(${item['cancelReason']})',
                                          style: TextStyle(
                                            color: AppColors.primaryRed.withValues(alpha: 0.85),
                                            fontSize: 9.5,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                              ...activeItems.map(
                                (item) => Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF0F172A)
                                        : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isDark
                                          ? const Color(0xFF334155)
                                          : const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  child: Text(
                                    '${item['quantity']}x ${item['itemName']}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.white : AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

    Widget _buildProductThumbnail(String imagePath) {
    final fallbackWidget = Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.primaryRed.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.fastfood_rounded, color: AppColors.primaryRed, size: 22),
    );

    final cleanPath = imagePath.trim();
    if (cleanPath.isEmpty) {
      return fallbackWidget;
    }

    if (cleanPath.startsWith('data:image') || (cleanPath.length > 100 && !cleanPath.startsWith('http') && !cleanPath.startsWith('assets/'))) {
      try {
        final base64Str = cleanPath.contains(',') ? cleanPath.split(',').last : cleanPath;
        final bytes = base64Decode(base64Str);
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            bytes,
            width: 44,
            height: 44,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => fallbackWidget,
          ),
        );
      } catch (_) {
        return fallbackWidget;
      }
    }

    if (cleanPath.startsWith('http://') || cleanPath.startsWith('https://')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          cleanPath,
          width: 44,
          height: 44,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => fallbackWidget,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.asset(
        cleanPath,
        width: 44,
        height: 44,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => fallbackWidget,
      ),
    );
  }

  Widget _buildReportStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: TextStyle(
                    color: isDark ? Colors.white : AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: isDark ? const Color(0xFF64748B) : AppColors.textMuted,
                    fontSize: 10,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
