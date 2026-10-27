import {
  Controller,
  Get,
  Query,
  UseGuards,
  ParseIntPipe,
  DefaultValuePipe,
} from '@nestjs/common';
import { PricingService } from './pricing.service';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { PermissionsGuard } from '../common/rbac/guards/permissions.guard';
import { RequirePermission } from '../common/rbac/decorators/permissions.decorator';
import { ApiResponse } from '../common/types/api-response.type';

@Controller('pricing')
@UseGuards(JwtAuthGuard, PermissionsGuard)
export class PricingController {
  constructor(private readonly pricingService: PricingService) {}

  /**
   * Surface price discrepancies, mismatches, and line overrides in an admin review list.
   * Read-only & immutable (Task 2 & Task 6).
   */
  @Get('audits')
  @RequirePermission('orders', 'view')
  async getPricingAudits(
    @Query('order_id') orderId?: string,
    @Query('pricing_status') pricingStatus?: string,
    @Query('source') source?: string,
    @Query('take', new DefaultValuePipe(50), ParseIntPipe) take = 50,
    @Query('skip', new DefaultValuePipe(0), ParseIntPipe) skip = 0,
  ): Promise<ApiResponse<any>> {
    const data = await this.pricingService.getPricingAudits({
      order_id: orderId,
      pricing_status: pricingStatus,
      source,
      take,
      skip,
    });
    return {
      success: true,
      data,
    };
  }

  /**
   * Surface manager-approved discounts log for auditing.
   * Read-only & immutable (Task 6).
   */
  @Get('discounts')
  @RequirePermission('orders', 'view')
  async getDiscountAudits(
    @Query('order_id') orderId?: string,
    @Query('take', new DefaultValuePipe(50), ParseIntPipe) take = 50,
    @Query('skip', new DefaultValuePipe(0), ParseIntPipe) skip = 0,
  ): Promise<ApiResponse<any>> {
    const data = await this.pricingService.getDiscountAudits(orderId, take, skip);
    return {
      success: true,
      data,
    };
  }
}
