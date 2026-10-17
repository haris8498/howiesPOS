import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { DeliveryRider, Prisma } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { AssignRiderDto, CreateDispatchDto, UpdateDispatchStatusDto } from '../dto/dispatch.dto';
import { QueryDispatchDto } from '../dto/query-delivery.dto';

const DISPATCH_INCLUDE = {
  online_order_detail: {
    include: {
      order: {
        include: {
          order_items: true,
        },
      },
      customer: true,
    },
  },
  rider: true,
} as const;

export type DeliveryDispatchWithRelations = Prisma.DeliveryDispatchGetPayload<{
  include: typeof DISPATCH_INCLUDE;
}>;

@Injectable()
export class DispatchesService {
  constructor(private readonly prisma: PrismaService) {}

  async listDispatches(query?: QueryDispatchDto): Promise<DeliveryDispatchWithRelations[]> {
    const where: Prisma.DeliveryDispatchWhereInput = {};

    if (query) {
      if (query.dispatch_status) {
        where.dispatch_status = query.dispatch_status;
      }
      if (query.rider_id) {
        where.rider_id = query.rider_id;
      }
      if (query.from_date || query.to_date) {
        where.estimated_delivery_time = {};
        if (query.from_date) {
          where.estimated_delivery_time.gte = new Date(query.from_date);
        }
        if (query.to_date) {
          where.estimated_delivery_time.lte = new Date(query.to_date);
        }
      }
      if (query.search) {
        const search = query.search.trim();
        where.online_order_detail = {
          OR: [
            { order: { order_number: { contains: search, mode: 'insensitive' } } },
            { customer_name: { contains: search, mode: 'insensitive' } },
            { customer_phone: { contains: search, mode: 'insensitive' } },
            { delivery_address: { contains: search, mode: 'insensitive' } },
          ],
        };
      }
    }

    return this.prisma.deliveryDispatch.findMany({
      where,
      include: DISPATCH_INCLUDE,
      orderBy: { estimated_delivery_time: 'desc' },
    });
  }

  async getDispatchById(id: string): Promise<DeliveryDispatchWithRelations> {
    let dispatch = await this.prisma.deliveryDispatch.findUnique({
      where: { id },
      include: DISPATCH_INCLUDE,
    });

    if (!dispatch) {
      const byOrder = await this.prisma.onlineOrderDetail.findFirst({
        where: {
          OR: [{ order_id: id }, { id: id }],
        },
        include: { delivery_dispatch: true },
      });
      if (byOrder && byOrder.delivery_dispatch) {
        dispatch = await this.prisma.deliveryDispatch.findUnique({
          where: { id: byOrder.delivery_dispatch.id },
          include: DISPATCH_INCLUDE,
        });
      }
    }

    if (!dispatch) {
      throw new NotFoundException(`Delivery dispatch record with ID '${id}' not found`);
    }

    return dispatch;
  }

  async getDispatchByOrderId(orderId: string): Promise<DeliveryDispatchWithRelations> {
    const onlineDetail = await this.prisma.onlineOrderDetail.findUnique({
      where: { order_id: orderId },
      include: { delivery_dispatch: true },
    });

    if (!onlineDetail || !onlineDetail.delivery_dispatch) {
      throw new NotFoundException(`Delivery dispatch for Order ID '${orderId}' not found`);
    }

    return this.getDispatchById(onlineDetail.delivery_dispatch.id);
  }

