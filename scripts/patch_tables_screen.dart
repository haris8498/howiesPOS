import 'dart:io';

void main() {
  final file = File('frontend/lib/features/tables/tables_screen.dart');
  String content = file.readAsStringSync();

  // 1. Order Creation & Modification (around line 3801)
  final targetBlock1 = '''                                    try {
                                      final ordersApi = widget.ref.read(ordersApiServiceProvider);
                                      if (effectiveOrderId != null && effectiveOrderId.isNotEmpty) {
                                        // Update / Modify existing order in database
                                        final updatedOrder = await ordersApi.updateOrder(effectiveOrderId, {
                                          'order_type': 'dineIn',
                                          if (table.id.isNotEmpty) 'table_id': table.id,
                                          'status': 'newOrder',
                                          'items': itemsPayload,
                                        });
                                        effectiveOrderId = updatedOrder['id']?.toString() ?? effectiveOrderId;
                                        effectiveOrderNumber = updatedOrder['order_number']?.toString() ?? effectiveOrderNumber;
                                        await ReceiptPrinterService.unmarkOrderKitchenReceiptPrinted(
                                          orderId: effectiveOrderId,
                                          orderNumber: effectiveOrderNumber,
                                          tableNumber: table.tableNumber,
                                        );
                                        debugPrint('✅ Dine-in Order modified in DB successfully: \$effectiveOrderId (#\$effectiveOrderNumber)');
                                      } else {
                                        // Insert New Dine-In Order into Database
                                        final orderDto = {
                                          'order_type': 'dineIn',
                                          if (table.id.isNotEmpty) 'table_id': table.id,
                                          'guest_count': table.capacity > 0 ? table.capacity : 1,
                                          'status': 'newOrder',
                                          'subtotal': _totalBill,
                                          'grand_total': _totalBill,
                                          'items': itemsPayload,
                                        };

                                        final createdOrder = await ordersApi.createOrder(orderDto);
                                        effectiveOrderId = createdOrder['id']?.toString();
                                        effectiveOrderNumber = createdOrder['order_number']?.toString();
                                        debugPrint('✅ Dine-in Order saved in DB successfully: \$effectiveOrderId (#\$effectiveOrderNumber)');
                                      }
                                    } catch (e) {
                                      debugPrint('⚠️ Error updating/creating dine-in order in DB: \$e');
                                    }''';

  final replacementBlock1 = '''                                    try {
                                      if (FeatureFlags.offlineFirstEnabled) {
                                        final orderRepo = widget.ref.read(orderRepositoryProvider);
                                        final orderItems = _cartItems.map((c) {
                                          final itemId = (c.item.id != null && c.item.id!.isNotEmpty && c.item.id!.length >= 30)
                                              ? c.item.id!
                                              : const Uuid().v7();
                                          return OrderItem(
                                            id: const Uuid().v7(),
                                            item: MenuItem(
                                              id: itemId,
                                              name: c.item.name,
                                              category: c.item.category,
                                              description: '',
                                              basePrice: c.item.price,
                                              imageUrl: c.item.imagePath,
                                            ),
                                            quantity: c.quantity,
                                            backendUnitPrice: c.item.price,
                                          );
                                        }).toList();

                                        if (effectiveOrderId != null && effectiveOrderId.isNotEmpty) {
                                          final existing = await orderRepo.getOrderById(effectiveOrderId);
                                          if (existing != null) {
                                            final updated = existing.copyWith(
                                              items: orderItems,
                                              subtotalOverride: _totalBill,
                                              grandTotalOverride: _totalBill,
                                              status: OrderStatus.newOrder,
                                            );
                                            final saved = await orderRepo.updateOrder(updated);
                                            effectiveOrderId = saved.id;
                                            effectiveOrderNumber = saved.orderNumber;
                                          } else {
                                            final newOrder = OrderModel(
                                              id: effectiveOrderId,
                                              orderNumber: effectiveOrderNumber ?? '',
                                              type: OrderType.dineIn,
                                              status: OrderStatus.newOrder,
                                              items: orderItems,
                                              createdAt: DateTime.now(),
                                              subtotalOverride: _totalBill,
                                              grandTotalOverride: _totalBill,
                                              dineInDetail: DineInOrderDetail(
                                                id: const Uuid().v7(),
                                                orderId: effectiveOrderId,
                                                tableId: table.id,
                                                guestCount: table.capacity > 0 ? table.capacity : 1,
                                                waiterName: 'Cashier',
                                              ),
                                            );
                                            final saved = await orderRepo.saveOrder(newOrder);
                                            effectiveOrderId = saved.id;
                                            effectiveOrderNumber = saved.orderNumber;
                                          }
                                        } else {
                                          final orderUuid = const Uuid().v7();
                                          final newOrder = OrderModel(
                                            id: orderUuid,
                                            orderNumber: '',
                                            type: OrderType.dineIn,
                                            status: OrderStatus.newOrder,
                                            items: orderItems,
                                            createdAt: DateTime.now(),
                                            subtotalOverride: _totalBill,
                                            grandTotalOverride: _totalBill,
                                            dineInDetail: DineInOrderDetail(
                                              id: const Uuid().v7(),
                                              orderId: orderUuid,
                                              tableId: table.id,
                                              guestCount: table.capacity > 0 ? table.capacity : 1,
                                              waiterName: 'Cashier',
                                            ),
                                          );
                                          final saved = await orderRepo.saveOrder(newOrder);
                                          effectiveOrderId = saved.id;
                                          effectiveOrderNumber = saved.orderNumber;
                                        }
                                        await ReceiptPrinterService.unmarkOrderKitchenReceiptPrinted(
                                          orderId: effectiveOrderId,
                                          orderNumber: effectiveOrderNumber,
                                          tableNumber: table.tableNumber,
                                        );
                                        debugPrint('✅ Offline-first dine-in order persisted: \$effectiveOrderId (#\$effectiveOrderNumber)');
                                      } else {
                                        final ordersApi = widget.ref.read(ordersApiServiceProvider);
                                        if (effectiveOrderId != null && effectiveOrderId.isNotEmpty) {
                                          // Update / Modify existing order in database
                                          final updatedOrder = await ordersApi.updateOrder(effectiveOrderId, {
                                            'order_type': 'dineIn',
                                            if (table.id.isNotEmpty) 'table_id': table.id,
                                            'status': 'newOrder',
                                            'items': itemsPayload,
                                          });
                                          effectiveOrderId = updatedOrder['id']?.toString() ?? effectiveOrderId;
                                          effectiveOrderNumber = updatedOrder['order_number']?.toString() ?? effectiveOrderNumber;
                                          await ReceiptPrinterService.unmarkOrderKitchenReceiptPrinted(
                                            orderId: effectiveOrderId,
                                            orderNumber: effectiveOrderNumber,
                                            tableNumber: table.tableNumber,
                                          );
                                          debugPrint('✅ Dine-in Order modified in DB successfully: \$effectiveOrderId (#\$effectiveOrderNumber)');
                                        } else {
                                          // Insert New Dine-In Order into Database
                                          final orderDto = {
                                            'order_type': 'dineIn',
                                            if (table.id.isNotEmpty) 'table_id': table.id,
                                            'guest_count': table.capacity > 0 ? table.capacity : 1,
                                            'status': 'newOrder',
                                            'subtotal': _totalBill,
                                            'grand_total': _totalBill,
                                            'items': itemsPayload,
                                          };

                                          final createdOrder = await ordersApi.createOrder(orderDto);
                                          effectiveOrderId = createdOrder['id']?.toString();
                                          effectiveOrderNumber = createdOrder['order_number']?.toString();
                                          debugPrint('✅ Dine-in Order saved in DB successfully: \$effectiveOrderId (#\$effectiveOrderNumber)');
                                        }
                                      }
                                    } catch (e) {
                                      debugPrint('⚠️ Error updating/creating dine-in order: \$e');
                                    }''';

  if (!content.contains(targetBlock1)) {
    print('ERROR: targetBlock1 not found!');
    return;
  }
  content = content.replaceFirst(targetBlock1, replacementBlock1);
  print('Successfully patched block 1 (Order creation/update)');

  // 2. Single-tender payment completion (around line 5131)
  final targetBlock2 = '''                          try {
                            final ordersApi = widget.ref.read(ordersApiServiceProvider);
                            await ordersApi.updateOrder(effectiveOrderId, {
                              'status': 'completed',
                              'payment_status': 'PAID',
                              'is_paid': true,
                              'payment_method': 'Cash',
                              'discount_amount': discountAmount,
                              'discount_percentage': effectiveDiscountPct,
                              'dine_in_tax': taxAmount,
                              'tax_amount': taxAmount,
                              'grand_total': netTotal,
                              'payments': [
                                {
                                  'payment_method': 'cash',
                                  'amount': netTotal,
                                  'tendered_amount': _cashGiven > 0 ? _cashGiven : netTotal,
                                  'change_returned': changeReturn >= 0 ? changeReturn : 0.0,
                                  'payment_status': 'COMPLETED',
                                  'received_by': 'Cashier',
                                }
                              ],
                            });
                          } catch (e) {
                            debugPrint('⚠️ Error completing table payment in DB: \$e');
                          }''';

  final replacementBlock2 = '''                          try {
                            if (FeatureFlags.offlineFirstEnabled) {
                              final orderRepo = widget.ref.read(orderRepositoryProvider);
                              final existing = await orderRepo.getOrderById(effectiveOrderId);
                              if (existing != null) {
                                final paidOrder = existing.copyWith(
                                  status: OrderStatus.completed,
                                  paymentStatus: 'PAID',
                                  isPaid: true,
                                  discountAmount: discountAmount,
                                  discountPercentage: effectiveDiscountPct,
                                  taxAmount: taxAmount,
                                  grandTotalOverride: netTotal,
                                  payments: [
                                    OrderPaymentModel(
                                      id: const Uuid().v7(),
                                      paymentMethod: 'cash',
                                      amount: netTotal,
                                      tenderedAmount: _cashGiven > 0 ? _cashGiven : netTotal,
                                      changeReturned: changeReturn >= 0 ? changeReturn : 0.0,
                                      paymentStatus: 'COMPLETED',
                                      receivedBy: 'Cashier',
                                      createdAt: DateTime.now(),
                                    ),
                                  ],
                                  dineInDetail: existing.dineInDetail?.copyWith(dineInTax: taxAmount),
                                );
                                await orderRepo.updateOrder(paidOrder);
                              }
                            } else {
                              final ordersApi = widget.ref.read(ordersApiServiceProvider);
                              await ordersApi.updateOrder(effectiveOrderId, {
                                'status': 'completed',
                                'payment_status': 'PAID',
                                'is_paid': true,
                                'payment_method': 'Cash',
                                'discount_amount': discountAmount,
                                'discount_percentage': effectiveDiscountPct,
                                'dine_in_tax': taxAmount,
                                'tax_amount': taxAmount,
                                'grand_total': netTotal,
                                'payments': [
                                  {
                                    'payment_method': 'cash',
                                    'amount': netTotal,
                                    'tendered_amount': _cashGiven > 0 ? _cashGiven : netTotal,
                                    'change_returned': changeReturn >= 0 ? changeReturn : 0.0,
                                    'payment_status': 'COMPLETED',
                                    'received_by': 'Cashier',
                                  }
                                ],
                              });
                            }
                          } catch (e) {
                            debugPrint('⚠️ Error completing table payment in DB: \$e');
                          }''';

  if (!content.contains(targetBlock2)) {
    print('ERROR: targetBlock2 not found!');
    return;
  }
  content = content.replaceFirst(targetBlock2, replacementBlock2);
  print('Successfully patched block 2 (Single-tender payment)');

  // 3. Multi-tender payment completion (around line 5742)
  final targetBlock3 = '''      try {
        final ordersApi = widget.ref.read(ordersApiServiceProvider);
        await ordersApi.updateOrder(effectiveOrderId, {
          'status': 'completed',
          'payment_status': 'PAID',
          'is_paid': true,
          'payment_method': primaryMethod,
          'discount_amount': widget.discountAmount ?? widget.table.discountAmount,
          'discount_percentage': widget.discountPercentage ?? widget.table.discountPercentage,
          'dine_in_tax': widget.dineInTax ?? widget.table.dineInTax,
          'tax_amount': widget.dineInTax ?? widget.table.dineInTax,
          'grand_total': widget.billAmount,
          'payments': paymentsList,
        });
        debugPrint('✅ Payment successfully persisted in DB for order: \$effectiveOrderId');
      } catch (e) {
        debugPrint('⚠️ Error settling table payment in DB: \$e');
      }''';

  final replacementBlock3 = '''      try {
        if (FeatureFlags.offlineFirstEnabled) {
          final orderRepo = widget.ref.read(orderRepositoryProvider);
          final existing = await orderRepo.getOrderById(effectiveOrderId);
          if (existing != null) {
            final mappedPayments = paymentsList.map((p) => OrderPaymentModel(
              id: const Uuid().v7(),
              paymentMethod: p['payment_method']?.toString() ?? 'cash',
              amount: double.tryParse(p['amount']?.toString() ?? '0') ?? 0.0,
              tenderedAmount: double.tryParse(p['tendered_amount']?.toString() ?? '0'),
              changeReturned: double.tryParse(p['change_returned']?.toString() ?? '0'),
              paymentStatus: 'COMPLETED',
              receivedBy: 'Cashier',
              createdAt: DateTime.now(),
            )).toList();
            final taxAmt = widget.dineInTax ?? widget.table.dineInTax;
            final updated = existing.copyWith(
              status: OrderStatus.completed,
              paymentStatus: 'PAID',
              isPaid: true,
              discountAmount: widget.discountAmount ?? widget.table.discountAmount,
              discountPercentage: widget.discountPercentage ?? widget.table.discountPercentage,
              taxAmount: taxAmt,
              grandTotalOverride: widget.billAmount,
              payments: mappedPayments,
              dineInDetail: existing.dineInDetail?.copyWith(dineInTax: taxAmt),
            );
            await orderRepo.updateOrder(updated);
          }
        } else {
          final ordersApi = widget.ref.read(ordersApiServiceProvider);
          await ordersApi.updateOrder(effectiveOrderId, {
            'status': 'completed',
            'payment_status': 'PAID',
            'is_paid': true,
            'payment_method': primaryMethod,
            'discount_amount': widget.discountAmount ?? widget.table.discountAmount,
            'discount_percentage': widget.discountPercentage ?? widget.table.discountPercentage,
            'dine_in_tax': widget.dineInTax ?? widget.table.dineInTax,
            'tax_amount': widget.dineInTax ?? widget.table.dineInTax,
            'grand_total': widget.billAmount,
            'payments': paymentsList,
          });
        }
        debugPrint('✅ Payment successfully persisted in DB for order: \$effectiveOrderId');
      } catch (e) {
        debugPrint('⚠️ Error settling table payment in DB: \$e');
      }''';

  if (!content.contains(targetBlock3)) {
    print('ERROR: targetBlock3 not found!');
    return;
  }
  content = content.replaceFirst(targetBlock3, replacementBlock3);
  print('Successfully patched block 3 (Multi-tender payment)');

  file.writeAsStringSync(content);
  print('Successfully updated frontend/lib/features/tables/tables_screen.dart!');
}
