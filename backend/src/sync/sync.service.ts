import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { BatchSyncOrdersDto, CreateSyncLogDto, ToggleSyncStatusDto } from './dto/sync-order.dto';

@Injectable()
export class SyncService {
  private readonly logger = new Logger(SyncService.name);

  constructor(private readonly prisma: PrismaService) {}

  /**
   * Get Live Synchronization Ledger & KPI Metrics
   */
  async getSyncOverview(params?: {
    sync_status?: string;
    order_type?: string;
    search?: string;
  }) {
    const orders = await this.prisma.order.findMany({
      orderBy: { created_at: 'desc' },
      include: {
        order_items: true,
        online_detail: true,
        takeaway_detail: true,
        dine_in_detail: {
          include: {
            table: true,
          },
        },
        payments: true,
      },
    });

    // 1. Calculate Universal KPIs
    let totalRevenue = 0;
    let syncedCount = 0;
    let pendingCount = 0;

    const mappedOrders = orders.map((ord) => {
      const grandTotalNum = Number(ord.grand_total) || 0;
      totalRevenue += grandTotalNum;

      const isSynced = (ord as any).is_synced !== false && (ord as any).sync_status !== 'pending';
      if (isSynced) {
        syncedCount++;
      } else {
        pendingCount++;
      }

      // Customer name extraction
      let customerName = 'Table Guest';
      let tableOrDetails = 'General';
      let normalizedType = 'Dine-In';

      if (ord.order_type === 'dineIn' || ord.order_type === 'dine_in') {
        normalizedType = 'Dine-In';
        const tName = ord.dine_in_detail?.table?.name || 'Table';
        const tSec = ord.dine_in_detail?.table?.section || 'Family Hall';
        tableOrDetails = `${tSec} ${tName}`;
        customerName = 'Table Guest';
      } else if (ord.order_type === 'takeaway') {
        normalizedType = 'Takeaway';
        const token = ord.takeaway_detail?.token_number || ord.order_number;
        tableOrDetails = `Token #${token}`;
        customerName = ord.takeaway_detail?.customer_name || 'Walk-in Guest';
      } else if (ord.order_type === 'online' || ord.order_type === 'delivery') {
        normalizedType = 'Delivery';
        tableOrDetails = ord.online_detail?.delivery_address || 'Direct Delivery';
        customerName = ord.online_detail?.customer_name || 'Delivery Customer';
      }

      // Format items list (mark cancelled items with prefix)
      const itemsSummary = ord.order_items
        .map((it) => it.is_cancelled
          ? `[CANCELLED]${it.quantity}x ${it.item_name}`
          : `${it.quantity}x ${it.item_name}`)
        .join(', ');

      // Payment details
      const isPaid = ord.is_paid || ord.payment_status === 'PAID';
      const paymentMethod = ord.payments.length > 0 ? ord.payments[0].payment_method : 'Cash';

      return {
        id: ord.id,
        order_number: ord.order_number,
        order_type: normalizedType,
        raw_order_type: ord.order_type,
        type_and_table: tableOrDetails,
        customer_name: customerName,
        items_summary: itemsSummary.length > 0 ? itemsSummary : 'Itemized Order',
        payment_method: paymentMethod,
        payment_status: isPaid ? 'PAID' : 'UNPAID',
        is_paid: isPaid,
        total_amount: grandTotalNum,
        created_at: ord.created_at,
        sync_status: (ord as any).sync_status || (isSynced ? 'synced' : 'pending'),
        is_synced: isSynced,
        synced_at: (ord as any).synced_at || (isSynced ? ord.created_at : null),
        local_sqlite_id: (ord as any).local_sqlite_id || `SQLITE-${ord.order_number}`,
        device_id: (ord as any).device_id || 'POS-TERMINAL-01',
        source_storage: 'SQLite Local',
        target_storage: 'PostgreSQL Cloud',
      };
    });

    // 2. Apply Filters if provided
    let filtered = mappedOrders;

    if (params?.sync_status && params.sync_status !== 'all') {
      const wanted = params.sync_status.toLowerCase();
      filtered = filtered.filter((o) => o.sync_status.toLowerCase() === wanted);
    }

    if (params?.order_type && params.order_type !== 'all') {
      const wantedType = params.order_type.toLowerCase();
      filtered = filtered.filter((o) => {
        const oType = o.order_type.toLowerCase();
        if (wantedType.includes('dine') && oType.includes('dine')) return true;
        if (wantedType.includes('takeaway') && oType.includes('takeaway')) return true;
        if (wantedType.includes('delivery') && oType.includes('delivery')) return true;
        return oType === wantedType;
      });
    }

    if (params?.search && params.search.trim().length > 0) {
      const q = params.search.toLowerCase().trim();
      filtered = filtered.filter((o) =>
        o.order_number.toLowerCase().includes(q) ||
        o.customer_name.toLowerCase().includes(q) ||
        o.type_and_table.toLowerCase().includes(q) ||
        o.items_summary.toLowerCase().includes(q)
      );
    }

    // Ensure all existing orders have corresponding sync log entries in data_sync_logs
    try {
      const existingLogsCount = await (this.prisma as any).dataSyncLog.count();
      if (existingLogsCount === 0 && orders.length > 0) {
        for (const ord of orders) {
          try {
            await (this.prisma as any).dataSyncLog.create({
              data: {
                order_id: ord.id,
                order_number: ord.order_number,
                sync_type: 'ORDER',
                sync_status: (ord as any).sync_status || 'synced',
                is_synced: (ord as any).is_synced !== false,
                source_storage: 'SQLite Local',
                target_storage: 'PostgreSQL Cloud',
                synced_at: (ord as any).synced_at || ord.created_at,
                created_at: ord.created_at,
                device_id: (ord as any).device_id || 'POS-TERMINAL-01',
                payload_json: JSON.stringify({
                  order_number: ord.order_number,
                  order_type: ord.order_type,
                  grand_total: Number(ord.grand_total),
                  action: 'INITIAL_SYNC',
                }),
              },
            });
          } catch (itemErr: any) {
            this.logger.warn(`Could not seed initial sync log for order #${ord.order_number}: ${itemErr?.message}`);
          }
        }
      }
    } catch (backfillErr: any) {
      this.logger.warn(`Could not backfill initial sync logs: ${backfillErr?.message}`);
    }

    return {
      summary: {
        total_orders: orders.length,
        total_revenue: totalRevenue,
        synced_count: syncedCount,
        pending_count: pendingCount,
        last_sync_timestamp: new Date().toISOString(),
        sqlite_storage_status: 'HEALTHY',
        cloud_storage_status: 'CONNECTED',
      },
      orders: filtered,
    };
  }

