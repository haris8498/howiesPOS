import { NotFoundException } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { Expense, Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { ExpensesService } from './expenses.service';

describe('ExpensesService', () => {
  let service: ExpensesService;

  const mockExpense1: Expense = {
    id: 'exp-1',
    title: 'Electricity Utility Bill',
    category: 'utilities',
    amount: new Prisma.Decimal(12500.0),
    date: new Date('2026-09-25T00:00:00Z'),
    recorded_by: 'Store Manager',
  };

  const mockExpense2: Expense = {
    id: 'exp-2',
    title: 'Flyer Distribution Campaign',
    category: 'marketing',
    amount: new Prisma.Decimal(3500.0),
    date: new Date('2026-09-26T00:00:00Z'),
    recorded_by: 'Store Manager',
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        ExpensesService,
        {
          provide: PrismaService,
          useValue: {
            expense: {
              findMany: jest.fn().mockImplementation(({ where }) => {
                if (where?.category?.equals === 'utilities') {
                  return Promise.resolve([mockExpense1]);
                }
                return Promise.resolve([mockExpense1, mockExpense2]);
              }),
              findUnique: jest.fn().mockImplementation(({ where }) => {
                if (where.id === 'exp-1') return Promise.resolve(mockExpense1);
                if (where.id === 'exp-2') return Promise.resolve(mockExpense2);
                return Promise.resolve(null);
              }),
              create: jest.fn().mockImplementation(({ data }) =>
                Promise.resolve({
                  id: 'exp-new',
                  ...data,
                }),
              ),
              update: jest.fn().mockImplementation(({ where, data }) =>
                Promise.resolve({
                  ...(where.id === 'exp-2' ? mockExpense2 : mockExpense1),
                  ...data,
                }),
              ),
              delete: jest.fn().mockResolvedValue(mockExpense1),
            },
          },
        },
      ],
    }).compile();

    service = module.get<ExpensesService>(ExpensesService);
  });

  it('should list all expenses', async () => {
    const expenses = await service.listExpenses();
    expect(expenses).toHaveLength(2);
    expect(expenses[0].title).toBe('Electricity Utility Bill');
  });

  it('should filter expenses by category', async () => {
    const expenses = await service.listExpenses({ category: 'utilities' });
    expect(expenses).toHaveLength(1);
    expect(expenses[0].category).toBe('utilities');
  });

  it('should calculate expense summary aggregation', async () => {
    const summary = await service.getExpenseSummary();
    expect(summary.count).toBe(2);
    expect(summary.totalAmount).toBe(16000.0);
    expect(summary.byCategory['utilities']).toBe(12500.0);
    expect(summary.byCategory['marketing']).toBe(3500.0);
  });

  it('should get expense by id', async () => {
    const expense = await service.getExpenseById('exp-1');
    expect(expense.id).toBe('exp-1');
    expect(expense.title).toBe('Electricity Utility Bill');
  });

  it('should throw NotFoundException for unknown expense id', async () => {
    await expect(service.getExpenseById('unknown')).rejects.toThrow(NotFoundException);
  });

  it('should create new expense record', async () => {
    const created = await service.createExpense(
      {
        title: 'Generator Fuel',
        category: 'utilities',
        amount: 5000.0,
      },
      { username: 'manager1' },
    );
    expect(created.title).toBe('Generator Fuel');
    expect(created.amount).toEqual(new Prisma.Decimal(5000.0));
  });

  it('should update expense details', async () => {
    const updated = await service.updateExpense('exp-1', {
      amount: 13000.0,
    });
    expect(updated.amount).toEqual(new Prisma.Decimal(13000.0));
  });

  it('should delete expense record', async () => {
    const result = await service.deleteExpense('exp-1');
    expect(result.message).toContain('deleted successfully');
  });
});
