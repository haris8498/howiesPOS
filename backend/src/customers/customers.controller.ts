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
import { Customer } from '@prisma/client';
import { CustomersService } from './customers.service';
import { CreateCustomerDto } from './dto/create-customer.dto';
import { UpdateCustomerDto } from './dto/update-customer.dto';
import { QueryCustomerDto } from './dto/query-customer.dto';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { PermissionsGuard } from '../common/rbac/guards/permissions.guard';
import { ApiResponse } from '../common/types/api-response.type';

@Controller('customers')
@UseGuards(JwtAuthGuard, PermissionsGuard)
export class CustomersController {
  constructor(private readonly customersService: CustomersService) {}

  @Get()
  async listCustomers(@Query() query: QueryCustomerDto): Promise<ApiResponse<Customer[]>> {
    const data = await this.customersService.listCustomers(query);
    return {
      success: true,
      data,
    };
  }

  @Get(':id')
  async getCustomerById(@Param('id') id: string): Promise<ApiResponse<Customer>> {
    const data = await this.customersService.getCustomerById(id);
    return {
      success: true,
      data,
    };
  }

  @Post()
  async createCustomer(@Body() dto: CreateCustomerDto): Promise<ApiResponse<Customer>> {
    const data = await this.customersService.createCustomer(dto);
    return {
      success: true,
      message: 'Customer created successfully',
      data,
    };
  }

  @Patch(':id')
  async updateCustomer(
    @Param('id') id: string,
    @Body() dto: UpdateCustomerDto,
  ): Promise<ApiResponse<Customer>> {
    const data = await this.customersService.updateCustomer(id, dto);
    return {
      success: true,
      message: 'Customer updated successfully',
      data,
    };
  }

  @Delete(':id')
  async deleteCustomer(@Param('id') id: string): Promise<ApiResponse<{ message: string }>> {
    const data = await this.customersService.deleteCustomer(id);
    return {
      success: true,
      message: data.message,
    };
  }
}
