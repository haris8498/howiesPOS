import { RealtimeGateway } from '../realtime/realtime.gateway';
import { Injectable, NotFoundException, Optional } from '@nestjs/common';
import { Expense, Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { CreateExpenseDto } from './dto/create-expense.dto';
import { UpdateExpenseDto } from './dto/update-expense.dto';
import { QueryExpenseDto } from './dto/query-expense.dto';

export interface ExpenseSummary {
  totalAmount: number;
  count: number;
  byCategory: Record<string, number>;
}

@Injectable()
export class ExpensesService {
  constructor(
    private readonly prisma: PrismaService,
    @Optional() private readonly realtimeGateway?: RealtimeGateway,
  ) {}

  async listExpenses(query?: QueryExpenseDto): Promise<Expense[]> {
    const where = this.buildWhereClause(query);

    return this.prisma.expense.findMany({
      where,
      orderBy: [{ date: 'desc' }, { id: 'desc' }],
    });
  }

  async getExpenseSummary(query?: QueryExpenseDto): Promise<ExpenseSummary> {
    const where = this.buildWhereClause(query);

    const expenses = await this.prisma.expense.findMany({
      where,
    });

    let totalAmount = 0;
    const byCategory: Record<string, number> = {};

    for (const exp of expenses) {
      const amt = Number(exp.amount);
      totalAmount += amt;
      const cat = exp.category || 'miscellaneous';
      byCategory[cat] = (byCategory[cat] || 0) + amt;
    }

    return {
      totalAmount,
      count: expenses.length,
      byCategory,
    };
  }

  async getExpenseById(id: string): Promise<Expense> {
    const expense = await this.prisma.expense.findUnique({
      where: { id },
    });

    if (!expense) {
      throw new NotFoundException(`Expense record with ID '${id}' not found`);
    }

    return expense;
  }

  async createExpense(
    dto: CreateExpenseDto,
    currentUser?: { username?: string; name?: string },
  ): Promise<Expense> {
    const recordedBy =
      dto.recorded_by?.trim() || currentUser?.username || currentUser?.name || 'Store Manager';

    const expenseDate = dto.date ? new Date(dto.date) : new Date();
    const safeAmount = Number(dto.amount) || 0;

    return this.prisma.expense.create({
      data: {
        title: dto.title.trim(),
        category: dto.category.trim(),
        amount: new Prisma.Decimal(safeAmount.toFixed(2)),
        date: expenseDate,
        recorded_by: recordedBy,
      },
    });
  }

  async updateExpense(id: string, dto: UpdateExpenseDto): Promise<Expense> {
    const expense = await this.prisma.expense.findUnique({
      where: { id },
    });

    if (!expense) {
      throw new NotFoundException(`Expense record with ID '${id}' not found`);
    }

    const data: Prisma.ExpenseUpdateInput = {};

    if (dto.title !== undefined) data.title = dto.title.trim();
    if (dto.category !== undefined) data.category = dto.category.trim();
    if (dto.amount !== undefined) {
      const safeAmount = Number(dto.amount) || 0;
      data.amount = new Prisma.Decimal(safeAmount.toFixed(2));
    }
    if (dto.date !== undefined) data.date = new Date(dto.date);
    if (dto.recorded_by !== undefined) data.recorded_by = dto.recorded_by.trim();

    return this.prisma.expense.update({
      where: { id },
      data,
    });
  }

  async deleteExpense(id: string): Promise<{ message: string }> {
    const expense = await this.prisma.expense.findUnique({
      where: { id },
    });

    if (!expense) {
      throw new NotFoundException(`Expense record with ID '${id}' not found`);
    }

    await this.prisma.expense.delete({
      where: { id },
    });

    return {
      message: `Expense '${expense.title}' deleted successfully`,
    };
  }

  private buildWhereClause(query?: QueryExpenseDto): Prisma.ExpenseWhereInput {
    const where: Prisma.ExpenseWhereInput = {};

    if (!query) return where;

    if (query.category && query.category !== 'ALL' && query.category !== 'All') {
      where.category = {
        equals: query.category,
        mode: 'insensitive',
      };
    }

    if (query.date) {
      const targetDate = new Date(query.date);
      const startOfDay = new Date(targetDate.setHours(0, 0, 0, 0));
      const endOfDay = new Date(targetDate.setHours(23, 59, 59, 999));
      where.date = {
        gte: startOfDay,
        lte: endOfDay,
      };
    } else if (query.from_date || query.to_date) {
      where.date = {};
      if (query.from_date) {
        where.date.gte = new Date(query.from_date);
      }
      if (query.to_date) {
        where.date.lte = new Date(query.to_date);
      }
    }

    if (query.search) {
      const search = query.search.trim();
      where.OR = [
        { title: { contains: search, mode: 'insensitive' } },
        { category: { contains: search, mode: 'insensitive' } },
        { recorded_by: { contains: search, mode: 'insensitive' } },
      ];
    }

    return where;
  }
}
