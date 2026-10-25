import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:hungry_howies_pos/core/database/app_database.dart';
import 'package:hungry_howies_pos/core/sync/sync_providers.dart';
import 'package:hungry_howies_pos/data/pos_repository.dart';
import 'package:hungry_howies_pos/data/repositories/drift_offline_first_order_repository.dart';
import 'package:hungry_howies_pos/data/repositories/order_repository_provider.dart';
import 'package:hungry_howies_pos/domain/models/menu_item.dart';
import 'package:hungry_howies_pos/domain/models/order_model.dart';

import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('POS Repository & Seam Integration Tests (§15.2, §17.2)', () {
    late AppDatabase testDb;

    const testPizza = MenuItem(
      id: 'pizza-01',
      name: 'Large Butter Cheese Pizza',
      category: 'Pizza',
      description: 'Hungry Howies Classic',
      basePrice: 18.99,
      imageUrl: '',
    );

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      testDb = AppDatabase(
        NativeDatabase.memory(
          setup: (rawDb) {
            rawDb.execute('PRAGMA foreign_keys = ON;');
          },
        ),
      );
    });

    tearDown(() async {
      await testDb.close();
    });

    test('1. Rapid Button Mashing Defense (§15.2 Tier 1): Concurrent checkout calls return same order', () async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(testDb),
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

      final notifier = container.read(posProvider.notifier);

      // Add item to cart
      notifier.addToCart(testPizza, size: 'Large', crust: 'Butter Cheese');
      expect(container.read(posProvider).currentCart.length, equals(1));

      // Simulate rapid 5x clicks on checkout button
      final results = await Future.wait([
        notifier.processOrderCheckout(PaymentMethod.cash),
        notifier.processOrderCheckout(PaymentMethod.cash),
        notifier.processOrderCheckout(PaymentMethod.cash),
        notifier.processOrderCheckout(PaymentMethod.cash),
        notifier.processOrderCheckout(PaymentMethod.cash),
      ]);

      expect(results.length, equals(5));

      // All 5 invocations must return the EXACT same order instance
      final firstOrder = results.first;
      for (final order in results) {
        expect(order.id, equals(firstOrder.id));
        expect(order.orderNumber, equals(firstOrder.orderNumber));
        expect(order.isPaid, isTrue);
      }

      // Verify only 1 order was persisted in Drift database
      final driftRepo = container.read(driftOfflineFirstOrderRepositoryProvider);
      final allOrders = await driftRepo.getAllOrders();
      expect(allOrders.length, equals(1),
          reason: 'Tier 1 in-flight future lock must prevent multiple order rows');

      // Verify only 1 outbox record was enqueued
      final outboxEntries = await testDb.outboxDao.getAllEntries();
      expect(outboxEntries.length, equals(1),
          reason: 'Only one mutation must be enqueued into sync_outbox');
    });

    test('2. Offline Checkout Flow: Completes order into Drift SQLite WAL and returns instantly', () async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(testDb),
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

      final notifier = container.read(posProvider.notifier);
      notifier.addToCart(testPizza);

      final completedOrder = await notifier.processOrderCheckout(PaymentMethod.cash);

      expect(completedOrder.orderNumber, startsWith('P1-'));
      expect(completedOrder.isPaid, isTrue);
      expect(completedOrder.kitchenTicketSent, isTrue);

      // Verify cart was cleared and completed orders list updated
      final state = container.read(posProvider);
      expect(state.currentCart, isEmpty);
      expect(state.completedOrders.length, equals(1));
      expect(state.completedOrders.first.id, equals(completedOrder.id));
    });
  });
}
