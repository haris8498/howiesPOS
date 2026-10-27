import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/sync/outbox_drain_gate.dart';
import '../../core/sync/sync_providers.dart';
import '../../domain/models/order_model.dart';
import '../../domain/repositories/order_repository.dart';
import '../../services/api/api_providers.dart';
import 'api_order_repository.dart';
import 'drift_offline_first_order_repository.dart';

/// Legacy REST API Order Repository provider.
final apiOrderRepositoryProvider = Provider<ApiOrderRepository>((ref) {
  final apiService = ref.watch(ordersApiServiceProvider);
  return ApiOrderRepository(ordersApiService: apiService);
});

/// Drift Offline-First Order Repository provider (Spec §17.2).
final driftOfflineFirstOrderRepositoryProvider =
    Provider<DriftOfflineFirstOrderRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return DriftOfflineFirstOrderRepository(
    db: db,
    terminalId: '1',
    deviceId: 'POS-P1',
  );
});

/// Order Repository Seam Provider per Architecture Spec §17.2 & Decision D-04:
/// - Uses the local-first path if `flag == true` OR `outbox` is non-empty (`drainGate.shouldUseLocalFirst`).
/// - The online-only path is chosen ONLY when `flag == false` AND `outbox` is empty.
/// - Never switch routing silently with rows pending.
final orderRepositoryProvider = Provider<IOrderRepository>((ref) {
  final drainGate = ref.watch(outboxDrainGateProvider);
  if (drainGate.shouldUseLocalFirst) {
    return ref.watch(driftOfflineFirstOrderRepositoryProvider);
  } else {
    return ref.watch(apiOrderRepositoryProvider);
  }
});

/// Reactive stream of all orders watched from the active repository (Drift stream).
final allOrdersStreamProvider = StreamProvider<List<OrderModel>>((ref) {
  final drainGate = ref.watch(outboxDrainGateProvider);
  if (drainGate.shouldUseLocalFirst) {
    final repo = ref.watch(driftOfflineFirstOrderRepositoryProvider);
    return repo.watchAllOrders();
  }
  return const Stream.empty();
});

/// Reactive stream of pending orders awaiting synchronization.
final pendingOrdersStreamProvider = StreamProvider<List<OrderModel>>((ref) {
  final drainGate = ref.watch(outboxDrainGateProvider);
  if (drainGate.shouldUseLocalFirst) {
    final repo = ref.watch(driftOfflineFirstOrderRepositoryProvider);
    return repo.watchPendingOrders();
  }
  return const Stream.empty();
});
