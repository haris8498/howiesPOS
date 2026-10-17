import { TableHandler } from './table.handler';
import { HandlerRegistry } from './handler-registry.service';
import { ChangeLogService } from '../change-log.service';
import { KitchenGateway } from '../../kitchen/kitchen.gateway';

describe('TableHandler', () => {
  let handler: TableHandler;
  let mockRegistry: any;
  let mockChangeLogService: any;
  let mockKitchenGateway: any;

  beforeEach(() => {
    mockRegistry = {
      register: jest.fn(),
    };
    mockChangeLogService = {
      record: jest.fn(),
    };
    mockKitchenGateway = {
      createEnvelope: jest.fn().mockImplementation((params: any) => ({
        event_id: 'mock-uuid',
        event_name: params.eventName,
        entity: params.entity,
        entity_id: params.entityId,
        action: params.action,
        version: params.version ?? 1,
        change_seq: 0,
        occurred_at: '2026-10-17T12:00:00.000Z',
        origin_device_id: params.originDeviceId || 'POS-P1',
        origin_user_id: 'SYSTEM',
        store_id: 'DEFAULT',
        payload: params.payload,
      })),
      emitRealtimeEnvelope: jest.fn(),
    };
    handler = new TableHandler(
      mockRegistry as HandlerRegistry,
      mockChangeLogService as ChangeLogService,
      mockKitchenGateway as KitchenGateway,
    );
  });

  it('should register both table and restaurant_table in registry onModuleInit', () => {
    handler.onModuleInit();
    expect(mockRegistry.register).toHaveBeenCalledTimes(2);
    expect(handler.entityType).toBe('table');
  });

  describe('handle INSERT', () => {
    it('should return DUPLICATE if table with entity_id already exists', async () => {
      const mockTx = {
        restaurantTable: {
          findUnique: jest.fn().mockResolvedValue({
            id: 'tbl-1',
            table_number: 'T-1',
            name: 'Table 1',
            version: 3,
            updated_at: new Date('2026-10-17T12:00:00Z'),
          }),
        },
      };

      const result = await handler.handle(
        mockTx as any,
        {
          operation_id: 'op-ins-1',
          entity_type: 'table',
          entity_id: 'tbl-1',
          operation_type: 'INSERT',
          payload: { table_number: 'T-1', name: 'Table 1' },
        },
        { deviceId: 'POS-P1', operationId: 'op-ins-1', receivedAt: new Date() },
      );

      expect(result.status).toBe('DUPLICATE');
      expect(result.server_version).toBe(3);
      expect(result.entity_id).toBe('tbl-1');
    });

    it('should return CONFLICT if another table already has the same table_number', async () => {
      const mockTx = {
        restaurantTable: {
          findUnique: jest
            .fn()
            .mockImplementation(({ where }: any) => {
              if (where.id) return null;
              if (where.table_number === 'T-Duplicate') {
                return { id: 'other-tbl-id', table_number: 'T-Duplicate', version: 1 };
              }
              return null;
            }),
        },
      };

      const result = await handler.handle(
        mockTx as any,
        {
          operation_id: 'op-ins-2',
          entity_type: 'table',
          entity_id: 'new-tbl-id',
          operation_type: 'INSERT',
          payload: { table_number: 'T-Duplicate', name: 'Duplicate Table' },
        },
        { deviceId: 'POS-P1', operationId: 'op-ins-2', receivedAt: new Date() },
      );

      expect(result.status).toBe('CONFLICT');
      expect(result.conflict_details?.conflict_code).toBe('TABLE_NUMBER_EXISTS');
    });

    it('should create new table with version 1 and record in change log', async () => {
      const mockTx = {
        restaurantTable: {
          findUnique: jest.fn().mockResolvedValue(null),
          create: jest.fn().mockResolvedValue({
            id: 'tbl-new',
            table_number: 'T-99',
            name: 'Table 99',
            capacity: 6,
            section: 'Patio',
            status: 'available',
            version: 1,
            updated_at: new Date('2026-10-17T12:00:00Z'),
          }),
        },
      };

      const result = await handler.handle(
        mockTx as any,
        {
          operation_id: 'op-ins-3',
          entity_type: 'table',
          entity_id: 'tbl-new',
          operation_type: 'INSERT',
          payload: { table_number: 'T-99', name: 'Table 99', capacity: 6, section: 'Patio' },
        },
        { deviceId: 'POS-P1', operationId: 'op-ins-3', receivedAt: new Date() },
      );

      expect(result.status).toBe('SYNCED');
      expect(result.server_version).toBe(1);
      expect(mockChangeLogService.record).toHaveBeenCalledWith(
        mockTx,
        'restaurant_table',
        'tbl-new',
        'INSERT',
        1,
        expect.objectContaining({ table_number: 'T-99', version: 1 }),
        false,
      );
    });
  });

  describe('handle UPDATE & Conflict Policy Scenarios', () => {
    it('1. Cashier reserves vs release race: returns machine-readable CONFLICT when base_version is stale', async () => {
      // Table was modified/released on server (now version 2, available)
      const mockTx = {
        restaurantTable: {
          findUnique: jest.fn().mockResolvedValue({
            id: 'tbl-4',
            table_number: '4',
            name: 'Table 4',
            status: 'available',
            active_order_id: null,
            version: 2, // server version is 2
            updated_at: new Date('2026-10-17T14:00:00Z'),
          }),
        },
        order: { findUnique: jest.fn().mockResolvedValue(null) },
      };

      // Cashier attempts to reserve table based on stale base_version 1
      const result = await handler.handle(
        mockTx as any,
        {
          operation_id: 'op-race-1',
          entity_type: 'table',
          entity_id: 'tbl-4',
          operation_type: 'UPDATE',
          base_version: 1, // Stale! Server is 2
          payload: {
            status: 'reserved',
            reserved_customer_name: 'Alice Walk-in Reservation',
            reservation_time: '2026-10-17T15:00:00Z',
          },
        },
        { deviceId: 'POS-P1', operationId: 'op-race-1', receivedAt: new Date() },
      );

      expect(result.status).toBe('CONFLICT');
      expect(result.server_version).toBe(2);
      expect(result.conflict_details).toBeDefined();
      expect(result.conflict_details.conflict_code).toBe('OCC_VERSION_MISMATCH');
      expect(result.conflict_details.client_base_version).toBe(1);
      expect(result.conflict_details.server_version).toBe(2);
      expect(result.conflict_details.auto_resolvable).toBe(false);
      expect(result.conflict_details.server_state.status).toBe('available');
    });

    it('2. Stale base_version: detected and rejected with CONFLICT when server has progressed', async () => {
      const mockTx = {
        restaurantTable: {
          findUnique: jest.fn().mockResolvedValue({
            id: 'tbl-5',
            table_number: '5',
            name: 'Table 5',
            status: 'reserved',
            reserved_customer_name: 'Online Guest',
            active_order_id: null,
            version: 3, // Server is version 3
            updated_at: new Date('2026-10-17T14:30:00Z'),
          }),
        },
        order: { findUnique: jest.fn().mockResolvedValue(null) },
      };

      const result = await handler.handle(
        mockTx as any,
        {
          operation_id: 'op-stale-1',
          entity_type: 'table',
          entity_id: 'tbl-5',
          operation_type: 'UPDATE',
          base_version: 1, // Client base is 1 (gap of 2 versions)
          payload: {
            status: 'available', // Stale release
          },
        },
        { deviceId: 'POS-P1', operationId: 'op-stale-1', receivedAt: new Date() },
      );

      expect(result.status).toBe('CONFLICT');
      expect(result.server_version).toBe(3);
      expect(result.conflict_details.client_base_version).toBe(1);
      expect(result.conflict_details.server_version).toBe(3);
    });

    it('3. Offline reserve then server changed: active/paid order must NEVER be lost due to stale table update (§10.2)', async () => {
      // Server currently has an active order on Table 4 (occupied, active_order_id = ord-101)
      const mockTx = {
        restaurantTable: {
          findUnique: jest.fn().mockResolvedValue({
            id: 'tbl-4',
            table_number: '4',
            name: 'Table 4',
            status: 'occupied',
            active_order_id: 'ord-101',
            version: 2,
            updated_at: new Date('2026-10-17T13:00:00Z'),
          }),
        },
        order: {
          findUnique: jest.fn().mockResolvedValue({
            id: 'ord-101',
            order_number: 'P1-101',
            status: 'preparing',
            is_paid: true, // PAID ORDER!
            grand_total: 45.0,
          }),
        },
      };

      // Client had taken an offline reservation while disconnected (base_version 1)
      const result = await handler.handle(
        mockTx as any,
        {
          operation_id: 'op-reserve-conflict-1',
          entity_type: 'table',
          entity_id: 'tbl-4',
          operation_type: 'UPDATE',
          base_version: 1,
          payload: {
            status: 'reserved',
            reserved_customer_name: 'Stale Reservation',
          },
        },
        { deviceId: 'POS-P1', operationId: 'op-reserve-conflict-1', receivedAt: new Date() },
      );

      expect(result.status).toBe('CONFLICT');
      expect(result.conflict_details.conflict_code).toBe('ACTIVE_ORDER_PROTECTED');
      expect(result.conflict_details.winning_rule).toBe('SERVER_ACTIVE_ORDER_WINS');
      expect(result.conflict_details.auto_resolvable).toBe(true);
      expect(result.conflict_details.policy_action).toBe('REVERT_TO_SERVER_STATE');
      expect(result.conflict_details.server_state.active_order_id).toBe('ord-101');
      expect(result.conflict_details.server_state.status).toBe('occupied');
    });

    it('4. Repeated conflict replay (idempotent): returns consistent DUPLICATE if already matching server state', async () => {
      const mockTx = {
        restaurantTable: {
          findUnique: jest.fn().mockResolvedValue({
            id: 'tbl-4',
            table_number: '4',
            name: 'Table 4',
            status: 'occupied',
            active_order_id: 'ord-101',
            version: 2,
            updated_at: new Date('2026-10-17T13:00:00Z'),
          }),
        },
        order: { findUnique: jest.fn().mockResolvedValue(null) },
      };

      // Client re-sends the exact same state that is already on server
      const result = await handler.handle(
        mockTx as any,
        {
          operation_id: 'op-replay-1',
          entity_type: 'table',
          entity_id: 'tbl-4',
          operation_type: 'UPDATE',
          base_version: 2,
          payload: {
            status: 'occupied',
            active_order_id: 'ord-101',
          },
        },
        { deviceId: 'POS-P1', operationId: 'op-replay-1', receivedAt: new Date() },
      );

      expect(result.status).toBe('DUPLICATE');
      expect(result.server_version).toBe(2);
    });

    it('5. Dining Table Hospitality Operational Priority (§10.1 & §10.2): POS Physical Seated Guest Wins over Online Reservation', async () => {
      // Server state: Remote owner reserved Table 4 on cloud portal (status: reserved, version: 2)
      const mockTx = {
        restaurantTable: {
          findUnique: jest.fn().mockResolvedValue({
            id: 'tbl-4',
            table_number: '4',
            name: 'Table 4',
            capacity: 4,
            section: 'Main Floor',
            zone_id: 'zone-1',
            status: 'reserved',
            reserved_customer_name: 'VIP Cloud Reservation',
            reservation_time: new Date('2026-10-17T18:00:00Z'),
            active_order_id: null,
            version: 2,
            updated_at: new Date('2026-10-17T15:00:00Z'),
          }),
          upsert: jest.fn().mockResolvedValue({
            id: 'overflow-tbl-id',
            table_number: '4-Overflow',
            name: 'Table 4 (Overflow)',
            status: 'reserved',
            reserved_customer_name: 'VIP Cloud Reservation',
          }),
          update: jest.fn().mockResolvedValue({
            id: 'tbl-4',
            table_number: '4',
            name: 'Table 4',
            status: 'occupied',
            active_order_id: 'offline-ord-uuid',
            current_customer_count: 3,
            version: 3,
            updated_at: new Date('2026-10-17T16:00:00Z'),
          }),
        },
        order: { findUnique: jest.fn().mockResolvedValue(null) },
      };

      // Offline Cashier seated walk-in guests at Table 4 (status: occupied, base_version: 1)
      const result = await handler.handle(
        mockTx as any,
        {
          operation_id: 'op-walkin-seats-1',
          entity_type: 'table',
          entity_id: 'tbl-4',
          operation_type: 'UPDATE',
          base_version: 1, // Cashier was offline when owner made reservation (base_version 1 vs server 2)
          payload: {
            status: 'occupied',
            active_order_id: 'offline-ord-uuid',
            current_customer_count: 3,
            current_bill_amount: 32.5,
          },
        },
        { deviceId: 'POS-P1', operationId: 'op-walkin-seats-1', receivedAt: new Date() },
      );

      // POS physical seated guest wins! Table remains occupied with active order
      expect(result.status).toBe('SYNCED');
      expect(result.server_version).toBe(3);

      // Owner reservation automatically reassigned to overflow table (§10.2 item 2)
      expect(mockTx.restaurantTable.upsert).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { table_number: '4-Overflow' },
          create: expect.objectContaining({
            table_number: '4-Overflow',
            name: 'Table 4 (Overflow)',
            status: 'reserved',
            reserved_customer_name: 'VIP Cloud Reservation',
          }),
        }),
      );

      // Realtime notification broadcast to kitchen / owner portal (§10.2 item 3)
      expect(mockKitchenGateway.emitRealtimeEnvelope).toHaveBeenCalledWith(
        expect.objectContaining({
          event_name: 'table.reservation_overflow',
          payload: expect.objectContaining({
            original_table_number: '4',
            overflow_table_number: '4-Overflow',
            reserved_customer_name: 'VIP Cloud Reservation',
          }),
        }),
      );

      // Change log recorded with overflow flag
      expect(mockChangeLogService.record).toHaveBeenCalledWith(
        mockTx,
        'restaurant_table',
        'tbl-4',
        'UPDATE',
        3,
        expect.objectContaining({
          status: 'occupied',
          active_order_id: 'offline-ord-uuid',
          overflow_reassigned: true,
        }),
        false,
      );
    });

    it('6. Normal update without conflict increments version and broadcasts status change', async () => {
      const mockTx = {
        restaurantTable: {
          findUnique: jest.fn().mockResolvedValue({
            id: 'tbl-1',
            table_number: '1',
            name: 'Table 1',
            status: 'available',
            active_order_id: null,
            version: 1,
            updated_at: new Date(),
          }),
          update: jest.fn().mockResolvedValue({
            id: 'tbl-1',
            table_number: '1',
            name: 'Table 1',
            status: 'occupied',
            active_order_id: 'ord-normal-1',
            version: 2,
            updated_at: new Date('2026-10-17T17:00:00Z'),
          }),
        },
        order: { findUnique: jest.fn().mockResolvedValue(null) },
      };

      const result = await handler.handle(
        mockTx as any,
        {
          operation_id: 'op-norm-1',
          entity_type: 'table',
          entity_id: 'tbl-1',
          operation_type: 'UPDATE',
          base_version: 1, // matches current version 1
          payload: {
            status: 'occupied',
            active_order_id: 'ord-normal-1',
            current_customer_count: 2,
            current_bill_amount: 25.0,
          },
        },
        { deviceId: 'POS-P1', operationId: 'op-norm-1', receivedAt: new Date() },
      );

      expect(result.status).toBe('SYNCED');
      expect(result.server_version).toBe(2);
      expect(mockTx.restaurantTable.update).toHaveBeenCalled();
      expect(mockChangeLogService.record).toHaveBeenCalledWith(
        mockTx,
        'restaurant_table',
        'tbl-1',
        'UPDATE',
        2,
        expect.anything(),
        false,
      );
    });
  });

  describe('handle DELETE', () => {
    it('should reject deletion with CONFLICT if table currently has active order', async () => {
      const mockTx = {
        restaurantTable: {
          findUnique: jest.fn().mockResolvedValue({
            id: 'tbl-del-1',
            table_number: 'Del-1',
            status: 'occupied',
            active_order_id: 'ord-del-100',
            version: 2,
          }),
        },
      };

      const result = await handler.handle(
        mockTx as any,
        {
          operation_id: 'op-del-1',
          entity_type: 'table',
          entity_id: 'tbl-del-1',
          operation_type: 'DELETE',
          payload: {},
        },
        { deviceId: 'POS-P1', operationId: 'op-del-1', receivedAt: new Date() },
      );

      expect(result.status).toBe('CONFLICT');
      expect(result.conflict_details?.conflict_code).toBe('ACTIVE_ORDER_PROTECTED');
    });

    it('should delete table and record deletion in change log if table is available', async () => {
      const mockTx = {
        restaurantTable: {
          findUnique: jest.fn().mockResolvedValue({
            id: 'tbl-del-2',
            table_number: 'Del-2',
            status: 'available',
            active_order_id: null,
            version: 1,
          }),
          delete: jest.fn().mockResolvedValue({ id: 'tbl-del-2' }),
        },
      };

      const result = await handler.handle(
        mockTx as any,
        {
          operation_id: 'op-del-2',
          entity_type: 'table',
          entity_id: 'tbl-del-2',
          operation_type: 'DELETE',
          payload: {},
        },
        { deviceId: 'POS-P1', operationId: 'op-del-2', receivedAt: new Date() },
      );

      expect(result.status).toBe('SYNCED');
      expect(mockTx.restaurantTable.delete).toHaveBeenCalledWith({ where: { id: 'tbl-del-2' } });
      expect(mockChangeLogService.record).toHaveBeenCalledWith(
        mockTx,
        'restaurant_table',
        'tbl-del-2',
        'DELETE',
        2,
        expect.anything(),
        true,
      );
    });
  });
});
