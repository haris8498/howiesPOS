import { ConflictException, Injectable, Logger, NotFoundException } from '@nestjs/common';
import { Customer, Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { CreateCustomerDto } from './dto/create-customer.dto';
import { UpdateCustomerDto } from './dto/update-customer.dto';
import { QueryCustomerDto } from './dto/query-customer.dto';

@Injectable()
export class CustomersService {
  private readonly logger = new Logger(CustomersService.name);

  constructor(private readonly prisma: PrismaService) {}

  async listCustomers(query: QueryCustomerDto = {}): Promise<Customer[]> {
    const where: Prisma.CustomerWhereInput = {};

    if (query.phone) {
      where.phone = { contains: query.phone, mode: 'insensitive' };
    }

    if (query.search) {
      where.OR = [
        { full_name: { contains: query.search, mode: 'insensitive' } },
        { phone: { contains: query.search, mode: 'insensitive' } },
        { email: { contains: query.search, mode: 'insensitive' } },
        { address: { contains: query.search, mode: 'insensitive' } },
      ];
    }

    return this.prisma.customer.findMany({
      where,
      orderBy: { full_name: 'asc' },
    });
  }

  async getCustomerById(id: string): Promise<Customer> {
    const customer = await this.prisma.customer.findUnique({
      where: { id },
    });

    if (!customer) {
      throw new NotFoundException(`Customer with ID '${id}' not found`);
    }

    return customer;
  }

  async getCustomerByPhone(phone: string): Promise<Customer | null> {
    return this.prisma.customer.findUnique({
      where: { phone },
    });
  }

  async createCustomer(dto: CreateCustomerDto): Promise<Customer> {
    const existing = await this.prisma.customer.findUnique({
      where: { phone: dto.phone },
    });

    if (existing) {
      throw new ConflictException(
        `Customer with phone number '${dto.phone}' already exists (${existing.full_name})`,
      );
    }

    const created = await this.prisma.customer.create({
      data: {
        full_name: dto.full_name,
        phone: dto.phone,
        email: dto.email ?? '',
        address: dto.address ?? '',
        birth_date: dto.birth_date ? new Date(dto.birth_date) : null,
        loyalty_points: dto.loyalty_points ?? 0,
        special_notes: dto.special_notes ?? '',
      },
    });

    this.logger.log(`Created customer '${created.full_name}' (${created.phone})`);
    return created;
  }

  async updateCustomer(id: string, dto: UpdateCustomerDto): Promise<Customer> {
    const existing = await this.prisma.customer.findUnique({
      where: { id },
    });

    if (!existing) {
      throw new NotFoundException(`Customer with ID '${id}' not found`);
    }

    if (dto.phone && dto.phone !== existing.phone) {
      const duplicate = await this.prisma.customer.findUnique({
        where: { phone: dto.phone },
      });

      if (duplicate && duplicate.id !== id) {
        throw new ConflictException(
          `Customer with phone number '${dto.phone}' already exists (${duplicate.full_name})`,
        );
      }
    }

    const updated = await this.prisma.customer.update({
      where: { id },
      data: {
        full_name: dto.full_name ?? existing.full_name,
        phone: dto.phone ?? existing.phone,
        email: dto.email !== undefined ? dto.email : existing.email,
        address: dto.address !== undefined ? dto.address : existing.address,
        birth_date:
          dto.birth_date !== undefined
            ? dto.birth_date
              ? new Date(dto.birth_date)
              : null
            : existing.birth_date,
        loyalty_points:
          dto.loyalty_points !== undefined ? dto.loyalty_points : existing.loyalty_points,
        special_notes: dto.special_notes !== undefined ? dto.special_notes : existing.special_notes,
      },
    });

    this.logger.log(`Updated customer '${updated.full_name}' (${id})`);
    return updated;
  }

  async deleteCustomer(id: string): Promise<{ message: string }> {
    const existing = await this.prisma.customer.findUnique({
      where: { id },
      include: {
        online_orders: true,
        takeaway_orders: true,
      },
    });

    if (!existing) {
      throw new NotFoundException(`Customer with ID '${id}' not found`);
    }

    const orderCount = existing.online_orders.length + existing.takeaway_orders.length;
    if (orderCount > 0) {
      throw new ConflictException(
        `Cannot delete customer '${existing.full_name}' because they are associated with ${orderCount} order(s).`,
      );
    }

    await this.prisma.customer.delete({
      where: { id },
    });

    this.logger.log(`Deleted customer '${existing.full_name}' (${id})`);
    return { message: `Customer '${existing.full_name}' deleted successfully` };
  }
}
