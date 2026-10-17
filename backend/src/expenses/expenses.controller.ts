import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { Expense } from '@prisma/client';
import { ExpenseSummary, ExpensesService } from './expenses.service';
import { CreateExpenseDto } from './dto/create-expense.dto';
import { UpdateExpenseDto } from './dto/update-expense.dto';
import { QueryExpenseDto } from './dto/query-expense.dto';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { PermissionsGuard } from '../common/rbac/guards/permissions.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { ApiResponse } from '../common/types/api-response.type';

@Controller('expenses')
@UseGuards(JwtAuthGuard, PermissionsGuard)
export class ExpensesController {
  constructor(private readonly expensesService: ExpensesService) {}

  @Get()
  async listExpenses(@Query() query: QueryExpenseDto): Promise<ApiResponse<Expense[]>> {
    const data = await this.expensesService.listExpenses(query);
    return {
      success: true,
      data,
    };
  }

  @Get('summary')
  async getExpenseSummary(@Query() query: QueryExpenseDto): Promise<ApiResponse<ExpenseSummary>> {
    const data = await this.expensesService.getExpenseSummary(query);
    return {
      success: true,
      data,
    };
  }

  @Get(':id')
  async getExpenseById(@Param('id') id: string): Promise<ApiResponse<Expense>> {
    const data = await this.expensesService.getExpenseById(id);
    return {
      success: true,
      data,
    };
  }

  @Post()
  async createExpense(
    @Body() dto: CreateExpenseDto,
    @CurrentUser() user: { username?: string; name?: string },
  ): Promise<ApiResponse<Expense>> {
    const data = await this.expensesService.createExpense(dto, user);
    return {
      success: true,
      message: `Expense record '${data.title}' logged successfully`,
      data,
    };
  }

  @Patch(':id')
  async updateExpense(
    @Param('id') id: string,
    @Body() dto: UpdateExpenseDto,
  ): Promise<ApiResponse<Expense>> {
    const data = await this.expensesService.updateExpense(id, dto);
    return {
      success: true,
      message: `Expense record '${data.title}' updated successfully`,
      data,
    };
  }

  @Delete(':id')
  async deleteExpense(@Param('id') id: string): Promise<ApiResponse<{ message: string }>> {
    const data = await this.expensesService.deleteExpense(id);
    return {
      success: true,
      message: data.message,
    };
  }
}
