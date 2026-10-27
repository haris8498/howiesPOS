import { Module } from '@nestjs/common';
import { ScheduleModule } from '@nestjs/schedule';
import { ConfigModule } from '@nestjs/config';
import configuration from './config/configuration';
import { HealthModule } from './health/health.module';
import { PrismaModule } from './prisma/prisma.module';
import { AuthModule } from './auth/auth.module';
import { PermissionsModule } from './permissions/permissions.module';
import { UsersModule } from './users/users.module';
import { StaffModule } from './staff/staff.module';
import { MenuModule } from './menu/menu.module';
import { CustomersModule } from './customers/customers.module';
import { OrdersModule } from './orders/orders.module';
import { TablesModule } from './tables/tables.module';
import { DeliveryModule } from './delivery/delivery.module';
import { InventoryModule } from './inventory/inventory.module';
import { ExpensesModule } from './expenses/expenses.module';
import { SettingsModule } from './settings/settings.module';
import { KitchenModule } from './kitchen/kitchen.module';
import { RedisModule } from './infrastructure/redis/redis.module';
import { QueueModule } from './infrastructure/queues/queue.module';
import { ReportsModule } from './reports/reports.module';
import { DailyCalculationModule } from './daily-calculation/daily-calculation.module';
import { PrinterModule } from './printer/printer.module';
import { SyncModule } from './sync/sync.module';
import { RealtimeModule } from './realtime/realtime.module';
import { PricingModule } from './pricing/pricing.module';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      load: [configuration],
    }),
    ScheduleModule.forRoot(),
    RealtimeModule,
    PrismaModule,
    PermissionsModule,
    AuthModule,
    UsersModule,
    StaffModule,
    MenuModule,
    CustomersModule,
    OrdersModule,
    TablesModule,
    DeliveryModule,
    InventoryModule,
    ExpensesModule,
    DailyCalculationModule,
    SyncModule,
    SettingsModule,
    KitchenModule,
    PrinterModule,
    RedisModule,
    QueueModule,
    ReportsModule,
    HealthModule,
    PricingModule,
  ],
})
export class AppModule {}
