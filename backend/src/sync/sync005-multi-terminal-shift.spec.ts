import { Test, TestingModule } from '@nestjs/testing';
import { ConflictException, ForbiddenException } from '@nestjs/common';
import * as fs from 'fs';
import * as path from 'path';
import { PrismaService } from '../prisma/prisma.service';
import { ShiftHandler } from './handlers/shift.handler';
import { ChangeLogService } from './change-log.service';
import { SyncPushService } from './sync-push.service';
import { HandlerRegistry } from './handlers/handler-registry.service';
import { KitchenGateway } from '../kitchen/kitchen.gateway';
import { RealtimeGateway } from '../realtime/realtime.gateway';
import { DailyCalculationService } from '../daily-calculation/daily-calculation.service';
import { SettingsService } from '../settings/settings.service';

describe('SYNC-005 Multi-Terminal Shift & Device Identity Verification', () => {
  let shiftHandler: ShiftHandler;
  let syncPushService: SyncPushService;
  let dailyCalcService: DailyCalculationService;
  let mockChangeLogService: any;
  let mockKitchenGateway: any;
  let mockRealtimeGateway: any;
  let mockPrisma: any;

  // In-memory shift database store
  let shiftsDb: Map<string, any>;
  let devicesDb: Map<string, any>;

  beforeEach(async () => {
    shiftsDb = new Map();
    devicesDb = new Map();

    mockChangeLogService = {
      record: jest.fn().mockResolvedValue({ global_sequence: BigInt(1) }),
    };

    mockKitchenGateway = {
      emitOrderCreated: jest.fn(),
      emitOrderUpdated: jest.fn(),
    };

    mockRealtimeGateway = {
      emitShiftStarted: jest.fn(),
      emitShiftClosed: jest.fn(),
    };

    mockPrisma = {
      dailyCalculation: {
        findUnique: jest.fn().mockImplementation(async ({ where }: any) => {
          return shiftsDb.get(where.id) || null;
        }),
        findFirst: jest.fn().mockImplementation(async ({ where }: any) => {
          for (const s of shiftsDb.values()) {
            let match = true;
            if (where.status && s.status !== where.status) match = false;
            if (where.id?.not && s.id === where.id.not) match = false;
            if (where.restaurant_id && s.restaurant_id !== where.restaurant_id) match = false;
            if (where.terminal_id && s.terminal_id !== where.terminal_id) match = false;
            if (match) return s;
          }
          return null;
        }),
        create: jest.fn().mockImplementation(async ({ data }: any) => {
          const record = {
            ...data,
            id: data.id || `shift-${Date.now()}-${Math.random()}`,
            restaurant_id: data.restaurant_id || 'default',
            terminal_id: data.terminal_id || '1',
            version: data.version || 1,
            created_at: data.created_at || new Date(),
            updated_at: new Date(),
          };
          shiftsDb.set(record.id, record);
          return record;
        }),
        update: jest.fn().mockImplementation(async ({ where, data }: any) => {
          const existing = shiftsDb.get(where.id);
          if (!existing) throw new Error(`Shift ${where.id} not found`);
          const updated = {
            ...existing,
            ...data,
            version: (existing.version || 1) + 1,
            updated_at: new Date(),
          };
          shiftsDb.set(where.id, updated);
          return updated;
        }),
      },
      device: {
        findUnique: jest.fn().mockImplementation(async ({ where }: any) => {
          const key = `${where.restaurant_id_device_id.restaurant_id}_${where.restaurant_id_device_id.device_id}`;
          return devicesDb.get(key) || null;
        }),
        create: jest.fn().mockImplementation(async ({ data }: any) => {
          const key = `${data.restaurant_id || 'default'}_${data.device_id}`;
          const device = {
            id: `dev-${Date.now()}`,
            ...data,
            restaurant_id: data.restaurant_id || 'default',
            is_blocked: data.is_blocked || false,
            created_at: new Date(),
            updated_at: new Date(),
          };
          devicesDb.set(key, device);
          return device;
        }),
        update: jest.fn().mockImplementation(async ({ where, data }: any) => {
          for (const [k, d] of devicesDb.entries()) {
            if (d.id === where.id) {
              const updated = { ...d, ...data, updated_at: new Date() };
              devicesDb.set(k, updated);
              return updated;
            }
          }
          return null;
        }),
        upsert: jest.fn().mockImplementation(async ({ where, create, update }: any) => {
          const key = `${where.restaurant_id_device_id.restaurant_id}_${where.restaurant_id_device_id.device_id}`;
          const existing = devicesDb.get(key);
          if (existing) {
            const updated = { ...existing, ...update, updated_at: new Date() };
            devicesDb.set(key, updated);
            return updated;
          }
          const created = {
            id: `dev-${Date.now()}`,
            ...create,
            restaurant_id: where.restaurant_id_device_id.restaurant_id,
            device_id: where.restaurant_id_device_id.device_id,
            is_blocked: false,
            created_at: new Date(),
            updated_at: new Date(),
          };
          devicesDb.set(key, created);
          return created;
        }),
      },
      order: {
        updateMany: jest.fn().mockResolvedValue({ count: 0 }),
        findMany: jest.fn().mockResolvedValue([]),
      },
      processedOperation: {
        findUnique: jest.fn().mockResolvedValue(null),
        upsert: jest.fn().mockResolvedValue({}),
      },
      $transaction: jest.fn().mockImplementation(async (cb) => {
        if (typeof cb === 'function') {
          return cb(mockPrisma);
        }
        return cb;
      }),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        ShiftHandler,
        SyncPushService,
        DailyCalculationService,
        HandlerRegistry,
        { provide: PrismaService, useValue: mockPrisma },
        { provide: ChangeLogService, useValue: mockChangeLogService },
        { provide: KitchenGateway, useValue: mockKitchenGateway },
        { provide: RealtimeGateway, useValue: mockRealtimeGateway },
        { provide: SettingsService, useValue: {} },
      ],
    }).compile();

    shiftHandler = module.get<ShiftHandler>(ShiftHandler);
    syncPushService = module.get<SyncPushService>(SyncPushService);
    dailyCalcService = module.get<DailyCalculationService>(DailyCalculationService);

    const handlerRegistry = module.get<HandlerRegistry>(HandlerRegistry);
    handlerRegistry.register(shiftHandler);
  });

  afterEach(() => {
    delete process.env.DEVICE_VALIDATION_ENABLED;
  });

  // ───────────────────────────────────────────────────────────────────────────
  // TEST SUITE 1: TWO TERMINALS CONCURRENT ACTIVE SHIFTS (SYNC-005 Core)
  // ───────────────────────────────────────────────────────────────────────────
  describe('Requirement 1: Two terminals hold active shifts at once; second shift on SAME terminal rejected', () => {
    it('allows Terminal 1 and Terminal 2 to hold active shifts concurrently via Sync Push', async () => {
      // Terminal 1 opens shift offline
      const t1ShiftId = 'shift-term-1-uuid';
      const openT1Mutation = {
        operation_id: 'op-open-t1',
        entity_type: 'shift',
        entity_id: t1ShiftId,
        operation_type: 'INSERT',
        dependency_order: 0,
        payload: {
          id: t1ShiftId,
          shift_name: 'Terminal 1 Morning',
          cashier_id: 'cashier-alice',
          cashier_name: 'Alice',
          starting_cash: 5000,
          terminal_id: '1',
          restaurant_id: 'default',
          status: 'ACTIVE',
        },
      };

      const resultT1 = await shiftHandler.handle(
        mockPrisma as any,
        openT1Mutation,
        { deviceId: 'device-term-1-uuid', operationId: 'op-open-t1', receivedAt: new Date() },
      );

      expect(resultT1.status).toBe('SYNCED');
      expect(resultT1.entity_id).toBe(t1ShiftId);

      // Terminal 2 opens shift offline concurrently
      const t2ShiftId = 'shift-term-2-uuid';
      const openT2Mutation = {
        operation_id: 'op-open-t2',
        entity_type: 'shift',
        entity_id: t2ShiftId,
        operation_type: 'INSERT',
        dependency_order: 0,
        payload: {
          id: t2ShiftId,
          shift_name: 'Terminal 2 Morning',
          cashier_id: 'cashier-bob',
          cashier_name: 'Bob',
          starting_cash: 3000,
          terminal_id: '2', // Distinct terminal!
          restaurant_id: 'default',
          status: 'ACTIVE',
        },
      };

      const resultT2 = await shiftHandler.handle(
        mockPrisma as any,
        openT2Mutation,
        { deviceId: 'device-term-2-uuid', operationId: 'op-open-t2', receivedAt: new Date() },
      );

      // Invariant: Terminal 2 must SUCCEED with SYNCED because active shifts are scoped per terminal!
      expect(resultT2.status).toBe('SYNCED');
      expect(resultT2.entity_id).toBe(t2ShiftId);

      // Verification: Both shifts are ACTIVE simultaneously
      const shift1 = shiftsDb.get(t1ShiftId);
      const shift2 = shiftsDb.get(t2ShiftId);
      expect(shift1).toBeDefined();
      expect(shift1.status).toBe('ACTIVE');
      expect(shift1.terminal_id).toBe('1');

      expect(shift2).toBeDefined();
      expect(shift2.status).toBe('ACTIVE');
      expect(shift2.terminal_id).toBe('2');
    });

    it('rejects a second active shift on the SAME terminal (Terminal 1) with CONFLICT (ACTIVE_SHIFT_EXISTS)', async () => {
      // Terminal 1 already has an active shift
      const activeT1ShiftId = 'shift-term-1-active';
      shiftsDb.set(activeT1ShiftId, {
        id: activeT1ShiftId,
        shift_name: 'First Active Shift',
        restaurant_id: 'default',
        terminal_id: '1',
        cashier_id: 'cashier-alice',
        status: 'ACTIVE',
        version: 1,
      });

      // Attempt to open a second active shift on Terminal 1
      const collidingT1ShiftId = 'shift-term-1-second';
      const collidingMutation = {
        operation_id: 'op-open-t1-collision',
        entity_type: 'shift',
        entity_id: collidingT1ShiftId,
        operation_type: 'INSERT',
        dependency_order: 0,
        payload: {
          id: collidingT1ShiftId,
          shift_name: 'Colliding Second Shift',
          terminal_id: '1', // SAME terminal!
          restaurant_id: 'default',
          cashier_id: 'cashier-charlie',
          starting_cash: 4000,
          status: 'ACTIVE',
        },
      };

      const result = await shiftHandler.handle(
        mockPrisma as any,
        collidingMutation,
        { deviceId: 'device-term-1-uuid', operationId: 'op-open-t1-collision', receivedAt: new Date() },
      );

      // Invariant: Second shift on same terminal must return CONFLICT
      expect(result.status).toBe('CONFLICT');
      expect(result.conflict_details?.code).toBe('ACTIVE_SHIFT_EXISTS');
      expect(result.conflict_details?.message).toContain("Terminal '1' already has active shift");

      // Invariant: Offline shift is preserved as OFFLINE_CLOSED so FKs and offline orders are not orphaned
      const preservedShift = shiftsDb.get(collidingT1ShiftId);
      expect(preservedShift).toBeDefined();
      expect(preservedShift.status).toBe('OFFLINE_CLOSED');
      expect(preservedShift.terminal_id).toBe('1');
    });

    it('supports online shift open via DailyCalculationService for multiple terminals', async () => {
      // 1. Terminal 1 starts session
      const t1 = await dailyCalcService.startSession({
        starting_cash: 5000,
        shift_name: 'Front Register Shift',
        cashier_id: 'cashier-1',
        cashier_name: 'Alice',
        terminal_id: '1',
      });
      expect(t1.has_active_session).toBe(true);
      expect(t1.session.terminal_id).toBe('1');

      // 2. Terminal 2 starts session concurrently
      const t2 = await dailyCalcService.startSession({
        starting_cash: 5000,
        shift_name: 'Drive Thru Shift',
        cashier_id: 'cashier-2',
        cashier_name: 'Bob',
        terminal_id: '2',
      });
      expect(t2.has_active_session).toBe(true);
      expect(t2.session.terminal_id).toBe('2');

      // 3. Opening another shift on Terminal 1 fails with ConflictException
      await expect(
        dailyCalcService.startSession({
          starting_cash: 5000,
          shift_name: 'Duplicate Terminal 1 Shift',
          cashier_id: 'cashier-3',
          cashier_name: 'Charlie',
          terminal_id: '1',
        }),
      ).rejects.toThrow(ConflictException);

      // 4. Opening another shift on Terminal 2 fails with ConflictException
      await expect(
        dailyCalcService.startSession({
          starting_cash: 5000,
          shift_name: 'Duplicate Terminal 2 Shift',
          cashier_id: 'cashier-4',
          cashier_name: 'Dave',
          terminal_id: '2',
        }),
      ).rejects.toThrow(ConflictException);
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // TEST SUITE 2: BACKWARD COMPATIBILITY FOR LEGACY 'POS-P1' CLIENTS
  // ───────────────────────────────────────────────────────────────────────────
  describe('Requirement 2: Legacy clients sending POS-P1 continue working', () => {
    it('accepts shift from legacy client sending POS-P1 and defaults to terminal 1 with a warning', async () => {
      const legacyShiftId = 'shift-legacy-pos-p1';
      const legacyMutation = {
        operation_id: 'op-legacy-1',
        entity_type: 'shift',
        entity_id: legacyShiftId,
        operation_type: 'INSERT',
        dependency_order: 0,
        payload: {
          id: legacyShiftId,
          shift_name: 'Legacy Shift',
          cashier_id: 'legacy-cashier',
          starting_cash: 2500,
          device_id: 'POS-P1', // Legacy literal
          status: 'ACTIVE',
        },
      };

      const result = await shiftHandler.handle(
        mockPrisma as any,
        legacyMutation,
        { deviceId: 'POS-P1', operationId: 'op-legacy-1', receivedAt: new Date() },
      );

      expect(result.status).toBe('SYNCED');
      const saved = shiftsDb.get(legacyShiftId);
      expect(saved).toBeDefined();
      expect(saved.terminal_id).toBe('1');
    });

    it('processes push from legacy client POS-P1 via SyncPushService without rejection', async () => {
      process.env.DEVICE_VALIDATION_ENABLED = 'true'; // Even when flag is on!

      const batch = {
        device_id: 'POS-P1', // Legacy client
        batch_id: 'batch-legacy-1',
        mutations: [],
      };

      // Invariant: Legacy POS-P1 must not be rejected even when DEVICE_VALIDATION_ENABLED=true
      const result = await syncPushService.pushMutations(batch as any);
      expect(result.success).toBe(true);
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // TEST SUITE 3: BACKEND DEVICE REGISTRATION & VALIDATION GUARD
  // ───────────────────────────────────────────────────────────────────────────
  describe('Requirement 3: Device Registration and Validation Flag Gating', () => {
    it('registers a new device via registerDevice()', async () => {
      const regResult = await syncPushService.registerDevice({
        device_id: 'hw-uuid-counter-01',
        restaurant_id: 'default',
        terminal_id: '1',
        terminal_name: 'Counter Terminal 1',
      });

      expect(regResult.success).toBe(true);
      expect(regResult.data.device_id).toBe('hw-uuid-counter-01');
      expect(regResult.data.terminal_id).toBe('1');
    });

    it('rejects pushes from unregistered devices ONLY when DEVICE_VALIDATION_ENABLED=true', async () => {
      const unregisteredBatch = {
        device_id: 'unregistered-rogue-device',
        batch_id: 'batch-unreg-1',
        mutations: [],
      };

      // Flag OFF (default): Push is accepted and auto-registered
      delete process.env.DEVICE_VALIDATION_ENABLED;
      const offResult = await syncPushService.pushMutations(unregisteredBatch as any);
      expect(offResult.success).toBe(true);

      // Flag ON: Push from unregistered device is rejected with 403 Forbidden
      process.env.DEVICE_VALIDATION_ENABLED = 'true';
      await expect(
        syncPushService.pushMutations({
          device_id: 'completely-unknown-device',
          batch_id: 'batch-unreg-2',
          mutations: [],
        } as any),
      ).rejects.toThrow(ForbiddenException);
    });

    it('rejects pushes from blocked devices regardless of flag status', async () => {
      // Register and block device
      const blockedDeviceId = 'stolen-tablet-01';
      devicesDb.set(`default_${blockedDeviceId}`, {
        id: 'dev-stolen',
        restaurant_id: 'default',
        device_id: blockedDeviceId,
        is_blocked: true, // Blocked by admin
      });

      const pushBatch = {
        device_id: blockedDeviceId,
        batch_id: 'batch-stolen',
        mutations: [],
      };

      await expect(syncPushService.pushMutations(pushBatch as any)).rejects.toThrow(
        ForbiddenException,
      );
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // TEST SUITE 4: PRISMA MIGRATION SQL VERIFICATION
  // ───────────────────────────────────────────────────────────────────────────
  describe('Requirement 4: Migration SQL File Inspection', () => {
    it('migration script drops single-shift index, scopes unique active shift per terminal, and defines devices table', () => {
      const migrationPath = path.resolve(
        __dirname,
        '../../prisma/migrations/20261026100000_terminal_scoped_active_shift_and_devices/migration.sql',
      );

      expect(fs.existsSync(migrationPath)).toBe(true);
      const sql = fs.readFileSync(migrationPath, 'utf8');

      // 1. Drops old index
      expect(sql).toMatch(/DROP\s+INDEX\s+IF\s+EXISTS\s+"unique_active_shift"/i);

      // 2. Adds columns safely with IF NOT EXISTS
      expect(sql).toMatch(/ALTER\s+TABLE\s+"daily_calculations"\s+ADD\s+COLUMN\s+IF\s+NOT\s+EXISTS\s+"restaurant_id"/i);
      expect(sql).toMatch(/ALTER\s+TABLE\s+"daily_calculations"\s+ADD\s+COLUMN\s+IF\s+NOT\s+EXISTS\s+"terminal_id"/i);

      // 3. Backfills legacy data
      expect(sql).toMatch(/UPDATE\s+"daily_calculations"\s+SET\s+"terminal_id"\s*=\s*'1'/i);
      expect(sql).toMatch(/UPDATE\s+"daily_calculations"\s+SET\s+"restaurant_id"\s*=\s*'default'/i);

      // 4. Creates terminal-scoped partial unique index
      expect(sql).toMatch(
        /CREATE\s+UNIQUE\s+INDEX\s+IF\s+NOT\s+EXISTS\s+"unique_active_shift_per_terminal"\s+ON\s+"daily_calculations"\s*\(\s*"restaurant_id",\s*"terminal_id"\s*\)\s+WHERE\s+"status"\s*=\s*'ACTIVE'/i,
      );

      // 5. Creates devices table with unique constraint on (restaurant_id, device_id)
      expect(sql).toMatch(/CREATE\s+TABLE\s+IF\s+NOT\s+EXISTS\s+"devices"/i);
      expect(sql).toMatch(/CREATE\s+UNIQUE\s+INDEX\s+IF\s+NOT\s+EXISTS\s+"devices_restaurant_id_device_id_key"\s+ON\s+"devices"/i);

      // 6. Contains rollback / down instructions
      expect(sql).toMatch(/--\s*To\s+rollback\s+this\s+migration/i);
      expect(sql).toMatch(/DROP\s+INDEX\s+IF\s+EXISTS\s+"unique_active_shift_per_terminal"/i);
      expect(sql).toMatch(/CREATE\s+UNIQUE\s+INDEX\s+IF\s+NOT\s+EXISTS\s+"unique_active_shift"/i);
    });
  });
});
