import { Test, TestingModule } from '@nestjs/testing';
import { Expense, Prisma } from '@prisma/client';
import { ExpensesController } from './expenses.controller';
import { ExpenseSummary, ExpensesService } from './expenses.service';
import { CreateExpenseDto } from './dto/create-expense.dto';
import { UpdateExpenseDto } from './dto/update-expense.dto';
import { QueryExpenseDto } from './dto/query-expense.dto';
import { PermissionsGuard } from '../common/rbac/guards/permissions.guard';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';

describe('ExpensesController', () => {
  let controller: ExpensesController;
  let service: ExpensesService;

  const mockExpense: Expense = {
    id: 'exp-1',
    title: 'Electricity Utility Bill',
    category: 'utilities',
    amount: new Prisma.Decimal(12500.0),
    date: new Date('2026-09-25T00:00:00Z'),
    recorded_by: 'Store Manager',
  };

  const mockSummary: ExpenseSummary = {
    totalAmount: 12500.0,
    count: 1,
    byCategory: { utilities: 12500.0 },
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [ExpensesController],
      providers: [
        {
          provide: ExpensesService,
          useValue: {
            listExpenses: jest.fn().mockResolvedValue([mockExpense]),
            getExpenseSummary: jest.fn().mockResolvedValue(mockSummary),
            getExpenseById: jest.fn().mockResolvedValue(mockExpense),
            createExpense: jest.fn().mockResolvedValue(mockExpense),
            updateExpense: jest
              .fn()
              .mockResolvedValue({ ...mockExpense, amount: new Prisma.Decimal(13000.0) }),
            deleteExpense: jest.fn().mockResolvedValue({ message: 'Expense deleted successfully' }),
          },
        },
      ],
    })
      .overrideGuard(JwtAuthGuard)
      .useValue({ canActivate: () => true })
      .overrideGuard(PermissionsGuard)
      .useValue({ canActivate: () => true })
      .compile();

    controller = module.get<ExpensesController>(ExpensesController);
    service = module.get<ExpensesService>(ExpensesService);
  });

  it('should be defined', () => {
    expect(controller).toBeDefined();
    expect(service).toBeDefined();
  });

  it('should return list of expenses', async () => {
    const query: QueryExpenseDto = {};
    const response = await controller.listExpenses(query);
    expect(response.success).toBe(true);
    expect(response.data).toHaveLength(1);
    expect(service.listExpenses).toHaveBeenCalledWith(query);
  });

  it('should return expense summary', async () => {
    const query: QueryExpenseDto = {};
    const response = await controller.getExpenseSummary(query);
    expect(response.success).toBe(true);
    expect(response.data?.totalAmount).toBe(12500.0);
    expect(service.getExpenseSummary).toHaveBeenCalledWith(query);
  });

  it('should return expense by id', async () => {
    const response = await controller.getExpenseById('exp-1');
    expect(response.success).toBe(true);
    expect(response.data?.id).toBe('exp-1');
    expect(service.getExpenseById).toHaveBeenCalledWith('exp-1');
  });

  it('should create expense', async () => {
    const createDto: CreateExpenseDto = {
      title: 'Electricity Utility Bill',
      category: 'utilities',
      amount: 12500.0,
    };
    const mockUser = { username: 'manager1' };

    const response = await controller.createExpense(createDto, mockUser);
    expect(response.success).toBe(true);
    expect(response.data?.title).toBe('Electricity Utility Bill');
    expect(service.createExpense).toHaveBeenCalledWith(createDto, mockUser);
  });

  it('should update expense', async () => {
    const updateDto: UpdateExpenseDto = {
      amount: 13000.0,
    };

    const response = await controller.updateExpense('exp-1', updateDto);
    expect(response.success).toBe(true);
    expect(response.data?.amount).toEqual(new Prisma.Decimal(13000.0));
    expect(service.updateExpense).toHaveBeenCalledWith('exp-1', updateDto);
  });

  it('should delete expense', async () => {
    const response = await controller.deleteExpense('exp-1');
    expect(response.success).toBe(true);
    expect(response.message).toBe('Expense deleted successfully');
    expect(service.deleteExpense).toHaveBeenCalledWith('exp-1');
  });
});
