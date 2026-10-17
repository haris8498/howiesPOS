import { Injectable, Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { JobsOptions, Queue } from 'bullmq';
import { RedisService } from '../redis/redis.service';
import { SystemJobData } from './workers/system.worker';

@Injectable()
export class QueueService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(QueueService.name);
  private systemQueue: Queue<SystemJobData> | null = null;

  constructor(private readonly redisService: RedisService) {}

  onModuleInit() {
    this.initQueues();
  }

  private initQueues() {
    try {
      const connectionOptions = this.redisService.getConnectionOptions();

      this.systemQueue = new Queue<SystemJobData>('system', {
        connection: connectionOptions,
        defaultJobOptions: {
          attempts: 3,
          backoff: {
            type: 'exponential',
            delay: 2000,
          },
          removeOnComplete: {
            count: 100,
            age: 3600, // 1 hour
          },
          removeOnFail: {
            count: 500,
          },
        },
      });

      this.logger.log('BullMQ system queue initialized');
    } catch (err: unknown) {
      this.logger.warn(`Failed to initialize BullMQ system queue: ${(err as Error).message}`);
    }
  }

  getSystemQueue(): Queue<SystemJobData> | null {
    return this.systemQueue;
  }

  async addSystemJob(name: string, data: SystemJobData, opts?: JobsOptions) {
    if (!this.systemQueue) {
      this.logger.warn(`Cannot enqueue job '${name}': Queue not initialized`);
      return null;
    }

    try {
      const job = await this.systemQueue.add(
        name,
        {
          ...data,
          timestamp: new Date().toISOString(),
        },
        opts,
      );

      this.logger.log(`Added job '${name}' [ID: ${job.id}] to system queue`);
      return job;
    } catch (err: unknown) {
      this.logger.warn(`Failed to add job '${name}' to system queue: ${(err as Error).message}`);
      return null;
    }
  }

  async isHealthy(): Promise<boolean> {
    if (!this.systemQueue) return false;
    try {
      const client = await this.systemQueue.client;
      const pong = await (client as { ping?: () => Promise<string> }).ping?.();
      return pong === 'PONG';
    } catch {
      return false;
    }
  }

  async onModuleDestroy() {
    if (this.systemQueue) {
      try {
        await this.systemQueue.close();
        this.logger.log('BullMQ system queue closed gracefully');
      } catch (err: unknown) {
        this.logger.warn(`Error closing BullMQ system queue: ${(err as Error).message}`);
      }
    }
  }
}
