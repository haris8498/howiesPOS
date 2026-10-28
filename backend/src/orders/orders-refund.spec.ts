import {
  BadRequestException,
  ForbiddenException,
  NotFoundException,
  UnauthorizedException,
} from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { Prisma } from '@prisma/client';
import { OrdersService } from './orders.service';
import { PrismaService } from '../prisma/prisma.service';
import { PasswordService } from '../auth/password.service';
import { ChangeLogService } from '../sync/change-log.service';
import { RefundOrderDto } from './dto/refund-order.dto';

describe('OrdersService - Supervisor Refund & order_adjustments Ledger (#13 follow-up)', () => {
  let service: OrdersService;
  let mockPrisma: any;
  let mockPasswordService: any;
  let mockChangeLogService: any;

  const mockSupervisorUser = {
    id: 'user-supervisor-1',
    username: 'manager_dan',
    role: 'manager',
    is_active: true,
    password_hash: '$argon2id$v=19$m=19456,p=1,t=2$mock_supervisor_hash',
  };

  const mockCashierUser = {
    id: 'user-cashier-1',
    username: 'cashier_bob',
    role: 'cashier',
    is_active: true,
    password_hash: '$argon2id$v=19$m=19456,p=1,t=2$mock_cashier_hash',
  };

  const mockPaidOrder: any = {
    id: 'order-paid-1',
    order_number: 'ORD-5001',
    order_type: 'takeaway',
    status: 'completed',
    subtotal: new Prisma.Decimal(2000.0),
    discount_amount: new Prisma.Decimal(0.0),
    tax_amount: new Prisma.Decimal(320.0),
    grand_total: new Prisma.Decimal(2320.0),
    payment_status: 'PAID',
    is_paid: true,
    version: 1,
    device_id: 'POS-P1',
    shift_id: 'shift-101',
    created_at: new Date('2026-10-28T10:00:00Z'),
    updated_at: new Date('2026-10-28T10:15:00Z'),
    order_items: [],
    payments: [{ id: 'pmt-1', amount: new Prisma.Decimal(2320.0), payment_method: 'cash' }],
    order_adjustments: [],
  };

  const mockUnpaidOrder: any = {
    ...mockPaidOrder,
    id: 'order-unpaid-1',
    order_number: 'ORD-5002',
    status: 'newOrder',
    payment_status: 'UNPAID',
    is_paid: false,
    payments: [],
    order_adjustments: [],
  };

  const mockAlreadyRefundedOrder: any = {
    ...mockPaidOrder,
    id: 'order-refunded-1',
    order_number: 'ORD-5003',
    status: 'cancelled',
    payment_status: 'REFUNDED',
    is_paid: false,
    order_adjustments: [
      {
        id: 'adj-existing-1',
        order_id: 'order-refunded-1',
        type: 'REFUND',
        amount: new Prisma.Decimal(2320.0),
      },
    ],
  };

  beforeEach(async () => {
    mockPasswordService = {
      verify: jest.fn().mockImplementation((hash: string, plain: string) => {
        if (plain === '1234' && hash === mockSupervisorUser.password_hash) {
          return Promise.resolve(true);
        }
        if (plain === '5678' && hash === mockCashierUser.password_hash) {
          return Promise.resolve(true);
        }
        return Promise.resolve(false);
      }),
    };

    mockChangeLogService = {
      record: jest.fn().mockResolvedValue({ id: 'log-1' }),
    };

    mockPrisma = {
      order: {
        findUnique: jest.fn().mockImplementation(({ where }: { where: { id: string } }) => {
          if (where.id === mockPaidOrder.id) return Promise.resolve({ ...mockPaidOrder });
          if (where.id === mockUnpaidOrder.id) return Promise.resolve({ ...mockUnpaidOrder });
          if (where.id === mockAlreadyRefundedOrder.id)
            return Promise.resolve({ ...mockAlreadyRefundedOrder });
          return Promise.resolve(null);
        }),
        update: jest.fn().mockImplementation(({ where, data }: any) => {
          return Promise.resolve({
            ...mockPaidOrder,
            ...data,
            id: where.id,
          });
        }),
      },
      orderAdjustment: {
        create: jest.fn().mockImplementation(({ data }: any) => {
          return Promise.resolve({
            id: data.id || 'adj-uuid-generated',
            ...data,
            created_at: new Date(),
          });
        }),
      },
      staffUser: {
        findMany: jest.fn().mockResolvedValue([mockSupervisorUser, mockCashierUser]),
        findFirst: jest.fn().mockImplementation(({ where }: any) => {
          if (where.OR) {
            const matches = where.OR.some(
              (clause: any) =>
                clause.id === mockSupervisorUser.id ||
                clause.username === mockSupervisorUser.username,
            );
            if (matches) return Promise.resolve(mockSupervisorUser);
          }
          return Promise.resolve(null);
        }),
      },
      restaurantTable: {
        findFirst: jest.fn().mockResolvedValue(null),
        update: jest.fn().mockResolvedValue({}),
      },
      $transaction: jest.fn().mockImplementation((fn: (tx: any) => Promise<any>) => fn(mockPrisma)),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        OrdersService,
        { provide: PrismaService, useValue: mockPrisma },
        { provide: PasswordService, useValue: mockPasswordService },
        { provide: ChangeLogService, useValue: mockChangeLogService },
      ],
    }).compile();

    service = module.get<OrdersService>(OrdersService);
  });

  // -------------------------------------------------------------------------
  // Test 1: Valid refund writes adjustment, updates order and change-log
  // -------------------------------------------------------------------------
  it('1. Valid refund writes the adjustment and updates the order and change-log', async () => {
    const refundDto: RefundOrderDto = {
      supervisor_pin: '1234',
      reason: 'Customer cancelled prior to preparation',
      refund_method: 'cash',
      device_id: 'POS-P1',
    };

    const result = await service.refundOrder(mockPaidOrder.id, refundDto, {
      id: 'cashier-session-id',
      username: 'cashier_bob',
      role: 'cashier',
      is_default: false,
    });

    // A. Response contract
    expect(result).toBeDefined();
    expect(result.adjustment_id).toBeDefined();
    expect(typeof result.adjustment_id).toBe('string');
    expect(result.order).toBeDefined();

    // B. Order state updated
    expect(result.order.status).toBe('cancelled');
    expect(result.order.payment_status).toBe('REFUNDED');
    expect(result.order.is_paid).toBe(false);
    expect(result.order.version).toBe(2);

    // C. Adjustment row created in ledger with order total and supervisor id
    expect(mockPrisma.orderAdjustment.create).toHaveBeenCalledTimes(1);
    expect(mockPrisma.orderAdjustment.create).toHaveBeenCalledWith({
      data: expect.objectContaining({
        order_id: mockPaidOrder.id,
        type: 'REFUND',
        amount: mockPaidOrder.grand_total,
        reason: 'Customer cancelled prior to preparation',
        refund_method: 'cash',
        supervisor_id: mockSupervisorUser.id,
        cashier_id: 'cashier-session-id',
        device_id: 'POS-P1',
        shift_id: mockPaidOrder.shift_id,
      }),
    });

    // D. Order table updated in Prisma
    expect(mockPrisma.order.update).toHaveBeenCalledTimes(1);
    expect(mockPrisma.order.update).toHaveBeenCalledWith({
      where: { id: mockPaidOrder.id },
      data: expect.objectContaining({
        status: 'cancelled',
        payment_status: 'REFUNDED',
        is_paid: false,
        version: 2,
      }),
      include: expect.anything(),
    });

    // E. Change-log entry emitted with version bump (#11 pattern)
    expect(mockChangeLogService.record).toHaveBeenCalledTimes(1);
    expect(mockChangeLogService.record).toHaveBeenCalledWith(
      expect.anything(),
      'order',
      mockPaidOrder.id,
      'UPDATE',
      2,
      expect.objectContaining({
        id: mockPaidOrder.id,
        status: 'cancelled',
        payment_status: 'REFUNDED',
        is_paid: false,
        version: 2,
      }),
      false,
    );
  });

  // -------------------------------------------------------------------------
  // Test 2: Wrong PIN or non-supervisor is rejected, nothing written
  // -------------------------------------------------------------------------
  it('2. Wrong PIN or non-supervisor is rejected, nothing written', async () => {
    // Case 2A: Wrong PIN (401 Unauthorized)
    const badPinDto: RefundOrderDto = {
      supervisor_pin: '0000',
      reason: 'Attempt with wrong pin',
      refund_method: 'cash',
    };

    await expect(service.refundOrder(mockPaidOrder.id, badPinDto)).rejects.toThrow(
      UnauthorizedException,
    );
    expect(mockPrisma.orderAdjustment.create).not.toHaveBeenCalled();
    expect(mockPrisma.order.update).not.toHaveBeenCalled();
    expect(mockChangeLogService.record).not.toHaveBeenCalled();

    // Case 2B: PIN belongs to a non-supervisor (e.g. cashier) -> 403 Forbidden
    const cashierPinDto: RefundOrderDto = {
      supervisor_pin: '5678', // matches mockCashierUser (role: cashier)
      reason: 'Attempt with cashier pin',
      refund_method: 'card',
    };

    await expect(service.refundOrder(mockPaidOrder.id, cashierPinDto)).rejects.toThrow(
      ForbiddenException,
    );
    expect(mockPrisma.orderAdjustment.create).not.toHaveBeenCalled();
    expect(mockPrisma.order.update).not.toHaveBeenCalled();
    expect(mockChangeLogService.record).not.toHaveBeenCalled();
  });

  // -------------------------------------------------------------------------
  // Test 3: Unpaid or already-refunded order is rejected
  // -------------------------------------------------------------------------
  it('3. Unpaid or already-refunded order is rejected', async () => {
    const validDto: RefundOrderDto = {
      supervisor_pin: '1234',
      reason: 'Attempt to refund',
      refund_method: 'original',
    };

    // Case 3A: Unpaid order (400 Bad Request)
    await expect(service.refundOrder(mockUnpaidOrder.id, validDto)).rejects.toThrow(
      BadRequestException,
    );
    expect(mockPrisma.orderAdjustment.create).not.toHaveBeenCalled();
    expect(mockPrisma.order.update).not.toHaveBeenCalled();
    expect(mockChangeLogService.record).not.toHaveBeenCalled();

    // Case 3B: Already refunded order (400 Bad Request)
    await expect(service.refundOrder(mockAlreadyRefundedOrder.id, validDto)).rejects.toThrow(
      BadRequestException,
    );
    expect(mockPrisma.orderAdjustment.create).not.toHaveBeenCalled();
    expect(mockPrisma.order.update).not.toHaveBeenCalled();
    expect(mockChangeLogService.record).not.toHaveBeenCalled();

    // Case 3C: Non-existent order (404 Not Found)
    await expect(service.refundOrder('non-existent-order-id', validDto)).rejects.toThrow(
      NotFoundException,
    );
    expect(mockPrisma.orderAdjustment.create).not.toHaveBeenCalled();
    expect(mockPrisma.order.update).not.toHaveBeenCalled();
    expect(mockChangeLogService.record).not.toHaveBeenCalled();
  });
});
