import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { DeliveryRider, Prisma } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { CreateRiderDto, ToggleRiderDutyDto, UpdateRiderDto } from '../dto/rider.dto';
import { QueryRiderDto } from '../dto/query-delivery.dto';

@Injectable()
export class RidersService {
  constructor(private readonly prisma: PrismaService) {}

  async listRiders(query?: QueryRiderDto): Promise<DeliveryRider[]> {
    const where: Prisma.DeliveryRiderWhereInput = {};

    if (query) {
      if (query.is_available !== undefined) {
        where.is_available = query.is_available;
      }
      if (query.is_clocked_in !== undefined) {
        where.is_clocked_in = query.is_clocked_in;
      }
      if (query.search) {
        const search = query.search.trim();
        where.OR = [
          { name: { contains: search, mode: 'insensitive' } },
          { phone: { contains: search, mode: 'insensitive' } },
        ];
      }
    }

    return this.prisma.deliveryRider.findMany({
      where,
      orderBy: [{ is_clocked_in: 'desc' }, { active_deliveries_count: 'asc' }, { name: 'asc' }],
    });
  }

  async getRiderById(id: string): Promise<DeliveryRider> {
    const rider = await this.prisma.deliveryRider.findUnique({
      where: { id },
      include: {
        dispatches: {
          orderBy: { estimated_delivery_time: 'desc' },
          take: 10,
        },
      },
    });

    if (!rider) {
      throw new NotFoundException(`Delivery rider with ID '${id}' not found`);
    }

    return rider;
  }

  async createRider(dto: CreateRiderDto): Promise<DeliveryRider> {
    const existingPhone = await this.prisma.deliveryRider.findUnique({
      where: { phone: dto.phone },
    });

    if (existingPhone) {
      throw new ConflictException(`A rider with phone number '${dto.phone}' already exists`);
    }

    return this.prisma.deliveryRider.create({
      data: {
        name: dto.name.trim(),
        phone: dto.phone.trim(),
        is_available: dto.is_available ?? true,
        is_clocked_in: dto.is_clocked_in ?? true,
        rating: dto.rating !== undefined ? new Prisma.Decimal(dto.rating) : new Prisma.Decimal(5.0),
        active_deliveries_count: 0,
        total_completed_deliveries: 0,
        avg_delivery_time_mins: new Prisma.Decimal(22.5),
      },
    });
  }

  async updateRider(id: string, dto: UpdateRiderDto): Promise<DeliveryRider> {
    const rider = await this.prisma.deliveryRider.findUnique({
      where: { id },
    });

    if (!rider) {
      throw new NotFoundException(`Delivery rider with ID '${id}' not found`);
    }

    if (dto.phone && dto.phone !== rider.phone) {
      const existingPhone = await this.prisma.deliveryRider.findUnique({
        where: { phone: dto.phone },
      });

      if (existingPhone) {
        throw new ConflictException(`A rider with phone number '${dto.phone}' already exists`);
      }
    }

    const data: Prisma.DeliveryRiderUpdateInput = {};

    if (dto.name !== undefined) data.name = dto.name.trim();
    if (dto.phone !== undefined) data.phone = dto.phone.trim();
    if (dto.is_available !== undefined) data.is_available = dto.is_available;
    if (dto.is_clocked_in !== undefined) data.is_clocked_in = dto.is_clocked_in;
    if (dto.rating !== undefined) data.rating = new Prisma.Decimal(dto.rating);

    return this.prisma.deliveryRider.update({
      where: { id },
      data,
    });
  }

  async toggleRiderDuty(id: string, dto?: ToggleRiderDutyDto): Promise<DeliveryRider> {
    const rider = await this.prisma.deliveryRider.findUnique({
      where: { id },
    });

    if (!rider) {
      throw new NotFoundException(`Delivery rider with ID '${id}' not found`);
    }

    let nextClockedIn = !rider.is_clocked_in;
    if (dto && dto.is_clocked_in !== undefined) {
      nextClockedIn = dto.is_clocked_in;
    }

    let nextAvailable = rider.is_available;
    if (dto && dto.is_available !== undefined) {
      nextAvailable = dto.is_available;
    } else if (!nextClockedIn) {
      // If clocked out, also mark unavailable
      nextAvailable = false;
    } else if (nextClockedIn && !rider.is_clocked_in) {
      // If clocked back in, mark available
      nextAvailable = true;
    }

    return this.prisma.deliveryRider.update({
      where: { id },
      data: {
        is_clocked_in: nextClockedIn,
        is_available: nextAvailable,
      },
    });
  }

  async deleteRider(id: string): Promise<{ message: string }> {
    const rider = await this.prisma.deliveryRider.findUnique({
      where: { id },
      include: {
        dispatches: {
          where: {
            dispatch_status: {
              in: ['pending', 'accepted', 'preparing', 'readyForDispatch', 'outForDelivery'],
            },
          },
        },
      },
    });

    if (!rider) {
      throw new NotFoundException(`Delivery rider with ID '${id}' not found`);
    }

    if (rider.dispatches.length > 0) {
      throw new BadRequestException(
        `Cannot delete rider '${rider.name}' because they have ${rider.dispatches.length} active delivery dispatches`,
      );
    }

    await this.prisma.deliveryRider.delete({
      where: { id },
    });

    return {
      message: `Delivery rider '${rider.name}' deleted successfully`,
    };
  }
}
