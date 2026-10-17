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
import { Deal, DealComponent } from '@prisma/client';
import { DealsService } from './deals.service';
import { CreateDealDto, UpdateDealDto } from '../dto/deal.dto';
import { QueryDealDto } from '../dto/query-menu.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { PermissionsGuard } from '../../common/rbac/guards/permissions.guard';
import { RequirePermission } from '../../common/rbac/decorators/permissions.decorator';
import { ApiResponse } from '../../common/types/api-response.type';

type DealWithComponents = Deal & { components: DealComponent[] };

@Controller('menu/deals')
@UseGuards(JwtAuthGuard, PermissionsGuard)
export class DealsController {
  constructor(private readonly dealsService: DealsService) {}

  @Get()
  async listDeals(@Query() query: QueryDealDto): Promise<ApiResponse<DealWithComponents[]>> {
    const data = (await this.dealsService.listDeals(query)) as DealWithComponents[];
    return {
      success: true,
      data,
    };
  }

  @Get(':id')
  async getDealById(@Param('id') id: string): Promise<ApiResponse<DealWithComponents>> {
    const data = (await this.dealsService.getDealById(id)) as DealWithComponents;
    return {
      success: true,
      data,
    };
  }

  @Post()
  @RequirePermission('Menu Catalog', 'Add & Edit Menu Items & Prices')
  async createDeal(@Body() dto: CreateDealDto): Promise<ApiResponse<DealWithComponents>> {
    const data = (await this.dealsService.createDeal(dto)) as DealWithComponents;
    return {
      success: true,
      message: 'Deal created successfully',
      data,
    };
  }

  @Patch(':id')
  @RequirePermission('Menu Catalog', 'Add & Edit Menu Items & Prices')
  async updateDeal(
    @Param('id') id: string,
    @Body() dto: UpdateDealDto,
  ): Promise<ApiResponse<DealWithComponents>> {
    const data = (await this.dealsService.updateDeal(id, dto)) as DealWithComponents;
    return {
      success: true,
      message: 'Deal updated successfully',
      data,
    };
  }

  @Delete(':id')
  @RequirePermission('Menu Catalog', 'Delete Menu Items')
  async deleteDeal(@Param('id') id: string): Promise<ApiResponse<{ message: string }>> {
    const data = await this.dealsService.deleteDeal(id);
    return {
      success: true,
      message: data.message,
    };
  }
}
