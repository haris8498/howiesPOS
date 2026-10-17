import { Module } from '@nestjs/common';
import { SyncController } from './sync.controller';
import { SyncService } from './sync.service';
import { SyncPushService } from './sync-push.service';
import { SyncPullService } from './sync-pull.service';
import { ChangeLogService } from './change-log.service';
import { HandlerRegistry } from './handlers/handler-registry.service';
import { OrderHandler } from './handlers/order.handler';
import { OrdersModule } from '../orders/orders.module';
import { KitchenModule } from '../kitchen/kitchen.module';

import { IdempotencyInterceptor } from './interceptors/idempotency.interceptor';

@Module({
  imports: [OrdersModule, KitchenModule],
  controllers: [SyncController],
  providers: [
    SyncService,
    SyncPushService,
    SyncPullService,
    ChangeLogService,
    HandlerRegistry,
    OrderHandler,
    IdempotencyInterceptor,
  ],
  exports: [
    SyncService,
    SyncPushService,
    SyncPullService,
    ChangeLogService,
    HandlerRegistry,
    OrderHandler,
    IdempotencyInterceptor,
  ],
})
export class SyncModule {}
