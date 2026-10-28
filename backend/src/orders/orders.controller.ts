import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Patch,
  Post,
  Put,
  Query,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { OrdersService, OrderWithDetails } from './orders.service';
import { CreateOrderDto } from './dto/create-order.dto';
import { UpdateOrderDto } from './dto/update-order.dto';
import { UpdateOrderStatusDto } from './dto/update-order-status.dto';
import { QueryOrderDto } from './dto/query-order.dto';
import { AppendOrderItemsDto } from './dto/append-order-items.dto';
import { VoidOrderItemDto } from './dto/void-order-item.dto';
import { RefundOrderDto } from './dto/refund-order.dto';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { AuthenticatedUser } from '../auth/interfaces/jwt-payload.interface';
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

  /**
   * Whole-order update (PUT /orders/:id and PATCH /orders/:id).
   * Reimplemented with append-only ledger diff semantics (SYNC-032 / D-05).
   * Items absent from payload are NOT removed unless explicit fullReplace: true.
   */
  @Put(':id')
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

  /**
   * Append batch of items to an existing order (POST /orders/:id/items).
   * Ledger semantics: Items are appended with client UUID v7 IDs.
   */
  @Post(':id/items')
  @UseInterceptors(IdempotencyInterceptor)
  async appendOrderItems(
    @Param('id') id: string,
    @Body() body: AppendOrderItemsDto,
  ): Promise<ApiResponse<OrderWithDetails>> {
    const items = body?.items || [];
    const deviceId = body?.device_id;
    const data = await this.ordersService.appendOrderItems(id, items, deviceId);
    return {
      success: true,
      message: 'Order items appended successfully',
      data,
    };
  }

  /**
   * Void a specific item from an order (POST /orders/:id/items/:itemId/void).
   * Ledger semantics: Item is marked voided; never deleted.
   */
  @Post(':id/items/:itemId/void')
  @UseInterceptors(IdempotencyInterceptor)
  async voidOrderItem(
    @Param('id') id: string,
    @Param('itemId') itemId: string,
    @Body() dto?: VoidOrderItemDto,
  ): Promise<ApiResponse<OrderWithDetails>> {
    const data = await this.ordersService.voidOrderItem(
      id,
      itemId,
      dto?.voided_by || dto?.voidedBy,
      dto?.reason || dto?.cancel_reason,
    );
    return {
      success: true,
      message: 'Order item voided successfully',
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

  /**
   * Refund a paid order (POST /api/orders/:id/refund).
   * Supervisor PIN authorized full-order refund writing to order_adjustments ledger.
   */
  @Post(':id/refund')
  @HttpCode(HttpStatus.CREATED)
  async refundOrder(
    @Param('id') id: string,
    @Body() dto: RefundOrderDto,
    @CurrentUser() user?: AuthenticatedUser,
  ): Promise<{ adjustment_id: string; order: OrderWithDetails }> {
    return this.ordersService.refundOrder(id, dto, user);
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
