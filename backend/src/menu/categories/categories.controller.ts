import { Body, Controller, Delete, Get, Param, Patch, Post, UseGuards } from '@nestjs/common';
import { MenuCategory } from '@prisma/client';
import { CategoriesService } from './categories.service';
import { CreateCategoryDto, UpdateCategoryDto } from '../dto/category.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { PermissionsGuard } from '../../common/rbac/guards/permissions.guard';
import { RequirePermission } from '../../common/rbac/decorators/permissions.decorator';
import { ApiResponse } from '../../common/types/api-response.type';

@Controller('menu/categories')
@UseGuards(JwtAuthGuard, PermissionsGuard)
export class CategoriesController {
  constructor(private readonly categoriesService: CategoriesService) {}

  @Get()
  async listCategories(): Promise<ApiResponse<MenuCategory[]>> {
    const data = await this.categoriesService.listCategories();
    return {
      success: true,
      data,
    };
  }

  @Get(':id')
  async getCategoryById(@Param('id') id: string): Promise<ApiResponse<MenuCategory>> {
    const data = await this.categoriesService.getCategoryById(id);
    return {
      success: true,
      data,
    };
  }

  @Post()
  @RequirePermission('Menu Catalog', 'Add & Edit Menu Items & Prices')
  async createCategory(@Body() dto: CreateCategoryDto): Promise<ApiResponse<MenuCategory>> {
    const data = await this.categoriesService.createCategory(dto);
    return {
      success: true,
      message: 'Category created successfully',
      data,
    };
  }

  @Patch(':id')
  @RequirePermission('Menu Catalog', 'Add & Edit Menu Items & Prices')
  async updateCategory(
    @Param('id') id: string,
    @Body() dto: UpdateCategoryDto,
  ): Promise<ApiResponse<MenuCategory>> {
    const data = await this.categoriesService.updateCategory(id, dto);
    return {
      success: true,
      message: 'Category updated successfully',
      data,
    };
  }

  @Delete(':id')
  @RequirePermission('Menu Catalog', 'Delete Menu Items')
  async deleteCategory(@Param('id') id: string): Promise<ApiResponse<{ message: string }>> {
    const data = await this.categoriesService.deleteCategory(id);
    return {
      success: true,
      message: data.message,
    };
  }
}
