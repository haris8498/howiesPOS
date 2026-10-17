import * as zlib from 'zlib';
import { SyncController } from './sync.controller';
import { SyncService } from './sync.service';
import { SyncPushService } from './sync-push.service';
import { SyncPullService } from './sync-pull.service';

describe('SyncController', () => {
  let controller: SyncController;
  let mockSyncService: any;
  let mockSyncPushService: any;
  let mockSyncPullService: any;

  beforeEach(() => {
    mockSyncService = {
      getSyncOverview: jest.fn().mockResolvedValue({ totalOrders: 10 }),
      syncSingleOrder: jest.fn().mockResolvedValue({ id: 'ord-1', synced: true }),
      syncBatchOrders: jest.fn().mockResolvedValue({ success: true, count: 5 }),
      toggleSyncStatus: jest.fn().mockResolvedValue({ id: 'ord-1', sync_status: 'synced' }),
      createSyncLog: jest.fn().mockResolvedValue({ id: 'log-1' }),
      getSyncLogs: jest.fn().mockResolvedValue([{ id: 'log-1' }]),
    };

    mockSyncPushService = {
      pushMutations: jest.fn().mockResolvedValue({
        success: true,
        batch_id: 'b-1',
        processed_count: 1,
        results: [{ operation_id: 'op-1', status: 'SYNCED', server_version: 1 }],
      }),
    };

    mockSyncPullService = {
      pullChanges: jest.fn().mockResolvedValue({
        success: true,
        cursor: 50,
        next_cursor: 50,
        has_more: false,
        changes: [],
      }),
      getBootstrapData: jest.fn().mockResolvedValue({
        max_global_sequence: 12345,
        server_timestamp: '2026-10-17T12:00:00.000Z',
        menu_items: [{ id: 'm1', name: 'Pizza' }],
        tables: [{ id: 't1', table_number: '1' }],
      }),
    };

    controller = new SyncController(
      mockSyncService as SyncService,
      mockSyncPushService as SyncPushService,
      mockSyncPullService as SyncPullService,
    );
  });

  describe('POST /api/sync/push', () => {
    it('should delegate batch to syncPushService', async () => {
      const dto = {
        device_id: 'POS-P1',
        batch_id: 'b-1',
        mutations: [
          {
            operation_id: 'op-1',
            entity_type: 'order',
            entity_id: 'ord-1',
            operation_type: 'INSERT',
            payload: {},
          },
        ],
      };

      const res = await controller.pushMutations(dto);
      expect(mockSyncPushService.pushMutations).toHaveBeenCalledWith(dto);
      expect(res.success).toBe(true);
      expect(res.results[0].status).toBe('SYNCED');
    });
  });

  describe('GET /api/sync/pull', () => {
    it('should delegate pull query to syncPullService', async () => {
      const query = { cursor: '10', limit: 20, device_id: 'POS-P1' };
      const res = await controller.pullChanges(query);
      expect(mockSyncPullService.pullChanges).toHaveBeenCalledWith(query);
      expect(res.next_cursor).toBe(50);
    });
  });

  describe('GET /api/sync/bootstrap', () => {
    it('should return gzipped payload with Content-Encoding: gzip header', async () => {
      const mockReq: any = { headers: { 'accept-encoding': 'gzip' } };
      let sentBuffer: Buffer | null = null;
      const headers: Record<string, string> = {};

      const mockRes: any = {
        setHeader: jest.fn((k, v) => {
          headers[k] = v;
        }),
        send: jest.fn((buf) => {
          sentBuffer = buf;
          return buf;
        }),
        json: jest.fn(),
      };

      await controller.getBootstrap(mockReq, mockRes);

      expect(mockRes.setHeader).toHaveBeenCalledWith('Content-Type', 'application/json');
      expect(mockRes.setHeader).toHaveBeenCalledWith('Content-Encoding', 'gzip');
      expect(sentBuffer).toBeInstanceOf(Buffer);

      // Decompress and verify content
      const decompressed = JSON.parse(zlib.gunzipSync(sentBuffer!).toString('utf-8'));
      expect(decompressed.max_global_sequence).toBe(12345);
      expect(decompressed.menu_items).toEqual([{ id: 'm1', name: 'Pizza' }]);
    });

    it('should return raw json if raw=true is passed', async () => {
      const mockReq: any = { headers: {} };
      const mockRes: any = {
        setHeader: jest.fn(),
        send: jest.fn(),
        json: jest.fn((data) => data),
      };

      const res: any = await controller.getBootstrap(mockReq, mockRes, 'true');
      expect(mockRes.json).toHaveBeenCalled();
      expect(res.max_global_sequence).toBe(12345);
    });
  });

  describe('Legacy Endpoints Preservation', () => {
    it('should preserve GET /api/sync/overview', async () => {
      const res = await controller.getSyncOverview('pending', 'dineIn');
      expect(mockSyncService.getSyncOverview).toHaveBeenCalledWith({
        sync_status: 'pending',
        order_type: 'dineIn',
        search: undefined,
      });
      expect(res.success).toBe(true);
    });

    it('should preserve POST /api/sync/batch', async () => {
      const res = await controller.syncBatchOrders({ orders: [] } as any);
      expect(mockSyncService.syncBatchOrders).toHaveBeenCalled();
      expect(res.success).toBe(true);
    });
  });
});
