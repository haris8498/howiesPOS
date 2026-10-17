import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { DailyCalculationService } from './daily-calculation.service';
import { SubmitDailyCalculationDto } from './dto/submit-daily-calculation.dto';
import { StartSessionDto } from './dto/start-session.dto';
import { QueryDailyCalculationDto } from './dto/query-daily-calculation.dto';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { PermissionsGuard } from '../common/rbac/guards/permissions.guard';
import { RequirePermission } from '../common/rbac/decorators/permissions.decorator';

@Controller(['daily-calculations', 'daily-calculation'])
@UseGuards(JwtAuthGuard, PermissionsGuard)
@RequirePermission('Daily Calculation', 'Allow Access to Daily Calculation')

export class DailyCalculationController {
  constructor(private readonly dailyCalculationService: DailyCalculationService) {}

  @Get('active-session')
  async getActiveSession(@Query('cashier_id') cashierId?: string, @CurrentUser() user?: any) {
    const effectiveCashierId = cashierId || (user ? user.userId || user.id : undefined);
    const data = await this.dailyCalculationService.getActiveSession(effectiveCashierId);
    return {
      success: true,
      data,
    };
  }

  @Post('active-session/expense')
  async addActiveExpense(
    @Body() dto: { item_name: string; category?: string; amount: number; receipt_number?: string; notes?: string; cashier_id?: string },
    @CurrentUser() user?: any,
  ) {
    const effectiveCashierId = dto.cashier_id || (user ? user.userId || user.id : undefined);
    const data = await this.dailyCalculationService.addExpenseItemToActiveSession({
      ...dto,
      cashier_id: effectiveCashierId,
    });
    return {
      success: true,
      data,
      message: 'Shift expense recorded to active session database',
    };
  }

  @Delete('active-session/expense/:id')
  async deleteActiveExpense(@Param('id') id: string) {
    await this.dailyCalculationService.deleteExpenseItemFromActiveSession(id);
    return {
      success: true,
      message: 'Shift expense removed from database',
    };
  }

  @Post('start-session')
  async startSession(@Body() dto: StartSessionDto, @CurrentUser() user?: any) {
    const cashierInfo = user ? { id: user.userId || user.id, username: user.username } : undefined;
    const data = await this.dailyCalculationService.startSession(dto, cashierInfo);
    return {
      success: true,
      data,
      message: 'Starting cash registered and session activated successfully',
    };
  }

  @Get('live-summary')
  async getLiveSummary(@Query('date') date?: string, @Query('cashier_id') cashierId?: string, @CurrentUser() user?: any) {
    const effectiveCashierId = cashierId || (user ? user.userId || user.id : undefined);
    const data = await this.dailyCalculationService.getLiveSummary(date, effectiveCashierId);
    return {
      success: true,
      data,
    };
  }

  @Post('submit')
  async submitDailyCalculation(
    @Body() dto: SubmitDailyCalculationDto,
    @CurrentUser() user: any,
  ) {
    const cashierInfo = user ? { id: user.userId || user.id, username: user.username } : undefined;
    const data = await this.dailyCalculationService.submitDailyCalculation(dto, cashierInfo);
    return {
      success: true,
      data,
      message: 'Day calculation submitted and store tables reset successfully',
    };
  }

  @Get()
  async getHistory(@Query() query: QueryDailyCalculationDto) {
    const data = await this.dailyCalculationService.getHistory(query);
    return {
      success: true,
      data,
    };
  }

  @Get(':id')
  async getById(@Param('id') id: string) {
    const data = await this.dailyCalculationService.getById(id);
    return {
      success: true,
      data,
    };
  }
}
