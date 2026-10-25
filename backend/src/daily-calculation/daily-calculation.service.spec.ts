import { ConflictException, NotFoundException } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { DailyCalculationService } from './daily-calculation.service';

describe('DailyCalculationService - Shift Locking & Management System', () => {
  let service: DailyCalculationService;
  let prisma: any;

  const mockShiftDate = new Date('2026-10-10T00:00:00.000Z');
  const mockOpenedAt = new Date('2026-10-10T20:00:00.000Z');

  const mockActiveShift = {
    id: 'shift-10-oct',
    date: mockShiftDate,
    shift_name: 'Evening Shift',
    cashier_id: 'cashier-1',
    cashier_name: 'Alexander Pierce',
    starting_cash: new Prisma.Decimal(5000),
    total_change_cash: new Prisma.Decimal(5000),
    opening_float: new Prisma.Decimal(5000),
    status: 'ACTIVE',
    version: 1,
    created_at: mockOpenedAt,
    updated_at: mockOpenedAt,
    submitted_at: null,
    expense_items: [],
  };

  beforeEach(async () => {
    prisma = {
      dailyCalculation: {
        findFirst: jest.fn(),
        findUnique: jest.fn(),
        create: jest.fn(),
        update: jest.fn(),
      },
      order: {
        findMany: jest.fn(),
        updateMany: jest.fn(),
      },
      deliveryDispatch: {
        findMany: jest.fn(),
      },
      dailyExpenseItem: {
        deleteMany: jest.fn(),
        createMany: jest.fn(),
        findMany: jest.fn(),
      },
      expense: {
        create: jest.fn(),
      },
      restaurantTable: {
        updateMany: jest.fn(),
      },
      deliveryRider: {
        updateMany: jest.fn(),
      },
      $transaction: jest.fn().mockImplementation((cb) => cb(prisma)),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        DailyCalculationService,
        {
          provide: PrismaService,
          useValue: prisma,
        },
      ],
    }).compile();

    service = module.get<DailyCalculationService>(DailyCalculationService);
  });

  describe('Core Rule 1: Only ONE active shift at a time (Store-Wide Locking)', () => {
    it('Case 2: should successfully open a shift when no active shift exists', async () => {
      prisma.dailyCalculation.findFirst.mockResolvedValueOnce(null); // No active session
      prisma.dailyCalculation.findFirst.mockResolvedValueOnce(null); // No history
      prisma.dailyCalculation.create.mockResolvedValueOnce({
        ...mockActiveShift,
        id: 'new-shift-uuid',
      });

      const result = await service.startSession({
        starting_cash: 5000,
        shift_name: 'Dinner Shift',
        cashier_id: 'cashier-1',
        cashier_name: 'Alexander Pierce',
      });

      expect(result.has_active_session).toBe(true);
      expect(prisma.dailyCalculation.create).toHaveBeenCalled();
    });

    it('Case 1: should block opening a second shift when an active shift is already open (HTTP 409 Conflict)', async () => {
      // Return existing active shift
      prisma.dailyCalculation.findFirst.mockResolvedValue(mockActiveShift);

      await expect(
        service.startSession({
          starting_cash: 5000,
          shift_name: 'Morning Shift',
          cashier_id: 'cashier-2',
          cashier_name: 'Elena Rostova',
        }),
      ).rejects.toThrow(ConflictException);

      try {
        await service.startSession({
          starting_cash: 5000,
          shift_name: 'Morning Shift',
        });
      } catch (err: any) {
        expect(err).toBeInstanceOf(ConflictException);
        const resp = err.getResponse();
        expect(resp.success).toBe(false);
        expect(resp.message).toContain('An active shift already exists');
      }
    });

    it('Case 8: should handle race condition via DB unique constraint violation (P2002) and return 409 Conflict', async () => {
      prisma.dailyCalculation.findFirst.mockResolvedValue(null); // Both see no active shift
      const prismaError = new Prisma.PrismaClientKnownRequestError('Unique constraint failed', {
        code: 'P2002',
        clientVersion: '5.22.0',
      });
      prisma.dailyCalculation.create.mockRejectedValueOnce(prismaError);

      await expect(
        service.startSession({
          starting_cash: 5000,
          shift_name: 'Concurrent Shift Attempt',
        }),
      ).rejects.toThrow(ConflictException);
    });
  });

  describe('Core Rule 2: Shift cannot be closed if pending orders exist', () => {
    it('Case 5: should block shift close when unresolved orders exist with 409 Conflict and order count', async () => {
      prisma.dailyCalculation.findUnique.mockResolvedValue(mockActiveShift);
      prisma.dailyCalculation.findFirst.mockResolvedValue(mockActiveShift);

      // Unresolved pending orders exist
      prisma.order.findMany.mockResolvedValueOnce([
        {
          id: 'ord-101',
          order_number: 'P1-101',
          order_type: 'dineIn',
          status: 'preparing',
          is_paid: false,
          grand_total: new Prisma.Decimal(1250),
          created_at: new Date('2026-10-10T21:00:00Z'),
        },
        {
          id: 'ord-102',
          order_number: 'P1-102',
          order_type: 'takeaway',
          status: 'ready',
          is_paid: true,
          grand_total: new Prisma.Decimal(850),
          created_at: new Date('2026-10-10T21:30:00Z'),
        },
        {
          id: 'ord-103',
          order_number: 'P1-103',
          order_type: 'online',
          status: 'newOrder',
          is_paid: false,
          grand_total: new Prisma.Decimal(2100),
          created_at: new Date('2026-10-10T22:00:00Z'),
        },
      ]);

      try {
        await service.submitDailyCalculation({
          shift_id: mockActiveShift.id,
          cash_submitted: 5000,
          total_cash: 5000,
          cash_skimming: 0,
        });
        fail('Should have thrown ConflictException');
      } catch (err: any) {
        expect(err).toBeInstanceOf(ConflictException);
        const resp = err.getResponse();
        expect(resp.success).toBe(false);
        expect(resp.pendingOrders).toBe(3);
        expect(resp.message).toContain('pending orders');
        expect(resp.orders).toHaveLength(3);
      }
    });

    it('Case 6: should successfully close shift when all orders are completed or resolved', async () => {
      prisma.dailyCalculation.findUnique.mockResolvedValue(mockActiveShift);
      prisma.dailyCalculation.findFirst.mockResolvedValue(mockActiveShift);

      // 0 unresolved orders
      prisma.order.findMany.mockResolvedValueOnce([]); // unresolved orders check
      prisma.deliveryDispatch.findMany.mockResolvedValueOnce([]); // active dispatches check
      prisma.order.findMany.mockResolvedValueOnce([]); // live calculation orders
      prisma.dailyCalculation.update.mockResolvedValueOnce({
        ...mockActiveShift,
        status: 'CLOSED',
        submitted_at: new Date('2026-10-11T02:00:00Z'),
      });

      const result = await service.submitDailyCalculation({
        shift_id: mockActiveShift.id,
        cash_submitted: 5000,
        total_cash: 5000,
        cash_skimming: 0,
        cashier_id: 'cashier-1',
        cashier_name: 'Alexander Pierce',
      });

      expect(result.status).toBe('CLOSED');
      expect(prisma.dailyCalculation.update).toHaveBeenCalled();
    });
  });

  describe('Core Rule 3, 4, 5 & 6: Overnight shifts & Shift Date Preservation', () => {
    it('Case 3 & 4: should preserve start date (10 Oct) even when closing at 2:00 AM on 11 Oct', async () => {
      prisma.dailyCalculation.findUnique.mockResolvedValue(mockActiveShift);
      prisma.dailyCalculation.findFirst.mockResolvedValue(mockActiveShift);
      prisma.order.findMany.mockResolvedValueOnce([]); // unresolved check
      prisma.deliveryDispatch.findMany.mockResolvedValueOnce([]); // active dispatches
      prisma.order.findMany.mockResolvedValueOnce([]); // live orders

      let updateDataCaptured: any;
      prisma.dailyCalculation.update.mockImplementation(({ data }: any) => {
        updateDataCaptured = data;
        return Promise.resolve({
          ...mockActiveShift,
          ...data,
        });
      });

      await service.submitDailyCalculation({
        shift_id: mockActiveShift.id,
        date: '2026-10-11', // Client sends 11 Oct (closing date)
        cash_submitted: 5000,
        total_cash: 5000,
        cash_skimming: 0,
      });

      // Shift Date must remain 10 Oct (original start date)
      expect(updateDataCaptured.date).toEqual(mockShiftDate);
      expect(updateDataCaptured.status).toBe('CLOSED');
      expect(updateDataCaptured.submitted_at).toBeDefined();
    });

    it('Case 7: orders created after midnight (11 Oct 1:00 AM) are permanently stamped with active shift ID', async () => {
      prisma.dailyCalculation.findUnique.mockResolvedValue(mockActiveShift);
      prisma.dailyCalculation.findFirst.mockResolvedValue(mockActiveShift);
      prisma.order.findMany.mockResolvedValueOnce([]);
      prisma.deliveryDispatch.findMany.mockResolvedValueOnce([]);
      prisma.order.findMany.mockResolvedValueOnce([]);

      let updateOrdersWhereCaptured: any;
      prisma.order.updateMany.mockImplementation(({ where }: any) => {
        updateOrdersWhereCaptured = where;
        return Promise.resolve({ count: 5 });
      });
      prisma.dailyCalculation.update.mockResolvedValueOnce({
        ...mockActiveShift,
        status: 'CLOSED',
      });

      await service.submitDailyCalculation({
        shift_id: mockActiveShift.id,
        cash_submitted: 5000,
        total_cash: 5000,
        cash_skimming: 0,
      });

      expect(prisma.order.updateMany).toHaveBeenCalledWith({
        where: expect.objectContaining({
          OR: expect.arrayContaining([
            { shift_id: mockActiveShift.id },
            expect.objectContaining({ shift_id: null }),
          ]),
        }),
        data: {
          shift_id: mockActiveShift.id,
        },
      });
    });

    it('Live summary returns original shift date and OPEN status across midnight', async () => {
      prisma.dailyCalculation.findFirst.mockResolvedValue(mockActiveShift);
      prisma.order.findMany.mockResolvedValue([]);

      const live = await service.getLiveSummary(undefined, 'cashier-1');
      expect(live.has_active_session).toBe(true);
      expect(live.status).toBe('OPEN');
      expect(live.shift_date).toBe('2026-10-10');
      expect(live.date).toBe('2026-10-10');
    });

    it('Case 2: after shift is closed, user can open next shift for 11 Oct', async () => {
      // Shift is closed, so findFirst for status: 'ACTIVE' returns null
      prisma.dailyCalculation.findFirst.mockImplementation(({ where }: any) => {
        if (where?.status === 'ACTIVE') {
          return Promise.resolve(null);
        }
        return Promise.resolve({ ...mockActiveShift, status: 'CLOSED' });
      });
      prisma.dailyCalculation.create.mockResolvedValueOnce({
        id: 'shift-11-oct',
        date: new Date('2026-10-11T00:00:00Z'),
        status: 'ACTIVE',
        starting_cash: new Prisma.Decimal(5000),
      });

      const nextShift = await service.startSession({
        starting_cash: 5000,
        shift_name: 'Opening Shift 11 Oct',
        cashier_id: 'cashier-1',
      });

      expect(nextShift.has_active_session).toBe(true);
      expect(prisma.dailyCalculation.create).toHaveBeenCalled();
    });
  });
});