  async createDispatch(dto: CreateDispatchDto): Promise<DeliveryDispatchWithRelations> {
    // 1. Verify online order detail exists
    const onlineDetail = await this.prisma.onlineOrderDetail.findUnique({
      where: { order_id: dto.order_id },
      include: { order: true, delivery_dispatch: true },
    });

    if (!onlineDetail) {
      throw new NotFoundException(`Online order detail for Order ID '${dto.order_id}' not found`);
    }

    if (onlineDetail.delivery_dispatch) {
      throw new ConflictException(
        `A dispatch record already exists for Order #${onlineDetail.order.order_number}`,
      );
    }

    // 2. Validate rider if provided
    let rider: DeliveryRider | null = null;
    if (dto.rider_id) {
      rider = await this.prisma.deliveryRider.findUnique({
        where: { id: dto.rider_id },
      });
      if (!rider) {
        throw new NotFoundException(`Delivery rider with ID '${dto.rider_id}' not found`);
      }
      if (!rider.is_clocked_in) {
        throw new BadRequestException(`Rider '${rider.name}' is currently clocked out / off duty`);
      }
    }

    // 3. Calculate ETA
    let estimatedDeliveryTime: Date;
    if (dto.estimated_delivery_time) {
      estimatedDeliveryTime = new Date(dto.estimated_delivery_time);
    } else {
      estimatedDeliveryTime = new Date(Date.now() + 30 * 60 * 1000);
    }

    const initialStatus = dto.dispatch_status || (rider ? 'outForDelivery' : 'pending');
    const dispatchedAt = initialStatus === 'outForDelivery' ? new Date() : null;

    // 4. Execute in transaction
    return this.prisma.$transaction(async (tx) => {
      if (rider && initialStatus === 'outForDelivery') {
        await tx.deliveryRider.update({
          where: { id: rider.id },
          data: {
            active_deliveries_count: { increment: 1 },
          },
        });
      }

      const created = await tx.deliveryDispatch.create({
        data: {
          online_order_detail_id: onlineDetail.id,
          rider_id: dto.rider_id,
          dispatch_status: initialStatus,
          estimated_delivery_time: estimatedDeliveryTime,
          dispatched_at: dispatchedAt,
        },
        include: DISPATCH_INCLUDE,
      });

      return created;
    });
  }

  async assignRider(id: string, dto: AssignRiderDto): Promise<DeliveryDispatchWithRelations> {
    return this.prisma.$transaction(async (tx) => {
      let dispatch = await tx.deliveryDispatch.findUnique({
        where: { id },
        include: { rider: true, online_order_detail: { include: { order: true } } },
      });

      if (!dispatch) {
        const byOrder = await tx.onlineOrderDetail.findFirst({
          where: {
            OR: [{ order_id: id }, { id: id }],
          },
          include: { delivery_dispatch: true },
        });
        if (byOrder && byOrder.delivery_dispatch) {
          dispatch = await tx.deliveryDispatch.findUnique({
            where: { id: byOrder.delivery_dispatch.id },
            include: { rider: true, online_order_detail: { include: { order: true } } },
          });
        }
      }

      if (!dispatch) {
        throw new NotFoundException(`Delivery dispatch record with ID '${id}' not found`);
      }

      if (['delivered', 'cancelled'].includes(dispatch.dispatch_status)) {
        throw new BadRequestException(
          `Cannot assign rider to a dispatch in '${dispatch.dispatch_status}' status`,
        );
      }

      const newRider = await tx.deliveryRider.findUnique({
        where: { id: dto.rider_id },
      });

      if (!newRider) {
        throw new NotFoundException(`Delivery rider with ID '${dto.rider_id}' not found`);
      }

      if (!newRider.is_clocked_in) {
        throw new BadRequestException(
          `Rider '${newRider.name}' is currently clocked out / off duty`,
        );
      }

      // If already assigned to the same rider, return as is
      if (dispatch.rider_id === newRider.id) {
        return tx.deliveryDispatch.findUniqueOrThrow({
          where: { id },
          include: DISPATCH_INCLUDE,
        });
      }

      // If previous rider existed and dispatch was active, decrement old rider count
      if (dispatch.rider_id) {
        const oldRider = await tx.deliveryRider.findUnique({
          where: { id: dispatch.rider_id },
        });
        if (oldRider && oldRider.active_deliveries_count > 0) {
          await tx.deliveryRider.update({
            where: { id: oldRider.id },
            data: {
              active_deliveries_count: { decrement: 1 },
            },
          });
        }
      }

      // Increment new rider active count
      await tx.deliveryRider.update({
        where: { id: newRider.id },
        data: {
          active_deliveries_count: { increment: 1 },
        },
      });

      // Update dispatch to outForDelivery & set dispatched_at if null
      const updated = await tx.deliveryDispatch.update({
        where: { id },
        data: {
          rider_id: newRider.id,
          dispatch_status: 'outForDelivery',
          dispatched_at: dispatch.dispatched_at || new Date(),
        },
        include: DISPATCH_INCLUDE,
      });

      // Also ensure order status aligns
      const order = dispatch.online_order_detail.order;
      if (order.status !== 'completed' && order.status !== 'cancelled') {
        await tx.order.update({
          where: { id: order.id },
          data: { status: 'outForDelivery' },
        });
      }

      return updated;
    });
  }