  /**
   * Sync a single order to Cloud and persist sync audit log
   */
  async syncSingleOrder(orderId: string) {
    const order = await this.prisma.order.findUnique({
      where: { id: orderId },
      include: { order_items: true },
    });

    if (!order) {
      throw new NotFoundException(`Order with ID ${orderId} not found`);
    }

    const now = new Date();

    const updated = await this.prisma.order.update({
      where: { id: orderId },
      data: {
        sync_status: 'synced',
        is_synced: true,
        synced_at: now,
      } as any,
    });

    // Create sync log
    try {
      await (this.prisma as any).dataSyncLog.create({
        data: {
          order_id: order.id,
          order_number: order.order_number,
          sync_type: 'ORDER',
          sync_status: 'synced',
          is_synced: true,
          source_storage: 'SQLite Local',
          target_storage: 'PostgreSQL Cloud',
          synced_at: now,
          device_id: (order as any).device_id || 'POS-TERMINAL-01',
          payload_json: JSON.stringify({
            order_number: order.order_number,
            grand_total: Number(order.grand_total),
            items_count: order.order_items ? order.order_items.length : 0,
            action: 'MANUAL_SYNC',
          }),
        },
      });
      this.logger.log(`Created dataSyncLog for order #${order.order_number}`);
    } catch (logErr: any) {
      this.logger.warn(`Could not create dataSyncLog for order #${order.order_number}: ${logErr?.message ?? logErr}`);
    }

    return {
      success: true,
      message: `Order #${order.order_number} successfully synchronized to Cloud database.`,
      order: updated,
    };
  }

