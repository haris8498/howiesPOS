import { Test, TestingModule } from '@nestjs/testing';
import { Prisma } from '@prisma/client';
import { OrderHandler } from './handlers/order.handler';
import { HandlerRegistry } from './handlers/handler-registry.service';
import { OrdersService } from '../orders/orders.service';
import { ChangeLogService } from './change-log.service';
import { PricingService } from '../pricing/pricing.service';
import { PasswordService } from '../auth/password.service';
import { PrismaService } from '../prisma/prisma.service';

describe('SYNC-016 / D-03 Server Pricing Authority & Discount Control (E2E Integration)', () => {
  let orderHandler: OrderHandler;
  let pricingService: PricingService;
  let ordersService: OrdersService;

  let createdOrders: Map<string, any>;
  let orderItemsMap: Map<string, any[]>;
  let catalogMap: Map<string, any>;
  let staffMap: Map<string, any>;
  let discountAudits: any[];
  let pricingAudits: any[];

  beforeEach(async () => {
    createdOrders = new Map();
    orderItemsMap = new Map();
    catalogMap = new Map();
    staffMap = new Map();
    discountAudits = [];
    pricingAudits = [];

    // Seed mock catalog
    catalogMap.set('menu-pizza', {
      id: 'menu-pizza',
      name: 'Fajita Pizza',
      base_price: new Prisma.Decimal('1000.00'),
      sizes: [
        { size_name: 'Small', price: new Prisma.Decimal('1000.00') },
        { size_name: 'Large', price: new Prisma.Decimal('1500.00') },
      ],
      options: [
        { option_type: 'topping', option_name: 'Extra Cheese', additional_price: new Prisma.Decimal('100.00') },
      ],
    });

    // Seed mock staff
    staffMap.set('mgr-1', {
      id: 'mgr-1',
      username: 'manager_sarah',
      role: 'MANAGER',
      is_active: true,
      password_hash: 'mock-hash',
    });

    staffMap.set('cashier-1', {
      id: 'cashier-1',
      username: 'cashier_tom',
      role: 'CASHIER',
      is_active: true,
      password_hash: 'mock-hash',
    });

    const mockPrismaService = {
      order: {
        findUnique: jest.fn().mockImplementation(({ where }) => Promise.resolve(createdOrders.get(where.id) || null)),
        findFirst: jest.fn(),
        create: jest.fn().mockImplementation(({ data }) => {
          const ord = {
            id: data.id || 'ord-gen',
            ...data,
            created_at: new Date(),
            updated_at: new Date(),
            version: 1,
          };
          createdOrders.set(ord.id, ord);
          return Promise.resolve(ord);
        }),
        update: jest.fn().mockImplementation(({ where, data }) => {
          const ord = createdOrders.get(where.id);
          const updated = { ...ord, ...data, updated_at: new Date() };
          createdOrders.set(where.id, updated);
          return Promise.resolve(updated);
        }),
      },
      orderItem: {
        findMany: jest.fn().mockImplementation(({ where }) => {
          const items = orderItemsMap.get(where.order_id) || [];
          return Promise.resolve(
            items.filter((i) => {
              if (where.voidedAt === null && i.voidedAt !== null) return false;
              if (where.is_cancelled === false && i.is_cancelled !== false) return false;
              return true;
            }),
          );
        }),
        createMany: jest.fn().mockImplementation(({ data }) => {
          for (const item of data) {
            const list = orderItemsMap.get(item.order_id) || [];
            list.push({ ...item, id: item.id || `item-${list.length + 1}` });
            orderItemsMap.set(item.order_id, list);
          }
          return Promise.resolve({ count: data.length });
        }),
        create: jest.fn().mockImplementation(({ data }) => {
          const list = orderItemsMap.get(data.order_id) || [];
          const item = { ...data, id: data.id || `item-${list.length + 1}` };
          list.push(item);
          orderItemsMap.set(data.order_id, list);
          return Promise.resolve(item);
        }),
        update: jest.fn(),
      },
      takeawayOrderDetail: {
        findUnique: jest.fn().mockResolvedValue(null),
        create: jest.fn().mockResolvedValue({}),
        update: jest.fn().mockResolvedValue({}),
      },
      dineInOrderDetail: {
        findUnique: jest.fn().mockResolvedValue(null),
        create: jest.fn().mockResolvedValue({}),
        update: jest.fn().mockResolvedValue({}),
      },
      onlineOrderDetail: {
        findUnique: jest.fn().mockResolvedValue(null),
        create: jest.fn().mockResolvedValue({}),
        update: jest.fn().mockResolvedValue({}),
      },
      orderPayment: {
        createMany: jest.fn().mockResolvedValue({ count: 0 }),
        create: jest.fn().mockResolvedValue({}),
      },
      menuItem: {
        findUnique: jest.fn().mockImplementation(({ where }) => Promise.resolve(catalogMap.get(where.id) || null)),
      },
      staffUser: {
        findFirst: jest.fn().mockImplementation(({ where }) => {
          for (const s of staffMap.values()) {
            if (where.OR) {
              for (const cond of where.OR) {
                if (cond.id && s.id === cond.id) return Promise.resolve(s);
                if (cond.username && s.username === cond.username) return Promise.resolve(s);
              }
            }
          }
          return Promise.resolve(null);
        }),
      },
      discountAudit: {
        create: jest.fn().mockImplementation(({ data }) => {
          discountAudits.push(data);
          return Promise.resolve(data);
        }),
      },
      pricingAudit: {
        create: jest.fn().mockImplementation(({ data }) => {
          pricingAudits.push(data);
          return Promise.resolve(data);
        }),
      },
      dataSyncLog: {
        create: jest.fn().mockResolvedValue({}),
      },
      systemChangeLog: {
        create: jest.fn().mockResolvedValue({}),
      },
    };

    const mockPasswordService = {
      verify: jest.fn().mockResolvedValue(true),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        OrderHandler,
        HandlerRegistry,
        OrdersService,
        ChangeLogService,
        PricingService,
        { provide: PrismaService, useValue: mockPrismaService },
        { provide: PasswordService, useValue: mockPasswordService },
      ],
    }).compile();

    orderHandler = module.get<OrderHandler>(OrderHandler);
    pricingService = module.get<PricingService>(PricingService);
    ordersService = module.get<OrdersService>(OrdersService);

    process.env.PRICING_ROUNDING_TOLERANCE = '1.00';
  });

  afterEach(() => {
    delete process.env.PRICING_ROUNDING_TOLERANCE;
  });

  it('Scenario 1: Tampered client total is corrected, order kept, mismatch flagged (SYNC-016)', async () => {
    const orderId = '0192e220-0001-7000-8000-000000000001';
    const mockTx = (pricingService as any).prisma;

    // Attacker sends 2 Large Pizzas (catalog 1500 each = 3000 PKR), but tampers unit_price to 10 and grand_total to 20
    const mutation = {
      operation_id: 'op-tamper-1',
      entity_type: 'order',
      entity_id: orderId,
      operation_type: 'INSERT',
      payload: {
        order_number: 'P1-101',
        order_type: 'takeaway',
        subtotal: 20.0,
        grand_total: 20.0, // Tampered!
        items: [
          {
            id: 'item-1',
            menu_item_id: 'menu-pizza',
            item_name: 'Fajita Pizza',
            selected_size: 'Large',
            quantity: 2,
            unit_price: 10.0, // Tampered unit price!
            total_price: 20.0,
          },
        ],
      },
    };

    const result = await orderHandler.handle(mockTx, mutation as any, { deviceId: 'POS-P1' } as any);

    // Order is persisted in DB
    expect(createdOrders.has(orderId)).toBe(true);
    const persisted = createdOrders.get(orderId);

    // Server-authoritative totals: 2 * 1500 = 3000
    expect(new Prisma.Decimal(persisted.subtotal).toString()).toBe('3000');
    expect(new Prisma.Decimal(persisted.grand_total).toString()).toBe('3000');
    expect(new Prisma.Decimal(persisted.client_reported_total).toString()).toBe('20');
    expect(persisted.pricing_status).toBe('MISMATCH');

    // Push response returns server totals, pricingStatus, and warning
    expect(result.status).toBe('SYNCED');
    expect(result.pricing_status).toBe('MISMATCH');
    expect(result.grand_total).toBe(3000);
    expect(result.server_grand_total).toBe(3000);
    expect(result.warning_code).toBe('PRICE_MISMATCH');

    // Pricing audit written
    expect(pricingAudits).toHaveLength(1);
    expect(pricingAudits[0].pricing_status).toBe('MISMATCH');
    expect(new Prisma.Decimal(pricingAudits[0].server_grand_total).toString()).toBe('3000');
    expect(new Prisma.Decimal(pricingAudits[0].client_grand_total).toString()).toBe('20');
  });

  it('Scenario 2: Rounding difference of 0.50 accepted silently within tolerance', async () => {
    const orderId = '0192e220-0002-7000-8000-000000000002';
    const mockTx = (pricingService as any).prisma;

    // 1 Small Pizza (catalog 1000). Client reports 1000.50 (e.g. tax rounding)
    const mutation = {
      operation_id: 'op-tol-1',
      entity_type: 'order',
      entity_id: orderId,
      operation_type: 'INSERT',
      payload: {
        order_number: 'P1-102',
        order_type: 'takeaway',
        subtotal: 1000.50,
        grand_total: 1000.50,
        items: [
          {
            id: 'item-1',
            menu_item_id: 'menu-pizza',
            item_name: 'Fajita Pizza',
            selected_size: 'Small',
            quantity: 1,
            unit_price: 1000.0,
            total_price: 1000.0,
          },
        ],
      },
    };

    const result = await orderHandler.handle(mockTx, mutation as any, { deviceId: 'POS-P1' } as any);

    expect(createdOrders.has(orderId)).toBe(true);
    const persisted = createdOrders.get(orderId);

    // Stored with server totals (1000) and kept clientReportedTotal (1000.50)
    expect(new Prisma.Decimal(persisted.grand_total).toString()).toBe('1000');
    expect(new Prisma.Decimal(persisted.client_reported_total).toString()).toBe('1000.5');
    expect(persisted.pricing_status).toBe('VERIFIED');
    expect(result.warning_code).toBeUndefined();
    expect(pricingAudits).toHaveLength(0); // Accepted silently!
  });

  it('Scenario 3: Discount with manager approval applied and audited (OFFLINE flow)', async () => {
    const orderId = '0192e220-0003-7000-8000-000000000003';
    const mockTx = (pricingService as any).prisma;

    // 1 Large Pizza = 1500 PKR. 10% discount = 150 PKR -> 1350 PKR. Approved by mgr-1.
    const mutation = {
      operation_id: 'op-disc-1',
      entity_type: 'order',
      entity_id: orderId,
      operation_type: 'INSERT',
      payload: {
        order_number: 'P1-103',
        order_type: 'dineIn',
        subtotal: 1500.0,
        discount_percentage: 10.0,
        discount_amount: 150.0,
        grand_total: 1350.0,
        manager_approval: {
          manager_id: 'mgr-1',
          device_id: 'POS-P1',
          approved_at: '2026-10-27T10:00:00Z',
          reason: 'Customer goodwill promo',
        },
        items: [
          {
            id: 'item-1',
            menu_item_id: 'menu-pizza',
            item_name: 'Fajita Pizza',
            selected_size: 'Large',
            quantity: 1,
            unit_price: 1500.0,
            total_price: 1500.0,
          },
        ],
      },
    };

    const result = await orderHandler.handle(mockTx, mutation as any, { deviceId: 'POS-P1' } as any);

    const persisted = createdOrders.get(orderId);
    expect(new Prisma.Decimal(persisted.discount_amount).toString()).toBe('150');
    expect(new Prisma.Decimal(persisted.grand_total).toString()).toBe('1350');
    expect(persisted.pricing_status).toBe('VERIFIED');
    expect(result.grand_total).toBe(1350);

    // Discount audit row created with OFFLINE source and manager approval
    expect(discountAudits).toHaveLength(1);
    expect(discountAudits[0].approved_by).toBe('mgr-1');
    expect(discountAudits[0].source).toBe('OFFLINE');
    expect(discountAudits[0].reason).toBe('Customer goodwill promo');
    expect(new Prisma.Decimal(discountAudits[0].amount).toString()).toBe('150');
  });

  it('Scenario 4: Discount without valid approval (rule 5): order kept, discount NOT applied, flagged UNAUTHORIZED_DISCOUNT', async () => {
    const orderId = '0192e220-0004-7000-8000-000000000004';
    const mockTx = (pricingService as any).prisma;

    // 1 Large Pizza = 1500 PKR. Cashier attempts 20% discount (300) without manager approval
    const mutation = {
      operation_id: 'op-unauth-disc-1',
      entity_type: 'order',
      entity_id: orderId,
      operation_type: 'INSERT',
      payload: {
        order_number: 'P1-104',
        order_type: 'dineIn',
        subtotal: 1500.0,
        discount_percentage: 20.0,
        discount_amount: 300.0,
        grand_total: 1200.0,
        // No manager_approval!
        items: [
          {
            id: 'item-1',
            menu_item_id: 'menu-pizza',
            item_name: 'Fajita Pizza',
            selected_size: 'Large',
            quantity: 1,
            unit_price: 1500.0,
            total_price: 1500.0,
          },
        ],
      },
    };

    const result = await orderHandler.handle(mockTx, mutation as any, { deviceId: 'POS-P1' } as any);

    // Order is persisted (the sale happened!)
    expect(createdOrders.has(orderId)).toBe(true);
    const persisted = createdOrders.get(orderId);

    // Rule 5: Discount NOT applied to authoritative total!
    expect(new Prisma.Decimal(persisted.discount_amount).toString()).toBe('0');
    expect(new Prisma.Decimal(persisted.grand_total).toString()).toBe('1500'); // Authoritative grand total remains 1500!
    expect(persisted.pricing_status).toBe('UNAUTHORIZED_DISCOUNT');

    expect(result.pricing_status).toBe('UNAUTHORIZED_DISCOUNT');
    expect(result.grand_total).toBe(1500);
    expect(result.warning_code).toBe('UNAUTHORIZED_DISCOUNT');

    // Audit row created for review
    expect(pricingAudits).toHaveLength(1);
    expect(pricingAudits[0].pricing_status).toBe('UNAUTHORIZED_DISCOUNT');
  });
});
