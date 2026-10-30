import { Test, TestingModule } from '@nestjs/testing';
import { Prisma } from '@prisma/client';
import { ForbiddenException, UnprocessableEntityException } from '@nestjs/common';
import { PricingService } from './pricing.service';
import { PrismaService } from '../prisma/prisma.service';
import { PasswordService } from '../auth/password.service';

describe('PricingService', () => {
  let service: PricingService;
  let mockPrisma: any;
  let mockPasswordService: any;

  beforeEach(async () => {
    mockPrisma = {
      order: {
        findUnique: jest.fn(),
        update: jest.fn(),
      },
      orderItem: {
        findMany: jest.fn(),
      },
      menuItem: {
        findUnique: jest.fn(),
      },
      staffUser: {
        findFirst: jest.fn(),
      },
      discountAudit: {
        create: jest.fn(),
        findMany: jest.fn(),
      },
      pricingAudit: {
        create: jest.fn(),
        findMany: jest.fn(),
      },
    };

    mockPasswordService = {
      verify: jest.fn().mockResolvedValue(true),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        PricingService,
        { provide: PrismaService, useValue: mockPrisma },
        { provide: PasswordService, useValue: mockPasswordService },
      ],
    }).compile();

    service = module.get<PricingService>(PricingService);
    process.env.PRICING_ROUNDING_TOLERANCE = '1.00';
  });

  afterEach(() => {
    delete process.env.PRICING_ROUNDING_TOLERANCE;
  });

  describe('calculate() with Active Items & Catalog Pricing (Decimals & Modifiers)', () => {
    it('computes subtotal from active ledger items and catalog prices using Decimal precision', async () => {
      const orderId = 'ord-1';
      const mockOrder = {
        id: orderId,
        order_type: 'dineIn',
        subtotal: new Prisma.Decimal('0.00'),
        tax_amount: new Prisma.Decimal('0.00'),
        grand_total: new Prisma.Decimal('0.00'),
        discount_percentage: new Prisma.Decimal('0.00'),
        discount_amount: new Prisma.Decimal('0.00'),
      };

      const mockItems = [
        {
          id: 'item-1',
          order_id: orderId,
          menu_item_id: 'menu-1',
          item_name: 'Fajita Pizza',
          selected_size: 'Large',
          selected_crust: 'Original',
          extra_toppings: 'Extra Cheese, Mushrooms',
          quantity: 2,
          unit_price: new Prisma.Decimal('1850.00'),
          total_price: new Prisma.Decimal('3700.00'),
          voidedAt: null,
          is_cancelled: false,
        },
      ];

      const mockCatalogItem = {
        id: 'menu-1',
        name: 'Fajita Pizza',
        base_price: new Prisma.Decimal('850.00'),
        sizes: [
          { size_name: 'Small', price: new Prisma.Decimal('850.00') },
          { size_name: 'Large', price: new Prisma.Decimal('1750.00') },
        ],
        options: [
          { option_type: 'topping', option_name: 'Extra Cheese', additional_price: new Prisma.Decimal('50.00') },
          { option_type: 'topping', option_name: 'Mushrooms', additional_price: new Prisma.Decimal('50.00') },
        ],
      };

      const tx = {
        order: {
          findUnique: jest.fn().mockResolvedValue(mockOrder),
          update: jest.fn().mockImplementation(({ data }) => Promise.resolve({ ...mockOrder, ...data })),
        },
        orderItem: {
          findMany: jest.fn().mockResolvedValue(mockItems),
        },
        menuItem: {
          findUnique: jest.fn().mockResolvedValue(mockCatalogItem),
        },
        staffUser: {
          findFirst: jest.fn(),
        },
        discountAudit: {
          create: jest.fn(),
        },
        pricingAudit: {
          create: jest.fn(),
        },
      };

      const result = await service.calculate(orderId, tx as any, {
        clientGrandTotal: 3700.00,
        source: 'OFFLINE',
      });

      // Unit price = 1750 (Large) + 50 (Cheese) + 50 (Mushrooms) = 1850
      // 2 * 1850 = 3700.00
      expect(result.subtotal.toString()).toBe('3700');
      expect(result.grandTotal.toString()).toBe('3700');
      expect(result.pricingStatus).toBe('VERIFIED');
      expect(result.lineDiscrepancies).toHaveLength(0);
    });

    it('strictly excludes voided ledger items from subtotal calculation (D-05)', async () => {
      const orderId = 'ord-voided';
      const mockOrder = {
        id: orderId,
        order_type: 'dineIn',
        subtotal: new Prisma.Decimal('0.00'),
        tax_amount: new Prisma.Decimal('0.00'),
        grand_total: new Prisma.Decimal('0.00'),
        discount_percentage: new Prisma.Decimal('0.00'),
        discount_amount: new Prisma.Decimal('0.00'),
      };

      // Only item-1 returned because query filters voidedAt: null && is_cancelled: false
      const mockActiveItems = [
        {
          id: 'item-active',
          order_id: orderId,
          menu_item_id: 'menu-1',
          item_name: 'Burger',
          selected_size: 'Regular',
          extra_toppings: '',
          quantity: 1,
          unit_price: new Prisma.Decimal('500.00'),
          total_price: new Prisma.Decimal('500.00'),
          voidedAt: null,
          is_cancelled: false,
        },
      ];

      const tx = {
        order: {
          findUnique: jest.fn().mockResolvedValue(mockOrder),
          update: jest.fn().mockImplementation(({ data }) => Promise.resolve({ ...mockOrder, ...data })),
        },
        orderItem: {
          findMany: jest.fn().mockResolvedValue(mockActiveItems),
        },
        menuItem: {
          findUnique: jest.fn().mockResolvedValue({
            id: 'menu-1',
            base_price: new Prisma.Decimal('500.00'),
            sizes: [],
            options: [],
          }),
        },
        staffUser: { findFirst: jest.fn() },
        discountAudit: { create: jest.fn() },
        pricingAudit: { create: jest.fn() },
      };

      const result = await service.calculate(orderId, tx as any, {
        clientGrandTotal: 500.00,
        source: 'OFFLINE',
      });

      // Filter passed to orderItem.findMany must include voidedAt: null, is_cancelled: false
      expect(tx.orderItem.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: expect.objectContaining({
            order_id: orderId,
            voidedAt: null,
            is_cancelled: false,
          }),
        }),
      );

      expect(result.subtotal.toString()).toBe('500');
      expect(result.grandTotal.toString()).toBe('500');
    });

    it('detects catalog line price differences when client unit price is tampered', async () => {
      const orderId = 'ord-tampered-line';
      const mockOrder = {
        id: orderId,
        order_type: 'dineIn',
        subtotal: new Prisma.Decimal('0.00'),
        grand_total: new Prisma.Decimal('0.00'),
      };

      const mockItems = [
        {
          id: 'item-tampered',
          order_id: orderId,
          menu_item_id: 'menu-pizza',
          item_name: 'Pepperoni Pizza',
          selected_size: 'Regular',
          extra_toppings: '',
          quantity: 1,
          unit_price: new Prisma.Decimal('10.00'), // Client tampered to 10!
          total_price: new Prisma.Decimal('10.00'),
          voidedAt: null,
          is_cancelled: false,
        },
      ];

      const tx = {
        order: {
          findUnique: jest.fn().mockResolvedValue(mockOrder),
          update: jest.fn().mockImplementation(({ data }) => Promise.resolve({ ...mockOrder, ...data })),
        },
        orderItem: {
          findMany: jest.fn().mockResolvedValue(mockItems),
        },
        menuItem: {
          findUnique: jest.fn().mockResolvedValue({
            id: 'menu-pizza',
            base_price: new Prisma.Decimal('1200.00'), // Catalog is 1200
            sizes: [],
            options: [],
          }),
        },
        staffUser: { findFirst: jest.fn() },
        discountAudit: { create: jest.fn() },
        pricingAudit: { create: jest.fn() },
      };

      const result = await service.calculate(orderId, tx as any, {
        clientGrandTotal: 10.00,
        source: 'OFFLINE',
      });

      // Authoritative subtotal is 1200, not client's 10
      expect(result.subtotal.toString()).toBe('1200');
      expect(result.grandTotal.toString()).toBe('1200');
      expect(result.lineDiscrepancies).toHaveLength(1);
      expect(result.lineDiscrepancies[0].clientUnitPrice.toString()).toBe('10');
      expect(result.lineDiscrepancies[0].catalogUnitPrice.toString()).toBe('1200');
      expect(result.pricingStatus).toBe('MISMATCH');
    });
  });

  describe('Tolerance Boundary Tests (Task 2)', () => {
    it('accepts rounding difference of 0.50 silently within default 1.00 tolerance', async () => {
      const orderId = 'ord-tol-50';
      const mockOrder = {
        id: orderId,
        order_type: 'takeaway',
        subtotal: new Prisma.Decimal('0.00'),
        grand_total: new Prisma.Decimal('0.00'),
      };

      const mockItems = [
        {
          id: 'item-1',
          order_id: orderId,
          menu_item_id: 'menu-1',
          item_name: 'Burger',
          selected_size: 'Regular',
          extra_toppings: '',
          quantity: 1,
          unit_price: new Prisma.Decimal('500.00'),
          total_price: new Prisma.Decimal('500.00'),
          voidedAt: null,
          is_cancelled: false,
        },
      ];

      const tx = {
        order: {
          findUnique: jest.fn().mockResolvedValue(mockOrder),
          update: jest.fn().mockImplementation(({ data }) => Promise.resolve({ ...mockOrder, ...data })),
        },
        orderItem: { findMany: jest.fn().mockResolvedValue(mockItems) },
        menuItem: {
          findUnique: jest.fn().mockResolvedValue({
            id: 'menu-1',
            base_price: new Prisma.Decimal('500.00'),
            sizes: [],
            options: [],
          }),
        },
        staffUser: { findFirst: jest.fn() },
        discountAudit: { create: jest.fn() },
        pricingAudit: { create: jest.fn() },
      };

      // Client says 500.50, server calculates 500.00 (diff = 0.50 <= 1.00 tolerance)
      const result = await service.calculate(orderId, tx as any, {
        clientGrandTotal: 500.50,
        source: 'OFFLINE',
      });

      expect(result.isWithinTolerance).toBe(true);
      expect(result.pricingStatus).toBe('VERIFIED');
      expect(result.grandTotal.toString()).toBe('500');
      expect(result.clientReportedTotal?.toString()).toBe('500.5');
      // No pricing audit needed for silent tolerance acceptance
      expect(tx.pricingAudit.create).not.toHaveBeenCalled();
    });

    it('accepts deviation of exactly 1.00 as within tolerance', async () => {
      const orderId = 'ord-tol-100';
      const mockOrder = {
        id: orderId,
        order_type: 'takeaway',
        subtotal: new Prisma.Decimal('0.00'),
        grand_total: new Prisma.Decimal('0.00'),
      };

      const mockItems = [
        {
          id: 'item-1',
          order_id: orderId,
          menu_item_id: 'menu-1',
          item_name: 'Burger',
          selected_size: 'Regular',
          extra_toppings: '',
          quantity: 1,
          unit_price: new Prisma.Decimal('500.00'),
          total_price: new Prisma.Decimal('500.00'),
          voidedAt: null,
          is_cancelled: false,
        },
      ];

      const tx = {
        order: {
          findUnique: jest.fn().mockResolvedValue(mockOrder),
          update: jest.fn().mockImplementation(({ data }) => Promise.resolve({ ...mockOrder, ...data })),
        },
        orderItem: { findMany: jest.fn().mockResolvedValue(mockItems) },
        menuItem: {
          findUnique: jest.fn().mockResolvedValue({
            id: 'menu-1',
            base_price: new Prisma.Decimal('500.00'),
            sizes: [],
            options: [],
          }),
        },
        staffUser: { findFirst: jest.fn() },
        discountAudit: { create: jest.fn() },
        pricingAudit: { create: jest.fn() },
      };

      // Client says 499.00, server is 500.00 (diff = 1.00 <= 1.00 tolerance)
      const result = await service.calculate(orderId, tx as any, {
        clientGrandTotal: 499.00,
        source: 'OFFLINE',
      });

      expect(result.isWithinTolerance).toBe(true);
      expect(result.pricingStatus).toBe('VERIFIED');
    });

    it('flags deviation of 1.01 (> 1.00 tolerance) as MISMATCH, keeps order, and writes audit row in offline sync', async () => {
      const orderId = 'ord-tol-101';
      const mockOrder = {
        id: orderId,
        order_type: 'takeaway',
        subtotal: new Prisma.Decimal('0.00'),
        grand_total: new Prisma.Decimal('0.00'),
      };

      const mockItems = [
        {
          id: 'item-1',
          order_id: orderId,
          menu_item_id: 'menu-1',
          item_name: 'Burger',
          selected_size: 'Regular',
          extra_toppings: '',
          quantity: 1,
          unit_price: new Prisma.Decimal('500.00'),
          total_price: new Prisma.Decimal('500.00'),
          voidedAt: null,
          is_cancelled: false,
        },
      ];

      const tx = {
        order: {
          findUnique: jest.fn().mockResolvedValue(mockOrder),
          update: jest.fn().mockImplementation(({ data }) => Promise.resolve({ ...mockOrder, ...data })),
        },
        orderItem: { findMany: jest.fn().mockResolvedValue(mockItems) },
        menuItem: {
          findUnique: jest.fn().mockResolvedValue({
            id: 'menu-1',
            base_price: new Prisma.Decimal('500.00'),
            sizes: [],
            options: [],
          }),
        },
        staffUser: { findFirst: jest.fn() },
        discountAudit: { create: jest.fn() },
        pricingAudit: { create: jest.fn() },
      };

      // Client says 498.99, server is 500.00 (diff = 1.01 > 1.00 tolerance)
      const result = await service.calculate(orderId, tx as any, {
        clientGrandTotal: 498.99,
        source: 'OFFLINE',
      });

      expect(result.isWithinTolerance).toBe(false);
      expect(result.pricingStatus).toBe('MISMATCH');
      expect(result.grandTotal.toString()).toBe('500');
      expect(result.clientReportedTotal?.toString()).toBe('498.99');
      // Order is STILL updated/persisted in DB
      expect(tx.order.update).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { id: orderId },
          data: expect.objectContaining({
            pricing_status: 'MISMATCH',
            grand_total: new Prisma.Decimal('500'),
            client_reported_total: new Prisma.Decimal('498.99'),
          }),
        }),
      );
      // Pricing audit row is written
      expect(tx.pricingAudit.create).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({
            order_id: orderId,
            pricing_status: 'MISMATCH',
            client_grand_total: new Prisma.Decimal('498.99'),
            server_grand_total: new Prisma.Decimal('500'),
          }),
        }),
      );
    });

    it('rejects online REST request with 422 if deviation > tolerance and rejectOnlineMismatch is enabled', async () => {
      const orderId = 'ord-online-reject';
      const mockOrder = {
        id: orderId,
        order_type: 'online',
        subtotal: new Prisma.Decimal('0.00'),
        grand_total: new Prisma.Decimal('0.00'),
      };

      const mockItems = [
        {
          id: 'item-1',
          order_id: orderId,
          menu_item_id: 'menu-1',
          item_name: 'Burger',
          selected_size: 'Regular',
          extra_toppings: '',
          quantity: 1,
          unit_price: new Prisma.Decimal('500.00'),
          total_price: new Prisma.Decimal('500.00'),
          voidedAt: null,
          is_cancelled: false,
        },
      ];

      const tx = {
        order: { findUnique: jest.fn().mockResolvedValue(mockOrder), update: jest.fn() },
        orderItem: { findMany: jest.fn().mockResolvedValue(mockItems) },
        menuItem: {
          findUnique: jest.fn().mockResolvedValue({
            id: 'menu-1',
            base_price: new Prisma.Decimal('500.00'),
            sizes: [],
            options: [],
          }),
        },
        staffUser: { findFirst: jest.fn() },
        discountAudit: { create: jest.fn() },
        pricingAudit: { create: jest.fn() },
      };

      await expect(
        service.calculate(orderId, tx as any, {
          clientGrandTotal: 400.00, // Diff = 100 > 1.00
          source: 'ONLINE',
          rejectOnlineMismatch: true,
        }),
      ).rejects.toThrow(UnprocessableEntityException);
    });
  });

  describe('Discount Authorization Matrix (Tasks 4 & 5)', () => {
    const validManager = {
      id: 'mgr-uuid-1',
      username: 'manager_bob',
      role: 'MANAGER',
      is_active: true,
      password_hash: 'argon2id-hash-mock',
    };

    it('applies discount and creates DiscountAudit when manager approval is valid (offline flow)', async () => {
      const orderId = 'ord-disc-approved';
      const mockOrder = {
        id: orderId,
        order_type: 'dineIn',
        subtotal: new Prisma.Decimal('1000.00'),
        grand_total: new Prisma.Decimal('1000.00'),
      };

      const mockItems = [
        {
          id: 'item-1',
          order_id: orderId,
          menu_item_id: 'menu-1',
          item_name: 'Pizza',
          selected_size: 'Regular',
          extra_toppings: '',
          quantity: 1,
          unit_price: new Prisma.Decimal('1000.00'),
          total_price: new Prisma.Decimal('1000.00'),
          voidedAt: null,
          is_cancelled: false,
        },
      ];

      const tx = {
        order: { findUnique: jest.fn().mockResolvedValue(mockOrder), update: jest.fn() },
        orderItem: { findMany: jest.fn().mockResolvedValue(mockItems) },
        menuItem: {
          findUnique: jest.fn().mockResolvedValue({
            id: 'menu-1',
            base_price: new Prisma.Decimal('1000.00'),
            sizes: [],
            options: [],
          }),
        },
        staffUser: { findFirst: jest.fn().mockResolvedValue(validManager) },
        discountAudit: { create: jest.fn().mockResolvedValue({ id: 'aud-1' }) },
        pricingAudit: { create: jest.fn() },
      };

      const result = await service.calculate(orderId, tx as any, {
        clientGrandTotal: 900.00,
        discountPercentage: 10, // 10% of 1000 = 100 discount -> 900 grand total
        discountApproval: {
          managerId: 'mgr-uuid-1',
          deviceId: 'POS-01',
          approvedAt: '2026-10-27T10:00:00Z',
          reason: 'VIP Customer',
        },
        source: 'OFFLINE',
      });

      expect(result.discountPercentage.toString()).toBe('10');
      expect(result.discountAmount.toString()).toBe('100');
      expect(result.grandTotal.toString()).toBe('900');
      expect(result.pricingStatus).toBe('VERIFIED');

      expect(tx.discountAudit.create).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({
            order_id: orderId,
            amount: new Prisma.Decimal('100'),
            percent: new Prisma.Decimal('10'),
            approved_by: 'mgr-uuid-1',
            source: 'OFFLINE',
            reason: 'VIP Customer',
          }),
        }),
      );
    });

    it('rejects unapproved discount in offline sync: keeps order, zeros discount, flags UNAUTHORIZED_DISCOUNT', async () => {
      const orderId = 'ord-disc-unapproved-offline';
      const mockOrder = {
        id: orderId,
        order_type: 'dineIn',
        subtotal: new Prisma.Decimal('1000.00'),
        grand_total: new Prisma.Decimal('1000.00'),
      };

      const mockItems = [
        {
          id: 'item-1',
          order_id: orderId,
          menu_item_id: 'menu-1',
          item_name: 'Pizza',
          selected_size: 'Regular',
          extra_toppings: '',
          quantity: 1,
          unit_price: new Prisma.Decimal('1000.00'),
          total_price: new Prisma.Decimal('1000.00'),
          voidedAt: null,
          is_cancelled: false,
        },
      ];

      const tx = {
        order: { findUnique: jest.fn().mockResolvedValue(mockOrder), update: jest.fn() },
        orderItem: { findMany: jest.fn().mockResolvedValue(mockItems) },
        menuItem: {
          findUnique: jest.fn().mockResolvedValue({
            id: 'menu-1',
            base_price: new Prisma.Decimal('1000.00'),
            sizes: [],
            options: [],
          }),
        },
        staffUser: { findFirst: jest.fn().mockResolvedValue(null) }, // No manager found!
        discountAudit: { create: jest.fn() },
        pricingAudit: { create: jest.fn() },
      };

      // Client requested 20% discount (paying 800) without valid manager approval
      const result = await service.calculate(orderId, tx as any, {
        clientGrandTotal: 800.00,
        discountPercentage: 20,
        source: 'OFFLINE',
      });

      // Discount NOT applied to authoritative total!
      expect(result.discountAmount.toString()).toBe('0');
      expect(result.grandTotal.toString()).toBe('1000'); // Authoritative grand total remains 1000
      expect(result.pricingStatus).toBe('UNAUTHORIZED_DISCOUNT');

      // Order is persisted with UNAUTHORIZED_DISCOUNT
      expect(tx.order.update).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { id: orderId },
          data: expect.objectContaining({
            pricing_status: 'UNAUTHORIZED_DISCOUNT',
            discount_amount: new Prisma.Decimal('0'),
            grand_total: new Prisma.Decimal('1000'),
          }),
        }),
      );

      // Pricing audit records unauthorized discount flag
      expect(tx.pricingAudit.create).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({
            order_id: orderId,
            pricing_status: 'UNAUTHORIZED_DISCOUNT',
          }),
        }),
      );
    });

    it('rejects unapproved discount in online REST with HTTP 403 ForbiddenException', async () => {
      const orderId = 'ord-disc-online-403';
      const mockOrder = {
        id: orderId,
        order_type: 'online',
        subtotal: new Prisma.Decimal('1000.00'),
        grand_total: new Prisma.Decimal('1000.00'),
      };

      const mockItems = [
        {
          id: 'item-1',
          order_id: orderId,
          menu_item_id: 'menu-1',
          item_name: 'Pizza',
          selected_size: 'Regular',
          extra_toppings: '',
          quantity: 1,
          unit_price: new Prisma.Decimal('1000.00'),
          total_price: new Prisma.Decimal('1000.00'),
          voidedAt: null,
          is_cancelled: false,
        },
      ];

      const tx = {
        order: { findUnique: jest.fn().mockResolvedValue(mockOrder), update: jest.fn() },
        orderItem: { findMany: jest.fn().mockResolvedValue(mockItems) },
        menuItem: {
          findUnique: jest.fn().mockResolvedValue({
            id: 'menu-1',
            base_price: new Prisma.Decimal('1000.00'),
            sizes: [],
            options: [],
          }),
        },
        staffUser: { findFirst: jest.fn().mockResolvedValue(null) },
        discountAudit: { create: jest.fn() },
        pricingAudit: { create: jest.fn() },
      };

      await expect(
        service.calculate(orderId, tx as any, {
          clientGrandTotal: 800.00,
          discountPercentage: 20,
          source: 'ONLINE',
        }),
      ).rejects.toThrow(ForbiddenException);
    });

    it('an offline order with a cashier discount keeps it after sync and writes the audit record', async () => {
      const orderId = 'ord-disc-cashier-offline';
      const mockOrder = {
        id: orderId,
        order_type: 'dineIn',
        subtotal: new Prisma.Decimal('1000.00'),
        grand_total: new Prisma.Decimal('800.00'),
      };

      const mockItems = [
        {
          id: 'item-1',
          order_id: orderId,
          menu_item_id: 'menu-1',
          item_name: 'Pizza',
          selected_size: 'Regular',
          extra_toppings: '',
          quantity: 1,
          unit_price: new Prisma.Decimal('1000.00'),
          total_price: new Prisma.Decimal('1000.00'),
          voidedAt: null,
          is_cancelled: false,
        },
      ];

      const cashierStaff = {
        id: 'cashier-uuid-1',
        username: 'bob_cashier',
        role: 'cashier',
        is_active: true,
      };

      const tx = {
        order: { findUnique: jest.fn().mockResolvedValue(mockOrder), update: jest.fn() },
        orderItem: { findMany: jest.fn().mockResolvedValue(mockItems) },
        menuItem: {
          findUnique: jest.fn().mockResolvedValue({
            id: 'menu-1',
            base_price: new Prisma.Decimal('1000.00'),
            sizes: [],
            options: [],
          }),
        },
        staffUser: { findFirst: jest.fn().mockResolvedValue(cashierStaff) },
        discountAudit: { create: jest.fn().mockResolvedValue({ id: 'aud-cashier-1' }) },
        pricingAudit: { create: jest.fn() },
      };

      const result = await service.calculate(orderId, tx as any, {
        clientGrandTotal: 800.00,
        discountPercentage: 20,
        cashierId: 'cashier-uuid-1',
        source: 'OFFLINE',
      });

      // The discount is preserved after sync and grand total is authoritatively recomputed!
      expect(result.discountPercentage.toString()).toBe('20');
      expect(result.discountAmount.toString()).toBe('200');
      expect(result.grandTotal.toString()).toBe('800');
      expect(result.pricingStatus).toBe('VERIFIED');

      // Order is persisted with VERIFIED status and discount applied
      expect(tx.order.update).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { id: orderId },
          data: expect.objectContaining({
            pricing_status: 'VERIFIED',
            discount_amount: new Prisma.Decimal('200'),
            grand_total: new Prisma.Decimal('800'),
          }),
        }),
      );

      // Immutable discount audit row is created with cashier_id, source=OFFLINE, and approved_by=null (Amendment 4)
      expect(tx.discountAudit.create).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({
            order_id: orderId,
            amount: new Prisma.Decimal('200'),
            percent: new Prisma.Decimal('20'),
            discount_type: 'PERCENTAGE',
            cashier_id: 'cashier-uuid-1',
            approved_by: null,
            source: 'OFFLINE',
          }),
        }),
      );

      // No unauthorized discount pricing audit recorded
      expect(tx.pricingAudit.create).not.toHaveBeenCalled();
    });

    it('accepts cashier discount without manager approval on online REST path and creates audit record', async () => {
      const orderId = 'ord-disc-cashier-online';
      const mockOrder = {
        id: orderId,
        order_type: 'takeaway',
        subtotal: new Prisma.Decimal('1000.00'),
        grand_total: new Prisma.Decimal('900.00'),
      };

      const mockItems = [
        {
          id: 'item-1',
          order_id: orderId,
          menu_item_id: 'menu-1',
          item_name: 'Pizza',
          selected_size: 'Regular',
          extra_toppings: '',
          quantity: 1,
          unit_price: new Prisma.Decimal('1000.00'),
          total_price: new Prisma.Decimal('1000.00'),
          voidedAt: null,
          is_cancelled: false,
        },
      ];

      const cashierStaff = {
        id: 'cashier-uuid-2',
        username: 'alice_cashier',
        role: 'cashier',
        is_active: true,
      };

      const tx = {
        order: { findUnique: jest.fn().mockResolvedValue(mockOrder), update: jest.fn() },
        orderItem: { findMany: jest.fn().mockResolvedValue(mockItems) },
        menuItem: {
          findUnique: jest.fn().mockResolvedValue({
            id: 'menu-1',
            base_price: new Prisma.Decimal('1000.00'),
            sizes: [],
            options: [],
          }),
        },
        staffUser: { findFirst: jest.fn().mockResolvedValue(cashierStaff) },
        discountAudit: { create: jest.fn().mockResolvedValue({ id: 'aud-cashier-2' }) },
        pricingAudit: { create: jest.fn() },
      };

      const result = await service.calculate(orderId, tx as any, {
        clientGrandTotal: 900.00,
        discountPercentage: 10,
        cashierId: 'cashier-uuid-2',
        source: 'ONLINE',
      });

      expect(result.discountPercentage.toString()).toBe('10');
      expect(result.discountAmount.toString()).toBe('100');
      expect(result.grandTotal.toString()).toBe('900');
      expect(result.pricingStatus).toBe('VERIFIED');
      expect(tx.discountAudit.create).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({
            order_id: orderId,
            cashier_id: 'cashier-uuid-2',
            approved_by: null,
            source: 'ONLINE',
          }),
        }),
      );
    });

    it('rejects unauthorized role (e.g. waiter) discount in offline sync: keeps order, zeros discount, flags UNAUTHORIZED_DISCOUNT', async () => {
      const orderId = 'ord-disc-waiter-offline';
      const mockOrder = {
        id: orderId,
        order_type: 'dineIn',
        subtotal: new Prisma.Decimal('1000.00'),
        grand_total: new Prisma.Decimal('1000.00'),
      };

      const mockItems = [
        {
          id: 'item-1',
          order_id: orderId,
          menu_item_id: 'menu-1',
          item_name: 'Pizza',
          selected_size: 'Regular',
          extra_toppings: '',
          quantity: 1,
          unit_price: new Prisma.Decimal('1000.00'),
          total_price: new Prisma.Decimal('1000.00'),
          voidedAt: null,
          is_cancelled: false,
        },
      ];

      const waiterStaff = {
        id: 'waiter-uuid-1',
        username: 'sam_waiter',
        role: 'waiter',
        is_active: true,
      };

      const tx = {
        order: { findUnique: jest.fn().mockResolvedValue(mockOrder), update: jest.fn() },
        orderItem: { findMany: jest.fn().mockResolvedValue(mockItems) },
        menuItem: {
          findUnique: jest.fn().mockResolvedValue({
            id: 'menu-1',
            base_price: new Prisma.Decimal('1000.00'),
            sizes: [],
            options: [],
          }),
        },
        staffUser: { findFirst: jest.fn().mockResolvedValue(waiterStaff) },
        discountAudit: { create: jest.fn() },
        pricingAudit: { create: jest.fn() },
      };

      const result = await service.calculate(orderId, tx as any, {
        clientGrandTotal: 800.00,
        discountPercentage: 20,
        staffId: 'waiter-uuid-1',
        source: 'OFFLINE',
      });

      expect(result.discountAmount.toString()).toBe('0');
      expect(result.grandTotal.toString()).toBe('1000');
      expect(result.pricingStatus).toBe('UNAUTHORIZED_DISCOUNT');
    });
  });

  describe('Audit Immutability & Review Queries (Task 6)', () => {
    it('provides read-only queries for pricing audits without update or delete operations', async () => {
      mockPrisma.pricingAudit.findMany.mockResolvedValue([
        { id: 'aud-1', pricing_status: 'MISMATCH' },
      ]);
      mockPrisma.discountAudit.findMany.mockResolvedValue([
        { id: 'disc-1', amount: new Prisma.Decimal('50.00') },
      ]);

      const audits = await service.getPricingAudits({ pricing_status: 'MISMATCH' });
      expect(audits).toHaveLength(1);
      expect(audits[0].pricing_status).toBe('MISMATCH');

      const discounts = await service.getDiscountAudits('ord-1');
      expect(discounts).toHaveLength(1);

      // Verify no update or delete methods exist on the service
      expect((service as any).updateDiscountAudit).toBeUndefined();
      expect((service as any).deleteDiscountAudit).toBeUndefined();
      expect((service as any).updatePricingAudit).toBeUndefined();
      expect((service as any).deletePricingAudit).toBeUndefined();
    });
  });
});
