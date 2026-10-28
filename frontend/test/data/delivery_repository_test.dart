import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:hungry_howies_pos/config/feature_flags.dart';
import 'package:hungry_howies_pos/core/database/app_database.dart';
import 'package:hungry_howies_pos/core/sync/sync_background_worker.dart';
import 'package:hungry_howies_pos/core/sync/sync_providers.dart';
import 'package:hungry_howies_pos/data/delivery_repository.dart';
import 'package:hungry_howies_pos/data/repositories/drift_offline_first_order_repository.dart';
import 'package:hungry_howies_pos/data/repositories/order_repository_provider.dart';
import 'package:hungry_howies_pos/services/api/api_providers.dart';
import 'package:hungry_howies_pos/services/api/delivery_api_service.dart';
import 'package:hungry_howies_pos/services/api/orders_api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class MockOrdersApiService extends Fake implements OrdersApiService {
  final List<Map<String, dynamic>> capturedDtos = [];
  int createOrderCallCount = 0;

  @override
  Future<List<Map<String, dynamic>>> listOrders({
    String? orderType,
    String? orderSource,
    String? status,
    String? paymentStatus,
    bool? isPaid,
    bool? isHeld,
    String? tableId,
    String? customerId,
    String? search,
    int? limit,
    int? offset,
  }) async => [];

  @override
  Future<Map<String, dynamic>> createOrder(Map<String, dynamic> dto) async {
    createOrderCallCount++;
    capturedDtos.add(Map<String, dynamic>.from(dto));
    return dto;
  }
}

class MockDeliveryApiService extends Fake implements DeliveryApiService {
  @override
  Future<List<Map<String, dynamic>>> listDispatches({
    String? status,
    String? riderId,
    String? search,
  }) async => [];

  @override
  Future<List<Map<String, dynamic>>> listRiders({
    bool? isClockedIn,
    bool? isAvailable,
    String? search,
  }) async => [];
}

class MockSyncBackgroundWorker extends Fake implements SyncBackgroundWorker {
  int triggerPushCount = 0;

  @override
  Future<void> triggerPush({bool force = false}) async {
    triggerPushCount++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Delivery Dual-Write Fix (#10)', () {
    late AppDatabase testDb;
    late MockOrdersApiService mockOrdersApi;
    late MockDeliveryApiService mockDeliveryApi;
    late MockSyncBackgroundWorker mockWorker;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      FeatureFlags.resetForTesting();
      testDb = AppDatabase(
        NativeDatabase.memory(
          setup: (rawDb) {
            rawDb.execute('PRAGMA foreign_keys = ON;');
          },
        ),
      );
      mockOrdersApi = MockOrdersApiService();
      mockDeliveryApi = MockDeliveryApiService();
      mockWorker = MockSyncBackgroundWorker();
    });

    tearDown(() async {
      FeatureFlags.resetForTesting();
      await testDb.close();
    });

    test('Simulated create timeout retry results in exactly one order ID and one outbox row (#10)', () async {
      FeatureFlags.setOfflineFirstEnabledForTesting(true);

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(testDb),
          ordersApiServiceProvider.overrideWithValue(mockOrdersApi),
          deliveryApiServiceProvider.overrideWithValue(mockDeliveryApi),
          syncBackgroundWorkerProvider.overrideWithValue(mockWorker),
          orderRepositoryProvider.overrideWith(
            (ref) => DriftOfflineFirstOrderRepository(
              db: testDb,
              terminalId: '1',
              deviceId: 'POS-P1',
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(deliveryProvider.notifier);
      final clientOrderId = const Uuid().v4();

      final items = [
        {
          'menu_item_id': 'item-pizza-1',
          'item_name': 'Pepperoni Pizza',
          'quantity': 2,
          'unit_price': 15.0,
          'selected_size': 'Large',
          'selected_crust': 'Original',
        }
      ];

      // 1. Initial order creation
      final order1 = await notifier.createDeliveryOrder(
        customerName: 'John Doe',
        customerPhone: '1234567890',
        deliveryAddress: '123 Main St',
        deliveryFee: 5.0,
        subtotal: 30.0,
        grandTotal: 35.0,
        paymentMethod: 'Cash',
        paymentStatus: 'UNPAID',
        itemsSummary: '2x Pepperoni Pizza',
        items: items,
        existingOrderId: clientOrderId,
      );

      expect(order1.orderId, equals(clientOrderId));
      expect(mockOrdersApi.createOrderCallCount, equals(0),
          reason: 'Offline-first delivery order must not trigger direct HTTP createOrder call');
      expect(mockWorker.triggerPushCount, equals(1),
          reason: 'triggerPush must be called once on local commit');

      // 2. Simulate client experiencing a timeout / network retry with the same order ID
      final order2 = await notifier.createDeliveryOrder(
        customerName: 'John Doe',
        customerPhone: '1234567890',
        deliveryAddress: '123 Main St',
        deliveryFee: 5.0,
        subtotal: 30.0,
        grandTotal: 35.0,
        paymentMethod: 'Cash',
        paymentStatus: 'UNPAID',
        itemsSummary: '2x Pepperoni Pizza',
        items: items,
        existingOrderId: clientOrderId,
      );

      expect(order2.orderId, equals(clientOrderId));
      expect(mockOrdersApi.createOrderCallCount, equals(0),
          reason: 'Retry must not call direct HTTP create');

      // 3. Verify exactly one order exists in local Drift database
      final matchingOrders = await (testDb.select(testDb.localOrders)
            ..where((t) => t.id.equals(clientOrderId)))
          .get();
      expect(matchingOrders.length, equals(1),
          reason: 'Simulated timeout retry must result in exactly one order ID in local DB');

      // 4. Verify exactly one outbox row exists
      final outboxEntries = await testDb.outboxDao.getAllEntries();
      final matchingOutbox = outboxEntries.where((o) => o.entityId == clientOrderId).toList();
      expect(matchingOutbox.length, equals(1),
          reason: 'Simulated timeout retry must result in exactly one outbox row');
    });
  });
}
