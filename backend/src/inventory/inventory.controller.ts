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
import { InventoryItem, StockMovement } from '@prisma/client';
import { InventoryItemWithMovements, InventoryService } from './inventory.service';
import { CreateInventoryItemDto } from './dto/create-inventory-item.dto';
import { UpdateInventoryItemDto } from './dto/update-inventory-item.dto';
import { QueryInventoryDto } from './dto/query-inventory.dto';
import {
  CreateStockInDto,
  CreateStockOutDto,
  QueryStockMovementDto,
} from './dto/stock-movement.dto';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { PermissionsGuard } from '../common/rbac/guards/permissions.guard';
import { ApiResponse } from '../common/types/api-response.type';

@Controller('inventory')
@UseGuards(JwtAuthGuard, PermissionsGuard)
export class InventoryController {
  constructor(private readonly inventoryService: InventoryService) {}

  @Get('items')
  async listItems(@Query() query: QueryInventoryDto): Promise<ApiResponse<InventoryItem[]>> {
    const data = await this.inventoryService.listItems(query);
    return {
      success: true,
      data,
    };
  }

  @Get('items/low-stock')
  async getLowStockItems(): Promise<ApiResponse<InventoryItem[]>> {
    const data = await this.inventoryService.getLowStockItems();
    return {
      success: true,
      data,
    };
  }

  @Get('items/:id')
  async getItemById(@Param('id') id: string): Promise<ApiResponse<InventoryItemWithMovements>> {
    const data = await this.inventoryService.getItemById(id);
    return {
      success: true,
      data,
    };
  }

  @Post('items')
  async createItem(@Body() dto: CreateInventoryItemDto): Promise<ApiResponse<InventoryItem>> {
    const data = await this.inventoryService.createItem(dto);
    return {
      success: true,
      message: `Inventory item '${data.name}' created successfully`,
      data,
    };
  }

  @Patch('items/:id')
  async updateItem(
    @Param('id') id: string,
    @Body() dto: UpdateInventoryItemDto,
  ): Promise<ApiResponse<InventoryItem>> {
    const data = await this.inventoryService.updateItem(id, dto);
    return {
      success: true,
      message: `Inventory item '${data.name}' updated successfully`,
      data,
    };
  }

  @Delete('items/:id')
  async deleteItem(@Param('id') id: string): Promise<ApiResponse<{ message: string }>> {
    const data = await this.inventoryService.deleteItem(id);
    return {
      success: true,
      message: data.message,
    };
  }

  @Post('stock-in')
  async stockIn(
    @Body() dto: CreateStockInDto,
  ): Promise<ApiResponse<{ item: InventoryItem; movement: StockMovement }>> {
    const data = await this.inventoryService.stockIn(dto);
    return {
      success: true,
      message: `Successfully added ${dto.quantity} ${data.item.unit} to '${data.item.name}' stock`,
      data,
    };
  }

  @Post('stock-out')
  async stockOut(
    @Body() dto: CreateStockOutDto,
  ): Promise<ApiResponse<{ item: InventoryItem; movement: StockMovement }>> {
    const data = await this.inventoryService.stockOut(dto);
    return {
      success: true,
      message: `Successfully deducted ${dto.quantity} ${data.item.unit} from '${data.item.name}' stock`,
      data,
    };
  }

  @Get('movements')
  async listMovements(
    @Query() query: QueryStockMovementDto,
  ): Promise<ApiResponse<StockMovement[]>> {
    const data = await this.inventoryService.listMovements(query);
    return {
      success: true,
      data,
    };
  }

  @Get('items/:id/movements')
  async getMovementsByItemId(@Param('id') id: string): Promise<ApiResponse<StockMovement[]>> {
    const data = await this.inventoryService.getMovementsByItemId(id);
    return {
      success: true,
      data,
    };
  }
}
