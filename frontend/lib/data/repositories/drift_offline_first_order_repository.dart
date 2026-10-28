// ignore_for_file: prefer_initializing_formals
import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/app_database.dart';
import '../../core/database/tables/offline_print_jobs_table.dart';
import '../../core/database/tables/sync_outbox_table.dart';
import '../../domain/models/menu_item.dart';
import '../../domain/models/order_model.dart';
import '../../domain/repositories/order_repository.dart';
import '../../domain/services/order_number_generator.dart';

/// Offline-First Order Repository per Architecture Spec §17.2, §5.2, §11, §12.
///
/// Core Invariants:
/// 1. ACID Durability: Saving an order executes in ONE atomic SQLite transaction
///    writing order + items + payment + outbox mutation row + durable print job.
/// 2. ORDER SAVING != PRINTING (§15.4): The transaction commits to local SQLite WAL
///    and enqueues the outbox mutation first; the UI returns immediately without waiting
///    for network transmission or physical thermal printer completion.
/// 3. Entity Identity: RFC 9562 UUID v7 for monotonic B-tree indexing (§4.2).
/// 4. Receipt Sequencing: Terminal-prefixed sequential receipt numbers `P<terminal>-<seq>`
///    from TerminalSequences table (101..999, daily rollover) (§4.3).
/// 5. Duplicate-Submit Protection (§15.2 Tiers 1-3):
///    - Tier 1: In-memory lock per order ID to debounce rapid concurrent submissions.
///    - Tier 2: Primary key constraint on `local_orders.id` (UUID v7).
///    - Tier 3: Unique operation constraint on `sync_outbox.operation_id`.
/// 6. Reactive Streams: Watch streams from Drift automatically notify the UI.
class DriftOfflineFirstOrderRepository implements IOrderRepository {
  final AppDatabase _db;
  final String _terminalId;
  final String _deviceId;
  final Uuid _uuid;

  /// Tier 1 Concurrency Lock: Prevents duplicate concurrent in-flight submissions
  final Set<String> _inFlightOrderIds = {};

  DriftOfflineFirstOrderRepository({
    required AppDatabase db,
    String terminalId = '1',
    String deviceId = 'POS-P1',
    Uuid? uuid,
  })  : _db = db,
        _terminalId = terminalId,
        _deviceId = deviceId,
        _uuid = uuid ?? const Uuid();

