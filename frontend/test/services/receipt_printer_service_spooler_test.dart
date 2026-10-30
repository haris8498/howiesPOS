import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hungry_howies_pos/core/database/app_database.dart';
import 'package:hungry_howies_pos/core/database/tables/offline_print_jobs_table.dart';
import 'package:hungry_howies_pos/data/repositories/drift_offline_first_order_repository.dart';
import 'package:hungry_howies_pos/domain/models/menu_item.dart';
import 'package:hungry_howies_pos/domain/models/order_model.dart';
import 'package:hungry_howies_pos/services/receipt_printer_service.dart';
import 'package:uuid/uuid.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Offline Print Spooler Tests (§15.4, §21 Dec 1, §5.4, §15.2, Risk #7, Risk #10)', () {
    late AppDatabase db;
    const uuid = Uuid();

    const sampleMenuItem = MenuItem(
      id: 'item-001',
      name: 'Pepperoni Pizza',
      category: 'Pizza',
      description: 'Classic Pepperoni',
      basePrice: 14.99,
      imageUrl: '',
    );

    OrderModel createTestOrder({
      String? id,
      String? orderNumber,
      bool isPaid = true,
      List<OrderItem>? items,
    }) {
      final orderId = id ?? uuid.v7();
      return OrderModel(
        id: orderId,
        orderNumber: orderNumber ?? 'HH-TEST-001',
        type: OrderType.dineIn,
        status: OrderStatus.accepted,
        items: items ??
            const [
              OrderItem(
                item: sampleMenuItem,
                quantity: 2,
                selectedSize: 'Large',
                selectedCrust: 'Original',
                extraToppings: ['Extra Cheese'],
                notes: 'Crispy crust',
              ),
            ],
        createdAt: DateTime.now(),
        subtotalOverride: 29.98,
        discountPercentage: 0.0,
        discountAmount: 0.0,
        taxAmount: 2.50,
        grandTotalOverride: 32.48,
        paymentStatus: isPaid ? 'PAID' : 'UNPAID',
        isPaid: isPaid,
        kitchenTicketSent: false,
        payments: isPaid
            ? [
                OrderPaymentModel(
                  id: uuid.v7(),
                  paymentMethod: 'cash',
                  amount: 32.48,
                  tenderedAmount: 40.00,
                  changeReturned: 7.52,
                  paymentStatus: 'COMPLETED',
                  receivedBy: 'Cashier Alice',
                  createdAt: DateTime.now(),
                ),
              ]
            : [],
      );
    }

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      db = AppDatabase(
        NativeDatabase.memory(
          setup: (rawDb) {
            rawDb.execute('PRAGMA foreign_keys = ON;');
          },
        ),
      );
      ReceiptPrinterService.resetForTesting();
      ReceiptPrinterService.setDatabase(db);
      await ReceiptPrinterService.savePrinterSettings(
        printerName: 'POS-TEST-PRINTER',
        kitchenPrinterName: 'KITCHEN-TEST-PRINTER',
        kitchenSameAsCustomer: false,
      );
    });

    tearDown(() async {
      ReceiptPrinterService.resetForTesting();
      await db.close();
    });

    test('1. Hardware failure keeps job in FAILED status with raw ESC/POS payload and non-blocking failure', () async {
      final order = createTestOrder(orderNumber: 'ORD-FAIL-01');
      final receiptData = ReceiptData.fromOrderModel(order: order, type: ReceiptType.customerReceipt);

      // Simulate hardware failure (e.g. out of paper / disconnected)
      ReceiptPrinterService.testPrinterFn = (printer, bytes, {String? docName}) async {
        return false;
      };

      final printSuccess = await ReceiptPrinterService.printReceipt(
        receipt: receiptData,
        db: db,
      );

      // Method returns false instead of throwing uncaught exception
      expect(printSuccess, isFalse);

      // Check OfflinePrintJobs table
      final jobs = await db.printJobsDao.getJobsForOrder(order.orderNumber);
      expect(jobs.length, 1);
      final job = jobs.first;
      expect(job.status, PrintJobStatus.failed);
      expect(job.printerTarget, 'POS-TEST-PRINTER');
      expect(job.jobType, PrintJobType.customerReceipt);
      expect(job.retryCount, 0);
      expect(job.rawEscPosData, isNotNull);
      expect(job.rawEscPosData.isNotEmpty, isTrue);
    });

    test('2. retryPrintJob retries printing, updates status to PRINTED, and avoids double-printing on second retry', () async {
      final order = createTestOrder(orderNumber: 'ORD-RETRY-01');
      final receiptData = ReceiptData.fromOrderModel(order: order, type: ReceiptType.customerReceipt);

      // First attempt fails
      ReceiptPrinterService.testPrinterFn = (printer, bytes, {String? docName}) async => false;
      await ReceiptPrinterService.printReceipt(
        receipt: receiptData,
        db: db,
      );

      final failedJobs = await db.printJobsDao.getJobsForOrder(order.orderNumber);
      expect(failedJobs.length, 1);
      final jobId = failedJobs.first.id;
      expect(failedJobs.first.status, PrintJobStatus.failed);

      // Second attempt: printer is now online and paper refilled
      int physicalPrintCount = 0;
      ReceiptPrinterService.testPrinterFn = (printer, bytes, {String? docName}) async {
        physicalPrintCount++;
        return true;
      };

      final retryResult = await ReceiptPrinterService.retryPrintJob(jobId, db: db);
      expect(retryResult, isTrue);
      expect(physicalPrintCount, 1);

      // Verify job status updated to PRINTED
      final updatedJob = await (db.select(db.offlinePrintJobs)..where((t) => t.id.equals(jobId))).getSingle();
      expect(updatedJob.status, PrintJobStatus.printed);
      expect(updatedJob.retryCount, 1);

      // Third attempt: retrying an already PRINTED job should be a no-op
      final secondRetry = await ReceiptPrinterService.retryPrintJob(jobId, db: db);
      expect(secondRetry, isTrue);
      expect(physicalPrintCount, 1, reason: 'Must not send duplicate raw bytes to printer for already printed job');
    });

    test('3. App restart mid-print does not double print KOT (dedup check & SQLite PRINTED check)', () async {
      const orderNumber = 'ORD-KOT-DEDUP';
      final order = createTestOrder(orderNumber: orderNumber);
      final kotReceipt = ReceiptData.fromOrderModel(order: order, type: ReceiptType.kitchenKot);

      int kotPrintCount = 0;
      ReceiptPrinterService.testPrinterFn = (printer, bytes, {String? docName}) async {
        kotPrintCount++;
        return true;
      };

      // Print KOT successfully first time
      final success = await ReceiptPrinterService.printReceipt(
        receipt: kotReceipt,
        db: db,
      );
      expect(success, isTrue);
      expect(kotPrintCount, greaterThanOrEqualTo(1));
      final countAfterFirst = kotPrintCount;

      // Verify recorded in SQLite OfflinePrintJobs as PRINTED
      final kotJobs = await db.printJobsDao.getJobsForOrder(orderNumber);
      expect(kotJobs.any((j) => j.jobType == PrintJobType.kitchenTicket && j.status == PrintJobStatus.printed), isTrue);

      // SIMULATE APP RESTART: Reset all in-memory static state
      ReceiptPrinterService.resetForTesting();
      // Re-attach persistent SQLite database
      ReceiptPrinterService.setDatabase(db);
      await ReceiptPrinterService.savePrinterSettings(
        printerName: 'POS-TEST-PRINTER',
        kitchenPrinterName: 'KITCHEN-TEST-PRINTER',
        kitchenSameAsCustomer: false,
      );

      // Verify Tier 5 check reads persisted PRINTED state from SQLite
      final isPrintedAfterRestart = await ReceiptPrinterService.isKitchenReceiptPrinted(orderNumber, db: db);
      expect(isPrintedAfterRestart, isTrue, reason: 'SQLite PRINTED status must persist across app restart');

      // Attempting to print KOT again without forcePrint should be blocked
      ReceiptPrinterService.testPrinterFn = (printer, bytes, {String? docName}) async {
        kotPrintCount++;
        return true;
      };

      await ReceiptPrinterService.printReceipt(
        receipt: kotReceipt,
        forcePrint: false,
        db: db,
      );

      // Physical printer count must remain unchanged (no duplicate kitchen ticket sent)
      expect(kotPrintCount, countAfterFirst);
    });

    test('4. Invariant: ORDER SAVING != PRINTING (Risk #7, §15.4) - Hardware failure never rolls back order', () async {
      final repository = DriftOfflineFirstOrderRepository(
        db: db,
        terminalId: '1',
        deviceId: 'POS-TEST-01',
      );

      final order = createTestOrder(orderNumber: 'ORD-ATOMIC-01');

      // Physical printer throws unhandled hardware exception (out of paper / I/O fault)
      ReceiptPrinterService.testPrinterFn = (printer, bytes, {String? docName}) async {
        throw Exception('Native Win32 spooler write fault: ERROR_OUT_OF_PAPER (28)');
      };

      // 1. Save order atomically through DriftOfflineFirstOrderRepository
      final savedOrder = await repository.saveOrder(order);
      expect(savedOrder.id, order.id);

      // 2. Attempt receipt print (which encounters the hardware failure)
      final receiptData = ReceiptData.fromOrderModel(order: savedOrder, type: ReceiptType.customerReceipt);
      final printResult = await ReceiptPrinterService.printReceipt(
        receipt: receiptData,
        db: db,
      );
      expect(printResult, isFalse);

      // 3. INVARIANT VERIFICATION: Order and payment MUST be committed in SQLite regardless of printer crash
      final persistedOrder = await db.ordersDao.getOrderById(order.id);
      expect(persistedOrder, isNotNull);
      expect(persistedOrder!.orderNumber, equals(savedOrder.orderNumber));
      expect(persistedOrder.isPaid, isTrue);

      final persistedPayments = await db.ordersDao.getOrderPayments(order.id);
      expect(persistedPayments.length, 1);
      expect(persistedPayments.first.paymentStatus, 'COMPLETED');

      final pendingMutations = await db.outboxDao.getAllEntries();
      expect(pendingMutations.any((m) => m.entityId == order.id && m.entityType == 'order'), isTrue);

      // 4. Print job is preserved in OfflinePrintJobs as FAILED for subsequent retry
      final printJobs = await db.printJobsDao.getJobsForOrder(savedOrder.orderNumber);
      expect(printJobs.isNotEmpty, isTrue);
      expect(printJobs.any((j) => j.status == PrintJobStatus.failed), isTrue);
    });

    test('5. Reprints are marked with *** COPY / REPRINT *** banner (§15.2)', () async {
      final order = createTestOrder(orderNumber: 'ORD-REPRINT-01');

      List<int> capturedCustomerBytes = [];
      ReceiptPrinterService.testPrinterFn = (printer, bytes, {String? docName}) async {
        capturedCustomerBytes = bytes;
        return true;
      };

      // 1. Regular original customer receipt
      final originalReceipt = ReceiptData.fromOrderModel(order: order, type: ReceiptType.customerReceipt, isReprint: false);
      await ReceiptPrinterService.printReceipt(
        receipt: originalReceipt,
        db: db,
      );
      final originalText = utf8.decode(capturedCustomerBytes, allowMalformed: true);
      expect(originalText.contains('*** COPY / REPRINT ***'), isFalse);

      // Clear debounce for next print of the same order
      ReceiptPrinterService.clearRecentPrintLocks();

      // 2. Reprint customer receipt
      final reprintReceipt = ReceiptData.fromOrderModel(order: order, type: ReceiptType.customerReceipt, isReprint: true);
      await ReceiptPrinterService.printReceipt(
        receipt: reprintReceipt,
        db: db,
      );
      final reprintText = utf8.decode(capturedCustomerBytes, allowMalformed: true);
      expect(reprintText.contains('*** COPY / REPRINT ***'), isTrue);

      // Clear debounce for next print
      ReceiptPrinterService.clearRecentPrintLocks();

      // 3. Kitchen KOT reprint
      List<int> capturedKotBytes = [];
      ReceiptPrinterService.testPrinterFn = (printer, bytes, {String? docName}) async {
        capturedKotBytes = bytes;
        return true;
      };

      final reprintKot = ReceiptData.fromOrderModel(order: order, type: ReceiptType.kitchenKot, isReprint: true);
      await ReceiptPrinterService.printReceipt(
        receipt: reprintKot,
        forcePrint: true,
        db: db,
      );
      final reprintKotText = utf8.decode(capturedKotBytes, allowMalformed: true);
      expect(reprintKotText.contains('*** COPY / REPRINT ***'), isTrue);
    });

    test('6. Cancelled-item tickets print only if order was already sent to kitchen (§15.2)', () async {
      const orderNo = 'ORD-CANCEL-01';
      final activeItem = OrderItem(
        id: 'ci-1',
        item: sampleMenuItem,
        quantity: 1,
        isCancelled: false,
      );
      final cancelledItem = OrderItem(
        id: 'ci-2',
        item: sampleMenuItem,
        quantity: 1,
        isCancelled: true,
        cancelReason: 'Customer changed mind',
      );

      final orderWithCancel = createTestOrder(
        orderNumber: orderNo,
        items: [activeItem, cancelledItem],
      );

      List<int> capturedBytes = [];
      ReceiptPrinterService.testPrinterFn = (printer, bytes, {String? docName}) async {
        capturedBytes = bytes;
        return true;
      };

      // Case A: Order was NEVER sent to kitchen (isKitchenReceiptPrinted is false)
      // When printed, cancelled items should be filtered out so kitchen never receives confusing cancellation
      final initialKot = ReceiptData.fromOrderModel(order: orderWithCancel, type: ReceiptType.kitchenKot);
      await ReceiptPrinterService.printReceipt(
        receipt: initialKot,
        db: db,
      );

      final textInitial = utf8.decode(capturedBytes, allowMalformed: true);
      expect(textInitial.contains('CANCELLED'), isFalse);

      // Clear debounce for next call
      ReceiptPrinterService.clearRecentPrintLocks();

      // Case B: Order WAS already sent to kitchen, now an item is cancelled
      await ReceiptPrinterService.markKitchenReceiptPrinted(orderNo, db: db);

      final cancellationKot = ReceiptData(
        type: ReceiptType.kitchenKot,
        orderNumber: orderNo,
        dateTime: DateTime.now(),
        items: [
          ReceiptItemData(
            id: 'ci-2',
            name: sampleMenuItem.name,
            quantity: 1,
            unitPrice: sampleMenuItem.basePrice,
            totalPrice: sampleMenuItem.basePrice,
            isCancelled: true,
            cancelReason: 'Customer changed mind',
          ),
        ],
        subtotal: 0.0,
        grandTotal: 0.0,
      );

      await ReceiptPrinterService.printReceipt(
        receipt: cancellationKot,
        forcePrint: true,
        db: db,
      );
      final textCancelled = utf8.decode(capturedBytes, allowMalformed: true);
      expect(textCancelled.contains('CANCELLED ITEM') || textCancelled.contains('Customer changed mind'), isTrue);
    });

    test('7. Shift Z-Report enqueues as SHIFT_Z_REPORT and prints successfully (§5.4, §15.4)', () async {
      List<int> capturedReportBytes = [];
      ReceiptPrinterService.testPrinterFn = (printer, bytes, {String? docName}) async {
        capturedReportBytes = bytes;
        return true;
      };

      final reportSuccess = await ReceiptPrinterService.printShiftZReport(
        shiftId: 'SHIFT-2026-10-17-01',
        date: DateTime(2026, 10, 17, 21, 0),
        cashierName: 'Elena Rostova',
        startingCash: 200.0,
        totalGrossSales: 1540.50,
        totalExpenses: 50.00,
        totalCashSales: 850.00,
        totalCardSales: 690.50,
        totalOnlineSales: 0.00,
        expectedCash: 1000.00,
        actualCash: 1000.00,
        variance: 0.00,
        totalOrders: 42,
        db: db,
      );

      expect(reportSuccess, isTrue);

      // Check OfflinePrintJobs table
      final shiftJobs = await (db.select(db.offlinePrintJobs)
            ..where((t) => t.jobType.equals(PrintJobType.shiftZReport)))
          .get();

      expect(shiftJobs.length, 1);
      final job = shiftJobs.first;
      expect(job.orderId, 'SHIFT-2026-10-17-01');
      expect(job.status, PrintJobStatus.printed);
      expect(job.rawEscPosData, isNotNull);

      final reportText = utf8.decode(capturedReportBytes, allowMalformed: true);
      expect(reportText.contains('DAILY SHIFT Z-REPORT'), isTrue);
      expect(reportText.contains('Elena Rostova'), isTrue);
      expect(reportText.contains('1000'), isTrue);
      expect(reportText.contains('Expected In Drawer'), isTrue);
    });

    test('8. Dine-In order modification and unmarking permits printing updated KOT (§15.2)', () async {
      final dineInTable = 'T-1';
      final orderNumber = 'DIN-101';
      final tokenNumber = '001';

      final initialKot = ReceiptData(
        type: ReceiptType.kitchenKot,
        orderNumber: tokenNumber,
        tokenNumber: tokenNumber,
        tableNumber: dineInTable,
        tableName: 'TABLE 1',
        tableSection: 'Hall',
        dateTime: DateTime.now(),
        items: [
          ReceiptItemData(
            id: 'item-1',
            name: 'Chicken Fajita Pizza',
            quantity: 1,
            unitPrice: 1200.0,
            totalPrice: 1200.0,
          ),
        ],
        subtotal: 1200.0,
        grandTotal: 1200.0,
      );

      int printCount = 0;
      ReceiptPrinterService.testPrinterFn = (printer, bytes, {String? docName}) async {
        printCount++;
        return true;
      };

      // 1. Initial print
      final success1 = await ReceiptPrinterService.printReceipt(
        receipt: initialKot,
        forcePrint: true,
        db: db,
      );
      expect(success1, isTrue);
      expect(printCount, 2); // Initial dual print

      // Verify it is marked printed
      final isPrintedInitial = await ReceiptPrinterService.isKitchenReceiptPrinted(
        orderNumber,
        tokenNumber: tokenNumber,
        currentItemsSignature: initialKot.itemsSignature,
        db: db,
      );
      expect(isPrintedInitial, isTrue);

      // 2. Order is modified (new item added)
      final modifiedKot = ReceiptData(
        type: ReceiptType.kitchenKot,
        orderNumber: tokenNumber,
        tokenNumber: tokenNumber,
        tableNumber: dineInTable,
        tableName: 'TABLE 1',
        tableSection: 'Hall',
        dateTime: DateTime.now(),
        items: [
          ReceiptItemData(
            id: 'item-1',
            name: 'Chicken Fajita Pizza',
            quantity: 1,
            unitPrice: 1200.0,
            totalPrice: 1200.0,
          ),
          ReceiptItemData(
            id: 'item-2',
            name: 'Garlic Bread',
            quantity: 1,
            unitPrice: 350.0,
            totalPrice: 350.0,
          ),
        ],
        subtotal: 1550.0,
        grandTotal: 1550.0,
        isModified: true,
      );

      // Signature mismatch unlocks printing!
      final isPrintedModified = await ReceiptPrinterService.isKitchenReceiptPrinted(
        orderNumber,
        tokenNumber: tokenNumber,
        currentItemsSignature: modifiedKot.itemsSignature,
        db: db,
      );
      expect(isPrintedModified, isFalse, reason: 'Modified items signature must allow updated ticket print');

      // 3. Unmarking resets both SQLite and in-memory locks
      await ReceiptPrinterService.unmarkOrderKitchenReceiptPrinted(
        orderNumber: orderNumber,
        tokenNumber: tokenNumber,
        tableNumber: dineInTable,
        db: db,
      );

      final isPrintedAfterUnmark = await ReceiptPrinterService.isKitchenReceiptPrinted(
        orderNumber,
        tokenNumber: tokenNumber,
        currentItemsSignature: modifiedKot.itemsSignature,
        db: db,
      );
      expect(isPrintedAfterUnmark, isFalse, reason: 'Unmarking must allow updated ticket print');

      // 4. Verify hasOrderEverPrintedKot is true
      final hasEverPrinted = await ReceiptPrinterService.hasOrderEverPrintedKot(
        orderNumber,
        tokenNumber: tokenNumber,
        db: db,
      );
      expect(hasEverPrinted, isTrue, reason: 'Order was printed at least once');

      // 5. Print updated KOT (forcePrint: false, signature check allows update)
      final success2 = await ReceiptPrinterService.printReceipt(
        receipt: modifiedKot,
        forcePrint: false,
        db: db,
      );
      expect(success2, isTrue);
      expect(printCount, 4); // Second dual print

      // 6. Verify it is locked again after printing the update
      final isPrintedAfterUpdate = await ReceiptPrinterService.isKitchenReceiptPrinted(
        orderNumber,
        tokenNumber: tokenNumber,
        currentItemsSignature: modifiedKot.itemsSignature,
        db: db,
      );
      expect(isPrintedAfterUpdate, isTrue, reason: 'Button must remain disabled once updated ticket is printed');
    });

    test('9. Cancel triggers no print and unmarks order for kitchen ticket (#36)', () async {
      int printCount = 0;
      ReceiptPrinterService.testPrinterFn = (printer, bytes, {String? docName}) async {
        printCount++;
        return true;
      };

      const orderNo = 'ORD-CANCEL-TEST';
      final initialKot = ReceiptData(
        type: ReceiptType.kitchenKot,
        orderNumber: orderNo,
        dateTime: DateTime.now(),
        items: const [
          ReceiptItemData(
            id: 'item-1',
            name: 'Pepperoni Pizza',
            quantity: 1,
            unitPrice: 1200.0,
            totalPrice: 1200.0,
          ),
        ],
        subtotal: 1200.0,
        grandTotal: 1200.0,
      );

      // 1. Initial KOT print succeeds
      final initialSuccess = await ReceiptPrinterService.printReceipt(
        receipt: initialKot,
        db: db,
      );
      expect(initialSuccess, isTrue);
      final countAfterInitial = printCount;
      expect(countAfterInitial, greaterThan(0));

      // 2. Item cancellation occurs: handler calls unmarkOrderKitchenReceiptPrinted() and DOES NOT print
      await ReceiptPrinterService.unmarkOrderKitchenReceiptPrinted(
        orderNumber: orderNo,
        db: db,
      );

      // Verify NO print was dispatched by the cancellation handler
      expect(printCount, equals(countAfterInitial), reason: 'Cancel handler must not dispatch a print');

      // 3. Updated ticket is now unlocked for kitchen button
      final modifiedKot = ReceiptData(
        type: ReceiptType.kitchenKot,
        orderNumber: orderNo,
        dateTime: DateTime.now(),
        items: const [
          ReceiptItemData(
            id: 'item-1',
            name: 'Pepperoni Pizza',
            quantity: 1,
            unitPrice: 1200.0,
            totalPrice: 1200.0,
            isCancelled: true,
            cancelReason: 'Customer changed mind',
          ),
        ],
        subtotal: 0.0,
        grandTotal: 0.0,
        isModified: true,
      );

      final isPrintedAfterCancel = await ReceiptPrinterService.isKitchenReceiptPrinted(
        orderNo,
        currentItemsSignature: modifiedKot.itemsSignature,
        db: db,
      );
      expect(isPrintedAfterCancel, isFalse, reason: 'Kitchen button must offer one updated ticket after cancel');
    });

    testWidgets('10. One KOT tap after a change prints once and second tap is blocked showing notice (#36)', (WidgetTester tester) async {
      int printCount = 0;
      ReceiptPrinterService.testPrinterFn = (printer, bytes, {String? docName}) async {
        printCount++;
        return true;
      };

      String? capturedNotice;
      ReceiptPrinterService.testDuplicateNoticeFn = (notice) {
        capturedNotice = notice;
      };

      const orderNo = 'ORD-TAP-TEST';
      final initialKot = ReceiptData(
        type: ReceiptType.kitchenKot,
        orderNumber: orderNo,
        dateTime: DateTime.now(),
        items: const [
          ReceiptItemData(
            id: 'item-1',
            name: 'Chicken Pizza',
            quantity: 1,
            unitPrice: 1000.0,
            totalPrice: 1000.0,
          ),
        ],
        subtotal: 1000.0,
        grandTotal: 1000.0,
      );

      // Build a widget with a Scaffold to capture SnackBar notices
      late BuildContext testContext;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) {
                testContext = ctx;
                return const Text('POS Screen');
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initial print
      final success0 = await ReceiptPrinterService.printReceipt(
        context: testContext,
        receipt: initialKot,
        db: db,
      );
      expect(success0, isTrue);
      expect(printCount, greaterThan(0));
      final countAfterInitial = printCount;

      // Order is modified (e.g. adding item)
      final modifiedKot = ReceiptData(
        type: ReceiptType.kitchenKot,
        orderNumber: orderNo,
        dateTime: DateTime.now(),
        items: const [
          ReceiptItemData(
            id: 'item-1',
            name: 'Chicken Pizza',
            quantity: 1,
            unitPrice: 1000.0,
            totalPrice: 1000.0,
          ),
          ReceiptItemData(
            id: 'item-2',
            name: 'Garlic Bread',
            quantity: 1,
            unitPrice: 350.0,
            totalPrice: 350.0,
          ),
        ],
        subtotal: 1350.0,
        grandTotal: 1350.0,
        isModified: true,
      );

      // Clear debounce lock so second call tests duplicate logic
      ReceiptPrinterService.clearRecentPrintLocks();

      // FIRST TAP: Prints once
      final success1 = await ReceiptPrinterService.printReceipt(
        context: testContext,
        receipt: modifiedKot,
        forcePrint: false,
        db: db,
      );
      expect(success1, isTrue, reason: 'First tap after modification must print updated ticket');
      expect(printCount, greaterThan(countAfterInitial));
      final countAfterFirstTap = printCount;

      // Clear debounce lock for second tap
      ReceiptPrinterService.clearRecentPrintLocks();

      // SECOND TAP: Blocked as duplicate and shows notice
      final success2 = await ReceiptPrinterService.printReceipt(
        context: testContext,
        receipt: modifiedKot,
        forcePrint: false,
        db: db,
      );
      expect(success2, isFalse, reason: 'Second tap must be blocked as duplicate');
      expect(printCount, equals(countAfterFirstTap), reason: 'No additional physical ticket must be printed');

      // Verify notice was shown both via callback and UI SnackBar
      expect(capturedNotice, equals('Already sent to the kitchen'));
      await tester.pump(); // Render SnackBar
      expect(find.text('Already sent to the kitchen'), findsOneWidget);
    });
  });
}
