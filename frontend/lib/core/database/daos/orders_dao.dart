import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/local_orders_tables.dart';
import '../tables/sync_outbox_table.dart';
import '../tables/offline_print_jobs_table.dart';

part 'orders_dao.g.dart';

@DriftAccessor(tables: [
  LocalOrders,
  LocalOrderItems,
  LocalOrderPayments,
  SyncOutbox,
  OfflinePrintJobs,
])
class OrdersDao extends DatabaseAccessor<AppDatabase> with _$OrdersDaoMixin {
  OrdersDao(super.db);

  /// Atomic "save order + items + payment + outbox row + print job placeholder"
  /// in one single ACID Drift transaction per Architecture Spec §5.2 and §11.
  /// If any part of this operation fails, the transaction rolls back cleanly,
  /// leaving zero orphaned rows.
  Future<void> saveOrderAtomic({
    required LocalOrdersCompanion order,
    required List<LocalOrderItemsCompanion> items,
    required List<LocalOrderPaymentsCompanion> payments,
    required SyncOutboxCompanion outboxEntry,
    OfflinePrintJobsCompanion? printJob,
  }) {
    return transaction(() async {
      await into(localOrders).insert(order);
      for (final item in items) {
        await into(localOrderItems).insert(item);
      }
      for (final payment in payments) {
        await into(localOrderPayments).insert(payment);
      }
      await into(syncOutbox).insert(outboxEntry);
      if (printJob != null) {
        await into(offlinePrintJobs).insert(printJob);
      }
    });
  }

  Future<LocalOrder?> getOrderById(String id) {
    return (select(localOrders)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<List<LocalOrderItem>> getOrderItems(String orderId) {
    return (select(localOrderItems)..where((t) => t.orderId.equals(orderId))).get();
  }

  Future<List<LocalOrderPayment>> getOrderPayments(String orderId) {
    return (select(localOrderPayments)..where((t) => t.orderId.equals(orderId))).get();
  }

  Stream<List<LocalOrder>> watchAllOrders() {
    return (select(localOrders)..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).watch();
  }

  Stream<List<LocalOrder>> watchPendingOrders() {
    return (select(localOrders)
      ..where((t) => t.syncStatus.equals('pending_insert') | t.syncStatus.equals('pending_update'))
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
      .watch();
  }

  Future<int> markOrderSynced(String orderId, int serverVersion, DateTime serverUpdatedAt) {
    return (update(localOrders)..where((t) => t.id.equals(orderId))).write(
      LocalOrdersCompanion(
        syncStatus: const Value('synced'),
        serverVersion: Value(serverVersion),
        serverUpdatedAt: Value(serverUpdatedAt),
      ),
    );
  }

  Future<int> updateReassignedOrderNumber(String orderId, String newOrderNumber) {
    return (update(localOrders)..where((t) => t.id.equals(orderId))).write(
      LocalOrdersCompanion(
        orderNumber: Value(newOrderNumber),
      ),
    );
  }

  Future<int> markOrderConflict(String orderId) {
    return (update(localOrders)..where((t) => t.id.equals(orderId))).write(
      const LocalOrdersCompanion(
        syncStatus: Value('conflict'),
      ),
    );
  }

  Future<int> deleteOrder(String id) {
    return (delete(localOrders)..where((t) => t.id.equals(id))).go();
  }
}
