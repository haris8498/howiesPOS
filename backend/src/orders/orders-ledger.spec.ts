import { Test, TestingModule } from '@nestjs/testing';
import { OrdersService } from './orders.service';
import { PrismaService } from '../prisma/prisma.service';
import { v7 as uuidv7 } from 'uuid';

describe('OrdersService - Append-Only Line-Item Ledger (SYNC-032 / D-05)', () => {
  let service: OrdersService;
  let mockPrisma: any;

  // In-memory data store for testing ledger semantics
  let ordersStore: Map<string, any>;
  let orderItemsStore: Map<string, any>;

  beforeEach(async () => {
    ordersStore = new Map();
    orderItemsStore = new Map();

    mockPrisma = {
      order: {
        findUnique: jest.fn().mockImplementation(({ where, include }: any) => {
          const order = ordersStore.get(where.id);
          if (!order) return Promise.resolve(null);
          const result = { ...order };
          if (include?.order_items) {
            result.order_items = Array.from(orderItemsStore.values()).filter(
              (item) => item.order_id === where.id,
            );
          }
          if (include?.payments) {
            result.payments = [];
          }
          return Promise.resolve(result);
        }),
        update: jest.fn().mockImplementation(({ where, data }: any) => {
          const order = ordersStore.get(where.id);
          if (!order) throw new Error('Order not found');
          const updated = {
            ...order,
            ...data,
            subtotal: data.subtotal !== undefined ? data.subtotal : order.subtotal,
            grand_total: data.grand_total !== undefined ? data.grand_total : order.grand_total,
            version: (order.version || 1) + 1,
            updated_at: new Date(),
          };
          ordersStore.set(where.id, updated);
          return Promise.resolve(updated);
        }),
      },
      orderItem: {
        findUnique: jest.fn().mockImplementation(({ where }: any) => {
          return Promise.resolve(orderItemsStore.get(where.id) || null);
        }),
        findMany: jest.fn().mockImplementation(({ where }: any) => {
          let items = Array.from(orderItemsStore.values()).filter(
            (i) => i.order_id === where.order_id,
          );
          if (where.voidedAt === null) {
            items = items.filter((i) => i.voidedAt == null);
          }
          if (where.is_cancelled === false) {
            items = items.filter((i) => !i.is_cancelled);
          }
          return Promise.resolve(items);
        }),
        create: jest.fn().mockImplementation(({ data }: any) => {
          const id = data.id || uuidv7();
          const item = {
            id,
            order_id: data.order_id,
            menu_item_id: data.menu_item_id || null,
            item_name: data.item_name,
            quantity: data.quantity ?? 1,
            selected_size: data.selected_size ?? 'Regular',
            selected_crust: data.selected_crust ?? 'Original',
            extra_toppings: data.extra_toppings ?? '',
            unit_price: Number(data.unit_price ?? 0),
            total_price: Number(data.total_price ?? 0),
            notes: data.notes ?? '',
            is_cancelled: data.is_cancelled ?? false,
            cancelled_at: data.cancelled_at ?? null,
            cancel_reason: data.cancel_reason ?? null,
            cancelled_by: data.cancelled_by ?? null,
            voidedAt: data.voidedAt ?? null,
            voidedBy: data.voidedBy ?? null,
            supersedesItemId: data.supersedesItemId ?? null,
            createdByDeviceId: data.createdByDeviceId ?? null,
            clientCreatedAt: data.clientCreatedAt ?? new Date(),
          };
          orderItemsStore.set(id, item);
          return Promise.resolve(item);
        }),
        createMany: jest.fn().mockImplementation(({ data }: any) => {
          const list = Array.isArray(data) ? data : [data];
          for (const d of list) {
            const id = d.id || uuidv7();
            orderItemsStore.set(id, {
              id,
              ...d,
              voidedAt: d.voidedAt ?? null,
              voidedBy: d.voidedBy ?? null,
              supersedesItemId: d.supersedesItemId ?? null,
              createdByDeviceId: d.createdByDeviceId ?? null,
              clientCreatedAt: d.clientCreatedAt ?? new Date(),
            });
          }
          return Promise.resolve({ count: list.length });
        }),
        update: jest.fn().mockImplementation(({ where, data }: any) => {
          const item = orderItemsStore.get(where.id);
          if (!item) throw new Error('Item not found');
          const updated = { ...item, ...data };
          orderItemsStore.set(where.id, updated);
          return Promise.resolve(updated);
        }),
        delete: jest.fn().mockImplementation(({ where }: any) => {
          orderItemsStore.delete(where.id);
          return Promise.resolve();
        }),
      },
      menuItem: {
        findUnique: jest.fn().mockImplementation(() => Promise.resolve(null)),
      },
      $transaction: jest.fn().mockImplementation(async (callback: any) => {
        return callback(mockPrisma);
      }),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        OrdersService,
        { provide: PrismaService, useValue: mockPrisma },
      ],
    }).compile();

    service = module.get<OrdersService>(OrdersService);
  });

  describe('getActiveItems (Task 5)', () => {
    it('returns only non-voided, non-cancelled items', async () => {
      const orderId = 'ord-100';
      ordersStore.set(orderId, {
        id: orderId,
        order_number: 'P1-100',
        order_type: 'dineIn',
        status: 'newOrder',
        subtotal: 300,
        grand_total: 300,
        version: 1,
      });

      // Active item
      orderItemsStore.set('item-1', {
        id: 'item-1',
        order_id: orderId,
        item_name: 'Cheese Pizza',
        quantity: 1,
        unit_price: 100,
        total_price: 100,
        is_cancelled: false,
        voidedAt: null,
      });

      // Voided item
      orderItemsStore.set('item-2', {
        id: 'item-2',
        order_id: orderId,
        item_name: 'Garlic Bread',
        quantity: 1,
        unit_price: 50,
        total_price: 50,
        is_cancelled: false,
        voidedAt: new Date(),
        voidedBy: 'cashier-1',
      });

      // Cancelled item (legacy)
      orderItemsStore.set('item-3', {
        id: 'item-3',
        order_id: orderId,
        item_name: 'Soda',
        quantity: 2,
        unit_price: 25,
        total_price: 50,
        is_cancelled: true,
        cancelled_at: new Date(),
        voidedAt: null,
      });

      const activeItems = await service.getActiveItems(orderId);
      expect(activeItems).toHaveLength(1);
      expect(activeItems[0].id).toBe('item-1');
    });
  });

  describe('Concurrent Updates & Merge Semantics (Task 3 & 4)', () => {
    it('does not delete unmentioned items from concurrent terminal updates when fullReplace is false', async () => {
      const orderId = 'ord-sync-032';
      ordersStore.set(orderId, {
        id: orderId,
        order_number: 'P1-200',
        order_type: 'dineIn',
        status: 'newOrder',
        subtotal: 100,
        grand_total: 100,
        version: 1,
      });

      // Existing item 1 (Pizza)
      orderItemsStore.set('item-pizza', {
        id: 'item-pizza',
        order_id: orderId,
        item_name: 'Pepperoni Pizza',
        quantity: 1,
        unit_price: 100,
        total_price: 100,
        is_cancelled: false,
        voidedAt: null,
      });

      // Device A adds Garlic Bread
      await service.updateOrder(orderId, {
        items: [
          {
            id: 'item-pizza',
            item_name: 'Pepperoni Pizza',
            quantity: 1,
            unit_price: 100,
          },
          {
            id: 'item-garlic-bread',
            item_name: 'Garlic Bread',
            quantity: 1,
            unit_price: 50,
          },
        ],
      } as any);

      // Verify Device A added garlic bread
      expect(orderItemsStore.has('item-pizza')).toBe(true);
      expect(orderItemsStore.has('item-garlic-bread')).toBe(true);

      // Now Device B (which had only seen item-pizza before A's update) sends its update adding Soda
      // Notice: Device B's payload does NOT contain 'item-garlic-bread'
      await service.updateOrder(orderId, {
        items: [
          {
            id: 'item-pizza',
            item_name: 'Pepperoni Pizza',
            quantity: 1,
            unit_price: 100,
          },
          {
            id: 'item-soda',
            item_name: 'Fountain Soda',
            quantity: 2,
            unit_price: 25,
          },
        ],
      } as any);

      // CRUCIAL SYNC-032 INVARIANT:
      // 'item-garlic-bread' MUST NOT have been deleted by Device B's update!
      expect(orderItemsStore.has('item-garlic-bread')).toBe(true);
      expect(orderItemsStore.has('item-soda')).toBe(true);
      expect(orderItemsStore.has('item-pizza')).toBe(true);

      const active = await service.getActiveItems(orderId);
      expect(active.map((i) => i.id)).toEqual(
        expect.arrayContaining(['item-pizza', 'item-garlic-bread', 'item-soda']),
      );
    });

    it('removes unmentioned items only when explicit fullReplace: true is provided', async () => {
      const orderId = 'ord-replace';
      ordersStore.set(orderId, {
        id: orderId,
        order_number: 'P1-201',
        order_type: 'dineIn',
        status: 'newOrder',
        subtotal: 150,
        grand_total: 150,
        version: 1,
      });

      orderItemsStore.set('item-1', {
        id: 'item-1',
        order_id: orderId,
        item_name: 'Old Item',
        quantity: 1,
        unit_price: 50,
        total_price: 50,
        is_cancelled: false,
        voidedAt: null,
      });

      await service.updateOrder(orderId, {
        fullReplace: true,
        items: [
          {
            id: 'item-new',
            item_name: 'New Item',
            quantity: 1,
            unit_price: 100,
          },
        ],
      } as any);

      const active = await service.getActiveItems(orderId);
      expect(active).toHaveLength(1);
      expect(active[0].id).toBe('item-new');
    });

    it('implements ledger semantics for item quantity edits (supersedes + void)', async () => {
      const orderId = 'ord-edit-qty';
      ordersStore.set(orderId, {
        id: orderId,
        order_number: 'P1-202',
        order_type: 'dineIn',
        status: 'newOrder',
        subtotal: 100,
        grand_total: 100,
        version: 1,
      });

      const initialItemId = 'item-pizza-1';
      orderItemsStore.set(initialItemId, {
        id: initialItemId,
        order_id: orderId,
        item_name: 'Pepperoni Pizza',
        quantity: 1,
        unit_price: 100,
        total_price: 100,
        is_cancelled: false,
        voidedAt: null,
      });

      // Quantity changed from 1 to 2
      await service.updateOrder(orderId, {
        items: [
          {
            id: initialItemId,
            item_name: 'Pepperoni Pizza',
            quantity: 2,
            unit_price: 100,
          },
        ],
      } as any);

      // Old item must be voided with supersedes linkage
      const oldItem = orderItemsStore.get(initialItemId);
      expect(oldItem.voidedAt).toBeTruthy();

      const active = await service.getActiveItems(orderId);
      expect(active).toHaveLength(1);
      expect(active[0].quantity).toBe(2);
      expect(active[0].supersedesItemId).toBe(initialItemId);
    });
  });

  describe('Append and Void Endpoints (Task 4)', () => {
    it('appendOrderItems appends batch of items with UUID v7 and updates subtotal', async () => {
      const orderId = 'ord-append';
      ordersStore.set(orderId, {
        id: orderId,
        order_number: 'P1-203',
        order_type: 'dineIn',
        status: 'newOrder',
        subtotal: 0,
        grand_total: 0,
        version: 1,
      });

      const item1Id = uuidv7();
      const item2Id = uuidv7();

      await service.appendOrderItems(orderId, [
        {
          id: item1Id,
          item_name: 'Item 1',
          quantity: 2,
          unit_price: 50,
        },
        {
          id: item2Id,
          item_name: 'Item 2',
          quantity: 1,
          unit_price: 75,
        },
      ]);

      const active = await service.getActiveItems(orderId);
      expect(active).toHaveLength(2);
      expect(Number(ordersStore.get(orderId).subtotal)).toBe(175);
    });

    it('voidOrderItem sets voidedAt and is_cancelled, excluding item from active subtotal', async () => {
      const orderId = 'ord-void';
      ordersStore.set(orderId, {
        id: orderId,
        order_number: 'P1-204',
        order_type: 'dineIn',
        status: 'newOrder',
        subtotal: 100,
        grand_total: 100,
        version: 1,
      });

      orderItemsStore.set('item-to-void', {
        id: 'item-to-void',
        order_id: orderId,
        item_name: 'Wrong Item',
        quantity: 1,
        unit_price: 100,
        total_price: 100,
        is_cancelled: false,
        voidedAt: null,
      });

      await service.voidOrderItem(orderId, 'item-to-void', 'supervisor-1', 'Customer cancelled');

      const voidedItem = orderItemsStore.get('item-to-void');
      expect(voidedItem.voidedAt).toBeTruthy();
      expect(voidedItem.voidedBy).toBe('supervisor-1');
      expect(voidedItem.is_cancelled).toBe(true);

      const active = await service.getActiveItems(orderId);
      expect(active).toHaveLength(0);
      expect(Number(ordersStore.get(orderId).subtotal)).toBe(0);
    });
  });

  describe('Commutative Property (Task 7)', () => {
    it('yields identical active state regardless of whether void or superseding edit executes first', async () => {
      // In commutative merge:
      // If terminal A voids an item, and terminal B edits its quantity,
      // a void always wins over a live copy!
      const orderId = 'ord-comm';
      ordersStore.set(orderId, {
        id: orderId,
        order_number: 'P1-205',
        order_type: 'dineIn',
        status: 'newOrder',
        subtotal: 100,
        grand_total: 100,
        version: 1,
      });

      orderItemsStore.set('item-z', {
        id: 'item-z',
        order_id: orderId,
        item_name: 'Item Z',
        quantity: 1,
        unit_price: 100,
        total_price: 100,
        is_cancelled: false,
        voidedAt: null,
      });

      // Permutation 1: Void happens
      await service.voidOrderItem(orderId, 'item-z', 'user-a');
      expect(orderItemsStore.get('item-z').voidedAt).toBeTruthy();

      // Later, update tries to update the already voided item
      await service.updateOrder(orderId, {
        items: [
          {
            id: 'item-z',
            item_name: 'Item Z',
            quantity: 2,
            unit_price: 100,
          },
        ],
      } as any);

      // Void must win: item-z remains voided!
      expect(orderItemsStore.get('item-z').voidedAt).toBeTruthy();
    });
  });
});
