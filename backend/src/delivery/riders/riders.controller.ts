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
import { DeliveryRider } from '@prisma/client';
import { RidersService } from './riders.service';
import { CreateRiderDto, ToggleRiderDutyDto, UpdateRiderDto } from '../dto/rider.dto';
import { QueryRiderDto } from '../dto/query-delivery.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { PermissionsGuard } from '../../common/rbac/guards/permissions.guard';
import { ApiResponse } from '../../common/types/api-response.type';

@Controller('delivery/riders')
@UseGuards(JwtAuthGuard, PermissionsGuard)
export class RidersController {
  constructor(private readonly ridersService: RidersService) {}

  @Get()
  async listRiders(@Query() query: QueryRiderDto): Promise<ApiResponse<DeliveryRider[]>> {
    const data = await this.ridersService.listRiders(query);
    return {
      success: true,
      data,
    };
  }

  @Get(':id')
  async getRiderById(@Param('id') id: string): Promise<ApiResponse<DeliveryRider>> {
    const data = await this.ridersService.getRiderById(id);
    return {
      success: true,
      data,
    };
  }

  @Post()
  async createRider(@Body() dto: CreateRiderDto): Promise<ApiResponse<DeliveryRider>> {
    const data = await this.ridersService.createRider(dto);
    return {
      success: true,
      message: 'Delivery rider registered successfully',
      data,
    };
  }

  @Patch(':id')
  async updateRider(
    @Param('id') id: string,
    @Body() dto: UpdateRiderDto,
  ): Promise<ApiResponse<DeliveryRider>> {
    const data = await this.ridersService.updateRider(id, dto);
    return {
      success: true,
      message: 'Delivery rider updated successfully',
      data,
    };
  }

  @Patch(':id/duty')
  async toggleRiderDuty(
    @Param('id') id: string,
    @Body() dto: ToggleRiderDutyDto,
  ): Promise<ApiResponse<DeliveryRider>> {
    const data = await this.ridersService.toggleRiderDuty(id, dto);
    return {
      success: true,
      message: `Rider duty status updated to ${data.is_clocked_in ? 'ON DUTY' : 'OFF DUTY'}`,
      data,
    };
  }

  @Delete(':id')
  async deleteRider(@Param('id') id: string): Promise<ApiResponse<{ message: string }>> {
    const data = await this.ridersService.deleteRider(id);
    return {
      success: true,
      message: data.message,
    };
  }
}
