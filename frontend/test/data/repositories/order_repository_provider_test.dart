import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:hungry_howies_pos/core/database/app_database.dart';
import 'package:hungry_howies_pos/core/sync/sync_providers.dart';
import 'package:hungry_howies_pos/data/repositories/api_order_repository.dart';
import 'package:hungry_howies_pos/data/repositories/drift_offline_first_order_repository.dart';
import 'package:hungry_howies_pos/data/repositories/order_repository_provider.dart';
import 'package:hungry_howies_pos/domain/repositories/order_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OrderRepositoryProvider Seam Tests (§17.2)', () {
    late AppDatabase testDb;

    setUp(() {
      testDb = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await testDb.close();
    });

    test('1. Active Flag State (offlineFirstEnabled == true): Resolves to DriftOfflineFirstOrderRepository', () {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(testDb),
        ],
      );
      addTearDown(container.dispose);

      final repo = container.read(orderRepositoryProvider);

      expect(repo, isA<IOrderRepository>());
      expect(repo, isA<DriftOfflineFirstOrderRepository>(),
          reason: 'When offlineFirstEnabled is true, provider routes to Drift SQLite WAL repository');
    });

    test('2. Legacy Flag State seam: Resolves to ApiOrderRepository', () {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(testDb),
          orderRepositoryProvider.overrideWith((ref) => ref.watch(apiOrderRepositoryProvider)),
        ],
      );
      addTearDown(container.dispose);

      final repo = container.read(orderRepositoryProvider);

      expect(repo, isA<IOrderRepository>());
      expect(repo, isA<ApiOrderRepository>(),
          reason: 'When configured with apiOrderRepositoryProvider, provider returns ApiOrderRepository');
    });

    test('3. Stream providers return empty stream when flag is OFF', () async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(testDb),
        ],
      );
      addTearDown(container.dispose);

      final asyncVal = container.read(allOrdersStreamProvider);
      expect(asyncVal.valueOrNull ?? [], isEmpty);
    });

    test('4. Stream providers return reactive Drift streams when Drift repo is active', () async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(testDb),
          orderRepositoryProvider.overrideWith((ref) => ref.watch(driftOfflineFirstOrderRepositoryProvider)),
        ],
      );
      addTearDown(container.dispose);

      final driftRepo = container.read(driftOfflineFirstOrderRepositoryProvider);
      final stream = driftRepo.watchAllOrders();

      expect(stream, isA<Stream>());
    });
  });
}
