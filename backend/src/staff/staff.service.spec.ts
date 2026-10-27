import { ConflictException, NotFoundException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Test, TestingModule } from '@nestjs/testing';
import { Payslip } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { StaffMemberWithUser, StaffService } from './staff.service';
import { PasswordService } from '../auth/password.service';

describe('StaffService', () => {
  let service: StaffService;
  let prisma: PrismaService;

  const mockStaff = {
    id: 'st-1',
    user_id: 'u-1',
    full_name: 'Alexander Pierce',
    phone: '+92 300 1234567',
    role: 'manager',
    status: 'Active',
    joining_date: new Date('2024-01-01'),
    assigned_shift: 'Morning Shift',
    monthly_salary: 100000.0,
    hourly_rate: 625.0,
    leaving_date: null,
    is_salary_paid: false,
    salary_paid_date: null,
    created_at: new Date(),
    updated_at: new Date(),
  };

  const mockActor = {
    id: 'admin-id',
    username: 'superadmin',
    role: 'owner',
    is_default: true,
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        StaffService,
        PasswordService,
        {
          provide: ConfigService,
          useValue: {
            get: jest.fn((key: string, defaultValue?: unknown) => {
              if (key === 'ARGON2_MEMORY_COST') return 19456;
              if (key === 'ARGON2_TIME_COST') return 2;
              if (key === 'ARGON2_PARALLELISM') return 1;
              return defaultValue;
            }),
          },
        },
        {
          provide: PrismaService,
          useValue: {
            staffMember: {
              findMany: jest.fn().mockResolvedValue([mockStaff]),
              findUnique: jest.fn().mockImplementation(({ where }) => {
                if (where.id === 'st-1') return Promise.resolve(mockStaff);
                return Promise.resolve(null);
              }),
              create: jest.fn().mockImplementation(({ data }) =>
                Promise.resolve({
                  id: 'st-new',
                  ...data,
                }),
              ),
              update: jest.fn().mockImplementation(({ data }) =>
                Promise.resolve({
                  ...mockStaff,
                  ...data,
                }),
              ),
              delete: jest.fn().mockResolvedValue(mockStaff),
            },
            staffUser: {
              findUnique: jest.fn().mockResolvedValue(null),
              create: jest.fn().mockResolvedValue({ id: 'u-new', username: 'alex' }),
            },
            payslip: {
              findFirst: jest.fn().mockResolvedValue(null),
              create: jest.fn().mockImplementation(({ data }) =>
                Promise.resolve({
                  id: 'ps-new',
                  status: 'Paid',
                  paid_at: new Date(),
                  ...data,
                }),
              ),
              update: jest.fn().mockImplementation(({ data }) =>
                Promise.resolve({
                  id: 'ps-1',
                  status: data.status || 'Paid',
                  paid_at: data.paid_at || new Date(),
                  ...data,
                }),
              ),
            },
            $transaction: jest.fn().mockImplementation((cb) =>
              cb({
                staffUser: {
                  create: jest.fn().mockResolvedValue({ id: 'u-new', username: 'alex' }),
                },
                staffMember: {
                  create: jest.fn().mockResolvedValue({ ...mockStaff, id: 'st-new' }),
                },
              }),
            ),
          },
        },
      ],
    }).compile();

    service = module.get<StaffService>(StaffService);
    prisma = module.get<PrismaService>(PrismaService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  it('should list staff members', async () => {
    const staff = await service.listStaff();
    expect(staff).toHaveLength(1);
    expect(staff[0].full_name).toBe('Alexander Pierce');
  });

  it('should compute staff stats correctly', async () => {
    const stats = await service.getStaffStats();
    expect(stats.totalCount).toBe(1);
    expect(stats.totalMonthlyPayroll).toBe(100000);
    expect(stats.pendingCount).toBe(1);
    expect(stats.paidCount).toBe(0);
  });

  it('should get staff by id', async () => {
    const staff = await service.getStaffById('st-1');
    expect(staff.id).toBe('st-1');
  });

  it('should throw NotFoundException if staff not found', async () => {
    await expect(service.getStaffById('nonexistent')).rejects.toThrow(NotFoundException);
  });

  it('should create staff member without login account', async () => {
    const created = await service.createStaff(
      {
        full_name: 'John Doe',
        phone: '+92 300 0000000',
        role: 'cashier',
      },
      mockActor,
    );

    expect(created.full_name).toBe('John Doe');
    expect(created.role).toBe('cashier');
  });

  it('should toggle salary status successfully', async () => {
    const toggled = await service.toggleSalary('st-1');
    expect(toggled.is_salary_paid).toBe(true);
    expect(toggled.salary_paid_date).toBeDefined();
  });

  it('should settle salary successfully', async () => {
    const settled = await service.settleSalary('st-1');
    expect(settled.is_salary_paid).toBe(true);
    expect(settled.salary_paid_date).toBeDefined();
  });

  it('should reject duplicate salary settlement', async () => {
    jest.spyOn(service, 'getStaffById').mockResolvedValue({
      ...mockStaff,
      is_salary_paid: true,
      salary_paid_date: new Date(),
    } as unknown as StaffMemberWithUser);
    jest.spyOn(prisma.payslip, 'findFirst').mockResolvedValue({
      id: 'ps-1',
      staff_id: 'st-1',
      month_year: '10-2026',
      status: 'Paid',
    } as unknown as Payslip);

    await expect(service.settleSalary('st-1')).rejects.toThrow(ConflictException);
  });
});