  @override
  Future<OrderModel> saveOrder(OrderModel order) async {
    // ── Tier 1: In-memory concurrency guard ──────────────────
    if (_inFlightOrderIds.contains(order.id)) {
      final existing = await getOrderById(order.id);
      if (existing != null) return existing;
    }
    _inFlightOrderIds.add(order.id);

    try {
      // ── Tier 2: Check existing UUID v7 primary key in SQLite ─
      if (order.id.isNotEmpty) {
        final existing = await getOrderById(order.id);
        if (existing != null) {
          return existing;
        }
      }

      // ── ONE Atomic Drift Transaction (§5.2, §11, §12) ────────
      return await _db.transaction(() async {
        // Resolve active shift first to bind business date and prevent midnight rollover resets (SYNC-038)
        final activeShift = await _db.dailyCalculationsDao.getAnyActiveCalculation();
        final businessDate = activeShift?.createdAt ?? DateTime.now();
        final businessDateStr = DateFormat('yyyy-MM-dd').format(businessDate);

        // 1. Atomic receipt sequence increment from TerminalSequences (§4.3)
        final seq = await _db.terminalSequencesDao.getNextSequence(
          'ORDER_NUMBER',
          businessDateStr,
          start: 101,
          max: 999,
        );
        final receiptNumber = OrderNumberGenerator.formatReceiptNumber(_terminalId, seq);

        // Ensure RFC 9562 UUID v7 identifier
        final effectiveOrderId = (order.id.isNotEmpty && order.id.length == 36)
            ? order.id
            : _uuid.v7();

        String? resolvedShiftId = order.shiftId;
        if (resolvedShiftId == null || resolvedShiftId.isEmpty) {
          if (activeShift != null) {
            resolvedShiftId = activeShift.id;
          } else {
            final latestShift = await (_db.select(_db.localDailyCalculations)
              ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
              ..limit(1))
              .getSingleOrNull();
            if (latestShift != null) {
              resolvedShiftId = latestShift.id;
            }
          }
        }
        final finalOrder = order.copyWith(
          shiftId: resolvedShiftId,
          id: effectiveOrderId,
          orderNumber: (order.orderNumber.isNotEmpty && !order.orderNumber.startsWith('ORD-') && !order.orderNumber.startsWith('HH-TEMP')) ? order.orderNumber : receiptNumber,
        );

        // 2. Prepare LocalOrders row
        final orderCompanion = LocalOrdersCompanion(
          id: Value(finalOrder.id),
          orderNumber: Value(finalOrder.orderNumber),
          orderType: Value(finalOrder.type.name),
          shiftId: Value(finalOrder.shiftId),
          status: Value(finalOrder.status.name),
          subtotal: Value(finalOrder.subtotal),
          discountPercentage: Value(finalOrder.discountPercentage),
          discountAmount: Value(finalOrder.discountAmount),
          taxAmount: Value(finalOrder.taxAmount),
          grandTotal: Value(finalOrder.grandTotal),
          paymentStatus: Value(finalOrder.isPaid ? 'PAID' : 'UNPAID'),
          isPaid: Value(finalOrder.isPaid),
          isHeld: Value(finalOrder.isHeld),
          kitchenTicketSent: Value(finalOrder.kitchenTicketSent),
          rejectionReason: Value(finalOrder.rejectionReason),
          deviceId: Value(_deviceId),
          createdAt: Value(finalOrder.createdAt),
          syncStatus: const Value('pending_insert'),
          serverVersion: const Value(1),
          clientUpdatedAt: Value(DateTime.now()),
          isDeleted: const Value(false),
        );

        // 3. Prepare LocalOrderItems rows
        final itemCompanions = <LocalOrderItemsCompanion>[];
        for (final item in finalOrder.items) {
          final itemId = (item.id != null && item.id!.isNotEmpty && item.id!.length == 36)
              ? item.id!
              : _uuid.v7();
          itemCompanions.add(
            LocalOrderItemsCompanion(
              id: Value(itemId),
              orderId: Value(finalOrder.id),
              menuItemId: Value(item.item.id.isNotEmpty ? item.item.id : null),
              itemName: Value(item.item.name),
              sizeName: Value(item.selectedSize),
              unitPrice: Value(item.unitPrice),
              quantity: Value(item.quantity),
              subtotal: Value(item.totalPrice),
              notes: Value(item.notes.isNotEmpty ? item.notes : null),
              isCancelled: Value(item.isCancelled),
              cancelledAt: Value(item.cancelledAt),
              cancelReason: Value(item.cancelReason),
              voidedAt: Value(item.voidedAt),
              voidedBy: Value(item.voidedBy),
              supersedesItemId: Value(item.supersedesItemId),
              createdByDeviceId: Value(item.createdByDeviceId ?? _deviceId),
              clientCreatedAt: Value(item.clientCreatedAt ?? DateTime.now()),
              syncStatus: const Value('pending_insert'),
              serverVersion: const Value(1),
            ),
          );
        }

        // 4. Prepare LocalOrderPayments rows
        final paymentCompanions = <LocalOrderPaymentsCompanion>[];
        if (finalOrder.payments.isNotEmpty) {
          for (final p in finalOrder.payments) {
            final payId = (p.id != null && p.id!.isNotEmpty && p.id!.length == 36)
                ? p.id!
                : _uuid.v7();
            paymentCompanions.add(
              LocalOrderPaymentsCompanion(
                id: Value(payId),
                orderId: Value(finalOrder.id),
                paymentMethod: Value(p.paymentMethod),
                amount: Value(p.amount),
                tenderedAmount: Value(p.tenderedAmount),
                changeReturned: Value(p.changeReturned),
                transactionReference: Value(p.transactionReference),
                cardLastFour: Value(p.cardLastFour),
                bankName: Value(p.bankName),
                paymentStatus: Value(p.paymentStatus.isNotEmpty ? p.paymentStatus : 'COMPLETED'),
                receivedBy: Value(p.receivedBy),
                createdAt: Value(p.createdAt ?? DateTime.now()),
                syncStatus: const Value('pending_insert'),
              ),
            );
          }
        } else if (finalOrder.isPaid) {
          final payId = _uuid.v7();
          paymentCompanions.add(
            LocalOrderPaymentsCompanion(
              id: Value(payId),
              orderId: Value(finalOrder.id),
              paymentMethod: Value(finalOrder.paymentMethod?.name ?? 'cash'),
              amount: Value(finalOrder.grandTotal),
              tenderedAmount: Value(finalOrder.grandTotal),
              changeReturned: const Value(0.0),
              paymentStatus: const Value('COMPLETED'),
              receivedBy: Value(finalOrder.waiterName),
              createdAt: Value(DateTime.now()),
              syncStatus: const Value('pending_insert'),
            ),
          );
        }

        // 5. Prepare SyncOutbox row (Spec §6.1, §6.3: Level 2 Order Header)
        final operationId = _uuid.v7();
        final payloadMap = finalOrder.toCreateOrderDto();
        payloadMap['id'] = finalOrder.id;

        final outboxCompanion = SyncOutboxCompanion(
          operationId: Value(operationId),
          deviceId: Value(_deviceId),
          entityType: const Value('order'),
          entityId: Value(finalOrder.id),
          operationType: const Value('INSERT'),
          baseVersion: const Value(1),
          payload: Value(jsonEncode(payloadMap)),
          dependencyOrder: const Value(2), // Level 2: Order Header per Spec §6.3
          status: const Value(SyncOutboxStatus.pending),
          retryCount: const Value(0),
          createdAt: Value(DateTime.now()),
        );

        // 6. Prepare Durable Print Job (Spec §5.4.3, §15.4: ORDER SAVING != PRINTING)
        final receiptText = 'ORDER ${finalOrder.orderNumber}\n'
            'Type: ${finalOrder.type.name}\n'
            'Total: ${finalOrder.grandTotal.toStringAsFixed(2)}\n';
        final printJobCompanion = OfflinePrintJobsCompanion(
          jobType: const Value(PrintJobType.customerReceipt),
          orderId: Value(finalOrder.id),
          printerTarget: const Value('WIN_DEFAULT'),
          rawEscPosData: Value(Uint8List.fromList(utf8.encode(receiptText))),
          status: const Value(PrintJobStatus.queued),
          retryCount: const Value(0),
          createdAt: Value(DateTime.now()),
        );

        // 7. Atomic batch commit using OrdersDao.saveOrderAtomic
        await _db.ordersDao.saveOrderAtomic(
          order: orderCompanion,
          items: itemCompanions,
          payments: paymentCompanions,
          outboxEntry: outboxCompanion,
          printJob: printJobCompanion,
        );

        // Local transaction committed; return immediately to UI (<5ms)
        return finalOrder;
      });
    } finally {
      _inFlightOrderIds.remove(order.id);
    }
  }

