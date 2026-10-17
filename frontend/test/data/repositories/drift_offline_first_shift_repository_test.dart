import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hungry_howies_pos/core/database/app_database.dart';
import 'package:hungry_howies_pos/core/database/tables/local_daily_calculations_table.dart';
import 'package:hungry_howies_pos/core/database/tables/sync_outbox_table.dart';
import 'package:hungry_howies_pos/data/repositories/drift_offline_first_order_repository.dart';
import 'package:hungry_howies_pos/data/repositories/drift_offline_first_shift_repository.dart';
import 'package:hungry_howies_pos/domain/models/menu_item.dart';
import 'package:hungry_howies_pos/domain/models/order_model.dart';
import 'package:uuid/uuid.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DriftOfflineFirstShiftRepository Tests (§5.2, §6.3, §7.3, §8.3(3), §21 Decision 2)', () {
    late AppDatabase db;
    late DriftOfflineFirstShiftRepository shiftRepository;
    late DriftOfflineFirstOrderRepository orderRepository;
    const uuid = Uuid();

    setUp(() {
      db = AppDatabase(
        NativeDatabase.memory(
          setup: (rawDb) {
            rawDb.execute('PRAGMA foreign_keys = ON;');
          },
        ),
      );
      shiftRepository = DriftOfflineFirstShiftRepository(
        db: db,
        deviceId: 'POS-P1',
        uuid: uuid,
      );
      orderRepository = DriftOfflineFirstOrderRepository(
        db: db,
        terminalId: '1',
        deviceId: 'POS-P1',
        uuid: uuid,
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('1. Atomic Transaction: Shift open writes local_daily_calculations and sync_outbox (Level 0)', () async {
      final shift = await shiftRepository.openShift(
        cashierId: 'cashier-001',
        cashierName: 'Elena Rostova',
        startingCash: 5000.0,
        shiftName: 'Morning Shift',
      );

      expect(shift.id, isNotEmpty);
      expect(shift.cashierId, equals('cashier-001'));
      expect(shift.startingCash, equals(5000.0));
      expect(shift.status, equals(DailyCalculationStatus.active));
      expect(shift.syncStatus, equals('pending_insert'));

      // Verify row in local_daily_calculations
      final dbShift = await db.dailyCalculationsDao.getCalculationById(shift.id);
      expect(dbShift, isNotNull);
      expect(dbShift!.startingCash, equals(5000.0));

      // Verify mutation in sync_outbox
      final outboxEntries = await db.outboxDao.getAllEntries();
      expect(outboxEntries.length, equals(1));
      final outbox = outboxEntries.first;
      expect(outbox.entityType, equals('shift'));
      expect(outbox.entityId, equals(shift.id));
      expect(outbox.operationType, equals('INSERT'));
      expect(outbox.dependencyOrder, equals(0)); // Level 0: Shift Session (§6.3)
      expect(outbox.status, equals(SyncOutboxStatus.pending));

      final payload = jsonDecode(outbox.payload) as Map<String, dynamic>;
      expect(payload['starting_cash'], equals(5000.0));
      expect(payload['status'], equals('ACTIVE'));
    });

    test('2. Atomic Transaction: Shift close writes OFFLINE_CLOSED, variance, and outbox (Level 5)', () async {
      final shift = await shiftRepository.openShift(
        cashierId: 'cashier-001',
        cashierName: 'Elena Rostova',
        startingCash: 5000.0,
      );

      // Close shift with shortage of PKR 300
      final closed = await shiftRepository.closeShift(
        shiftId: shift.id,
        actualCashCounted: 14700.0,
        expectedCashDrawer: 15000.0, // Shortage = 14700 - 15000 = -300
        closingNotes: 'Shortage PKR 300 due to change discrepancy',
        varianceReason: 'Cash shortage',
      );

      expect(closed.status, equals(DailyCalculationStatus.offlineClosed));
      expect(closed.actualCashCounted, equals(14700.0));
      expect(closed.expectedCashDrawer, equals(15000.0));
      expect(closed.cashVariance, equals(-300.0)); // Shortage
      expect(closed.syncStatus, equals('pending_update'));

      // Check sync_outbox contains Level 5 mutation
      final outboxEntries = await db.outboxDao.getAllEntries();
      expect(outboxEntries.length, equals(2)); // Level 0 INSERT + Level 5 UPDATE

      final closeOutbox = outboxEntries.last;
      expect(closeOutbox.entityType, equals('shift'));
      expect(closeOutbox.entityId, equals(shift.id));
      expect(closeOutbox.operationType, equals('UPDATE'));
      expect(closeOutbox.dependencyOrder, equals(5)); // Level 5: Shift Close (§6.3)

      final payload = jsonDecode(closeOutbox.payload) as Map<String, dynamic>;
      expect(payload['status'], equals('OFFLINE_CLOSED'));
      expect(payload['actual_cash_counted'], equals(14700.0));
      expect(payload['cash_variance'], equals(-300.0));
    });

    test('3. Decision 2: Blocks nothing based on variance size (handles both shortage and overage)', () async {
      // Test A: Large shortage (PKR 5,000 short) — must NOT throw or block
      final shiftA = await shiftRepository.openShift(
        cashierId: 'cashier-002',
        cashierName: 'Ahmed Ali',
        startingCash: 10000.0,
      );

      final closedShort = await shiftRepository.closeShift(
        shiftId: shiftA.id,
        actualCashCounted: 5000.0,
        expectedCashDrawer: 10000.0,
      );
      expect(closedShort.cashVariance, equals(-5000.0));
      expect(closedShort.status, equals(DailyCalculationStatus.offlineClosed));

      // Test B: Large overage (PKR 3,000 excess) — must NOT throw or block
      final shiftB = await shiftRepository.openShift(
        cashierId: 'cashier-003',
        cashierName: 'Sara Khan',
        startingCash: 5000.0,
      );

      final closedOver = await shiftRepository.closeShift(
        shiftId: shiftB.id,
        actualCashCounted: 8000.0,
        expectedCashDrawer: 5000.0,
      );
      expect(closedOver.cashVariance, equals(3000.0));
      expect(closedOver.status, equals(DailyCalculationStatus.offlineClosed));
    });

    test('4. Idempotency: Two closes for same shift return cleanly without duplicate outbox mutation', () async {
      final shift = await shiftRepository.openShift(
        cashierId: 'cashier-001',
        cashierName: 'Elena Rostova',
        startingCash: 5000.0,
      );

      final close1 = await shiftRepository.closeShift(
        shiftId: shift.id,
        actualCashCounted: 15000.0,
        expectedCashDrawer: 15000.0,
      );
      expect(close1.status, equals(DailyCalculationStatus.offlineClosed));

      final outboxCountAfterFirstClose = (await db.outboxDao.getAllEntries()).length;
      expect(outboxCountAfterFirstClose, equals(2)); // Open + Close

      // Second close attempt on same shift
      final close2 = await shiftRepository.closeShift(
        shiftId: shift.id,
        actualCashCounted: 15000.0,
        expectedCashDrawer: 15000.0,
      );
      expect(close2.status, equals(DailyCalculationStatus.offlineClosed));

      // Outbox must still have only 2 entries (idempotent, no duplicate queue entry)
      final outboxCountAfterSecondClose = (await db.outboxDao.getAllEntries()).length;
      expect(outboxCountAfterSecondClose, equals(2));
    });

    test('5. Dependency Ordering (§6.3): Level 0 (open) < Level 2 (orders) < Level 5 (close)', () async {
      // 1. Open shift (Level 0)
      final shift = await shiftRepository.openShift(
        cashierId: 'cashier-001',
        cashierName: 'Elena',
        startingCash: 5000.0,
      );

      // 2. Create order during shift (Level 2)
      final sampleOrder = OrderModel(
        id: uuid.v7(),
        orderNumber: 'TEMP',
        shiftId: shift.id,
        type: OrderType.dineIn,
        status: OrderStatus.completed,
        items: const [
          OrderItem(
            item: MenuItem(id: 'm1', name: 'Pizza', category: 'Pizza', description: '', basePrice: 20, imageUrl: ''),
            quantity: 1,
            selectedSize: 'Regular',
          ),
        ],
        createdAt: DateTime.now(),
        subtotalOverride: 20,
        grandTotalOverride: 20,
        isPaid: true,
      );
      final savedOrder = await orderRepository.saveOrder(sampleOrder);

      // 3. Close shift (Level 5) with dependency on order operation
      final orderOutbox = (await db.outboxDao.getAllEntries()).firstWhere((e) => e.entityType == 'order');

      await shiftRepository.closeShift(
        shiftId: shift.id,
        actualCashCounted: 5020.0,
        expectedCashDrawer: 5020.0,
        dependsOnOperationId: orderOutbox.operationId,
      );

      // 4. Query push batch: must strictly order Level 0 -> Level 2 -> Level 5
      final batch = await db.outboxDao.getPushBatch(limit: 10);
      expect(batch.length, equals(3));

      expect(batch[0].dependencyOrder, equals(0));
      expect(batch[0].entityType, equals('shift'));
      expect(batch[0].operationType, equals('INSERT'));

      expect(batch[1].dependencyOrder, equals(2));
      expect(batch[1].entityType, equals('order'));
      expect(batch[1].operationType, equals('INSERT'));
      expect(batch[1].entityId, equals(savedOrder.id));

      expect(batch[2].dependencyOrder, equals(5));
      expect(batch[2].entityType, equals('shift'));
      expect(batch[2].operationType, equals('UPDATE'));
      expect(batch[2].dependsOnOperationId, equals(orderOutbox.operationId));
    });

    test('6. Queries: getActiveShift and watchActiveShift reflect shift status reactively', () async {
      expect(await shiftRepository.getActiveShift('cashier-001'), isNull);

      final shift = await shiftRepository.openShift(
        cashierId: 'cashier-001',
        cashierName: 'Elena',
        startingCash: 5000.0,
      );

      final active = await shiftRepository.getActiveShift('cashier-001');
      expect(active, isNotNull);
      expect(active!.id, equals(shift.id));

      await shiftRepository.closeShift(
        shiftId: shift.id,
        actualCashCounted: 5000.0,
        expectedCashDrawer: 5000.0,
      );

      // After closing, getActiveShift returns null
      expect(await shiftRepository.getActiveShift('cashier-001'), isNull);
    });
  });
}
