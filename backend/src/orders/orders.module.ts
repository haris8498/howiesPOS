import { forwardRef, Module } from '@nestjs/common';
import { OrdersController } from './orders.controller';
import { OrdersService } from './orders.service';
import { KitchenModule } from '../kitchen/kitchen.module';
import { PricingModule } from '../pricing/pricing.module';

@Module({
  imports: [forwardRef(() => KitchenModule), PricingModule],
  controllers: [OrdersController],
  providers: [OrdersService],
  exports: [OrdersService, PricingModule],
})
export class OrdersModule {}