  @override
  Future<OrderModel> updateOrder(OrderModel order) async {
    return await _db.transaction(() async {
      await (_db.update(_db.localOrders)..where((t) => t.id.equals(order.id))).write(
        LocalOrdersCompanion(
          subtotal: Value(order.subtotal),
          grandTotal: Value(order.grandTotal),
          discountPercentage: Value(order.discountPercentage),
          discountAmount: Value(order.discountAmount),
          taxAmount: Value(order.taxAmount),
          status: Value(order.status.name),
          paymentStatus: Value(order.isPaid ? 'PAID' : 'UNPAID'),
          isPaid: Value(order.isPaid),
          syncStatus: const Value('pending_update'),
          clientUpdatedAt: Value(DateTime.now()),
        ),
      );

      // Append-only ledger updates: diff -> ledger ops (D-05 / SYNC-032)
      if (order.items.isNotEmpty) {
        final existingItems = await _db.ordersDao.getOrderItems(order.id);
        final existingMap = {for (final i in existingItems) i.id: i};

        for (final item in order.items) {
          if (item.id != null && existingMap.containsKey(item.id)) {
            final oldItem = existingMap[item.id]!;
            final isVoidedOrCancelled = item.isCancelled || item.voidedAt != null;
            final wasVoidedOrCancelled = oldItem.isCancelled || oldItem.voidedAt != null;

            if (isVoidedOrCancelled && !wasVoidedOrCancelled) {
              final voidTime = item.voidedAt ?? item.cancelledAt ?? DateTime.now();
              await (_db.update(_db.localOrderItems)..where((t) => t.id.equals(item.id!))).write(
                LocalOrderItemsCompanion(
                  isCancelled: const Value(true),
                  cancelledAt: Value(voidTime),
                  cancelReason: Value(item.cancelReason),
                  voidedAt: Value(voidTime),
                  voidedBy: Value(item.voidedBy ?? item.cancelledBy ?? 'LOCAL_EDIT'),
                  syncStatus: const Value('pending_update'),
                ),
              );
            } else if (!isVoidedOrCancelled &&
                (oldItem.quantity != item.quantity ||
                    oldItem.sizeName != item.selectedSize ||
                    oldItem.notes != (item.notes.isNotEmpty ? item.notes : null) ||
                    oldItem.unitPrice != item.unitPrice)) {
              // Item modified: void old item and insert new superseding item
              final voidTime = DateTime.now();
              await (_db.update(_db.localOrderItems)..where((t) => t.id.equals(item.id!))).write(
                LocalOrderItemsCompanion(
                  isCancelled: const Value(true),
                  cancelledAt: Value(voidTime),
                  cancelReason: const Value('MODIFIED'),
                  voidedAt: Value(voidTime),
                  voidedBy: const Value('LOCAL_EDIT'),
                  syncStatus: const Value('pending_update'),
                ),
              );

              final newId = _uuid.v7();
              await _db.into(_db.localOrderItems).insert(
                LocalOrderItemsCompanion(
                  id: Value(newId),
                  orderId: Value(order.id),
                  menuItemId: Value(item.item.id.isNotEmpty ? item.item.id : null),
                  itemName: Value(item.item.name),
                  sizeName: Value(item.selectedSize),
                  unitPrice: Value(item.unitPrice),
                  quantity: Value(item.quantity),
                  subtotal: Value(item.totalPrice),
                  notes: Value(item.notes.isNotEmpty ? item.notes : null),
                  supersedesItemId: Value(oldItem.id),
                  createdByDeviceId: Value(_deviceId),
                  clientCreatedAt: Value(DateTime.now()),
                  syncStatus: const Value('pending_insert'),
                  serverVersion: const Value(1),
                ),
              );
            }
          } else {
            // New item appended
            final itemId = (item.id != null && item.id!.isNotEmpty && item.id!.length == 36)
                ? item.id!
                : _uuid.v7();
            await _db.into(_db.localOrderItems).insert(
              LocalOrderItemsCompanion(
                id: Value(itemId),
                orderId: Value(order.id),
                menuItemId: Value(item.item.id.isNotEmpty ? item.item.id : null),
                itemName: Value(item.item.name),
                sizeName: Value(item.selectedSize),
                unitPrice: Value(item.unitPrice),
                quantity: Value(item.quantity),
                subtotal: Value(item.totalPrice),
                notes: Value(item.notes.isNotEmpty ? item.notes : null),
                isCancelled: Value(item.isCancelled),
                cancelledAt: Value(item.cancelledAt),
                cancelReason: Value(item.cancelReason),
                voidedAt: Value(item.voidedAt),
                voidedBy: Value(item.voidedBy),
                supersedesItemId: Value(item.supersedesItemId),
                createdByDeviceId: Value(item.createdByDeviceId ?? _deviceId),
                clientCreatedAt: Value(item.clientCreatedAt ?? DateTime.now()),
                syncStatus: const Value('pending_insert'),
                serverVersion: const Value(1),
              ),
            );
          }
        }
      }

      // Record payments if any
      if (order.payments.isNotEmpty) {
        await (_db.delete(_db.localOrderPayments)..where((t) => t.orderId.equals(order.id))).go();
        for (final payment in order.payments) {
          final paymentId = (payment.id != null && payment.id!.isNotEmpty && payment.id!.length == 36)
              ? payment.id!
              : _uuid.v7();
          await _db.into(_db.localOrderPayments).insert(
            LocalOrderPaymentsCompanion(
              id: Value(paymentId),
              orderId: Value(order.id),
              paymentMethod: Value(payment.paymentMethod),
              amount: Value(payment.amount),
              tenderedAmount: Value(payment.tenderedAmount),
              changeReturned: Value(payment.changeReturned),
              transactionReference: Value(payment.transactionReference),
              cardLastFour: Value(payment.cardLastFour),
              bankName: Value(payment.bankName),
              paymentStatus: Value(payment.paymentStatus.isNotEmpty ? payment.paymentStatus : 'COMPLETED'),
              receivedBy: Value(payment.receivedBy),
              createdAt: Value(payment.createdAt ?? DateTime.now()),
              syncStatus: const Value('pending_update'),
            ),
          );
        }
      }

      // Enqueue UPDATE in outbox
      final opId = _uuid.v7();
      final payloadMap = order.toCreateOrderDto();
      payloadMap['id'] = order.id;

      await _db.outboxDao.insertEntry(
        SyncOutboxCompanion(
          operationId: Value(opId),
          deviceId: Value(_deviceId),
          entityType: const Value('order'),
          entityId: Value(order.id),
          operationType: const Value('UPDATE'),
          baseVersion: Value((await (_db.select(_db.localOrders)..where((t) => t.id.equals(order.id))).getSingleOrNull())?.serverVersion ?? 1),
          payload: Value(jsonEncode(payloadMap)),
          dependencyOrder: const Value(2),
          status: const Value(SyncOutboxStatus.pending),
          createdAt: Value(DateTime.now()),
        ),
      );

      return order;
    });
  }

