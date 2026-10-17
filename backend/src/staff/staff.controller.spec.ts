import { Test, TestingModule } from '@nestjs/testing';
import { Prisma } from '@prisma/client';
import { StaffController } from './staff.controller';
import { StaffService, StaffMemberWithUser } from './staff.service';
import { PermissionsService } from '../permissions/permissions.service';

describe('StaffController', () => {
  let controller: StaffController;

  const mockStaffMember: StaffMemberWithUser = {
    id: 'st-1',
    user_id: 'u-1',
    full_name: 'Alexander Pierce',
    phone: '+92 300 1234567',
    role: 'owner',
    status: 'Active',
    joining_date: new Date('2023-01-01'),
    leaving_date: null,
    assigned_shift: 'Full Day Executive Shift',
    monthly_salary: new Prisma.Decimal(100000.0),
    hourly_rate: new Prisma.Decimal(500.0),
    is_salary_paid: false,
    salary_paid_date: null,
  };

  const mockActor = {
    id: 'admin-id',
    username: 'superadmin',
    role: 'owner',
    is_default: true,
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [StaffController],
      providers: [
        {
          provide: StaffService,
          useValue: {
            listStaff: jest.fn().mockResolvedValue([mockStaffMember]),
            getStaffStats: jest.fn().mockResolvedValue({
              totalCount: 1,
              totalMonthlyPayroll: 100000,
              paidCount: 0,
              paidPayroll: 0,
              pendingCount: 1,
              pendingPayroll: 100000,
            }),
            getStaffById: jest.fn().mockResolvedValue(mockStaffMember),
            createStaff: jest.fn().mockResolvedValue(mockStaffMember),
            updateStaff: jest.fn().mockResolvedValue(mockStaffMember),
            deleteStaff: jest
              .fn()
              .mockResolvedValue({ message: 'Staff member deleted successfully' }),
            settleSalary: jest.fn().mockResolvedValue({ ...mockStaffMember, is_salary_paid: true }),
            toggleSalary: jest.fn().mockResolvedValue({ ...mockStaffMember, is_salary_paid: true }),
          },
        },
        {
          provide: PermissionsService,
          useValue: {
            hasPermission: jest.fn().mockResolvedValue(true),
          },
        },
      ],
    }).compile();

    controller = module.get<StaffController>(StaffController);
  });

  it('should be defined', () => {
    expect(controller).toBeDefined();
  });

  it('GET /staff should return staff members list', async () => {
    const response = await controller.listStaff({});
    expect(response.success).toBe(true);
    expect(response.data).toHaveLength(1);
    expect(response.data?.[0].full_name).toBe('Alexander Pierce');
  });

  it('GET /staff/stats should return summary stats', async () => {
    const response = await controller.getStaffStats();
    expect(response.success).toBe(true);
    expect(response.data?.totalCount).toBe(1);
    expect(response.data?.totalMonthlyPayroll).toBe(100000);
  });

  it('POST /staff should create staff member', async () => {
    const response = await controller.createStaff(
      {
        full_name: 'Alexander Pierce',
        phone: '+92 300 1234567',
        role: 'owner',
      },
      mockActor,
    );

    expect(response.success).toBe(true);
    expect(response.message).toContain('created successfully');
  });

  it('POST /staff/:id/toggle-salary should toggle staff salary paid status', async () => {
    const response = await controller.toggleSalary('st-1');
    expect(response.success).toBe(true);
    expect(response.data?.is_salary_paid).toBe(true);
  });

  it('POST /staff/:id/salary-settle should settle salary', async () => {
    const response = await controller.settleSalary('st-1');
    expect(response.success).toBe(true);
    expect(response.data?.is_salary_paid).toBe(true);
  });
});

