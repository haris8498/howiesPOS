import { Injectable, Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { Job, Worker } from 'bullmq';
import { RedisService } from '../../redis/redis.service';

export interface SystemJobData {
  jobId?: string;
  type: string;
  orderId?: string;
  meta?: Record<string, unknown>;
  timestamp?: string;
}

@Injectable()
export class SystemWorker implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(SystemWorker.name);
  private worker: Worker<SystemJobData> | null = null;

  constructor(private readonly redisService: RedisService) {}

  onModuleInit() {
    this.initWorker();
  }

  private initWorker() {
    try {
      const connectionOptions = this.redisService.getConnectionOptions();

      this.worker = new Worker<SystemJobData>(
        'system',
        async (job: Job<SystemJobData>) => {
          return this.processJob(job);
        },
        {
          connection: connectionOptions,
          concurrency: 2, // Conservative concurrency for single-branch POS
        },
      );

      this.worker.on('ready', () => {
        this.logger.log('BullMQ SystemWorker ready and listening on queue: system');
      });

      this.worker.on('completed', (job) => {
        this.logger.log(`Job completed: ID ${job.id} [${job.name}]`);
      });

      this.worker.on('failed', (job, err) => {
        this.logger.error(
          `Job failed: ID ${job?.id} [${job?.name}] - Attempt ${job?.attemptsMade}/${job?.opts.attempts}: ${err.message}`,
        );
      });

      this.worker.on('error', (err) => {
        this.logger.warn(`BullMQ SystemWorker connection warning: ${err.message}`);
      });
    } catch (err: unknown) {
      this.logger.warn(`Failed to initialize BullMQ SystemWorker: ${(err as Error).message}`);
    }
  }

  async processJob(job: Job<SystemJobData>): Promise<{ success: boolean; result: string }> {
    this.logger.log(`Processing job ID ${job.id} (${job.name}) with type: ${job.data.type}`);

    switch (job.data.type) {
      case 'AUDIT_LOG':
      case 'NOTIFICATION_DISPATCH':
      case 'PING':
        return {
          success: true,
          result: `Processed ${job.data.type} successfully`,
        };

      default:
        this.logger.log(
          `Executing background task: ${job.data.type} for entity ${job.data.orderId || 'N/A'}`,
        );
        return {
          success: true,
          result: `Standard job ${job.data.type} executed`,
        };
    }
  }

  async onModuleDestroy() {
    if (this.worker) {
      try {
        await this.worker.close();
        this.logger.log('BullMQ SystemWorker closed gracefully');
      } catch (err: unknown) {
        this.logger.warn(`Error closing BullMQ SystemWorker: ${(err as Error).message}`);
      }
    }
  }
}
