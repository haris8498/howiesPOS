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
import { DeliveryDispatchWithRelations, DispatchesService } from './dispatches.service';
import { AssignRiderDto, CreateDispatchDto, UpdateDispatchStatusDto } from '../dto/dispatch.dto';
import { QueryDispatchDto } from '../dto/query-delivery.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { PermissionsGuard } from '../../common/rbac/guards/permissions.guard';
import { ApiResponse } from '../../common/types/api-response.type';

@Controller('delivery/dispatches')
@UseGuards(JwtAuthGuard, PermissionsGuard)
export class DispatchesController {
  constructor(private readonly dispatchesService: DispatchesService) {}

  @Get()
  async listDispatches(
    @Query() query: QueryDispatchDto,
  ): Promise<ApiResponse<DeliveryDispatchWithRelations[]>> {
    const data = await this.dispatchesService.listDispatches(query);
    return {
      success: true,
      data,
    };
  }

  @Get(':id')
  async getDispatchById(
    @Param('id') id: string,
  ): Promise<ApiResponse<DeliveryDispatchWithRelations>> {
    const data = await this.dispatchesService.getDispatchById(id);
    return {
      success: true,
      data,
    };
  }

  @Get('order/:orderId')
  async getDispatchByOrderId(
    @Param('orderId') orderId: string,
  ): Promise<ApiResponse<DeliveryDispatchWithRelations>> {
    const data = await this.dispatchesService.getDispatchByOrderId(orderId);
    return {
      success: true,
      data,
    };
  }

  @Post()
  async createDispatch(
    @Body() dto: CreateDispatchDto,
  ): Promise<ApiResponse<DeliveryDispatchWithRelations>> {
    const data = await this.dispatchesService.createDispatch(dto);
    return {
      success: true,
      message: 'Delivery dispatch record created successfully',
      data,
    };
  }

  @Post(':id/assign')
  async assignRider(
    @Param('id') id: string,
    @Body() dto: AssignRiderDto,
  ): Promise<ApiResponse<DeliveryDispatchWithRelations>> {
    const data = await this.dispatchesService.assignRider(id, dto);
    return {
      success: true,
      message: `Rider assigned successfully to dispatch`,
      data,
    };
  }

  @Patch(':id/status')
  async updateDispatchStatus(
    @Param('id') id: string,
    @Body() dto: UpdateDispatchStatusDto,
  ): Promise<ApiResponse<DeliveryDispatchWithRelations>> {
    const data = await this.dispatchesService.updateDispatchStatus(id, dto);
    return {
      success: true,
      message: `Dispatch status updated to '${dto.dispatch_status}'`,
      data,
    };
  }

  @Delete(':id')
  async deleteDispatch(@Param('id') id: string): Promise<ApiResponse<{ message: string }>> {
    const data = await this.dispatchesService.deleteDispatch(id);
    return {
      success: true,
      message: data.message,
    };
  }
}
