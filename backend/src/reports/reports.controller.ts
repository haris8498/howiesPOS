import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { PermissionsGuard } from '../common/rbac/guards/permissions.guard';
import { QueryReportDto } from './dto/query-report.dto';
import { ReportsService } from './reports.service';

@Controller('reports')
@UseGuards(JwtAuthGuard, PermissionsGuard)
export class ReportsController {
  constructor(private readonly reportsService: ReportsService) {}

  @Get('summary')
  async getSummary(@Query() query: QueryReportDto) {
    const data = await this.reportsService.getSummary(query);
    return {
      success: true,
      data,
    };
  }

  @Get('products')
  async getProductPerformance(@Query() query: QueryReportDto) {
    const data = await this.reportsService.getProductPerformance(query);
    return {
      success: true,
      data,
      count: data.length,
    };
  }

  @Get('order-types')
  async getOrderTypeStats(@Query() query: QueryReportDto) {
    const data = await this.reportsService.getOrderTypeStats(query);
    return {
      success: true,
      data,
      count: data.length,
    };
  }

  @Get('daily-sales')
  async getDailySalesTrend(@Query() query: QueryReportDto) {
    const data = await this.reportsService.getDailySalesTrend(query);
    return {
      success: true,
      data,
      count: data.length,
    };
  }

  @Get('cancelled-orders')
  async getCancelledOrders(@Query() query: QueryReportDto) {
    const data = await this.reportsService.getCancelledOrders(query);
    return {
      success: true,
      data,
      count: data.length,
    };
  }
}
