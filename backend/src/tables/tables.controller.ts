import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  Req,
  Query,
  UseGuards,
} from '@nestjs/common';
import { RestaurantTable } from '@prisma/client';
import { TablesService } from './tables.service';
import { CreateTableDto } from './dto/create-table.dto';
import { UpdateTableDto } from './dto/update-table.dto';
import { UpdateTableStatusDto } from './dto/update-table-status.dto';
import { TransferTableDto } from './dto/transfer-table.dto';
import { TableReservationDto } from './dto/table-reservation.dto';
import { QueryTableDto } from './dto/query-table.dto';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { PermissionsGuard } from '../common/rbac/guards/permissions.guard';
import { RequirePermission } from '../common/rbac/decorators/permissions.decorator';
import { ApiResponse } from '../common/types/api-response.type';

@Controller('tables')
@UseGuards(JwtAuthGuard, PermissionsGuard)
export class TablesController {
  constructor(private readonly tablesService: TablesService) {}

  @Get()
  @RequirePermission('Tables', 'Allow Access to Tables')
  async listTables(@Query() query: QueryTableDto): Promise<ApiResponse<RestaurantTable[]>> {
    const data = await this.tablesService.listTables(query);
    return {
      success: true,
      data,
    };
  }

  @Get('zones')
  @RequirePermission('Tables', 'Allow Access to Tables')
  async listZones(): Promise<ApiResponse<any[]>> {
    const data = await this.tablesService.listZones();
    return {
      success: true,
      data,
    };
  }

  @Post('zones')
  @RequirePermission('Tables', 'Add Tables')
  async createZone(@Body('name') name: string): Promise<ApiResponse<any>> {
    const data = await this.tablesService.createZone(name);
    return {
      success: true,
      message: `Floor zone '${data.name}' created successfully`,
      data,
    };
  }

  @Delete('zones/:idOrName')
  @RequirePermission('Tables', 'Delete Tables')
  async deleteZone(@Param('idOrName') idOrName: string): Promise<ApiResponse<{ message: string }>> {
    const data = await this.tablesService.deleteZone(idOrName);
    return {
      success: true,
      message: data.message,
    };
  }

  @Get(':id')
  @RequirePermission('Tables', 'Allow Access to Tables')
  async getTableById(@Param('id') id: string): Promise<ApiResponse<RestaurantTable>> {
    const data = await this.tablesService.getTableById(id);
    return {
      success: true,
      data,
    };
  }

  @Post()
  @RequirePermission('Tables', 'Add Tables')
  async createTable(@Body() dto: CreateTableDto): Promise<ApiResponse<RestaurantTable>> {
    const data = await this.tablesService.createTable(dto);
    return {
      success: true,
      message: 'Table created successfully',
      data,
    };
  }

  @Patch(':id')
  @RequirePermission('Tables', 'Edit Tables')
  async updateTable(
    @Param('id') id: string,
    @Body() dto: UpdateTableDto,
  ): Promise<ApiResponse<RestaurantTable>> {
    const data = await this.tablesService.updateTable(id, dto);
    return {
      success: true,
      message: 'Table updated successfully',
      data,
    };
  }

  @Patch(':id/status')
  @RequirePermission('Tables', 'Allow Access to Tables')
  async updateTableStatus(
    @Param('id') id: string,
    @Body() dto: UpdateTableStatusDto,
  ): Promise<ApiResponse<RestaurantTable>> {
    const data = await this.tablesService.updateTableStatus(id, dto);
    return {
      success: true,
      message: `Table status updated to '${dto.status}'`,
      data,
    };
  }

  @Post(':id/release')
  @RequirePermission('Tables', 'Allow Access to Tables')
  async releaseTable(@Param('id') id: string): Promise<ApiResponse<RestaurantTable>> {
    const data = await this.tablesService.releaseTable(id);
    return {
      success: true,
      message: 'Table released successfully',
      data,
    };
  }

  @Post('transfer')
  @RequirePermission('Tables', 'Edit Tables')
  async transferTable(
    @Body() dto: TransferTableDto,
  ): Promise<ApiResponse<{ fromTable: RestaurantTable; toTable: RestaurantTable }>> {
    const data = await this.tablesService.transferTable(dto);
    return {
      success: true,
      message: `Transferred dining session from '${data.fromTable.name}' to '${data.toTable.name}'`,
      data,
    };
  }

  @Patch(':id/reservation')
  @RequirePermission('Tables', 'Edit Tables')
  async updateTableReservation(
    @Param('id') id: string,
    @Body() dto: TableReservationDto,
  ): Promise<ApiResponse<RestaurantTable>> {
    const data = await this.tablesService.updateTableReservation(id, dto);
    return {
      success: true,
      message: 'Table reservation updated successfully',
      data,
    };
  }

  @Post(':id/restore')
  @RequirePermission('Tables', 'Delete Tables')
  async restoreTable(@Param('id') id: string): Promise<ApiResponse<RestaurantTable>> {
    const data = await this.tablesService.restoreTable(id);
    return {
      success: true,
      message: data.message,
      data: data.table,
    };
  }

  @Delete(':id')
  @RequirePermission('Tables', 'Delete Tables')
  async deleteTable(
    @Param('id') id: string,
    @Req() req?: any,
  ): Promise<ApiResponse<{ message: string; table?: RestaurantTable; open_orders?: any[]; openOrders?: any[]; has_open_orders?: boolean }>> {
    const deletedBy = req?.user?.username || req?.user?.id || 'admin';
    const data = await this.tablesService.deleteTable(id, deletedBy);
    return {
      success: true,
      message: data.message,
      data,
    };
  }
}
