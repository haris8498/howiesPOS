import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Patch,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { PermissionsGuard } from '../common/rbac/guards/permissions.guard';
import { KitchenService } from './kitchen.service';
import { UpdateKitchenStatusDto } from './dto/update-kitchen-status.dto';
import { UpdateCookingTimeDto } from './dto/update-cooking-time.dto';
import { QueryKitchenDto } from './dto/query-kitchen.dto';

@Controller('kitchen')
@UseGuards(JwtAuthGuard, PermissionsGuard)
export class KitchenController {
  constructor(private readonly kitchenService: KitchenService) {}

  @Get('orders')
  async getKitchenOrders(@Query() query: QueryKitchenDto) {
    const orders = await this.kitchenService.getKitchenOrders(query);
    return {
      success: true,
      data: orders,
      count: orders.length,
    };
  }

  @Get('orders/:id')
  async getKitchenOrderById(@Param('id') id: string) {
    const order = await this.kitchenService.getKitchenOrderById(id);
    return {
      success: true,
      data: order,
    };
  }

  @Patch('orders/:id/status')
  async updateStatus(@Param('id') id: string, @Body() dto: UpdateKitchenStatusDto) {
    const updated = await this.kitchenService.updateStatus(id, dto);
    return {
      success: true,
      message: `Kitchen order status updated to '${dto.status}'`,
      data: updated,
    };
  }

  @Patch('orders/:id/cooking')
  async updateCookingTime(@Param('id') id: string, @Body() dto: UpdateCookingTimeDto) {
    const updated = await this.kitchenService.updateCookingTime(id, dto);
    return {
      success: true,
      message: `Kitchen order cooking timer set to ${dto.cooking_time_minutes} minutes`,
      data: updated,
    };
  }

  @Post('orders/:id/send-ticket')
  @HttpCode(HttpStatus.OK)
  async sendKitchenTicket(@Param('id') id: string) {
    const updated = await this.kitchenService.sendKitchenTicket(id);
    return {
      success: true,
      message: 'Kitchen ticket sent / KOT printed successfully',
      data: updated,
    };
  }
}
