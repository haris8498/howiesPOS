import { OrderHandler } from './order.handler';
import { HandlerRegistry } from './handler-registry.service';
import { OrdersService } from '../../orders/orders.service';
import { ChangeLogService } from '../change-log.service';

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

  describe('handle UPDATE', () => {
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
  });
});
