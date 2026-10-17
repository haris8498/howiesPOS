import { Body, Controller, Delete, Get, Param, Patch, Post, UseGuards } from '@nestjs/common';
import { MenuItemSize } from '@prisma/client';
import { SizesService } from './sizes.service';
import { CreateSizeDto, UpdateSizeDto } from '../dto/size.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { PermissionsGuard } from '../../common/rbac/guards/permissions.guard';
import { RequirePermission } from '../../common/rbac/decorators/permissions.decorator';
import { ApiResponse } from '../../common/types/api-response.type';

@Controller('menu')
@UseGuards(JwtAuthGuard, PermissionsGuard)
export class SizesController {
  constructor(private readonly sizesService: SizesService) {}

  @Get('items/:itemId/sizes')
  @RequirePermission('Menu Catalog', 'Allow Access to Menu Catalog Module')
  async listSizesByItem(@Param('itemId') itemId: string): Promise<ApiResponse<MenuItemSize[]>> {
    const data = await this.sizesService.listSizesByItem(itemId);
    return {
      success: true,
      data,
    };
  }

  @Post('items/:itemId/sizes')
  @RequirePermission('Menu Catalog', 'Add & Edit Menu Items & Prices')
  async createSize(
    @Param('itemId') itemId: string,
    @Body() dto: CreateSizeDto,
  ): Promise<ApiResponse<MenuItemSize>> {
    const data = await this.sizesService.createSize(itemId, dto);
    return {
      success: true,
      message: 'Menu item size added successfully',
      data,
    };
  }

  @Patch('sizes/:id')
  @RequirePermission('Menu Catalog', 'Add & Edit Menu Items & Prices')
  async updateSize(
    @Param('id') id: string,
    @Body() dto: UpdateSizeDto,
  ): Promise<ApiResponse<MenuItemSize>> {
    const data = await this.sizesService.updateSize(id, dto);
    return {
      success: true,
      message: 'Menu item size updated successfully',
      data,
    };
  }

  @Delete('sizes/:id')
  @RequirePermission('Menu Catalog', 'Delete Menu Items')
  async deleteSize(@Param('id') id: string): Promise<ApiResponse<{ message: string }>> {
    const data = await this.sizesService.deleteSize(id);
    return {
      success: true,
      message: data.message,
    };
  }
}
