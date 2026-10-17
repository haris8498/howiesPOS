import { Body, Controller, Get, Param, Post, Query } from '@nestjs/common';
import { SyncService } from './sync.service';
import { BatchSyncOrdersDto, CreateSyncLogDto, ToggleSyncStatusDto } from './dto/sync-order.dto';

@Controller('sync')
export class SyncController {
  constructor(private readonly syncService: SyncService) {}

  /**
   * GET /api/sync/overview
   * Returns list of orders with sync status and KPI metrics (Total Orders, Revenue, Synced, Pending)
   */
  @Get('overview')
  async getSyncOverview(
    @Query('sync_status') syncStatus?: string,
    @Query('order_type') orderType?: string,
    @Query('search') search?: string,
  ) {
    const data = await this.syncService.getSyncOverview({
      sync_status: syncStatus,
      order_type: orderType,
      search,
    });
    return {
      success: true,
      data,
    };
  }

  /**
   * POST /api/sync/order/:id
   * Syncs a single pending order to Cloud
   */
  @Post('order/:id')
  async syncSingleOrder(@Param('id') id: string) {
    const data = await this.syncService.syncSingleOrder(id);
    return {
      success: true,
      data,
    };
  }

  /**
   * POST /api/sync/batch
   * Upload batch of offline orders from SQLite to Cloud PostgreSQL
   */
  @Post('batch')
  async syncBatchOrders(@Body() dto: BatchSyncOrdersDto) {
    const data = await this.syncService.syncBatchOrders(dto);
    return {
      success: true,
      data,
    };
  }

  /**
   * POST /api/sync/toggle/:id
   * Toggles sync status between pending and synced for offline demo and verification
   */
  @Post('toggle/:id')
  async toggleSyncStatus(
    @Param('id') id: string,
    @Body() dto: ToggleSyncStatusDto,
  ) {
    const data = await this.syncService.toggleSyncStatus(id, dto);
    return {
      success: true,
      data,
    };
  }

  /**
   * POST /api/sync/log
   * Records a data sync log event into PostgreSQL database
   */
  @Post('log')
  async createSyncLog(@Body() dto: CreateSyncLogDto) {
    const data = await this.syncService.createSyncLog(dto);
    return {
      success: true,
      data,
    };
  }

  /**
   * GET /api/sync/logs
   * Returns sync audit logs
   */
  @Get('logs')
  async getSyncLogs() {
    const data = await this.syncService.getSyncLogs();
    return {
      success: true,
      data,
    };
  }
}

