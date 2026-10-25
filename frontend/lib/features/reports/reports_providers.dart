import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/feature_flags.dart';
import '../../core/sync/sync_providers.dart';
import '../../core/database/app_database.dart';
import '../../services/api/api_providers.dart';

final reportFiltersProvider = StateProvider<Map<String, String?>>((ref) {
  return {'period': 'This Month'};
});

/// Matches an order against active report filter period / dates (with offline fallback support)
bool _orderMatchesReportFilter(
  LocalOrder order,
  Map<String, String?> filters,
  LocalDailyCalculation? activeShift,
) {
  final s = order.status.toLowerCase();
  if (s == 'cancelled' || s == 'rejected') return false;

  final cleanPeriod = filters['period']?.toLowerCase().replaceAll(RegExp(r'[\s_-]'), '') ?? 'today';
  final now = DateTime.now();
  final shiftDate = activeShift != null
      ? DateTime(activeShift.createdAt.year, activeShift.createdAt.month, activeShift.createdAt.day)
      : DateTime(now.year, now.month, now.day);

  // If order explicitly belongs to active shift, always match for today/shift view
  if (activeShift != null && order.shiftId == activeShift.id) {
    if (cleanPeriod == 'today' || cleanPeriod == 'currentshift' || cleanPeriod == 'shift') {
      return true;
    }
  }

  final oDate = order.createdAt.toLocal();

  if (filters['startDate'] != null) {
    final start = DateTime.tryParse(filters['startDate']!);
    final end = filters['endDate'] != null ? DateTime.tryParse(filters['endDate']!) : null;
    if (start != null && oDate.isBefore(start)) return false;
    if (end != null && oDate.isAfter(end.add(const Duration(days: 1)))) return false;
    return true;
  }

  if (cleanPeriod == 'today' || cleanPeriod == 'currentshift' || cleanPeriod == 'shift') {
    return oDate.year == shiftDate.year && oDate.month == shiftDate.month && oDate.day == shiftDate.day;
  } else if (cleanPeriod == 'thisweek') {
    final weekStart = shiftDate.subtract(Duration(days: shiftDate.weekday - 1));
    return oDate.isAfter(weekStart.subtract(const Duration(seconds: 1)));
  } else if (cleanPeriod == 'thismonth') {
    return oDate.year == shiftDate.year && oDate.month == shiftDate.month;
  } else if (cleanPeriod == 'thisyear') {
    return oDate.year == shiftDate.year;
  } else if (cleanPeriod == 'lastyear') {
    return oDate.year == (shiftDate.year - 1);
  }

  return true;
}

final reportProductsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final api = ref.watch(reportsApiServiceProvider);
  final filters = ref.watch(reportFiltersProvider);

  List<Map<String, dynamic>> products = [];
  try {
    products = await api.getProductPerformance(
      startDate: filters['startDate'],
      endDate: filters['endDate'],
      period: filters['period'],
    );
  } catch (_) {}

  // Fallback: ONLY for live today shift if report API returned empty list
  final cleanPeriod = filters['period']?.toLowerCase().replaceAll(RegExp(r'[\s_-]'), '');
  final isTodayOrShift = cleanPeriod == 'today' || cleanPeriod == 'currentshift' || cleanPeriod == 'shift';
  if (isTodayOrShift && products.isEmpty && filters['startDate'] == null) {
    try {
      final ordersApi = ref.watch(ordersApiServiceProvider);
      final orders = await ordersApi.listOrders();
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);

      final Map<String, Map<String, dynamic>> aggregated = {};

      for (final ord in orders) {
        final status = (ord['status'] ?? '').toString().toLowerCase();
        if (status == 'cancelled' || status == 'rejected') continue;

        final createdRaw = ord['created_at'];
        if (createdRaw != null) {
          final dt = DateTime.tryParse(createdRaw.toString())?.toLocal();
          if (dt != null && dt.isBefore(todayStart)) {
            if (filters['period']?.toLowerCase() == 'today') continue;
          }
        }

        final items = ord['order_items'] as List? ?? [];
        for (final item in items) {
          if (item['is_cancelled'] == true) continue;
          final name = item['item_name']?.toString() ?? 'Item';
          final qty = ((item['quantity'] ?? 1) as num).toInt();
          final price = ((item['unit_price'] ?? 0) as num).toDouble();
          final total = ((item['total_price'] ?? (price * qty)) as num).toDouble();
          final category = item['category']?.toString() ??
              (item['menu_item']?['category']?['name']?.toString() ?? 'General');
          final imageUrl = item['image_url'] ?? item['menu_item']?['image_url'];

          if (aggregated.containsKey(name)) {
            aggregated[name]!['unitsSold'] = (aggregated[name]!['unitsSold'] as int) + qty;
            aggregated[name]!['totalRevenue'] = (aggregated[name]!['totalRevenue'] as double) + total;
          } else {
            aggregated[name] = {
              'productName': name,
              'category': category,
              'unitPrice': price,
              'unitsSold': qty,
              'totalRevenue': total,
              'image_url': imageUrl,
              'imagePath': imageUrl,
            };
          }
        }
      }
      if (aggregated.isNotEmpty) {
        products = aggregated.values.toList()
          ..sort((a, b) => (b['totalRevenue'] as num).compareTo(a['totalRevenue'] as num));
      }
    } catch (_) {}
  }

  // Offline SQLite Fallback for products across all periods
  if (products.isEmpty && FeatureFlags.offlineFirstEnabled) {
    try {
      final db = ref.watch(appDatabaseProvider);
      final activeShift = await db.dailyCalculationsDao.getAnyActiveCalculation();

      final localOrders = await (db.select(db.localOrders)
            ..where((t) => t.isDeleted.equals(false)))
          .get();

      final filteredOrders = localOrders.where((o) => _orderMatchesReportFilter(o, filters, activeShift)).toList();
      final orderIds = filteredOrders.map((o) => o.id).toSet();

      if (orderIds.isNotEmpty) {
        final allItems = await (db.select(db.localOrderItems)
              ..where((t) => t.isCancelled.equals(false)))
            .get();

        Map<String, String> itemCatMap = {};
        try {
          final menuItems = await db.select(db.localMenuItems).get();
          final categories = await db.select(db.localMenuCategories).get();
          final catMap = {for (final c in categories) c.id: c.name};
          itemCatMap = {
            for (final m in menuItems) m.name.trim().toLowerCase(): catMap[m.categoryId] ?? 'General'
          };
        } catch (_) {}

        final Map<String, Map<String, dynamic>> aggregated = {};

        for (final item in allItems) {
          if (!orderIds.contains(item.orderId)) continue;

          final name = item.itemName;
          final qty = item.quantity;
          final price = item.unitPrice;
          final total = item.subtotal;
          final category = itemCatMap[name.trim().toLowerCase()] ?? 'General';

          if (aggregated.containsKey(name)) {
            aggregated[name]!['unitsSold'] = (aggregated[name]!['unitsSold'] as int) + qty;
            aggregated[name]!['totalRevenue'] = (aggregated[name]!['totalRevenue'] as double) + total;
          } else {
            aggregated[name] = {
              'productName': name,
              'category': category,
              'unitPrice': price,
              'unitsSold': qty,
              'totalRevenue': total,
              'image_url': null,
              'imagePath': null,
            };
          }
        }

        if (aggregated.isNotEmpty) {
          products = aggregated.values.toList()
            ..sort((a, b) => (b['totalRevenue'] as num).compareTo(a['totalRevenue'] as num));
        }
      }
    } catch (_) {}
  }

  return products;
});

final reportSummaryProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final api = ref.watch(reportsApiServiceProvider);
  final filters = ref.watch(reportFiltersProvider);

  Map<String, dynamic> summary = {};
  try {
    summary = await api.getSummary(
      startDate: filters['startDate'],
      endDate: filters['endDate'],
      period: filters['period'],
    );
  } catch (_) {}

  final rev = ((summary['totalRevenue'] ?? 0) as num).toDouble();
  final ords = ((summary['totalOrders'] ?? 0) as num).toInt();

  // If online summary is empty or 0 revenue, calculate from SQLite local database!
  if (rev == 0 && ords == 0 && FeatureFlags.offlineFirstEnabled) {
    try {
      final db = ref.watch(appDatabaseProvider);
      final activeShift = await db.dailyCalculationsDao.getAnyActiveCalculation();

      final localOrders = await (db.select(db.localOrders)
            ..where((t) => t.isDeleted.equals(false)))
          .get();

      final matchingOrders = localOrders.where((o) => _orderMatchesReportFilter(o, filters, activeShift)).toList();

      if (matchingOrders.isNotEmpty) {
        double grossRevenue = 0.0;
        double totalSubtotal = 0.0;
        double totalDiscounts = 0.0;
        double totalTax = 0.0;

        for (final o in matchingOrders) {
          grossRevenue += o.grandTotal;
          totalSubtotal += o.subtotal;
          totalDiscounts += o.discountAmount;
          totalTax += o.taxAmount;
        }

        final matchingOrderIds = matchingOrders.map((o) => o.id).toSet();
        final allPayments = await db.select(db.localOrderPayments).get();
        final relevantPayments = allPayments.where((p) => matchingOrderIds.contains(p.orderId)).toList();

        double cashSales = 0.0;
        double cardSales = 0.0;
        double onlineSales = 0.0;

        for (final p in relevantPayments) {
          final m = p.paymentMethod.toLowerCase();
          if (m == 'cash') {
            cashSales += p.amount;
          } else if (m == 'card') {
            cardSales += p.amount;
          } else {
            onlineSales += p.amount;
          }
        }
        if (relevantPayments.isEmpty) {
          cashSales = grossRevenue;
        }

        // Calculate units sold directly from reportProductsProvider
        int computedUnits = 0;
        final prodsAsync = ref.watch(reportProductsProvider);
        final prods = prodsAsync.value ?? [];
        for (final p in prods) {
          computedUnits += ((p['unitsSold'] ?? 0) as num).toInt();
        }

        final double avgPrice = computedUnits > 0 ? (totalSubtotal / computedUnits) : 0.0;
        final topCategory = prods.isNotEmpty ? (prods.first['category']?.toString() ?? 'General') : 'General';

        return {
          'totalRevenue': grossRevenue,
          'totalCashSales': cashSales,
          'totalCardSales': cardSales,
          'totalOnlineSales': onlineSales,
          'totalSubtotal': totalSubtotal,
          'totalDiscount': totalDiscounts,
          'totalTax': totalTax,
          'totalOrders': matchingOrders.length,
          'totalUnitsSold': computedUnits,
          'avgItemPrice': avgPrice,
          'topCategory': topCategory,
          'totalExpenses': (summary['totalExpenses'] ?? 0),
          'netProfit': (grossRevenue - ((summary['totalExpenses'] ?? 0) as num).toDouble()),
          'dateRange': {
            'startDate': filters['startDate'] ?? DateTime.now().toIso8601String(),
            'endDate': filters['endDate'] ?? DateTime.now().toIso8601String(),
            'period': filters['period'] ?? 'Today',
          },
        };
      }
    } catch (_) {}
  }

  return summary;
});

final cancelledOrdersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final api = ref.watch(reportsApiServiceProvider);
  final filters = ref.watch(reportFiltersProvider);

  List<Map<String, dynamic>> cancelled = [];
  try {
    cancelled = await api.getCancelledOrders(
      startDate: filters['startDate'],
      endDate: filters['endDate'],
      period: filters['period'],
    );
  } catch (_) {}

  final cleanPeriod = filters['period']?.toLowerCase().replaceAll(RegExp(r'[\s_-]'), '');
  final isTodayOrShift = cleanPeriod == 'today' || cleanPeriod == 'currentshift' || cleanPeriod == 'shift';
  if (isTodayOrShift && cancelled.isEmpty && filters['startDate'] == null) {
    try {
      final ordersApi = ref.watch(ordersApiServiceProvider);
      final orders = await ordersApi.listOrders();
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);

      for (final ord in orders) {
        final status = (ord['status'] ?? '').toString().toLowerCase();
        final items = (ord['order_items'] as List? ?? []);
        final hasCancelledItem = items.any((i) => i['is_cancelled'] == true);
        final isCancelledOrder = (status == 'cancelled' || status == 'rejected');

        if (!isCancelledOrder && !hasCancelledItem) continue;

        final createdRaw = ord['created_at'];
        if (createdRaw != null) {
          final dt = DateTime.tryParse(createdRaw.toString())?.toLocal();
          if (dt != null && dt.isBefore(todayStart)) {
            if (filters['period']?.toLowerCase() == 'today') continue;
          }
        }

        final cancelledItems = items.where((i) => i['is_cancelled'] == true).map((i) => {
          'itemName': i['item_name'] ?? 'Item',
          'quantity': i['quantity'] ?? 1,
          'unitPrice': ((i['unit_price'] ?? 0) as num).toDouble(),
          'totalPrice': ((i['total_price'] ?? 0) as num).toDouble(),
          'cancelReason': i['cancel_reason'],
          'cancelledAt': i['cancelled_at'],
        }).toList();

        final activeItems = items.where((i) => i['is_cancelled'] != true).map((i) => {
          'itemName': i['item_name'] ?? 'Item',
          'quantity': i['quantity'] ?? 1,
          'unitPrice': ((i['unit_price'] ?? 0) as num).toDouble(),
          'totalPrice': ((i['total_price'] ?? 0) as num).toDouble(),
        }).toList();

        double cancelledValue = cancelledItems.fold(0.0, (s, i) => s + ((i['totalPrice'] ?? 0) as num).toDouble());
        if (isCancelledOrder && cancelledValue == 0) {
          cancelledValue = ((ord['grand_total'] ?? 0) as num).toDouble();
        }

        cancelled.add({
          'id': ord['id']?.toString() ?? '',
          'orderNumber': ord['order_number']?.toString() ?? '',
          'orderType': ord['order_type']?.toString() ?? 'Dine-In',
          'tableOrDetails': ord['dine_in_detail']?['table']?['name']?.toString() ??
              ord['takeaway_detail']?['token_number']?.toString() ?? '',
          'customerName': ord['customer_name']?.toString() ?? 'Guest',
          'cancelledItems': cancelledItems,
          'activeItems': activeItems,
          'grandTotal': ((ord['grand_total'] ?? 0) as num).toDouble(),
          'cancelledValue': cancelledValue,
          'createdAt': ord['created_at']?.toString() ?? DateTime.now().toIso8601String(),
          'cancelledAt': ord['updated_at']?.toString() ?? ord['created_at']?.toString(),
        });
      }
    } catch (_) {}
  }

  // Offline SQLite Fallback for cancelled orders across all periods
  if (cancelled.isEmpty && FeatureFlags.offlineFirstEnabled) {
    try {
      final db = ref.watch(appDatabaseProvider);
      final activeShift = await db.dailyCalculationsDao.getAnyActiveCalculation();

      final localOrders = await (db.select(db.localOrders)).get();
      final filteredOrders = localOrders.where((o) {
        if (activeShift != null && o.shiftId == activeShift.id) return true;
        final s = o.status.toLowerCase();
        return s == 'cancelled' || s == 'rejected' || _orderMatchesReportFilter(o, filters, activeShift);
      }).toList();

      final allItems = await db.select(db.localOrderItems).get();

      for (final ord in filteredOrders) {
        final ordItems = allItems.where((i) => i.orderId == ord.id).toList();
        final hasCancelled = ordItems.any((i) => i.isCancelled);
        final isCancelledOrd = ord.status.toLowerCase() == 'cancelled' || ord.status.toLowerCase() == 'rejected';

        if (!isCancelledOrd && !hasCancelled) continue;

        final cancelledItems = ordItems.where((i) => i.isCancelled).map((i) => {
          'itemName': i.itemName,
          'quantity': i.quantity,
          'unitPrice': i.unitPrice,
          'totalPrice': i.subtotal,
          'cancelReason': i.cancelReason,
          'cancelledAt': i.cancelledAt?.toIso8601String(),
        }).toList();

        final activeItems = ordItems.where((i) => !i.isCancelled).map((i) => {
          'itemName': i.itemName,
          'quantity': i.quantity,
          'unitPrice': i.unitPrice,
          'totalPrice': i.subtotal,
        }).toList();

        double cancelledVal = cancelledItems.fold(0.0, (s, i) => s + ((i['totalPrice'] ?? 0) as num).toDouble());
        if (isCancelledOrd && cancelledVal == 0) {
          cancelledVal = ord.grandTotal;
        }

        cancelled.add({
          'id': ord.id,
          'orderNumber': ord.orderNumber,
          'orderType': ord.orderType,
          'tableOrDetails': 'Table Order',
          'customerName': 'Guest',
          'cancelledItems': cancelledItems,
          'activeItems': activeItems,
          'grandTotal': ord.grandTotal,
          'cancelledValue': cancelledVal,
          'createdAt': ord.createdAt.toIso8601String(),
          'cancelledAt': ord.clientUpdatedAt.toIso8601String(),
        });
      }
    } catch (_) {}
  }

  return cancelled;
});
