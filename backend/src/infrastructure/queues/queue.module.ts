import { Global, Module } from '@nestjs/common';
import { RedisModule } from '../redis/redis.module';
import { QueueService } from './queue.service';
import { SystemWorker } from './workers/system.worker';

@Global()
@Module({
  imports: [RedisModule],
  providers: [QueueService, SystemWorker],
  exports: [QueueService, SystemWorker],
})
export class QueueModule {}
