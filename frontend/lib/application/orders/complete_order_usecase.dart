import '../../core/errors/failures.dart';
import '../../core/result/result.dart';
import '../../domain/models/order_model.dart';
import '../../domain/models/restaurant_table.dart';
import '../../domain/repositories/inventory_repository.dart';
import '../../domain/repositories/kitchen_repository.dart';
import '../../domain/repositories/order_repository.dart';
import '../../domain/repositories/table_repository.dart';
import '../../domain/services/order_number_generator.dart';
import '../../domain/services/order_validation_service.dart';
import '../../domain/services/pricing_engine.dart';
import '../../domain/services/stock_deduction_engine.dart';

/// Request DTO for completing an order
class CompleteOrderCommand {
  final List<OrderItem> items;
  final OrderType orderType;
  final PaymentMethod paymentMethod;
  final RestaurantTable? selectedTable;
  final int guestCount;
  final String waiterName;
  final String? customerName;
  final String? customerPhone;
  final String? deliveryAddress;
  final double discountPercentage;
  final double discountAmount;

  const CompleteOrderCommand({
    required this.items,
    required this.orderType,
    required this.paymentMethod,
    this.selectedTable,
    this.guestCount = 1,
    this.waiterName = 'Elena (Cashier)',
    this.customerName,
    this.customerPhone,
    this.deliveryAddress,
    this.discountPercentage = 0.0,
    this.discountAmount = 0.0,
  });
}

/// Comprehensive Application Use Case for completing POS orders.
/// Enforces a clear transaction boundary across Order, Payment, Table, Kitchen, and Inventory.
class CompleteOrderUseCase {
  final IOrderRepository orderRepository;
  final ITableRepository? tableRepository;
  final IKitchenRepository? kitchenRepository;
  final IInventoryRepository? inventoryRepository;
  final OrderValidationService validationService;
  final PricingEngine pricingEngine;
  final IOrderNumberGenerator orderNumberGenerator;
  final StockDeductionEngine stockDeductionEngine;

  CompleteOrderUseCase({
    required this.orderRepository,
    this.tableRepository,
    this.kitchenRepository,
    this.inventoryRepository,
    this.validationService = const OrderValidationService(),
    this.pricingEngine = const PricingEngine(),
    IOrderNumberGenerator? orderNumberGenerator,
    this.stockDeductionEngine = const StockDeductionEngine(),
  }) : orderNumberGenerator = orderNumberGenerator ?? OrderNumberGenerator();

  Future<Result<OrderModel, Failure>> execute(CompleteOrderCommand command) async {
    // 1. Validate Order Inputs
    final validationResult = validationService.validateOrderForCheckout(
      cartItems: command.items,
      orderType: command.orderType,
      tableId: command.selectedTable?.id,
      customerName: command.customerName,
      customerPhone: command.customerPhone,
      deliveryAddress: command.deliveryAddress,
      paymentMethod: command.paymentMethod,
    );

    if (validationResult.isFailure) {
      return Result.failure(validationResult.failure);
    }

    try {
      // 2. Calculate Final Pricing Totals through Pure Domain Engine
      final totals = pricingEngine.calculateOrderTotals(
        items: command.items,
        orderType: command.orderType,
        discountPercentage: command.discountPercentage,
        discountAmount: command.discountAmount,
      );

      // 3. Generate Secure Order Identifiers & Tokens
      final orderId = orderNumberGenerator.generateUniqueId();
      final orderNumber = orderNumberGenerator.generateOrderNumber();
      final tokenNumber = (command.orderType == OrderType.takeaway || command.orderType == OrderType.takeAway)
          ? orderNumberGenerator.generateTakeawayToken()
          : null;

      // 4. Construct Immutable Order Model
      OnlineOrderDetail? onlineDetail;
      if (command.orderType == OrderType.delivery || command.orderType == OrderType.online) {
        onlineDetail = OnlineOrderDetail(
          id: orderId,
          orderId: orderId,
          orderSource: 'POS',
          customerName: command.customerName ?? 'Walk-in Delivery',
          customerPhone: command.customerPhone ?? '',
          deliveryAddress: command.deliveryAddress ?? '',
          deliveryFee: totals.deliveryFee,
        );
      }

      TakeawayOrderDetail? takeawayDetail;
      if (command.orderType == OrderType.takeaway || command.orderType == OrderType.takeAway) {
        takeawayDetail = TakeawayOrderDetail(
          id: orderId,
          orderId: orderId,
          customerName: command.customerName ?? 'Guest Customer',
          customerPhone: command.customerPhone ?? '',
          tokenNumber: tokenNumber ?? 'TK-1',
        );
      }

      DineInOrderDetail? dineInDetail;
      if (command.orderType == OrderType.dineIn || command.orderType == OrderType.quickOrder) {
        dineInDetail = DineInOrderDetail(
          id: orderId,
          orderId: orderId,
          tableId: command.selectedTable?.id ?? '',
          guestCount: command.guestCount,
          waiterName: command.waiterName,
          dineInTax: totals.taxAmount,
        );
      }

      final completedOrder = OrderModel(
        id: orderId,
        orderNumber: orderNumber,
        tokenNumber: tokenNumber,
        tableId: command.selectedTable?.id,
        tableName: command.selectedTable?.name,
        guestCount: command.guestCount,
        waiterName: command.waiterName,
        type: command.orderType,
        status: OrderStatus.accepted,
        items: List.unmodifiable(command.items),
        createdAt: DateTime.now(),
        discountPercentage: totals.discountPercentage,
        discountAmount: totals.discountAmount,
        taxAmount: totals.taxAmount,
        taxPercentage: pricingEngine.policy.taxPercentage,
        serviceChargePercentage: pricingEngine.policy.serviceChargePercentage,
        deliveryFee: totals.deliveryFee,
        customerName: command.customerName,
        customerPhone: command.customerPhone,
        deliveryAddress: command.deliveryAddress,
        paymentMethod: command.paymentMethod,
        isPaid: true,
        kitchenTicketSent: true,
        onlineDetail: onlineDetail,
        takeawayDetail: takeawayDetail,
        dineInDetail: dineInDetail,
        payments: [
          OrderPaymentModel(
            paymentMethod: command.paymentMethod.name,
            amount: totals.grandTotal,
            tenderedAmount: totals.grandTotal,
            changeReturned: 0.0,
            paymentStatus: 'COMPLETED',
            receivedBy: command.waiterName,
            createdAt: DateTime.now(),
          ),
        ],
      );

      // 5. Persist Order Record
      final savedOrder = await orderRepository.saveOrder(completedOrder);

      // 6. Update Table State if Dine-In
      if (command.selectedTable != null && tableRepository != null) {
        await tableRepository!.freeTable(command.selectedTable!.id);
      }

      // 7. Dispatch Kitchen Ticket to KDS (Solves Disconnected Kitchen Ticket Defect)
      if (kitchenRepository != null) {
        await kitchenRepository!.addKitchenOrder(savedOrder);
      }

      // 8. Deduct Inventory Ingredients (Solves Transaction Isolation Defect)
      if (inventoryRepository != null) {
        final requiredIngredients = stockDeductionEngine.calculateTotalIngredientRequirements(command.items);
        for (final entry in requiredIngredients.entries) {
          await inventoryRepository!.deductStockByItemName(
            entry.key,
            entry.value,
            'Order $orderNumber Auto-Deduction',
          );
        }
      }

      return Result.success(savedOrder);
    } catch (e) {
      return Result.failure(OrderFailure('Failed to complete transaction: $e'));
    }
  }
}
