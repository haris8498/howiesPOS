import { OrderHandler } from './order.handler';
import { HandlerRegistry } from './handler-registry.service';
import { OrdersService } from '../../orders/orders.service';
import { ChangeLogService } from '../change-log.service';
import { Prisma } from '@prisma/client';

describe('OrderHandler', () => {
  let handler: OrderHandler;
  let mockRegistry: any;
  let mockOrdersService: any;
  let mockChangeLogService: any;

  beforeEach(() => {
    mockRegistry = {
      register: jest.fn(),
    };
    mockOrdersService = {
      createOrderInTx: jest.fn(),
    };
    mockChangeLogService = {
      record: jest.fn(),
    };
    handler = new OrderHandler(
      mockRegistry as HandlerRegistry,
      mockOrdersService as OrdersService,
      mockChangeLogService as ChangeLogService,
    );
  });

  it('should register itself in handler registry on module init', () => {
    handler.onModuleInit();
    expect(mockRegistry.register).toHaveBeenCalledWith(handler);
    expect(handler.entityType).toBe('order');
  });

  describe('handle INSERT', () => {
    it('should return DUPLICATE if order ID already exists in DB', async () => {
      const mockTx = {
        order: {
          findUnique: jest.fn().mockResolvedValue({
            id: 'ord-uuid-1',
            version: 2,
            updated_at: new Date('2026-10-17T12:00:00Z'),
            created_at: new Date('2026-10-17T10:00:00Z'),
          }),
        },
      };

      const result = await handler.handle(
        mockTx as any,
        {
          operation_id: 'op-1',
          entity_type: 'order',
          entity_id: 'ord-uuid-1',
          operation_type: 'INSERT',
          payload: { order_number: 'P1-101' },
        },
        { deviceId: 'POS-P1', operationId: 'op-1', receivedAt: new Date() },
      );

      expect(result.status).toBe('DUPLICATE');
      expect(result.entity_id).toBe('ord-uuid-1');
      expect(result.server_version).toBe(2);
      expect(mockOrdersService.createOrderInTx).not.toHaveBeenCalled();
    });

    it('should create order and record change log on new order INSERT', async () => {
      const mockTx = {
        order: {
          findUnique: jest.fn().mockResolvedValue(null),
        },
      };

      const createdOrder = {
        id: 'ord-uuid-2',
        order_number: 'P1-102',
        order_type: 'dineIn',
        status: 'newOrder',
        subtotal: 25,
        grand_total: 25,
        payment_status: 'PAID',
        is_paid: true,
        version: 1,
        created_at: new Date('2026-10-17T12:00:00Z'),
        updated_at: new Date('2026-10-17T12:00:00Z'),
        order_items: [{ id: 'item-1' }],
        payments: [{ id: 'pay-1' }],
      };
      mockOrdersService.createOrderInTx.mockResolvedValue(createdOrder);

      const result = await handler.handle(
        mockTx as any,
        {
          operation_id: 'op-2',
          entity_type: 'order',
          entity_id: 'ord-uuid-2',
          operation_type: 'INSERT',
          payload: {
            order_number: 'P1-102',
            order_type: 'dineIn',
            items: [{ item_name: 'Pizza', quantity: 1, unit_price: 25 }],
            payments: [{ payment_method: 'cash', amount: 25 }],
          },
        },
        { deviceId: 'POS-P1', operationId: 'op-2', receivedAt: new Date() },
      );

      expect(result.status).toBe('SYNCED');
      expect(result.entity_id).toBe('ord-uuid-2');
      expect(result.server_version).toBe(1);
      expect(mockOrdersService.createOrderInTx).toHaveBeenCalled();
      expect(mockChangeLogService.record).toHaveBeenCalledWith(
        mockTx,
        'order',
        'ord-uuid-2',
        'INSERT',
        1,
        expect.objectContaining({ order_number: 'P1-102' }),
        false,
      );
    });
  });

  describe('handle UPDATE (SYNC-003)', () => {
    it('should return FAILED_FATAL if order does not exist', async () => {
      const mockTx = {
        order: {
          findUnique: jest.fn().mockResolvedValue(null),
        },
      };

      const result = await handler.handle(
        mockTx as any,
        {
          operation_id: 'op-3',
          entity_type: 'order',
          entity_id: 'missing-ord',
          operation_type: 'UPDATE',
          payload: { status: 'completed' },
        },
        { deviceId: 'POS-P1', operationId: 'op-3', receivedAt: new Date() },
      );

      expect(result.status).toBe('FAILED_FATAL');
    });

    it('should detect OCC version conflict when server version > base_version', async () => {
      const mockTx = {
        order: {
          findUnique: jest.fn().mockResolvedValue({
            id: 'ord-uuid-3',
            version: 3,
            updated_at: new Date(),
          }),
        },
      };

      const result = await handler.handle(
        mockTx as any,
        {
          operation_id: 'op-4',
          entity_type: 'order',
          entity_id: 'ord-uuid-3',
          operation_type: 'UPDATE',
          base_version: 1, // client base is 1, but server is 3
          payload: { status: 'completed' },
        },
        { deviceId: 'POS-P1', operationId: 'op-4', receivedAt: new Date() },
      );

      expect(result.status).toBe('CONFLICT');
      expect(result.conflict_details).toBeDefined();
    });

    it('should update order and increment version when no conflict', async () => {
      const mockTx = {
        order: {
          findUnique: jest.fn().mockResolvedValue({
            id: 'ord-uuid-4',
            version: 1,
            status: 'newOrder',
            updated_at: new Date(),
          }),
          update: jest.fn().mockResolvedValue({
            id: 'ord-uuid-4',
            order_number: 'P1-104',
            version: 2,
            status: 'completed',
            payment_status: 'PAID',
            is_paid: true,
            updated_at: new Date('2026-10-17T14:00:00Z'),
          }),
        },
      };

      const result = await handler.handle(
        mockTx as any,
        {
          operation_id: 'op-5',
          entity_type: 'order',
          entity_id: 'ord-uuid-4',
          operation_type: 'UPDATE',
          base_version: 1,
          payload: { status: 'completed', payment_status: 'PAID', is_paid: true },
        },
        { deviceId: 'POS-P1', operationId: 'op-5', receivedAt: new Date() },
      );

      expect(result.status).toBe('SYNCED');
      expect(result.server_version).toBe(2);
      expect(mockChangeLogService.record).toHaveBeenCalledWith(
        mockTx,
        'order',
        'ord-uuid-4',
        'UPDATE',
        2,
        expect.anything(),
        false,
      );
    });

    // -------------------------------------------------------------------------
    // SPECIFIC SYNC-003 ACCEPTANCE TESTS
    // -------------------------------------------------------------------------

    it('Offline settle of a dine-in table creates payment rows equal to payload', async () => {
      const existingOrder = {
        id: 'ord-settle-1',
        order_number: 'P1-105',
        order_type: 'dineIn',
        status: 'accepted',
        subtotal: new Prisma.Decimal(2500),
        grand_total: new Prisma.Decimal(2500),
        payment_status: 'UNPAID',
        is_paid: false,
        version: 1,
        payments: [],
        order_items: [{ id: 'item-1', unit_price: 2500, quantity: 1 }],
      };

      const mockTx = {
        order: {
          findUnique: jest.fn().mockResolvedValue(existingOrder),
          update: jest.fn().mockImplementation(({ data }) => ({
            ...existingOrder,
            ...data,
            version: 2,
            updated_at: new Date('2026-10-17T14:00:00Z'),
          })),
        },
        orderPayment: {
          upsert: jest.fn().mockResolvedValue({
            id: 'pay-uuid-1',
            order_id: 'ord-settle-1',
            payment_method: 'cash',
            amount: new Prisma.Decimal(2500),
          }),
        },
      };

      const mutation = {
        operation_id: 'op-settle-1',
        entity_type: 'order',
        entity_id: 'ord-settle-1',
        operation_type: 'UPDATE',
        base_version: 1,
        payload: {
          status: 'completed',
          payment_status: 'PAID',
          is_paid: true,
          payments: [
            {
              id: 'pay-uuid-1',
              payment_method: 'cash',
              amount: 2500,
              tendered_amount: 3000,
              change_returned: 500,
            },
          ],
        },
      };

      const result = await handler.handle(
        mockTx as any,
        mutation,
        { deviceId: 'POS-P1', operationId: 'op-settle-1', receivedAt: new Date() },
      );

      expect(result.status).toBe('SYNCED');
      expect(result.server_version).toBe(2);

      // Verify payment was upserted with correct client id and amount
      expect(mockTx.orderPayment.upsert).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { id: 'pay-uuid-1' },
          create: expect.objectContaining({
            id: 'pay-uuid-1',
            order_id: 'ord-settle-1',
            payment_method: 'cash',
            amount: new Prisma.Decimal(2500),
            tendered_amount: new Prisma.Decimal(3000),
            change_returned: new Prisma.Decimal(500),
          }),
        }),
      );

      // Verify order was marked completed and paid
      expect(mockTx.order.update).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { id: 'ord-settle-1' },
          data: expect.objectContaining({
            status: 'completed',
            payment_status: 'PAID',
            is_paid: true,
          }),
        }),
      );

      // Verify change log recorded payment breakdown
      expect(mockChangeLogService.record).toHaveBeenCalledWith(
        mockTx,
        'order',
        'ord-settle-1',
        'UPDATE',
        2,
        expect.objectContaining({
          is_paid: true,
          payments_count: 1,
          payment_methods: { cash: 2500 },
        }),
        false,
      );
    });

    it('Replay of the same update does not duplicate payments', async () => {
      // In-memory payment ledger simulation
      const paymentDb = new Map<string, any>();
      const existingOrder: any = {
        id: 'ord-replay-1',
        order_number: 'P1-106',
        order_type: 'dineIn',
        status: 'accepted',
        subtotal: new Prisma.Decimal(1800),
        grand_total: new Prisma.Decimal(1800),
        payment_status: 'UNPAID',
        is_paid: false,
        version: 1,
        payments: [],
      };

      const mockTx = {
        order: {
          findUnique: jest.fn().mockImplementation(() => ({
            ...existingOrder,
            payments: Array.from(paymentDb.values()),
          })),
          update: jest.fn().mockImplementation(({ data }) => {
            Object.assign(existingOrder, data);
            existingOrder.version = (existingOrder.version || 1) + 1;
            return existingOrder;
          }),
        },
        orderPayment: {
          upsert: jest.fn().mockImplementation(({ where, create, update }) => {
            const id = where.id;
            const existing = paymentDb.get(id);
            if (existing) {
              const updated = { ...existing, ...update };
              paymentDb.set(id, updated);
              return updated;
            } else {
              paymentDb.set(id, create);
              return create;
            }
          }),
        },
      };

      const mutation = {
        operation_id: 'op-replay-1',
        entity_type: 'order',
        entity_id: 'ord-replay-1',
        operation_type: 'UPDATE',
        base_version: 1,
        payload: {
          status: 'completed',
          payment_status: 'PAID',
          is_paid: true,
          payments: [
            {
              id: 'pay-replay-uuid-1',
              payment_method: 'card',
              amount: 1800,
            },
          ],
        },
      };

      // First run: executes update and records payment
      const firstResult = await handler.handle(
        mockTx as any,
        mutation,
        { deviceId: 'POS-P1', operationId: 'op-replay-1', receivedAt: new Date() },
      );
      expect(firstResult.status).toBe('SYNCED');
      expect(paymentDb.size).toBe(1);
      expect(Number(paymentDb.get('pay-replay-uuid-1').amount)).toBe(1800);

      // Second run: exact same mutation replayed
      const secondResult = await handler.handle(
        mockTx as any,
        mutation,
        { deviceId: 'POS-P1', operationId: 'op-replay-1', receivedAt: new Date() },
      );

      // Replay should return DUPLICATE or SYNCED, and NEVER duplicate payment records in DB
      expect(['DUPLICATE', 'SYNCED']).toContain(secondResult.status);
      expect(paymentDb.size).toBe(1); // STILL exactly 1 payment row, NOT 2!
      expect(Number(paymentDb.get('pay-replay-uuid-1').amount)).toBe(1800);
    });

    it('Total mismatch is rejected/flagged, is_paid stays false', async () => {
      const existingOrder = {
        id: 'ord-mismatch-1',
        order_number: 'P1-107',
        order_type: 'dineIn',
        status: 'accepted',
        subtotal: new Prisma.Decimal(3000),
        grand_total: new Prisma.Decimal(3000),
        payment_status: 'UNPAID',
        is_paid: false,
        version: 1,
        payments: [],
      };

      const mockTx = {
        order: {
          findUnique: jest.fn().mockResolvedValue(existingOrder),
          update: jest.fn(),
        },
        orderPayment: {
          upsert: jest.fn(),
        },
      };

      // Underpayment attempt: customer owes 3000, but only 2000 tendered
      const mutation = {
        operation_id: 'op-mismatch-1',
        entity_type: 'order',
        entity_id: 'ord-mismatch-1',
        operation_type: 'UPDATE',
        base_version: 1,
        payload: {
          status: 'completed',
          payment_status: 'PAID',
          is_paid: true,
          payments: [
            {
              id: 'pay-under-1',
              payment_method: 'cash',
              amount: 2000,
            },
          ],
        },
      };

      const result = await handler.handle(
        mockTx as any,
        mutation,
        { deviceId: 'POS-P1', operationId: 'op-mismatch-1', receivedAt: new Date() },
      );

      // Must return CONFLICT status, not silent success
      expect(result.status).toBe('CONFLICT');
      expect(result.conflict_details).toBeDefined();
      expect(result.conflict_details.order_total).toBe(3000);
      expect(result.conflict_details.payments_total).toBe(2000);

      // is_paid MUST stay false — order update must not set is_paid = true
      expect(mockTx.order.update).not.toHaveBeenCalled();
      expect(existingOrder.is_paid).toBe(false);
    });

    it('Discounts and taxes persisted and ledger total equals order total', async () => {
      const existingOrder = {
        id: 'ord-tax-disc-1',
        order_number: 'P1-108',
        order_type: 'dineIn',
        status: 'accepted',
        subtotal: new Prisma.Decimal(1000),
        discount_amount: new Prisma.Decimal(0),
        tax_amount: new Prisma.Decimal(0),
        grand_total: new Prisma.Decimal(1000),
        payment_status: 'UNPAID',
        is_paid: false,
        version: 1,
        payments: [],
        dine_in_detail: { table_id: 'tbl-1', guest_count: 2 },
      };

      let updatedOrderData: any = null;
      const mockTx = {
        order: {
          findUnique: jest.fn().mockResolvedValue(existingOrder),
          update: jest.fn().mockImplementation(({ data }) => {
            updatedOrderData = data;
            return {
              ...existingOrder,
              ...data,
              version: 2,
              updated_at: new Date(),
            };
          }),
        },
        orderPayment: {
          upsert: jest.fn().mockResolvedValue({}),
        },
        dineInOrderDetail: {
          update: jest.fn().mockResolvedValue({}),
        },
        restaurantTable: {
          update: jest.fn().mockResolvedValue({}),
        },
      };

      // Settle with: Subtotal: 5000, 10% discount (-500), 16% GST (+720) => Grand total = 5220
      const mutation = {
        operation_id: 'op-disc-tax-1',
        entity_type: 'order',
        entity_id: 'ord-tax-disc-1',
        operation_type: 'UPDATE',
        base_version: 1,
        payload: {
          status: 'completed',
          payment_status: 'PAID',
          is_paid: true,
          subtotal: 5000,
          discounts: [{ name: 'Promo 10%', amount: 500 }],
          taxes: [{ name: 'GST', amount: 720 }],
          grand_total: 5220,
          payments: [
            {
              id: 'pay-disc-1',
              payment_method: 'card',
              amount: 5220,
            },
          ],
        },
      };

      const result = await handler.handle(
        mockTx as any,
        mutation,
        { deviceId: 'POS-P1', operationId: 'op-disc-tax-1', receivedAt: new Date() },
      );

      expect(result.status).toBe('SYNCED');

      // Check discount, tax, subtotal, and grand_total updated in order table
      expect(updatedOrderData.subtotal).toEqual(new Prisma.Decimal(5000));
      expect(updatedOrderData.discount_amount).toEqual(new Prisma.Decimal(500));
      expect(updatedOrderData.tax_amount).toEqual(new Prisma.Decimal(720));
      expect(updatedOrderData.grand_total).toEqual(new Prisma.Decimal(5220));
      expect(updatedOrderData.is_paid).toBe(true);

      // Ledger payment amount equals recorded total
      expect(mockTx.orderPayment.upsert).toHaveBeenCalledWith(
        expect.objectContaining({
          create: expect.objectContaining({
            amount: new Prisma.Decimal(5220),
          }),
        }),
      );
    });

    it('Status-only update still works without overwriting payments or financial totals', async () => {
      const existingOrder = {
        id: 'ord-status-1',
        order_number: 'P1-109',
        order_type: 'dineIn',
        status: 'newOrder',
        subtotal: new Prisma.Decimal(1200),
        discount_amount: new Prisma.Decimal(0),
        tax_amount: new Prisma.Decimal(0),
        grand_total: new Prisma.Decimal(1200),
        payment_status: 'UNPAID',
        is_paid: false,
        version: 1,
        payments: [],
      };

      let updatedData: any = null;
      const mockTx = {
        order: {
          findUnique: jest.fn().mockResolvedValue(existingOrder),
          update: jest.fn().mockImplementation(({ data }) => {
            updatedData = data;
            return {
              ...existingOrder,
              ...data,
              version: 2,
              updated_at: new Date(),
            };
          }),
        },
        orderPayment: {
          upsert: jest.fn(),
        },
      };

      const mutation = {
        operation_id: 'op-status-only',
        entity_type: 'order',
        entity_id: 'ord-status-1',
        operation_type: 'UPDATE',
        base_version: 1,
        payload: {
          status: 'preparing',
        },
      };

      const result = await handler.handle(
        mockTx as any,
        mutation,
        { deviceId: 'POS-P1', operationId: 'op-status-only', receivedAt: new Date() },
      );

      expect(result.status).toBe('SYNCED');
      expect(result.server_version).toBe(2);

      // Status was updated, financial totals were NOT overwritten
      expect(updatedData.status).toBe('preparing');
      expect(updatedData.subtotal).toBeUndefined();
      expect(updatedData.grand_total).toBeUndefined();
      expect(mockTx.orderPayment.upsert).not.toHaveBeenCalled();
    });

    it('Updated line items in dine-in order are persisted and subtotal recomputed', async () => {
      const existingOrder = {
        id: 'ord-items-update',
        order_number: 'P1-110',
        order_type: 'dineIn',
        status: 'accepted',
        subtotal: new Prisma.Decimal(1000),
        discount_amount: new Prisma.Decimal(0),
        tax_amount: new Prisma.Decimal(0),
        grand_total: new Prisma.Decimal(1000),
        payment_status: 'UNPAID',
        is_paid: false,
        version: 1,
        order_items: [
          {
            id: 'item-existing-1',
            item_name: 'Garlic Bread',
            quantity: 1,
            unit_price: 1000,
            is_cancelled: false,
          },
        ],
        payments: [],
      };

      const createdItems: any[] = [];
      const updatedItems: any[] = [];
      let finalOrderData: any = null;

      const mockTx = {
        order: {
          findUnique: jest.fn().mockResolvedValue(existingOrder),
          update: jest.fn().mockImplementation(({ data }) => {
            finalOrderData = data;
            return {
              ...existingOrder,
              ...data,
              version: 2,
              updated_at: new Date(),
            };
          }),
        },
        orderItem: {
          update: jest.fn().mockImplementation(({ data }) => {
            updatedItems.push(data);
            return data;
          }),
          create: jest.fn().mockImplementation(({ data }) => {
            createdItems.push(data);
            return { id: 'item-new-1', ...data };
          }),
          delete: jest.fn(),
        },
        orderPayment: {
          upsert: jest.fn().mockResolvedValue({}),
        },
      };

      // Add a second item (Pizza: 1500) and settle total 2500
      const mutation = {
        operation_id: 'op-items-add',
        entity_type: 'order',
        entity_id: 'ord-items-update',
        operation_type: 'UPDATE',
        base_version: 1,
        payload: {
          status: 'completed',
          payment_status: 'PAID',
          is_paid: true,
          items: [
            {
              id: 'item-existing-1',
              item_name: 'Garlic Bread',
              quantity: 1,
              unit_price: 1000,
            },
            {
              id: 'item-new-1',
              item_name: 'Chicken Supreme Pizza',
              quantity: 1,
              unit_price: 1500,
            },
          ],
          payments: [
            {
              id: 'pay-items-1',
              payment_method: 'cash',
              amount: 2500,
            },
          ],
        },
      };

      const result = await handler.handle(
        mockTx as any,
        mutation,
        { deviceId: 'POS-P1', operationId: 'op-items-add', receivedAt: new Date() },
      );

      expect(result.status).toBe('SYNCED');
      expect(mockTx.orderItem.create).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({
            item_name: 'Chicken Supreme Pizza',
            unit_price: new Prisma.Decimal(1500),
          }),
        }),
      );
      expect(finalOrderData.subtotal).toEqual(new Prisma.Decimal(2500));
      expect(finalOrderData.grand_total).toEqual(new Prisma.Decimal(2500));
      expect(finalOrderData.is_paid).toBe(true);
    });
  });
});
