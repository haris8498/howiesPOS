import { Module } from '@nestjs/common';
import { DailyCalculationController } from './daily-calculation.controller';
import { DailyCalculationService } from './daily-calculation.service';
import { PrismaModule } from '../prisma/prisma.module';
import { PermissionsModule } from '../permissions/permissions.module';

@Module({
  imports: [PrismaModule, PermissionsModule],
  controllers: [DailyCalculationController],
  providers: [DailyCalculationService],
  exports: [DailyCalculationService],
})
export class DailyCalculationModule {}