  async updateDispatchStatus(
    id: string,
    dto: UpdateDispatchStatusDto,
  ): Promise<DeliveryDispatchWithRelations> {
    return this.prisma.$transaction(async (tx) => {
      let dispatch = await tx.deliveryDispatch.findUnique({
        where: { id },
        include: { rider: true, online_order_detail: { include: { order: true } } },
      });

      if (!dispatch) {
        const byOrder = await tx.onlineOrderDetail.findFirst({
          where: {
            OR: [{ order_id: id }, { id: id }],
          },
          include: { delivery_dispatch: true },
        });
        if (byOrder && byOrder.delivery_dispatch) {
          dispatch = await tx.deliveryDispatch.findUnique({
            where: { id: byOrder.delivery_dispatch.id },
            include: { rider: true, online_order_detail: { include: { order: true } } },
          });
        }
      }

      if (!dispatch) {
        throw new NotFoundException(`Delivery dispatch record with ID '${id}' not found`);
      }

      const prevStatus = dispatch.dispatch_status;
      const nextStatus = dto.dispatch_status;

      if (prevStatus === nextStatus) {
        return tx.deliveryDispatch.findUniqueOrThrow({
          where: { id },
          include: DISPATCH_INCLUDE,
        });
      }

      const updateData: Prisma.DeliveryDispatchUpdateInput = {
        dispatch_status: nextStatus,
      };

      // Set dispatched_at when transitioning to outForDelivery
      if (nextStatus === 'outForDelivery' && !dispatch.dispatched_at) {
        updateData.dispatched_at = new Date();
      }

      const orderId = dispatch.online_order_detail.order.id;

      // Handle delivery completion
      if (nextStatus === 'delivered') {
        updateData.delivered_at = new Date();

        // Update rider statistics
        if (dispatch.rider_id) {
          const rider = await tx.deliveryRider.findUnique({
            where: { id: dispatch.rider_id },
          });

          if (rider) {
            const nextActive = Math.max(0, rider.active_deliveries_count - 1);
            await tx.deliveryRider.update({
              where: { id: rider.id },
              data: {
                active_deliveries_count: nextActive,
                total_completed_deliveries: { increment: 1 },
              },
            });
          }
        }

        // Sync order status to completed
        await tx.order.update({
          where: { id: orderId },
          data: { status: 'completed' },
        });
      }

      // Handle cancellation
      if (nextStatus === 'cancelled') {
        if (dispatch.rider_id && prevStatus !== 'delivered') {
          const rider = await tx.deliveryRider.findUnique({
            where: { id: dispatch.rider_id },
          });

          if (rider && rider.active_deliveries_count > 0) {
            await tx.deliveryRider.update({
              where: { id: rider.id },
              data: {
                active_deliveries_count: { decrement: 1 },
              },
            });
          }
        }

        // Sync order status to cancelled
        await tx.order.update({
          where: { id: orderId },
          data: { status: 'cancelled' },
        });
      }

      return tx.deliveryDispatch.update({
        where: { id },
        data: updateData,
        include: DISPATCH_INCLUDE,
      });
    });
  }

  async deleteDispatch(id: string): Promise<{ message: string }> {
    return this.prisma.$transaction(async (tx) => {
      let dispatch = await tx.deliveryDispatch.findUnique({
        where: { id },
        include: { rider: true },
      });

      if (!dispatch) {
        const byOrder = await tx.onlineOrderDetail.findFirst({
          where: {
            OR: [{ order_id: id }, { id: id }],
          },
          include: { delivery_dispatch: true },
        });
        if (byOrder && byOrder.delivery_dispatch) {
          dispatch = await tx.deliveryDispatch.findUnique({
            where: { id: byOrder.delivery_dispatch.id },
            include: { rider: true },
          });
        }
      }

      if (!dispatch) {
        throw new NotFoundException(`Delivery dispatch record with ID '${id}' not found`);
      }

      // If active assignment, decrement rider active counter
      if (dispatch.rider_id && !['delivered', 'cancelled'].includes(dispatch.dispatch_status)) {
        const rider = await tx.deliveryRider.findUnique({
          where: { id: dispatch.rider_id },
        });
        if (rider && rider.active_deliveries_count > 0) {
          await tx.deliveryRider.update({
            where: { id: rider.id },
            data: {
              active_deliveries_count: { decrement: 1 },
            },
          });
        }
      }

      await tx.deliveryDispatch.delete({
        where: { id },
      });

      return {
        message: 'Delivery dispatch record deleted successfully',
      };
    });
  }
}
