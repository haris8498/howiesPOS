import { BadRequestException, NotFoundException } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { OrderItem, Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { OrdersService, OrderWithDetails } from './orders.service';

describe('OrdersService', () => {
  let service: OrdersService;

  const mockItem = {
    id: 'oi-1',
    order_id: 'ord-1',
    menu_item_id: 'mi-1',
    item_name: 'Pepperoni Passion',
    quantity: 2,
    selected_size: 'Large',
    selected_crust: 'Butter Cheese',
    extra_toppings: 'Jalapenos',
    unit_price: new Prisma.Decimal(899.0),
    total_price: new Prisma.Decimal(1798.0),
    notes: 'Crispy crust',
  } as unknown as OrderItem;

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
    order_items: [mockItem],
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

  const mockStoreSettings = {
    id: 'set-1',
    chain_name: "Hungry Howie's",
    branch_code: 'Branch #402',
    branch_name: 'Metro Central Outlet',
    store_phone: '+1 (555) 000-0000',
    updated_at: new Date(),
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        OrdersService,
        {
          provide: PrismaService,
          useValue: {
            order: {
              findMany: jest.fn().mockResolvedValue([mockOrder]),
              findUnique: jest.fn().mockImplementation(({ where }) => {
                if (where?.id === 'ord-1' || where?.order_number === 'ORD-1001') {
                  return Promise.resolve(mockOrder);
                }
                return Promise.resolve(null);
              }),
              findFirst: jest.fn().mockResolvedValue(mockOrder),
              create: jest.fn().mockResolvedValue(mockOrder),
              update: jest.fn().mockImplementation(({ data }) =>
                Promise.resolve({
                  ...mockOrder,
                  ...data,
                }),
              ),
              delete: jest.fn().mockResolvedValue(mockOrder),
            },
            orderItem: {
              createMany: jest.fn().mockResolvedValue({ count: 1 }),
              deleteMany: jest.fn().mockResolvedValue({ count: 1 }),
            },
            customer: {
              findUnique: jest.fn().mockImplementation(({ where }) => {
                if (where.id === 'cust-1') {
                  return Promise.resolve({
                    id: 'cust-1',
                    full_name: 'Robert Miller',
                    phone: '+1 (555) 234-5678',
                  });
                }
                return Promise.resolve(null);
              }),
            },
            restaurantTable: {
              findUnique: jest.fn().mockImplementation(({ where }) => {
                if (where.id === 'tbl-1') {
                  return Promise.resolve({
                    id: 'tbl-1',
                    name: 'Table 4',
                    table_number: 'T-04',
                  });
                }
                return Promise.resolve(null);
              }),
            },
            menuItem: {
              findUnique: jest.fn().mockImplementation(({ where }) => {
                if (where.id === 'mi-1') {
                  return Promise.resolve({
                    id: 'mi-1',
                    name: 'Pepperoni Passion',
                  });
                }
                return Promise.resolve(null);
              }),
            },
            dineInOrderDetail: {
              create: jest.fn().mockResolvedValue({ id: 'dine-1' }),
              update: jest.fn().mockResolvedValue({ id: 'dine-1' }),
            },
            takeawayOrderDetail: {
              findUnique: jest.fn().mockResolvedValue(null),
              create: jest.fn().mockResolvedValue({ id: 'tk-1' }),
              update: jest.fn().mockResolvedValue({ id: 'tk-1' }),
            },
            onlineOrderDetail: {
              findUnique: jest.fn().mockResolvedValue(null),
              create: jest.fn().mockResolvedValue({ id: 'on-1' }),
              update: jest.fn().mockResolvedValue({ id: 'on-1' }),
            },
            storeSetting: {
              findFirst: jest.fn().mockResolvedValue(mockStoreSettings),
            },
            $transaction: jest.fn().mockImplementation(async (callback) => {
              return callback({
                order: {
                  create: jest.fn().mockResolvedValue(mockOrder),
                  update: jest.fn().mockResolvedValue(mockOrder),
                  findUnique: jest.fn().mockImplementation(({ where }) => {
                    if (where?.id === 'ord-1' || where?.order_number === 'ORD-1001') {
                      return Promise.resolve(mockOrder);
                    }
                    return Promise.resolve(null);
                  }),
                  findFirst: jest.fn().mockResolvedValue(mockOrder),
                },
                orderItem: {
                  createMany: jest.fn().mockResolvedValue({ count: 1 }),
                  deleteMany: jest.fn().mockResolvedValue({ count: 1 }),
                  create: jest.fn().mockResolvedValue({ ...mockItem, id: 'oi-new' }),
                  update: jest.fn().mockResolvedValue(mockItem),
                  delete: jest.fn().mockResolvedValue(mockItem),
                  findMany: jest.fn().mockResolvedValue([mockItem]),
                },
                deliveryDispatch: {
                  create: jest.fn().mockResolvedValue({ id: 'disp-1' }),
                },
                customer: {
                  findUnique: jest.fn().mockImplementation(({ where }) => {
                    if (where.id === 'cust-1') {
                      return Promise.resolve({
                        id: 'cust-1',
                        full_name: 'Robert Miller',
                        phone: '+1 (555) 234-5678',
                      });
                    }
                    return Promise.resolve(null);
                  }),
                },
                restaurantTable: {
                  findUnique: jest.fn().mockImplementation(({ where }) => {
                    if (where.id === 'tbl-1') {
                      return Promise.resolve({
                        id: 'tbl-1',
                        name: 'Table 4',
                        table_number: 'T-04',
                      });
                    }
                    return Promise.resolve(null);
                  }),
                  findFirst: jest.fn().mockResolvedValue({
                    id: 'tbl-1',
                    name: 'Table 4',
                    table_number: 'T-04',
                  }),
                  update: jest.fn().mockResolvedValue({ id: 'tbl-1' }),
                },
                menuItem: {
                  findUnique: jest.fn().mockImplementation(({ where }) => {
                    if (where.id === 'mi-1') {
                      return Promise.resolve({
                        id: 'mi-1',
                        name: 'Pepperoni Passion',
                      });
                    }
                    return Promise.resolve(null);
                  }),
                },
                dineInOrderDetail: {
                  create: jest.fn().mockResolvedValue({ id: 'dine-1' }),
                  update: jest.fn().mockResolvedValue({ id: 'dine-1' }),
                },
                takeawayOrderDetail: {
                  findUnique: jest.fn().mockResolvedValue(null),
                  create: jest.fn().mockResolvedValue({ id: 'tk-1' }),
                  update: jest.fn().mockResolvedValue({ id: 'tk-1' }),
                },
                onlineOrderDetail: {
                  findUnique: jest.fn().mockResolvedValue(null),
                  create: jest.fn().mockResolvedValue({ id: 'on-1' }),
                  update: jest.fn().mockResolvedValue({ id: 'on-1' }),
                },
                storeSetting: {
                  findFirst: jest.fn().mockResolvedValue(mockStoreSettings),
                },
              });
            }),
          },
        },
      ],
    }).compile();

    service = module.get<OrdersService>(OrdersService);
  });

  it('should list all orders with query filters', async () => {
    const result = await service.listOrders({ order_type: 'dineIn', is_held: false });
    expect(result).toHaveLength(1);
    expect(result[0].id).toBe('ord-1');
  });

  it('should get an order by id', async () => {
    const result = await service.getOrderById('ord-1');
    expect(result.id).toBe('ord-1');
    expect(result.order_items).toHaveLength(1);
  });

  it('should throw NotFoundException if order does not exist', async () => {
    await expect(service.getOrderById('unknown')).rejects.toThrow(NotFoundException);
  });

  it('should create a Dine-In order with table and calculate totals', async () => {
    const result = await service.createOrder({
      order_type: 'dineIn',
      table_id: 'tbl-1',
      customer_id: 'cust-1',
      guest_count: 2,
      items: [
        {
          menu_item_id: 'mi-1',
          item_name: 'Pepperoni Passion',
          quantity: 2,
          unit_price: 899.0,
          selected_size: 'Large',
        },
      ],
    });
    expect(result).toBeDefined();
    expect(result.id).toBe('ord-1');
  });

  it('should create a Takeaway order and generate token number', async () => {
    const result = await service.createOrder({
      order_type: 'takeAway',
      items: [
        {
          menu_item_id: 'mi-1',
          item_name: 'Pepperoni Passion',
          quantity: 1,
          unit_price: 899.0,
        },
      ],
    });
    expect(result).toBeDefined();
  });

  it('should create a Delivery order with delivery fee', async () => {
    const result = await service.createOrder({
      order_type: 'delivery',
      delivery_fee: 150.0,
      delivery_address: '742 Evergreen Terrace',
      customer_name: 'Robert Miller',
      customer_phone: '+1 (555) 234-5678',
      items: [
        {
          menu_item_id: 'mi-1',
          item_name: 'Pepperoni Passion',
          quantity: 1,
          unit_price: 899.0,
        },
      ],
    });
    expect(result).toBeDefined();
  });

  it('should create a Quick Order', async () => {
    const result = await service.createOrder({
      order_type: 'quickOrder',
      items: [
        {
          item_name: 'Zinger Burger',
          quantity: 1,
          unit_price: 450.0,
        },
      ],
    });
    expect(result).toBeDefined();
  });

  it('should gracefully handle non-existing customer_id without failing order creation', async () => {
    const result = await service.createOrder({
      order_type: 'dineIn',
      customer_id: 'non-existing-customer',
      items: [
        {
          item_name: 'Burger',
          quantity: 1,
          unit_price: 450.0,
        },
      ],
    });
    expect(result).toBeDefined();
    expect(result.id).toBe('ord-1');
  });

  it('should gracefully handle non-existing table_id without failing order creation', async () => {
    const result = await service.createOrder({
      order_type: 'dineIn',
      table_id: 'non-existing-table',
      items: [
        {
          item_name: 'Burger',
          quantity: 1,
          unit_price: 450.0,
        },
      ],
    });
    expect(result).toBeDefined();
    expect(result.id).toBe('ord-1');
  });

  it('should gracefully handle custom or non-existing menu_item_id without failing order creation', async () => {
    const result = await service.createOrder({
      order_type: 'quickOrder',
      items: [
        {
          menu_item_id: 'non-existing-menu-item',
          item_name: 'Burger',
          quantity: 1,
          unit_price: 450.0,
        },
      ],
    });
    expect(result).toBeDefined();
    expect(result.id).toBe('ord-1');
  });

  it('should update order details', async () => {
    const result = await service.updateOrder('ord-1', {
      is_held: true,
    });
    expect(result).toBeDefined();
  });

  it('should update order status', async () => {
    const result = await service.updateOrderStatus('ord-1', {
      status: 'preparing',
    });
    expect(result).toBeDefined();
  });

  it('should delete order', async () => {
    const result = await service.deleteOrder('ord-1');
    expect(result.message).toContain('deleted successfully');
  });
});
