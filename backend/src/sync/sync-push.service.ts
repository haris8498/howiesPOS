import {
  Injectable,
  Logger,
  ConflictException,
  Optional,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { HandlerRegistry } from './handlers/handler-registry.service';
import { SyncPushDto } from './dto/sync-push.dto';
import {
  SyncMutationResult,
  SyncMutationContext,
} from './handlers/sync-entity.handler';
import { KitchenGateway } from '../kitchen/kitchen.gateway';

@Injectable()
export class SyncPushService {
  private readonly logger = new Logger(SyncPushService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly handlerRegistry: HandlerRegistry,
    @Optional() private readonly kitchenGateway?: KitchenGateway,
  ) {}

  /**
   * Ingest a batch of offline mutations.
   * Sorts mutations by dependency_order ASC, created_at ASC.
   * Processes each mutation in its own isolated database transaction so that
   * one failed mutation does not poison the batch.
   */
  async pushMutations(dto: SyncPushDto) {
    const { device_id, batch_id, mutations = [] } = dto;
    const results: SyncMutationResult[] = [];

    // Sort mutations in topological dependency_order then created_at
    const sortedMutations = [...mutations].sort((a, b) => {
      const orderA = a.dependency_order ?? 1;
      const orderB = b.dependency_order ?? 1;
      if (orderA !== orderB) {
        return orderA - orderB;
      }
      const timeA = a.created_at ? new Date(a.created_at).getTime() : 0;
      const timeB = b.created_at ? new Date(b.created_at).getTime() : 0;
      return timeA - timeB;
    });

    this.logger.log(
      `Processing sync batch ${batch_id} from device ${device_id} with ${sortedMutations.length} mutations`,
    );

    for (const mutation of sortedMutations) {
      const context: SyncMutationContext = {
        deviceId: device_id,
        operationId: mutation.operation_id,
        batchId: batch_id,
        receivedAt: new Date(),
      };

      const handler = this.handlerRegistry.get(mutation.entity_type);
      if (!handler) {
        this.logger.warn(
          `No sync entity handler found for '${mutation.entity_type}'`,
        );
        results.push({
          operation_id: mutation.operation_id,
          entity_id: mutation.entity_id,
          status: 'FAILED_FATAL',
          server_version: mutation.base_version ?? 1,
          server_timestamp: new Date().toISOString(),
          error_message: `No sync entity handler registered for entity_type '${mutation.entity_type}'`,
        });
        continue;
      }

      // Process EACH mutation in its own isolated database transaction
      try {
        const result = await this.prisma.$transaction(async (tx) => {
          return await handler.handle(tx, mutation, context);
        });
        results.push(result);
      } catch (err: any) {
        this.logger.error(
          `Mutation ${mutation.operation_id} (${mutation.entity_type}:${mutation.entity_id}) failed: ${err.message}`,
        );

        const isConflict =
          err instanceof ConflictException ||
          err?.code === 'P2002' ||
          (err.message && err.message.toLowerCase().includes('already exists')) ||
          (err.message && err.message.toLowerCase().includes('conflict'));

        results.push({
          operation_id: mutation.operation_id,
          entity_id: mutation.entity_id,
          status: isConflict ? 'CONFLICT' : 'FAILED_FATAL',
          server_version: mutation.base_version ?? 1,
          server_timestamp: new Date().toISOString(),
          error_message: err.message || 'Transaction execution failed',
        });
      }
    }

    return {
      success: true,
      batch_id,
      processed_count: results.length,
      results,
    };
  }
}
