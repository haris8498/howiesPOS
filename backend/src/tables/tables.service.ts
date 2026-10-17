import {
  BadRequestException,
  ConflictException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { Prisma, RestaurantTable } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { CreateTableDto } from './dto/create-table.dto';
import { UpdateTableDto } from './dto/update-table.dto';
import { UpdateTableStatusDto } from './dto/update-table-status.dto';
import { TransferTableDto } from './dto/transfer-table.dto';
import { TableReservationDto } from './dto/table-reservation.dto';
import { QueryTableDto } from './dto/query-table.dto';

@Injectable()
export class TablesService {
  private readonly logger = new Logger(TablesService.name);

  constructor(private readonly prisma: PrismaService) {}

  async listTables(query: QueryTableDto = {}): Promise<any[]> {
    const where: Prisma.RestaurantTableWhereInput = {};

    if (query.status) {
      where.status = query.status;
    }

    if (query.section) {
      where.section = query.section;
    }

    if (query.search) {
      where.OR = [
        { table_number: { contains: query.search, mode: 'insensitive' } },
        { name: { contains: query.search, mode: 'insensitive' } },
        { section: { contains: query.search, mode: 'insensitive' } },
      ];
    }

    const now = new Date();
    const todayDateString = now.toDateString();

    const tables = await this.prisma.restaurantTable.findMany({
      where,
      include: {
        dine_in_orders: {
          where: {
            order: {
              is_paid: false,
              status: { notIn: ['completed'] },
            },
          },
          include: {
            order: {
              include: { order_items: true, dine_in_detail: true },
            },
          },
          orderBy: { order: { created_at: 'desc' } },
          take: 1,
        },
      },
      orderBy: { table_number: 'asc' },
    });

    // Fallback: fetch orders for occupied tables that have active_order_id
    const fallbackOrderIds = tables
      .filter((t) => t.status === 'occupied' && t.active_order_id && (!t.dine_in_orders?.[0]?.order?.order_items?.length))
      .map((t) => t.active_order_id as string);

    let fallbackOrdersMap = new Map<string, any>();
    if (fallbackOrderIds.length > 0) {
      const fallbackOrders = await this.prisma.order.findMany({
        where: { id: { in: fallbackOrderIds }, is_paid: false, status: { notIn: ['completed'] } },
        include: { order_items: true, dine_in_detail: true },
      });
      fallbackOrdersMap = new Map(fallbackOrders.map((o) => [o.id, o]));
    }

    return tables.map((t) => {
      let status = t.status;
      let reservedCustomerName = t.reserved_customer_name;
      let reservationTime = t.reservation_time;

      // Date-aware reservation checking: Expired past reservations automatically reset to available
      if (status === 'reserved') {
        if (t.reservation_time) {
          const resDate = new Date(t.reservation_time);
          if (resDate.toDateString() !== todayDateString && resDate < now) {
            status = 'available';
            reservedCustomerName = null;
            reservationTime = null;
          }
        }
      }

      const isOccupied = status === 'occupied';
      const activeDetail = isOccupied ? t.dine_in_orders?.[0] : null;
      const orderFromDineIn = activeDetail?.order;
      const orderFromActiveId = isOccupied && t.active_order_id ? fallbackOrdersMap.get(t.active_order_id) : null;
      const activeOrder = isOccupied ? (orderFromActiveId || orderFromDineIn) : null;

      // If marked occupied but no active unpaid order exists, table starts fresh available
      if (isOccupied && !activeOrder) {
        status = 'available';
      }

      const effectiveOccupied = status === 'occupied' && activeOrder != null;

      const activeItems =
        effectiveOccupied
          ? activeOrder?.order_items?.map((item: any) => ({
              id: item.id,
              name: item.item_name,
              quantity: item.quantity,
              price: Number(item.unit_price),
              selected_size: item.selected_size,
              selected_crust: item.selected_crust,
              extra_toppings: item.extra_toppings,
              notes: item.notes,
              is_cancelled: item.is_cancelled === true,
              cancel_reason: item.cancel_reason,
              cancelled_at: item.cancelled_at,
              cancelled_by: item.cancelled_by,
            })) || []
          : [];

      const dineInTax =
        effectiveOccupied && activeOrder?.dine_in_detail?.dine_in_tax !== undefined
          ? Number(activeOrder.dine_in_detail.dine_in_tax)
          : Number(activeOrder?.tax_amount ?? 0);

      return {
        id: t.id,
        table_number: t.table_number,
        name: t.name,
        capacity: t.capacity,
        section: t.section,
        zone_id: t.zone_id,
        status,
        current_customer_count: effectiveOccupied ? t.current_customer_count : 0,
        current_bill_amount: effectiveOccupied ? Number(activeOrder.grand_total) : 0,
        active_order_id: effectiveOccupied ? (t.active_order_id || activeOrder?.id || null) : null,
        active_order_number: effectiveOccupied ? (activeOrder?.order_number || null) : null,
        dine_in_tax: effectiveOccupied ? dineInTax : 0,
        discount_amount: effectiveOccupied ? Number(activeOrder?.discount_amount ?? 0) : 0,
        discount_percentage: effectiveOccupied ? Number(activeOrder?.discount_percentage ?? 0) : 0,
        occupied_since: effectiveOccupied ? t.occupied_since : null,
        reserved_customer_name: reservedCustomerName,
        reservation_time: reservationTime,
        current_order_items: activeItems,
      };
    });
  }

  async getTableById(id: string): Promise<any> {
    const now = new Date();
    const todayDateString = now.toDateString();

    const table = await this.prisma.restaurantTable.findUnique({
      where: { id },
      include: {
        dine_in_orders: {
          where: {
            order: {
              is_paid: false,
              status: { notIn: ['completed'] },
            },
          },
          include: {
            order: {
              include: { order_items: true, dine_in_detail: true },
            },
          },
          orderBy: { order: { created_at: 'desc' } },
          take: 1,
        },
      },
    });

    if (!table) {
      throw new NotFoundException(`Restaurant table with ID '${id}' not found`);
    }

    let status = table.status;
    let reservedCustomerName = table.reserved_customer_name;
    let reservationTime = table.reservation_time;

    if (status === 'reserved' && table.reservation_time) {
      const resDate = new Date(table.reservation_time);
      if (resDate.toDateString() !== todayDateString && resDate < now) {
        status = 'available';
        reservedCustomerName = null;
        reservationTime = null;
      }
    }

    const isOccupied = status === 'occupied';
    let activeOrder = isOccupied ? table.dine_in_orders?.[0]?.order : null;
    if (isOccupied && !activeOrder?.order_items?.length && table.active_order_id) {
      activeOrder = (await this.prisma.order.findFirst({
        where: { id: table.active_order_id, is_paid: false, status: { notIn: ['completed'] } },
        include: { order_items: true, dine_in_detail: true },
      })) as any;
    }

    if (isOccupied && !activeOrder) {
      status = 'available';
    }

    const effectiveOccupied = status === 'occupied' && activeOrder != null;

    const activeItems =
      effectiveOccupied
        ? activeOrder?.order_items?.map((item: any) => ({
            id: item.id,
            name: item.item_name,
            quantity: item.quantity,
            price: Number(item.unit_price),
            selected_size: item.selected_size,
            selected_crust: item.selected_crust,
            extra_toppings: item.extra_toppings,
            notes: item.notes,
            is_cancelled: item.is_cancelled === true,
            cancel_reason: item.cancel_reason,
            cancelled_at: item.cancelled_at,
            cancelled_by: item.cancelled_by,
          })) || []
        : [];

    const dineInTax =
      effectiveOccupied && activeOrder?.dine_in_detail?.dine_in_tax !== undefined
        ? Number(activeOrder.dine_in_detail.dine_in_tax)
        : Number(activeOrder?.tax_amount ?? 0);

    return {
      id: table.id,
      table_number: table.table_number,
      name: table.name,
      capacity: table.capacity,
      section: table.section,
      zone_id: table.zone_id,
      status,
      current_customer_count: effectiveOccupied ? table.current_customer_count : 0,
      current_bill_amount: effectiveOccupied ? Number(activeOrder?.grand_total ?? 0) : 0,
      active_order_id: effectiveOccupied ? (table.active_order_id || activeOrder?.id || null) : null,
      active_order_number: effectiveOccupied ? (activeOrder?.order_number || null) : null,
      dine_in_tax: effectiveOccupied ? dineInTax : 0,
      discount_amount: effectiveOccupied ? Number(activeOrder?.discount_amount ?? 0) : 0,
      discount_percentage: effectiveOccupied ? Number(activeOrder?.discount_percentage ?? 0) : 0,
      occupied_since: effectiveOccupied ? table.occupied_since : null,
      reserved_customer_name: reservedCustomerName,
      reservation_time: reservationTime,
      current_order_items: activeItems,
    };
  }

  async createTable(dto: CreateTableDto): Promise<RestaurantTable> {
    const trimmedName = dto.name.trim();
    const trimmedNumber = (dto.table_number || dto.name).trim();

    const existing = await this.prisma.restaurantTable.findFirst({
      where: {
        OR: [
          { table_number: { equals: trimmedNumber, mode: 'insensitive' } },
          { name: { equals: trimmedName, mode: 'insensitive' } },
        ],
      },
    });

    if (existing) {
      throw new ConflictException(
        `Table with name '${trimmedName}' or number '${trimmedNumber}' already exists!`,
      );
    }

    const created = await this.prisma.restaurantTable.create({
      data: {
        table_number: trimmedNumber,
        name: trimmedName,
        capacity: dto.capacity,
        section: dto.section ?? 'Hall',
        status: dto.status ?? 'available',
      },
    });

    this.logger.log(
      `Created table '${created.name}' (${created.table_number}) in ${created.section}`,
    );
    return created;
  }

  async updateTable(id: string, dto: UpdateTableDto): Promise<RestaurantTable> {
    const existing = await this.prisma.restaurantTable.findUnique({
      where: { id },
    });

    if (!existing) {
      throw new NotFoundException(`Restaurant table with ID '${id}' not found`);
    }

    const trimmedName = dto.name?.trim();
    const trimmedNumber = dto.table_number?.trim();

    if (trimmedName || trimmedNumber) {
      const duplicate = await this.prisma.restaurantTable.findFirst({
        where: {
          id: { not: id },
          OR: [
            ...(trimmedNumber ? [{ table_number: { equals: trimmedNumber, mode: 'insensitive' as const } }] : []),
            ...(trimmedName ? [{ name: { equals: trimmedName, mode: 'insensitive' as const } }] : []),
          ],
        },
      });

      if (duplicate) {
        throw new ConflictException(
          `Another table with name '${trimmedName || duplicate.name}' or number '${trimmedNumber || duplicate.table_number}' already exists!`,
        );
      }
    }

    const updated = await this.prisma.restaurantTable.update({
      where: { id },
      data: {
        table_number: trimmedNumber ?? existing.table_number,
        name: trimmedName ?? existing.name,
        capacity: dto.capacity ?? existing.capacity,
        section: dto.section ?? existing.section,
        status: dto.status ?? existing.status,
        current_customer_count:
          dto.current_customer_count !== undefined
            ? dto.current_customer_count
            : existing.current_customer_count,
        current_bill_amount:
          dto.current_bill_amount !== undefined
            ? dto.current_bill_amount
            : existing.current_bill_amount,
        active_order_id:
          dto.active_order_id !== undefined ? dto.active_order_id : existing.active_order_id,
      },
    });

    this.logger.log(`Updated table '${updated.name}' (${id})`);
    return updated;
  }

  async updateTableStatus(id: string, dto: UpdateTableStatusDto): Promise<RestaurantTable> {
    const existing = await this.prisma.restaurantTable.findUnique({
      where: { id },
    });

    if (!existing) {
      throw new NotFoundException(`Restaurant table with ID '${id}' not found`);
    }

    const data: Prisma.RestaurantTableUpdateInput = {
      status: dto.status,
    };

    if (dto.status === 'occupied') {
      data.occupied_since = existing.occupied_since ?? new Date();
      if (dto.active_order_id !== undefined) {
        data.active_order_id = dto.active_order_id;
      }
      if (dto.current_bill_amount !== undefined) {
        data.current_bill_amount = dto.current_bill_amount;
      }
      if (dto.current_customer_count !== undefined) {
        data.current_customer_count = dto.current_customer_count;
      }
    } else if (dto.status === 'available') {
      data.occupied_since = null;
      data.active_order_id = null;
      data.current_bill_amount = 0.0;
      data.current_customer_count = 0;
      data.reserved_customer_name = null;
      data.reservation_time = null;
    }

    const updated = await this.prisma.restaurantTable.update({
      where: { id },
      data,
    });

    this.logger.log(`Updated table '${updated.name}' status to '${dto.status}'`);
    return updated;
  }

  async releaseTable(id: string): Promise<RestaurantTable> {
    const existing = await this.prisma.restaurantTable.findUnique({
      where: { id },
    });

    if (!existing) {
      throw new NotFoundException(`Restaurant table with ID '${id}' not found`);
    }

    const updated = await this.prisma.restaurantTable.update({
      where: { id },
      data: {
        status: 'available',
        active_order_id: null,
        occupied_since: null,
        current_bill_amount: 0.0,
        current_customer_count: 0,
        reserved_customer_name: null,
        reservation_time: null,
      },
    });

    this.logger.log(`Released table '${updated.name}' (${id}) to available`);
    return updated;
  }

  async transferTable(
    dto: TransferTableDto,
  ): Promise<{ fromTable: RestaurantTable; toTable: RestaurantTable }> {
    if (dto.from_table_id === dto.to_table_id) {
      throw new BadRequestException('Source and destination tables must be different');
    }

    return this.prisma.$transaction(async (tx) => {
      const fromTable = await tx.restaurantTable.findUnique({
        where: { id: dto.from_table_id },
      });

      if (!fromTable) {
        throw new NotFoundException(`Source table with ID '${dto.from_table_id}' not found`);
      }

      if (fromTable.status !== 'occupied') {
        throw new BadRequestException(`Source table '${fromTable.name}' is not occupied`);
      }

      const toTable = await tx.restaurantTable.findUnique({
        where: { id: dto.to_table_id },
      });

      if (!toTable) {
        throw new NotFoundException(`Destination table with ID '${dto.to_table_id}' not found`);
      }

      if (toTable.status === 'occupied') {
        throw new ConflictException(`Destination table '${toTable.name}' is already occupied`);
      }

      // Find active order ID or any active unpaid dine_in_order_details attached to source table
      let activeOrderId = fromTable.active_order_id;

      const activeDineInOrders = tx.dineInOrderDetail?.findMany
        ? await tx.dineInOrderDetail.findMany({
            where: {
              table_id: fromTable.id,
              order: {
                is_paid: false,
                status: { notIn: ['completed', 'cancelled', 'rejected'] },
              },
            },
            include: { order: true },
          })
        : [];

      if (!activeOrderId && activeDineInOrders.length > 0) {
        activeOrderId = activeDineInOrders[0].order_id;
      }

      // Reassign all active dine-in order details to destination table
      if (activeOrderId) {
        await tx.dineInOrderDetail.updateMany({
          where: { order_id: activeOrderId },
          data: { table_id: toTable.id },
        });
      }

      for (const d of activeDineInOrders) {
        if (d.order_id !== activeOrderId) {
          await tx.dineInOrderDetail.updateMany({
            where: { id: d.id },
            data: { table_id: toTable.id },
          });
        }
      }

      const effectiveBill =
        Number(fromTable.current_bill_amount) > 0
          ? fromTable.current_bill_amount
          : activeDineInOrders.length > 0
          ? activeDineInOrders[0].order.grand_total
          : new Prisma.Decimal(0);

      // Update destination table
      const updatedTo = await tx.restaurantTable.update({
        where: { id: toTable.id },
        data: {
          status: 'occupied',
          active_order_id: activeOrderId,
          current_bill_amount: effectiveBill,
          current_customer_count: fromTable.current_customer_count,
          occupied_since: fromTable.occupied_since ?? new Date(),
        },
      });

      // Release source table
      const updatedFrom = await tx.restaurantTable.update({
        where: { id: fromTable.id },
        data: {
          status: 'available',
          active_order_id: null,
          current_bill_amount: new Prisma.Decimal(0.0),
          current_customer_count: 0,
          occupied_since: null,
        },
      });

      this.logger.log(`Transferred dining session from '${fromTable.name}' to '${toTable.name}'`);

      return { fromTable: updatedFrom, toTable: updatedTo };
    });
  }

  async updateTableReservation(id: string, dto: TableReservationDto): Promise<RestaurantTable> {
    const existing = await this.prisma.restaurantTable.findUnique({
      where: { id },
    });

    if (!existing) {
      throw new NotFoundException(`Restaurant table with ID '${id}' not found`);
    }

    let status = existing.status;
    let reservedName: string | null = null;
    let reservationTime: Date | null = null;

    if (dto.reserved_customer_name) {
      status = 'reserved';
      reservedName = dto.reserved_customer_name;
      reservationTime = dto.reservation_time ? new Date(dto.reservation_time) : new Date();
    } else {
      if (existing.status === 'reserved') {
        status = 'available';
      }
    }

    const updated = await this.prisma.restaurantTable.update({
      where: { id },
      data: {
        status,
        reserved_customer_name: reservedName,
        reservation_time: reservationTime,
      },
    });

    this.logger.log(
      `Updated reservation for table '${updated.name}' - Reserved for '${reservedName ?? 'None'}'`,
    );
    return updated;
  }

  async deleteTable(idOrNumber: string): Promise<{ message: string }> {
    const existing = await this.prisma.restaurantTable.findFirst({
      where: {
        OR: [
          { id: idOrNumber },
          { table_number: idOrNumber },
          { name: { equals: idOrNumber, mode: 'insensitive' } },
        ],
      },
    });

    if (!existing) {
      throw new NotFoundException(`Restaurant table '${idOrNumber}' not found`);
    }

    if (existing.status === 'occupied' || existing.active_order_id) {
      throw new ConflictException(
        `Cannot delete table '${existing.name}' while it is currently occupied`,
      );
    }

    // Protect historical order integrity: if any dine-in orders reference this table,
    // block deletion because table_id is non-nullable on dine_in_order_details.
    // Deleting these rows would destroy permanent historical records.
    const linkedOrderCount = await this.prisma.dineInOrderDetail.count({
      where: { table_id: existing.id },
    });

    if (linkedOrderCount > 0) {
      throw new ConflictException(
        `Cannot delete table '${existing.name}' because it has ${linkedOrderCount} historical order record(s). ` +
        `Historical records must be preserved. Consider deactivating the table instead.`,
      );
    }

    await this.prisma.restaurantTable.delete({
      where: { id: existing.id },
    });

    this.logger.log(`Deleted table '${existing.name}' (${existing.id}) from database`);
    return { message: `Table '${existing.name}' deleted successfully from database` };
  }

  // ----------------------------------------------------
  // FLOOR ZONES MANAGEMENT (floor_zones table)
  // ----------------------------------------------------
  async listZones(): Promise<any[]> {
    return this.prisma.floorZone.findMany({
      orderBy: { created_at: 'asc' },
      include: {
        _count: {
          select: { tables: true },
        },
      },
    });
  }

  async createZone(name: string): Promise<any> {
    const trimmed = name.trim();
    if (!trimmed) {
      throw new BadRequestException('Zone name cannot be empty');
    }

    const existing = await this.prisma.floorZone.findUnique({
      where: { name: trimmed },
    });

    if (existing) {
      return existing;
    }

    const created = await this.prisma.floorZone.create({
      data: { name: trimmed },
    });

    this.logger.log(`Created new floor zone '${created.name}' (${created.id})`);
    return created;
  }

  async deleteZone(idOrName: string): Promise<{ message: string }> {
    const zone = await this.prisma.floorZone.findFirst({
      where: {
        OR: [
          { id: idOrName },
          { name: { equals: idOrName, mode: 'insensitive' } },
        ],
      },
      include: {
        tables: true,
      },
    });

    if (!zone) {
      throw new NotFoundException(`Floor zone '${idOrName}' not found`);
    }

    // Check if any tables in this zone are occupied
    const occupied = zone.tables.find((t) => t.status === 'occupied');
    if (occupied) {
      throw new ConflictException(
        `Cannot delete zone '${zone.name}' because table '${occupied.name}' is currently occupied`,
      );
    }

    // Delete associated tables in this zone
    await this.prisma.restaurantTable.deleteMany({
      where: {
        OR: [
          { zone_id: zone.id },
          { section: { equals: zone.name, mode: 'insensitive' } },
        ],
      },
    });

    // Delete the floor zone
    await this.prisma.floorZone.delete({
      where: { id: zone.id },
    });

    this.logger.log(`Deleted floor zone '${zone.name}' and its tables`);
    return { message: `Floor zone '${zone.name}' and all its tables deleted successfully` };
  }
}
