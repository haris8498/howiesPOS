import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/api/api_providers.dart';

final reportFiltersProvider = StateProvider<Map<String, String?>>((ref) {
  return {'period': 'This Month'};
});

final reportSummaryProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final api = ref.watch(reportsApiServiceProvider);
  final filters = ref.watch(reportFiltersProvider);
  return api.getSummary(
    startDate: filters['startDate'],
    endDate: filters['endDate'],
    period: filters['period'],
  );
});

final reportProductsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final api = ref.watch(reportsApiServiceProvider);
  final filters = ref.watch(reportFiltersProvider);
  return api.getProductPerformance(
    startDate: filters['startDate'],
    endDate: filters['endDate'],
    period: filters['period'],
  );
});

final cancelledOrdersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final api = ref.watch(reportsApiServiceProvider);
  final filters = ref.watch(reportFiltersProvider);
  return api.getCancelledOrders(
    startDate: filters['startDate'],
    endDate: filters['endDate'],
    period: filters['period'],
  );
});
