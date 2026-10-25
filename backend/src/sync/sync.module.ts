import { RealtimeModule } from '../realtime/realtime.module';
import { Module } from '@nestjs/common';
import { SyncController } from './sync.controller';
import { SyncService } from './sync.service';
import { SyncPushService } from './sync-push.service';
import { SyncPullService } from './sync-pull.service';
import { ChangeLogService } from './change-log.service';
import { HandlerRegistry } from './handlers/handler-registry.service';
import { OrderHandler } from './handlers/order.handler';
import { TableHandler } from './handlers/table.handler';
import { ShiftHandler } from './handlers/shift.handler';
import { OrdersModule } from '../orders/orders.module';
import { KitchenModule } from '../kitchen/kitchen.module';

import { IdempotencyInterceptor } from './interceptors/idempotency.interceptor';

@Module({
  imports: [OrdersModule, KitchenModule, RealtimeModule],
  controllers: [SyncController],
  providers: [
    SyncService,
    SyncPushService,
    SyncPullService,
    ChangeLogService,
    HandlerRegistry,
    OrderHandler,
    TableHandler,
    ShiftHandler,
    IdempotencyInterceptor,
  ],
  exports: [
    SyncService,
    SyncPushService,
    SyncPullService,
    ChangeLogService,
    HandlerRegistry,
    OrderHandler,
    TableHandler,
    ShiftHandler,
    IdempotencyInterceptor,
  ],
})
export class SyncModule {}
