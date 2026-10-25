import { CurrentUser } from '../common/decorators/current-user.decorator';
import {
  Body,
  Controller,
  Get,
  Param,
  Post,
  Query,
  Req,
  Res,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { Request, Response } from 'express';
import * as zlib from 'zlib';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { IdempotencyInterceptor } from './interceptors/idempotency.interceptor';
import { SyncService } from './sync.service';
import { SyncPushService } from './sync-push.service';
import { SyncPullService } from './sync-pull.service';
import { SyncPushDto } from './dto/sync-push.dto';
import { SyncPullDto } from './dto/sync-pull.dto';
import {
  BatchSyncOrdersDto,
  CreateSyncLogDto,
  ToggleSyncStatusDto,
} from './dto/sync-order.dto';

@Controller('sync')
@UseGuards(JwtAuthGuard)
export class SyncController {
  constructor(
    private readonly syncService: SyncService,
    private readonly syncPushService: SyncPushService,
    private readonly syncPullService: SyncPullService,
  ) {}

  /**
   * POST /api/sync/push
   * Ingest offline mutations batch (§8.1.1)
   */
  @Post('push')
  @UseInterceptors(IdempotencyInterceptor)
  async pushMutations(@Body() dto: SyncPushDto) {
    return this.syncPushService.pushMutations(dto);
  }

  /**
   * GET /api/sync/pull
   * Incremental delta replication stream (§8.1.2)
   */
  @Get('pull')
  async pullChanges(@Query() query: SyncPullDto) {
    return this.syncPullService.pullChanges(query);
  }

  /**
   * GET /api/sync/bootstrap
   * Cold-start catalog & layout snapshot (§8.1.3), returned gzipped
   */
  @Get('bootstrap')
  async getBootstrap(
    @Req() req: Request,
    @Res() res: Response,
    @Query('raw') raw?: string,
  ) {
    const data = await this.syncPullService.getBootstrapData();

    // Check if client explicitly requested uncompressed JSON with raw=true
    if (raw === 'true') {
      return res.json(data);
    }

    // Default is gzipped payload as specified in §8.1.3
    const jsonStr = JSON.stringify(data);
    const gzipped = zlib.gzipSync(Buffer.from(jsonStr, 'utf-8'));

    res.setHeader('Content-Type', 'application/json');
    res.setHeader('Content-Encoding', 'gzip');
    res.setHeader('Vary', 'Accept-Encoding');
    return res.send(gzipped);
  }

  // ───────────────────────────────────────────────────────────────────────────
  // LEGACY ENDPOINTS (Preserved for backwards compatibility with existing UI)
  // ───────────────────────────────────────────────────────────────────────────

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
    return { success: true, data };
  }

  @Post('order/:id')
  async syncSingleOrder(@Param('id') id: string) {
    const data = await this.syncService.syncSingleOrder(id);
    return { success: true, data };
  }

  @Post('batch')
  async syncBatchOrders(@Body() dto: BatchSyncOrdersDto) {
    const data = await this.syncService.syncBatchOrders(dto);
    return { success: true, data };
  }

  @Post('toggle/:id')
  async toggleSyncStatus(
    @Param('id') id: string,
    @Body() dto: ToggleSyncStatusDto,
  ) {
    const data = await this.syncService.toggleSyncStatus(id, dto);
    return { success: true, data };
  }

  @Post('log')
  async createSyncLog(@Body() dto: CreateSyncLogDto) {
    const data = await this.syncService.createSyncLog(dto);
    return { success: true, data };
  }

  @Get('logs')
  async getSyncLogs() {
    const data = await this.syncService.getSyncLogs();
    return { success: true, data };
  }

  @Get('modules')
  async getSyncModulesStatus() {
    return this.syncService.getSyncModulesStatus();
  }

  @Get('history')
  async getSyncHistory(
    @Query('page') page?: string,
    @Query('limit') limit?: string,
    @Query('module') moduleName?: string,
    @Query('status') status?: string,
    @Query('search') search?: string,
  ) {
    return this.syncService.getSyncHistory({
      page: page ? parseInt(page, 10) : 1,
      limit: limit ? parseInt(limit, 10) : 30,
      module: moduleName,
      status,
      search,
    });
  }

  @Get('conflicts')
  async getSyncConflicts() {
    return this.syncService.getSyncConflicts();
  }
  /**
   * GET /api/sync/cashier-shifts
   * Cashier's own shift history (RBAC protected)
   */
  @Get('cashier-shifts')
  async getCashierShifts(@CurrentUser() user: any) {
    const userId = user?.id || user?.userId || '';
    const username = user?.username;
    const data = await this.syncService.getCashierShifts(userId, username);
    return { success: true, data };
  }

  /**
   * GET /api/sync/cashier-shift/:shiftId
   * Shift-First synchronization details for Cashier
   */
  @Get('cashier-shift/:shiftId')
  async getCashierShiftDetails(
    @Param('shiftId') shiftId: string,
    @CurrentUser() user: any,
  ) {
    const userId = user?.id || user?.userId || '';
    const username = user?.username;
    const role = user?.role;
    const data = await this.syncService.getCashierShiftDetails(
      shiftId,
      userId,
      username,
      role,
    );
    return { success: true, data };
  }
}
