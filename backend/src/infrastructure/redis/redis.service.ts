import { Injectable, Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import Redis, { RedisOptions } from 'ioredis';

@Injectable()
export class RedisService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(RedisService.name);
  private client: Redis | null = null;
  private isConnected = false;

  constructor(private readonly configService: ConfigService) {}

  onModuleInit() {
    this.initRedis();
  }

  private initRedis() {
    try {
      const redisUrl = this.configService.get<string>('REDIS_URL');
      const host = this.configService.get<string>('REDIS_HOST') || 'localhost';
      const port = Number(this.configService.get<number>('REDIS_PORT')) || 6379;
      const password = this.configService.get<string>('REDIS_PASSWORD') || undefined;

      const redisOptions: RedisOptions = {
        host,
        port,
        password,
        maxRetriesPerRequest: null, // Required by BullMQ
        enableReadyCheck: false,
        retryStrategy: (times) => {
          if (times > 5) {
            this.logger.warn(`Redis connection retry limit reached. Continuing in degraded mode.`);
            return null; // Stop retrying automatically to prevent log flood
          }
          return Math.min(times * 1000, 5000);
        },
        lazyConnect: true,
      };

      if (redisUrl) {
        this.client = new Redis(redisUrl, redisOptions);
      } else {
        this.client = new Redis(redisOptions);
      }

      this.client.on('connect', () => {
        this.isConnected = true;
        this.logger.log(`Redis connected successfully to ${host}:${port}`);
      });

      this.client.on('ready', () => {
        this.isConnected = true;
      });

      this.client.on('error', (err) => {
        this.isConnected = false;
        this.logger.warn(`Redis connection error: ${err.message}`);
      });

      this.client.on('close', () => {
        this.isConnected = false;
        this.logger.log('Redis connection closed');
      });

      // Attempt non-blocking initial connection
      this.client.connect().catch((err: Error) => {
        this.isConnected = false;
        this.logger.warn(
          `Initial Redis connection attempt failed: ${err.message} (Application continuing in degraded mode)`,
        );
      });
    } catch (err: unknown) {
      this.isConnected = false;
      this.logger.warn(`Failed to initialize Redis client: ${(err as Error).message}`);
    }
  }

  getClient(): Redis | null {
    return this.client;
  }

  getConnectionOptions(): RedisOptions {
    const host = this.configService.get<string>('REDIS_HOST') || 'localhost';
    const port = Number(this.configService.get<number>('REDIS_PORT')) || 6379;
    const password = this.configService.get<string>('REDIS_PASSWORD') || undefined;

    return {
      host,
      port,
      password,
      maxRetriesPerRequest: null,
      enableReadyCheck: false,
      retryStrategy: (times) => {
        if (times > 3) return null;
        return Math.min(times * 500, 2000);
      },
    };
  }

  async isHealthy(): Promise<boolean> {
    if (!this.client) {
      return false;
    }
    try {
      const pong = await this.client.ping();
      return pong === 'PONG';
    } catch {
      return false;
    }
  }

  async get(key: string): Promise<string | null> {
    if (!this.client || !this.isConnected) return null;
    try {
      return await this.client.get(key);
    } catch (err: unknown) {
      this.logger.warn(`Redis get error for key '${key}': ${(err as Error).message}`);
      return null;
    }
  }

  async set(key: string, value: string, ttlSeconds?: number): Promise<void> {
    if (!this.client || !this.isConnected) return;
    try {
      if (ttlSeconds) {
        await this.client.set(key, value, 'EX', ttlSeconds);
      } else {
        await this.client.set(key, value);
      }
    } catch (err: unknown) {
      this.logger.warn(`Redis set error for key '${key}': ${(err as Error).message}`);
    }
  }

  async del(key: string): Promise<void> {
    if (!this.client || !this.isConnected) return;
    try {
      await this.client.del(key);
    } catch (err: unknown) {
      this.logger.warn(`Redis del error for key '${key}': ${(err as Error).message}`);
    }
  }

  async onModuleDestroy() {
    if (this.client) {
      try {
        await this.client.quit();
        this.logger.log('Redis client connection closed gracefully on module shutdown');
      } catch (err: unknown) {
        this.logger.warn(`Error during Redis client shutdown: ${(err as Error).message}`);
      }
    }
  }
}
