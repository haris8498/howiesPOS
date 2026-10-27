import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { ChangeLogService } from './change-log.service';
import { SyncPullDto } from './dto/sync-pull.dto';

const ORDER_INCLUDE = {
  order_items: true,
  payments: true,
  online_detail: {
    include: { delivery_dispatch: true },
  },
  takeaway_detail: true,
  dine_in_detail: {
    include: {
      table: { select: { id: true, name: true, table_number: true } },
    },
  },
} as const;

@Injectable()
export class SyncPullService {
  private readonly logger = new Logger(SyncPullService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly changeLogService: ChangeLogService,
  ) {}

  /**
   * Pull incremental delta stream from system_change_logs (§8.1.2).
   * Ordered by global_sequence > cursor ASC.
   */
  async pullChanges(query: SyncPullDto) {
    const rawCursor = query.cursor ? BigInt(query.cursor) : BigInt(0);
    const limit = query.limit
      ? Math.min(Math.max(1, Number(query.limit)), 500)
      : 100;

    const where: any = {
      global_sequence: { gt: rawCursor },
    };

    if (query.entity_type) {
      where.entity_type = query.entity_type.toLowerCase().trim();
    }

    // Query limit + 1 to detect has_more without an extra count query
    const logs = await this.prisma.systemChangeLog.findMany({
      where,
      orderBy: { global_sequence: 'asc' },
      take: limit + 1,
    });

    const hasMore = logs.length > limit;
    const page = hasMore ? logs.slice(0, limit) : logs;
    const nextCursor =
      page.length > 0
        ? Number(page[page.length - 1].global_sequence)
        : Number(rawCursor);

    return {
      success: true,
      cursor: nextCursor,
      next_cursor: nextCursor,
      has_more: hasMore,
      changes: page.map((log) => ({
        sequence: Number(log.global_sequence),
        entity_type: log.entity_type,
        entity_id: log.entity_id,
        operation: log.operation,
        record_version: log.record_version,
        is_deleted: log.is_deleted,
        data: log.payload,
        payload: log.payload,
        created_at: log.created_at.toISOString(),
      })),
    };
  }

  /**
   * Cold-start bootstrap catalog & reference data snapshot (§8.1.3).
   * Gathers all store configuration, RBAC, menu catalog, floor layout,
   * clocked-in riders, active shift, and open orders.
   */
  async getBootstrapData() {
    const maxSeq = await this.changeLogService.getMaxSequence();

    const [
      storeSettings,
      rolePermissions,
      staffUsers,
      categories,
      menuItems,
      menuSizes,
      menuOptions,
      deals,
      floorZones,
      tables,
      riders,
      activeShift,
      activeOrders,
    ] = await Promise.all([
      this.prisma.storeSetting.findMany(),
      this.prisma.rolePermission.findMany(),
      this.prisma.staffUser.findMany({
        select: {
          id: true,
          username: true,
          role: true,
          is_default: true,
          is_active: true,
          last_updated: true,
          updated_by: true,
        },
      }),
      this.prisma.menuCategory.findMany({ orderBy: { name: 'asc' } }),
      this.prisma.menuItem.findMany({
        where: { is_deleted: false },
        orderBy: { name: 'asc' },
      }),
      this.prisma.menuItemSize.findMany(),
      this.prisma.menuItemOption.findMany(),
      this.prisma.deal.findMany({ include: { components: true } }),
      this.prisma.floorZone.findMany({ orderBy: { name: 'asc' } }),
      this.prisma.restaurantTable.findMany({
        where: { is_deleted: false },
        orderBy: { table_number: 'asc' },
      }),
      this.prisma.deliveryRider.findMany({ where: { is_available: true } }),
      this.prisma.dailyCalculation.findFirst({
        where: { status: 'ACTIVE' },
        orderBy: { created_at: 'desc' },
      }),
      this.prisma.order.findMany({
        where: { status: { notIn: ['completed', 'cancelled'] } },
        include: ORDER_INCLUDE,
        take: 100,
        orderBy: { created_at: 'desc' },
      }),
    ]);

    return {
      max_global_sequence: Number(maxSeq),
      server_timestamp: new Date().toISOString(),
      store_settings: storeSettings,
      role_permissions: rolePermissions,
      staff_users: staffUsers,
      categories,
      menu_items: menuItems,
      menu_sizes: menuSizes,
      menu_options: menuOptions,
      deals,
      floor_zones: floorZones,
      tables,
      riders,
      active_shift: activeShift,
      active_orders: activeOrders,
    };
  }
}
