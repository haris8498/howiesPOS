import { Module } from '@nestjs/common';
import { PrismaModule } from '../prisma/prisma.module';
import { PermissionsModule } from '../permissions/permissions.module';
import { RidersController } from './riders/riders.controller';
import { RidersService } from './riders/riders.service';
import { DispatchesController } from './dispatches/dispatches.controller';
import { DispatchesService } from './dispatches/dispatches.service';

@Module({
  imports: [PrismaModule, PermissionsModule],
  controllers: [RidersController, DispatchesController],
  providers: [RidersService, DispatchesService],
  exports: [RidersService, DispatchesService],
})
export class DeliveryModule {}
