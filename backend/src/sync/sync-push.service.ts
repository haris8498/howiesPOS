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

import * as crypto from 'crypto';
import { canonicalJson } from './interceptors/idempotency.interceptor';

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
      // 1. Check idempotency ledger for this mutation (§8.2, §7.1)
      const existingOp = this.prisma.processedOperation?.findUnique
        ? await this.prisma.processedOperation.findUnique({
            where: { operation_id: mutation.operation_id },
          })
        : null;

      if (existingOp && existingOp.status === 'COMPLETED') {
        const cachedPayload = existingOp.response_payload as any;
        results.push({
          operation_id: mutation.operation_id,
          entity_id: mutation.entity_id,
          status: 'DUPLICATE',
          server_version: cachedPayload?.server_version ?? mutation.base_version ?? 1,
          server_timestamp: (existingOp.completed_at || existingOp.created_at).toISOString(),
        });
        continue;
      }

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

        // Durably record in idempotency ledger (§7.1, §8.2)
        if (this.prisma.processedOperation?.upsert) {
          try {
            const reqHash = crypto
              .createHash('sha256')
              .update(canonicalJson(mutation.payload || {}))
              .digest('hex');

            await this.prisma.processedOperation.upsert({
              where: { operation_id: mutation.operation_id },
              create: {
                operation_id: mutation.operation_id,
                device_id: device_id,
                entity_type: mutation.entity_type,
                entity_id: mutation.entity_id,
                request_hash: reqHash,
                status: 'COMPLETED',
                response_payload: result as any,
                http_status: 200,
                completed_at: new Date(),
              },
              update: {
                status: 'COMPLETED',
                response_payload: result as any,
                completed_at: new Date(),
              },
            });
          } catch (ledgerErr: any) {
            this.logger.warn(
              `Could not update processedOperation for ${mutation.operation_id}: ${ledgerErr.message}`,
            );
          }
        }

        // Post-commit realtime broadcast (§9.4)
        if (
          result.status === 'SYNCED' &&
          mutation.entity_type === 'order' &&
          this.kitchenGateway
        ) {
          try {
            this.kitchenGateway.emitOrderCreated({
              id: mutation.entity_id,
              order_number: mutation.payload?.order_number,
              order_type: mutation.payload?.order_type,
              status: mutation.payload?.status || 'newOrder',
              grand_total: mutation.payload?.grand_total || 0,
              created_at: mutation.payload?.created_at || new Date(),
              device_id: device_id,
              order_items: mutation.payload?.items || [],
            });
          } catch (wsErr: any) {
            this.logger.warn(`Could not emit kitchen event: ${wsErr?.message}`);
          }
        }
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
