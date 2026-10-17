import { Injectable, Optional } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { RedisService } from '../infrastructure/redis/redis.service';

export interface HealthCheckResult {
  success: boolean;
  status: string;
  service: string;
  database: 'connected' | 'disconnected';
  redis: 'connected' | 'disconnected';
  timestamp: string;
  uptime: number;
}

@Injectable()
export class HealthService {
  constructor(
    private readonly prisma: PrismaService,
    @Optional() private readonly redisService?: RedisService,
  ) {}

  async check(): Promise<HealthCheckResult> {
    const isDbConnected = await this.prisma.isHealthy();
    const isRedisConnected = this.redisService ? await this.redisService.isHealthy() : false;

    return {
      success: isDbConnected,
      status: isDbConnected ? 'ok' : 'degraded',
      service: 'hungry-howies-pos-api',
      database: isDbConnected ? 'connected' : 'disconnected',
      redis: isRedisConnected ? 'connected' : 'disconnected',
      timestamp: new Date().toISOString(),
      uptime: Math.floor(process.uptime()),
    };
  }
}