  /**
   * Batch upload pending orders from local SQLite to PostgreSQL Cloud and persist logs
   */
  async syncBatchOrders(dto: BatchSyncOrdersDto) {
    const results = [];
    const now = new Date();

    for (const ord of dto.orders) {
      const orderId = ord.id || ord.order_id;
      if (!orderId) continue;

      try {
        const updated = await this.prisma.order.update({
          where: { id: orderId },
          data: {
            sync_status: 'synced',
            is_synced: true,
            synced_at: now,
            device_id: dto.device_id || 'POS-TERMINAL-01',
          } as any,
        });

        results.push({ order_id: orderId, status: 'synced' });

        try {
          await (this.prisma as any).dataSyncLog.create({
            data: {
              order_id: updated.id,
              order_number: updated.order_number,
              sync_type: 'ORDER',
              sync_status: 'synced',
              is_synced: true,
              source_storage: 'SQLite Local',
              target_storage: 'PostgreSQL Cloud',
              synced_at: now,
              device_id: dto.device_id || (updated as any).device_id || 'POS-TERMINAL-01',
              payload_json: JSON.stringify({
                order_number: updated.order_number,
                grand_total: Number(updated.grand_total),
                action: 'BATCH_SYNC',
              }),
            },
          });
          this.logger.log(`Created dataSyncLog for batch order #${updated.order_number}`);
        } catch (logErr: any) {
          this.logger.warn(`Could not create dataSyncLog for batch order #${updated.order_number}: ${logErr?.message ?? logErr}`);
        }
      } catch (err: any) {
        results.push({ order_id: orderId, status: 'failed', error: err.message });
      }
    }

    return {
      success: true,
      synced_count: results.filter((r) => r.status === 'synced').length,
      failed_count: results.filter((r) => r.status === 'failed').length,
      results,
    };
  }

  /**
   * Toggle order sync status between 'pending' and 'synced' and store audit log in database
   */
  async toggleSyncStatus(orderId: string, dto?: ToggleSyncStatusDto) {
    const order = await this.prisma.order.findUnique({
      where: { id: orderId },
    });

    if (!order) {
      throw new NotFoundException(`Order with ID ${orderId} not found`);
    }

    const currentStatus = (order as any).sync_status || 'synced';
    const newStatus = dto?.status || (currentStatus === 'synced' ? 'pending' : 'synced');
    const isSynced = newStatus === 'synced';
    const now = new Date();

    const updated = await this.prisma.order.update({
      where: { id: orderId },
      data: {
        sync_status: newStatus,
        is_synced: isSynced,
        synced_at: isSynced ? now : null,
      } as any,
    });

    // Create sync log for toggle event
    try {
      await (this.prisma as any).dataSyncLog.create({
        data: {
          order_id: updated.id,
          order_number: updated.order_number,
          sync_type: 'ORDER',
          sync_status: newStatus,
          is_synced: isSynced,
          source_storage: 'SQLite Local',
          target_storage: 'PostgreSQL Cloud',
          synced_at: isSynced ? now : null,
          device_id: (updated as any).device_id || 'POS-TERMINAL-01',
          payload_json: JSON.stringify({
            order_number: updated.order_number,
            action: isSynced ? 'ORDER_SYNCED' : 'ORDER_MARKED_PENDING',
            grand_total: Number(updated.grand_total),
          }),
        },
      });
      this.logger.log(`Created dataSyncLog for toggled order #${updated.order_number} (${newStatus})`);
    } catch (logErr: any) {
      this.logger.warn(`Could not create dataSyncLog for toggle #${updated.order_number}: ${logErr?.message ?? logErr}`);
    }

    return {
      success: true,
      order_id: order.id,
      order_number: order.order_number,
      sync_status: newStatus,
      is_synced: isSynced,
    };
  }

  /**
   * Directly record a synchronization audit log into database
   */
  async createSyncLog(dto: CreateSyncLogDto) {
    const now = new Date();
    const isSynced = dto.is_synced ?? (dto.sync_status !== 'pending' && dto.sync_status !== 'failed');
    const log = await (this.prisma as any).dataSyncLog.create({
      data: {
        order_id: dto.order_id,
        order_number: dto.order_number || 'SYSTEM',
        sync_type: dto.sync_type || 'ORDER',
        sync_status: dto.sync_status || (isSynced ? 'synced' : 'pending'),
        is_synced: isSynced,
        source_storage: dto.source_storage || 'SQLite Local',
        target_storage: dto.target_storage || 'PostgreSQL Cloud',
        synced_at: isSynced ? now : null,
        device_id: dto.device_id || 'POS-TERMINAL-01',
        error_message: dto.error_message,
        payload_json: dto.payload_json,
      },
    });
    return log;
  }

  /**
   * Get sync audit logs
   */
  async getSyncLogs() {
    try {
      const logs = await (this.prisma as any).dataSyncLog.findMany({
        orderBy: { created_at: 'desc' },
        take: 100,
      });
      return logs;
    } catch (_) {
      return [];
    }
  }
}

