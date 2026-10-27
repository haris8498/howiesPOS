import { Module } from '@nestjs/common';
import { TablesController } from './tables.controller';
import { TablesService } from './tables.service';
import { ChangeLogService } from '../sync/change-log.service';

@Module({
  controllers: [TablesController],
  providers: [TablesService, ChangeLogService],
  exports: [TablesService],
})
export class TablesModule {}
