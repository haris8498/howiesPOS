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
import { ItemsService, FullMenuItem } from './items.service';
import { CreateMenuItemDto, UpdateAvailabilityDto, UpdateMenuItemDto } from '../dto/menu-item.dto';
import { QueryMenuItemDto } from '../dto/query-menu.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { PermissionsGuard } from '../../common/rbac/guards/permissions.guard';
import { RequirePermission } from '../../common/rbac/decorators/permissions.decorator';
import { ApiResponse } from '../../common/types/api-response.type';

@Controller('menu/items')
@UseGuards(JwtAuthGuard, PermissionsGuard)
export class ItemsController {
  constructor(private readonly itemsService: ItemsService) {}

  @Get()
  async listItems(@Query() query: QueryMenuItemDto): Promise<ApiResponse<FullMenuItem[]>> {
    const data = await this.itemsService.listItems(query);
    return {
      success: true,
      data,
    };
  }

  @Get(':id')
  async getItemById(@Param('id') id: string): Promise<ApiResponse<FullMenuItem>> {
    const data = await this.itemsService.getItemById(id);
    return {
      success: true,
      data,
    };
  }

  @Post()
  @RequirePermission('Menu Catalog', 'Add & Edit Menu Items & Prices')
  async createItem(@Body() dto: CreateMenuItemDto): Promise<ApiResponse<FullMenuItem>> {
    const data = await this.itemsService.createItem(dto);
    return {
      success: true,
      message: 'Menu item created successfully',
      data,
    };
  }

  @Patch(':id')
  @RequirePermission('Menu Catalog', 'Add & Edit Menu Items & Prices')
  async updateItem(
    @Param('id') id: string,
    @Body() dto: UpdateMenuItemDto,
  ): Promise<ApiResponse<FullMenuItem>> {
    const data = await this.itemsService.updateItem(id, dto);
    return {
      success: true,
      message: 'Menu item updated successfully',
      data,
    };
  }

  @Patch(':id/availability')
  @RequirePermission('Menu Catalog', 'Add & Edit Menu Items & Prices')
  async updateAvailability(
    @Param('id') id: string,
    @Body() dto: UpdateAvailabilityDto,
  ): Promise<ApiResponse<FullMenuItem>> {
    const data = await this.itemsService.updateAvailability(id, dto);
    return {
      success: true,
      message: 'Menu item availability updated',
      data,
    };
  }

  @Delete(':id')
  @RequirePermission('Menu Catalog', 'Delete Menu Items')
  async deleteItem(@Param('id') id: string): Promise<ApiResponse<{ message: string }>> {
    const data = await this.itemsService.deleteItem(id);
    return {
      success: true,
      message: data.message,
    };
  }
}
