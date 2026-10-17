import { Controller, Get } from '@nestjs/common';
import { HealthCheckResult, HealthService } from './health.service';

@Controller('health')
export class HealthController {
  constructor(private readonly healthService: HealthService) {}

  @Get()
  async check(): Promise<HealthCheckResult> {
    return this.healthService.check();
  }
}
