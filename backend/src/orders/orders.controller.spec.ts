import { Test, TestingModule } from '@nestjs/testing';
import { Prisma } from '@prisma/client';
import { OrdersController } from './orders.controller';
import { OrdersService, OrderWithDetails } from './orders.service';
import { PermissionsService } from '../permissions/permissions.service';
import { PrismaService } from '../prisma/prisma.service';

describe('OrdersController', () => {
  let controller: OrdersController;

  const mockOrder = {
    id: 'ord-1',
    order_number: 'ORD-1001',
    order_type: 'dineIn',
    status: 'newOrder',
    subtotal: new Prisma.Decimal(1798.0),
    discount_percentage: new Prisma.Decimal(0.0),
    discount_amount: new Prisma.Decimal(0.0),
    tax_amount: new Prisma.Decimal(0.0),
    grand_total: new Prisma.Decimal(1798.0),
    payment_status: 'UNPAID',
    is_paid: false,
    is_held: false,
    kitchen_ticket_sent: true,
    rejection_reason: null,
    cooking_time_minutes: 20,
    estimated_ready_at: new Date('2026-09-26T21:00:00Z'),
    created_at: new Date('2026-09-26T20:30:00Z'),
    order_items: [],
    payments: [],
    online_detail: null,
    takeaway_detail: null,
    dine_in_detail: {
      id: 'dine-1',
      order_id: 'ord-1',
      table_id: 'tbl-1',
      guest_count: 2,
      waiter_name: 'Elena (Cashier)',
      dine_in_tax: new Prisma.Decimal(0.0),
      table: { id: 'tbl-1', name: 'Table 4', table_number: 'T-04' },
    } as any,
  } as unknown as OrderWithDetails;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [OrdersController],
      providers: [
        {
          provide: OrdersService,
          useValue: {
            listOrders: jest.fn().mockResolvedValue([mockOrder]),
            getOrderById: jest.fn().mockResolvedValue(mockOrder),
            createOrder: jest.fn().mockResolvedValue(mockOrder),
            updateOrder: jest.fn().mockResolvedValue(mockOrder),
            appendOrderItems: jest.fn().mockResolvedValue(mockOrder),
            voidOrderItem: jest.fn().mockResolvedValue(mockOrder),
            updateOrderStatus: jest.fn().mockResolvedValue({
              ...mockOrder,
              status: 'preparing',
            }),
            refundOrder: jest.fn().mockResolvedValue({
              adjustment_id: 'adj-1',
              order: { ...mockOrder, status: 'cancelled', payment_status: 'REFUNDED' },
            }),
            deleteOrder: jest.fn().mockResolvedValue({ message: 'Order deleted' }),
          },
        },
        {
          provide: PermissionsService,
          useValue: {
            hasPermission: jest.fn().mockResolvedValue(true),
          },
        },
        {
          provide: PrismaService,
          useValue: {
            processedOperation: {
              findUnique: jest.fn().mockResolvedValue(null),
              create: jest.fn().mockResolvedValue({}),
              update: jest.fn().mockResolvedValue({}),
              delete: jest.fn().mockResolvedValue({}),
            },
          },
        },
      ],
    }).compile();

    controller = module.get<OrdersController>(OrdersController);
  });

  it('should list orders', async () => {
    const result = await controller.listOrders({});
    expect(result.success).toBe(true);
    expect(result.data).toHaveLength(1);
    expect(result.data?.[0].order_number).toBe('ORD-1001');
  });

  it('should get order by id', async () => {
    const result = await controller.getOrderById('ord-1');
    expect(result.success).toBe(true);
    expect(result.data?.id).toBe('ord-1');
  });

  it('should create order', async () => {
    const result = await controller.createOrder({
      order_type: 'dineIn',
      items: [
        {
          item_name: 'Pepperoni Pizza',
          quantity: 1,
          unit_price: 899.0,
        },
      ],
    });
    expect(result.success).toBe(true);
    expect(result.message).toBe('Order created successfully');
  });

  it('should update order', async () => {
    const result = await controller.updateOrder('ord-1', {
      is_held: true,
    });
    expect(result.success).toBe(true);
    expect(result.message).toBe('Order updated successfully');
  });

  it('should update order status', async () => {
    const result = await controller.updateOrderStatus('ord-1', {
      status: 'preparing',
    });
    expect(result.success).toBe(true);
    expect(result.data?.status).toBe('preparing');
  });

  it('should delete order', async () => {
    const result = await controller.deleteOrder('ord-1');
    expect(result.success).toBe(true);
  });

  it('should append order items (POST /orders/:id/items)', async () => {
    const result = await controller.appendOrderItems('ord-1', {
      items: [
        {
          item_name: 'Garlic Bread',
          quantity: 1,
          unit_price: 300.0,
        },
      ],
    });
    expect(result.success).toBe(true);
    expect(result.message).toBe('Order items appended successfully');
  });

  it('should void order item (POST /orders/:id/items/:itemId/void)', async () => {
    const result = await controller.voidOrderItem('ord-1', 'item-1', {
      reason: 'Guest changed mind',
      voided_by: 'Cashier Elena',
    });
    expect(result.success).toBe(true);
    expect(result.message).toBe('Order item voided successfully');
  });

  it('should refund order (POST /orders/:id/refund)', async () => {
    const result = await controller.refundOrder('ord-1', {
      supervisor_pin: '1234',
      reason: 'Wrong item charged',
      refund_method: 'cash',
    });
    expect(result.adjustment_id).toBe('adj-1');
    expect(result.order.status).toBe('cancelled');
    expect(result.order.payment_status).toBe('REFUNDED');
  });
});
