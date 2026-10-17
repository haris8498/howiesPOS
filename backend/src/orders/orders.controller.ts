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
  UseInterceptors,
} from '@nestjs/common';
import { OrdersService, OrderWithDetails } from './orders.service';
import { CreateOrderDto } from './dto/create-order.dto';
import { UpdateOrderDto } from './dto/update-order.dto';
import { UpdateOrderStatusDto } from './dto/update-order-status.dto';
import { QueryOrderDto } from './dto/query-order.dto';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { PermissionsGuard } from '../common/rbac/guards/permissions.guard';
import { ApiResponse } from '../common/types/api-response.type';
import { IdempotencyInterceptor } from '../sync/interceptors/idempotency.interceptor';

@Controller('orders')
@UseGuards(JwtAuthGuard, PermissionsGuard)
export class OrdersController {
  constructor(private readonly ordersService: OrdersService) {}

  @Get()
  async listOrders(@Query() query: QueryOrderDto): Promise<ApiResponse<OrderWithDetails[]>> {
    const data = await this.ordersService.listOrders(query);
    return {
      success: true,
      data,
    };
  }

  @Get(':id')
  async getOrderById(@Param('id') id: string): Promise<ApiResponse<OrderWithDetails>> {
    const data = await this.ordersService.getOrderById(id);
    return {
      success: true,
      data,
    };
  }

  @Post()
  @UseInterceptors(IdempotencyInterceptor)
  async createOrder(@Body() dto: CreateOrderDto): Promise<ApiResponse<OrderWithDetails>> {
    const data = await this.ordersService.createOrder(dto);
    return {
      success: true,
      message: 'Order created successfully',
      data,
    };
  }

  @Patch(':id')
  @UseInterceptors(IdempotencyInterceptor)
  async updateOrder(
    @Param('id') id: string,
    @Body() dto: UpdateOrderDto,
  ): Promise<ApiResponse<OrderWithDetails>> {
    const data = await this.ordersService.updateOrder(id, dto);
    return {
      success: true,
      message: 'Order updated successfully',
      data,
    };
  }

  @Patch(':id/status')
  async updateOrderStatus(
    @Param('id') id: string,
    @Body() dto: UpdateOrderStatusDto,
  ): Promise<ApiResponse<OrderWithDetails>> {
    const data = await this.ordersService.updateOrderStatus(id, dto);
    return {
      success: true,
      message: `Order status updated to '${dto.status}'`,
      data,
    };
  }

  @Post(':id/cancel-item')
  async cancelOrderItem(
    @Param('id') id: string,
    @Body() dto: { item_id: string; reason?: string; cancelled_by?: string },
  ): Promise<ApiResponse<OrderWithDetails>> {
    const data = await this.ordersService.cancelOrderItem(id, dto);
    return {
      success: true,
      message: 'Order item cancelled successfully',
      data,
    };
  }

  @Delete(':id')
  async deleteOrder(@Param('id') id: string): Promise<ApiResponse<{ message: string }>> {
    const data = await this.ordersService.deleteOrder(id);
    return {
      success: true,
      message: data.message,
    };
  }
}
