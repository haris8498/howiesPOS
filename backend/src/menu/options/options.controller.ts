import { Body, Controller, Delete, Get, Param, Patch, Post, UseGuards } from '@nestjs/common';
import { MenuItemOption } from '@prisma/client';
import { OptionsService } from './options.service';
import { CreateOptionDto, UpdateOptionDto } from '../dto/option.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { PermissionsGuard } from '../../common/rbac/guards/permissions.guard';
import { RequirePermission } from '../../common/rbac/decorators/permissions.decorator';
import { ApiResponse } from '../../common/types/api-response.type';

@Controller('menu')
@UseGuards(JwtAuthGuard, PermissionsGuard)
export class OptionsController {
  constructor(private readonly optionsService: OptionsService) {}

  @Get('items/:itemId/options')
  @RequirePermission('Menu Catalog', 'Allow Access to Menu Catalog Module')
  async listOptionsByItem(@Param('itemId') itemId: string): Promise<ApiResponse<MenuItemOption[]>> {
    const data = await this.optionsService.listOptionsByItem(itemId);
    return {
      success: true,
      data,
    };
  }

  @Post('items/:itemId/options')
  @RequirePermission('Menu Catalog', 'Add & Edit Menu Items & Prices')
  async createOption(
    @Param('itemId') itemId: string,
    @Body() dto: CreateOptionDto,
  ): Promise<ApiResponse<MenuItemOption>> {
    const data = await this.optionsService.createOption(itemId, dto);
    return {
      success: true,
      message: 'Menu item option added successfully',
      data,
    };
  }

  @Patch('options/:id')
  @RequirePermission('Menu Catalog', 'Add & Edit Menu Items & Prices')
  async updateOption(
    @Param('id') id: string,
    @Body() dto: UpdateOptionDto,
  ): Promise<ApiResponse<MenuItemOption>> {
    const data = await this.optionsService.updateOption(id, dto);
    return {
      success: true,
      message: 'Menu item option updated successfully',
      data,
    };
  }

  @Delete('options/:id')
  @RequirePermission('Menu Catalog', 'Delete Menu Items')
  async deleteOption(@Param('id') id: string): Promise<ApiResponse<{ message: string }>> {
    const data = await this.optionsService.deleteOption(id);
    return {
      success: true,
      message: data.message,
    };
  }
}