  @override
  Future<List<OrderModel>> getAllOrders() async {
    final orders = await (_db.select(_db.localOrders)
      ..where((t) => t.isDeleted.equals(false))
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
      .get();

    final result = <OrderModel>[];
    for (final o in orders) {
      final items = await _db.ordersDao.getOrderItems(o.id);
      final payments = await _db.ordersDao.getOrderPayments(o.id);
      result.add(_mapToOrderModel(o, items, payments));
    }
    return result;
  }

  @override
  Future<OrderModel?> getOrderById(String id) async {
    final o = await _db.ordersDao.getOrderById(id);
    if (o == null || o.isDeleted) return null;
    final items = await _db.ordersDao.getOrderItems(id);
    final payments = await _db.ordersDao.getOrderPayments(id);
    return _mapToOrderModel(o, items, payments);
  }

  @override
  Future<List<OrderModel>> getCompletedOrders() async {
    final orders = await (_db.select(_db.localOrders)
      ..where((t) =>
          t.status.equals('completed') &
          t.isDeleted.equals(false))
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
      .get();

    final result = <OrderModel>[];
    for (final o in orders) {
      final items = await _db.ordersDao.getOrderItems(o.id);
      final payments = await _db.ordersDao.getOrderPayments(o.id);
      result.add(_mapToOrderModel(o, items, payments));
    }
    return result;
  }

  @override
  Future<List<OrderModel>> getHeldOrders() async {
    final orders = await (_db.select(_db.localOrders)
      ..where((t) => t.isHeld.equals(true) & t.isDeleted.equals(false))
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
      .get();

    final result = <OrderModel>[];
    for (final o in orders) {
      final items = await _db.ordersDao.getOrderItems(o.id);
      final payments = await _db.ordersDao.getOrderPayments(o.id);
      result.add(_mapToOrderModel(o, items, payments));
    }
    return result;
  }

  @override
  Future<void> updateOrderStatus(String orderId, OrderStatus status) async {
    // SYNC-026: Atomic local write and outbox mutation inside transaction
    await _db.transaction(() async {
      await (_db.update(_db.localOrders)..where((t) => t.id.equals(orderId))).write(
        LocalOrdersCompanion(
          status: Value(status.name),
          syncStatus: const Value('pending_update'),
          clientUpdatedAt: Value(DateTime.now()),
        ),
      );

      // Enqueue outbox mutation
      final opId = _uuid.v7();
      await _db.outboxDao.insertEntry(
        SyncOutboxCompanion(
          operationId: Value(opId),
          deviceId: Value(_deviceId),
          entityType: const Value('order'),
          entityId: Value(orderId),
          operationType: const Value('UPDATE'),
          dependencyOrder: const Value(2),
          status: const Value(SyncOutboxStatus.pending),
          payload: Value(jsonEncode({
            'id': orderId,
            'status': status.name,
          })),
          createdAt: Value(DateTime.now()),
        ),
      );
    });
  }

  @override
  Future<void> cancelOrder(String orderId) async {
    await updateOrderStatus(orderId, OrderStatus.cancelled);
  }

  @override
  Future<void> deleteHeldOrder(String orderId) async {
    // SYNC-026: Atomic local write and outbox mutation inside transaction
    await _db.transaction(() async {
      await (_db.update(_db.localOrders)..where((t) => t.id.equals(orderId))).write(
        LocalOrdersCompanion(
          isDeleted: const Value(true),
          syncStatus: const Value('pending_update'),
          clientUpdatedAt: Value(DateTime.now()),
        ),
      );

      final opId = _uuid.v7();
      await _db.outboxDao.insertEntry(
        SyncOutboxCompanion(
          operationId: Value(opId),
          deviceId: Value(_deviceId),
          entityType: const Value('order'),
          entityId: Value(orderId),
          operationType: const Value('DELETE'),
          dependencyOrder: const Value(2),
          status: const Value(SyncOutboxStatus.pending),
          payload: Value(jsonEncode({
            'id': orderId,
          })),
          createdAt: Value(DateTime.now()),
        ),
      );
    });
  }

  @override
  Future<OrderItem> addOrderItem(String orderId, OrderItem item) async {
    return await _db.transaction(() async {
      final itemId = (item.id != null && item.id!.isNotEmpty && item.id!.length == 36)
          ? item.id!
          : _uuid.v7();
      final now = DateTime.now();
      final effectiveItem = item.copyWith(
        id: itemId,
        createdByDeviceId: item.createdByDeviceId ?? _deviceId,
        clientCreatedAt: item.clientCreatedAt ?? now,
      );

      await _db.into(_db.localOrderItems).insert(
        LocalOrderItemsCompanion(
          id: Value(effectiveItem.id!),
          orderId: Value(orderId),
          menuItemId: Value(effectiveItem.item.id.isNotEmpty ? effectiveItem.item.id : null),
          itemName: Value(effectiveItem.item.name),
          sizeName: Value(effectiveItem.selectedSize),
          unitPrice: Value(effectiveItem.unitPrice),
          quantity: Value(effectiveItem.quantity),
          subtotal: Value(effectiveItem.totalPrice),
          notes: Value(effectiveItem.notes.isNotEmpty ? effectiveItem.notes : null),
          supersedesItemId: Value(effectiveItem.supersedesItemId),
          createdByDeviceId: Value(effectiveItem.createdByDeviceId),
          clientCreatedAt: Value(effectiveItem.clientCreatedAt),
          syncStatus: const Value('pending_insert'),
          serverVersion: const Value(1),
        ),
      );

      final allItems = await _db.ordersDao.getOrderItems(orderId);
      final activeItems = allItems.where((i) => !i.isCancelled && i.voidedAt == null);
      final newSubtotal = activeItems.fold<double>(0.0, (sum, i) => sum + i.subtotal);

      final existingOrder = await _db.ordersDao.getOrderById(orderId);
      if (existingOrder != null) {
        final newGrandTotal = (newSubtotal - existingOrder.discountAmount + existingOrder.taxAmount).clamp(0.0, double.infinity);
        await (_db.update(_db.localOrders)..where((t) => t.id.equals(orderId))).write(
          LocalOrdersCompanion(
            subtotal: Value(newSubtotal),
            grandTotal: Value(newGrandTotal),
            syncStatus: const Value('pending_update'),
            clientUpdatedAt: Value(now),
          ),
        );
      }

      final opId = _uuid.v7();
      await _db.outboxDao.insertEntry(
        SyncOutboxCompanion(
          operationId: Value(opId),
          deviceId: Value(_deviceId),
          entityType: const Value('order'),
          entityId: Value(orderId),
          operationType: const Value('ITEM_ADD'),
          dependencyOrder: const Value(2),
          status: const Value(SyncOutboxStatus.pending),
          payload: Value(jsonEncode(effectiveItem.toCreateItemDto())),
          createdAt: Value(now),
        ),
      );

      return effectiveItem;
    });
  }

  @override
  Future<void> voidOrderItem(String orderId, String itemId, {String? voidedBy, String? reason}) async {
    await _db.transaction(() async {
      final now = DateTime.now();
      await (_db.update(_db.localOrderItems)..where((t) => t.id.equals(itemId))).write(
        LocalOrderItemsCompanion(
          isCancelled: const Value(true),
          cancelledAt: Value(now),
          cancelReason: Value(reason),
          voidedAt: Value(now),
          voidedBy: Value(voidedBy ?? 'USER'),
          syncStatus: const Value('pending_update'),
        ),
      );

      final allItems = await _db.ordersDao.getOrderItems(orderId);
      final activeItems = allItems.where((i) => !i.isCancelled && i.voidedAt == null);
      final newSubtotal = activeItems.fold<double>(0.0, (sum, i) => sum + i.subtotal);

      final existingOrder = await _db.ordersDao.getOrderById(orderId);
      if (existingOrder != null) {
        final newGrandTotal = (newSubtotal - existingOrder.discountAmount + existingOrder.taxAmount).clamp(0.0, double.infinity);
        await (_db.update(_db.localOrders)..where((t) => t.id.equals(orderId))).write(
          LocalOrdersCompanion(
            subtotal: Value(newSubtotal),
            grandTotal: Value(newGrandTotal),
            syncStatus: const Value('pending_update'),
            clientUpdatedAt: Value(now),
          ),
        );
      }

      final opId = _uuid.v7();
      await _db.outboxDao.insertEntry(
        SyncOutboxCompanion(
          operationId: Value(opId),
          deviceId: Value(_deviceId),
          entityType: const Value('order'),
          entityId: Value(orderId),
          operationType: const Value('ITEM_VOID'),
          dependencyOrder: const Value(2),
          status: const Value(SyncOutboxStatus.pending),
          payload: Value(jsonEncode({
            'order_id': orderId,
            'item_id': itemId,
            'voided_by': voidedBy ?? 'USER',
            'reason': reason,
            'voided_at': now.toIso8601String(),
          })),
          createdAt: Value(now),
        ),
      );
    });
  }

  /// Reactive stream of all orders from local SQLite WAL
  Stream<List<OrderModel>> watchAllOrders() {
    return _db.ordersDao.watchAllOrders().asyncMap((orders) async {
      final active = orders.where((o) => !o.isDeleted).toList();
      final result = <OrderModel>[];
      for (final o in active) {
        final items = await _db.ordersDao.getOrderItems(o.id);
        final payments = await _db.ordersDao.getOrderPayments(o.id);
        result.add(_mapToOrderModel(o, items, payments));
      }
      return result;
    });
  }

  /// Reactive stream of pending orders awaiting synchronization
  Stream<List<OrderModel>> watchPendingOrders() {
    return _db.ordersDao.watchPendingOrders().asyncMap((orders) async {
      final active = orders.where((o) => !o.isDeleted).toList();
      final result = <OrderModel>[];
      for (final o in active) {
        final items = await _db.ordersDao.getOrderItems(o.id);
        final payments = await _db.ordersDao.getOrderPayments(o.id);
        result.add(_mapToOrderModel(o, items, payments));
      }
      return result;
    });
  }

  /// Maps Drift local tables to domain OrderModel
  OrderModel _mapToOrderModel(
    LocalOrder o,
    List<LocalOrderItem> items,
    List<LocalOrderPayment> payments,
  ) {
    final orderType = OrderType.values.firstWhere(
      (e) => e.name == o.orderType,
      orElse: () => OrderType.dineIn,
    );
    final orderStatus = OrderStatus.values.firstWhere(
      (e) => e.name == o.status,
      orElse: () => OrderStatus.newOrder,
    );

    return OrderModel(
      id: o.id,
      orderNumber: o.orderNumber,
      type: orderType,
      status: orderStatus,
      items: items.map((i) {
        return OrderItem(
          id: i.id,
          item: MenuItem(
            id: i.menuItemId ?? '',
            name: i.itemName,
            category: 'General',
            description: '',
            basePrice: i.unitPrice,
            imageUrl: '',
          ),
          quantity: i.quantity,
          selectedSize: i.sizeName ?? 'Regular',
          selectedCrust: 'Original',
          extraToppings: const [],
          notes: i.notes ?? '',
          backendUnitPrice: i.unitPrice,
          isCancelled: i.isCancelled || i.voidedAt != null,
          cancelledAt: i.cancelledAt ?? i.voidedAt,
          cancelReason: i.cancelReason,
          cancelledBy: i.voidedBy,
          voidedAt: i.voidedAt,
          voidedBy: i.voidedBy,
          supersedesItemId: i.supersedesItemId,
          createdByDeviceId: i.createdByDeviceId,
          clientCreatedAt: i.clientCreatedAt,
        );
      }).toList(),
      createdAt: o.createdAt,
      shiftId: o.shiftId,
      subtotalOverride: o.subtotal,
      discountPercentage: o.discountPercentage,
      discountAmount: o.discountAmount,
      taxAmount: o.taxAmount,
      grandTotalOverride: o.grandTotal,
      paymentStatus: o.paymentStatus,
      isPaid: o.isPaid,
      isHeld: o.isHeld,
      kitchenTicketSent: o.kitchenTicketSent,
      rejectionReason: o.rejectionReason,
      payments: payments.map((p) {
        return OrderPaymentModel(
          id: p.id,
          paymentMethod: p.paymentMethod,
          amount: p.amount,
          tenderedAmount: p.tenderedAmount,
          changeReturned: p.changeReturned,
          transactionReference: p.transactionReference,
          cardLastFour: p.cardLastFour,
          bankName: p.bankName,
          paymentStatus: p.paymentStatus,
          receivedBy: p.receivedBy,
          createdAt: p.createdAt,
        );
      }).toList(),
      dineInDetail: (orderType == OrderType.dineIn || orderType == OrderType.quickOrder)
          ? DineInOrderDetail(
              id: o.id,
              orderId: o.id,
              tableId: '',
              guestCount: 1,
              waiterName: '',
            )
          : null,
      takeawayDetail: orderType == OrderType.takeAway
          ? TakeawayOrderDetail(
              id: o.id,
              orderId: o.id,
              tokenNumber: o.orderNumber,
            )
          : null,
      onlineDetail: (orderType == OrderType.delivery || orderType == OrderType.online)
          ? OnlineOrderDetail(
              id: o.id,
              orderId: o.id,
              orderSource: 'POS',
              customerName: '',
              customerPhone: '',
              deliveryAddress: '',
            )
          : null,
    );
  }
}
