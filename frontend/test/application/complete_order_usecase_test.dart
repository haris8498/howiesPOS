import 'package:flutter_test/flutter_test.dart';
import 'package:hungry_howies_pos/application/orders/complete_order_usecase.dart';
import 'package:hungry_howies_pos/data/repositories/in_memory_inventory_repository.dart';
import 'package:hungry_howies_pos/data/repositories/in_memory_kitchen_repository.dart';
import 'package:hungry_howies_pos/data/repositories/in_memory_order_repository.dart';
import 'package:hungry_howies_pos/data/repositories/in_memory_table_repository.dart';
import 'package:hungry_howies_pos/domain/models/menu_item.dart';
import 'package:hungry_howies_pos/domain/models/order_model.dart';
import 'package:hungry_howies_pos/domain/models/restaurant_table.dart';

void main() {
  group('CompleteOrderUseCase Coordinated Transaction Tests', () {
    late InMemoryOrderRepository orderRepo;
    late InMemoryTableRepository tableRepo;
    late InMemoryKitchenRepository kitchenRepo;
    late InMemoryInventoryRepository inventoryRepo;
    late CompleteOrderUseCase useCase;

    const testItem = MenuItem(
      id: 'p1',
      name: 'Howie Special Pizza',
      category: 'Pizza',
      description: 'Test Pizza',
      basePrice: 15.0,
      imageUrl: 'https://example.com/pizza.jpg',
    );

    setUp(() {
      orderRepo = InMemoryOrderRepository();
      tableRepo = InMemoryTableRepository();
      kitchenRepo = InMemoryKitchenRepository();
      inventoryRepo = InMemoryInventoryRepository();

      useCase = CompleteOrderUseCase(
        orderRepository: orderRepo,
        tableRepository: tableRepo,
        kitchenRepository: kitchenRepo,
        inventoryRepository: inventoryRepo,
      );
    });

    test('successfully coordinates checkout across Order, Table, Kitchen, and Inventory', () async {
      const table = RestaurantTable(
        id: 't1',
        name: 'Table 01',
        tableNumber: '01',
        section: 'Hall',
        capacity: 4,
        status: TableStatus.occupied,
      );
      await tableRepo.saveTable(table);

      final command = CompleteOrderCommand(
        items: const [
          OrderItem(
            item: testItem,
            quantity: 2,
            selectedSize: 'Large',
          ),
        ],
        orderType: OrderType.dineIn,
        paymentMethod: PaymentMethod.cash,
        selectedTable: table,
        guestCount: 2,
        waiterName: 'Elena (Cashier)',
      );

      final result = await useCase.execute(command);

      expect(result.isSuccess, isTrue);
      final order = result.data;
      expect(order.orderNumber, isNotEmpty);
      expect(order.isPaid, isTrue);
      expect(order.kitchenTicketSent, isTrue);

      // 1. Verify Order is saved in OrderRepository
      final savedOrders = await orderRepo.getAllOrders();
      expect(savedOrders.length, equals(1));
      expect(savedOrders.first.id, equals(order.id));

      // 2. Verify Kitchen KDS ticket was created
      final kitchenOrders = await kitchenRepo.getKitchenOrders();
      expect(kitchenOrders.length, equals(1));
      expect(kitchenOrders.first.id, equals(order.id));

      // 3. Verify Table was freed
      final updatedTable = await tableRepo.getTableById('t1');
      expect(updatedTable?.status, equals(TableStatus.available));
      expect(updatedTable?.activeOrderId, isNull);

      // 4. Verify Inventory stock movement was recorded
      final movements = await inventoryRepo.getStockMovements();
      expect(movements, isNotEmpty);
    });

    test('fails gracefully when cart is empty', () async {
      final command = const CompleteOrderCommand(
        items: [],
        orderType: OrderType.takeAway,
        paymentMethod: PaymentMethod.cash,
      );

      final result = await useCase.execute(command);
      expect(result.isFailure, isTrue);
      expect(result.failure.message, contains('empty'));
    });
  });
}
