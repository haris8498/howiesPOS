import { RealtimeGateway } from '../realtime/realtime.gateway';
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
    @Optional() private readonly realtimeGateway?: RealtimeGateway,
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
    const completedInBatch = new Set<string>();

    // Build dependency graph for batch
    const mutationMap = new Map(mutations.map((m) => [m.operation_id, m]));
    const isAncestorOf = (potentialAncestorId: string, targetId: string, visited = new Set<string>()): boolean => {
      if (visited.has(targetId)) return false;
      visited.add(targetId);
      const target = mutationMap.get(targetId);
      if (!target || !target.depends_on_operation_id) return false;
      if (target.depends_on_operation_id === potentialAncestorId) return true;
      return isAncestorOf(potentialAncestorId, target.depends_on_operation_id, visited);
    };

    const sortedMutations = [...mutations].sort((a, b) => {
      // 1. Explicit direct or transitive dependency
      if (isAncestorOf(a.operation_id, b.operation_id)) return -1;
      if (isAncestorOf(b.operation_id, a.operation_id)) return 1;

      // 2. Dependency order level (Level 0..6)
      const orderA = a.dependency_order ?? 1;
      const orderB = b.dependency_order ?? 1;
      if (orderA !== orderB) {
        return orderA - orderB;
      }

      // 3. Chronological timeline ordering within same dependency level
      const timeA = a.created_at ? new Date(a.created_at).getTime() : 0;
      const timeB = b.created_at ? new Date(b.created_at).getTime() : 0;
      if (timeA !== timeB) {
        return timeA - timeB;
      }

      return a.operation_id.localeCompare(b.operation_id);
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

      // 2. Validate dependency graph (§6.3)
      if (mutation.depends_on_operation_id) {
        let isDepSatisfied = completedInBatch.has(mutation.depends_on_operation_id);

        if (!isDepSatisfied && this.prisma.processedOperation?.findUnique) {
          const depOp = await this.prisma.processedOperation.findUnique({
            where: { operation_id: mutation.depends_on_operation_id },
          });
          if (depOp && depOp.status === 'COMPLETED') {
            isDepSatisfied = true;
          }
        }

        if (!isDepSatisfied) {
          this.logger.warn(
            `Mutation ${mutation.operation_id} has unsynced dependency: ${mutation.depends_on_operation_id}`,
          );
          results.push({
            operation_id: mutation.operation_id,
            entity_id: mutation.entity_id,
            status: 'FAILED_RETRYABLE',
            server_version: mutation.base_version ?? 1,
            server_timestamp: new Date().toISOString(),
            error_message: `Unsynced dependency: operation '${mutation.depends_on_operation_id}' has not completed yet`,
          });
          continue;
        }
      }

      const context: SyncMutationContext = {
        deviceId: device_id,
        operationId: mutation.operation_id,
        batchId: batch_id,
        receivedAt: new Date(),
        completedInBatch,
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
        if (result.status === "SYNCED" || result.status === "DUPLICATE" || result.status === "APPLIED") {
          completedInBatch.add(mutation.operation_id);
        }

        if (result.status === 'SYNCED' || result.status === 'APPLIED') {
          try {
            if (mutation.entity_type === 'shift') {
              if (mutation.operation_type === 'INSERT') {
                this.realtimeGateway?.emitShiftStarted({ id: mutation.entity_id, ...(mutation.payload || {}) });
              } else if (mutation.operation_type === 'UPDATE') {
                this.realtimeGateway?.emitShiftClosed({ id: mutation.entity_id, ...(mutation.payload || {}) });
              }
            } else if (mutation.entity_type === 'order') {
              if (mutation.operation_type === 'INSERT') {
                this.realtimeGateway?.emitOrderCreated({ id: mutation.entity_id, ...(mutation.payload || {}) });
              } else if (mutation.operation_type === 'UPDATE') {
                this.realtimeGateway?.emitOrderUpdated({ id: mutation.entity_id, ...(mutation.payload || {}) });
              }
            }
          } catch (rtErr) {
            this.logger.warn(`Failed to broadcast realtime event for mutation ${mutation.operation_id}: ${rtErr}`);
          }
        }

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
        if ((result.status === 'SYNCED' || result.status === 'APPLIED') && this.kitchenGateway) {
          if (mutation.entity_type === 'order') {
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
          } else if (
            mutation.entity_type === 'table' ||
            mutation.entity_type === 'restaurant_table'
          ) {
            try {
              const envelope = this.kitchenGateway.createEnvelope({
                eventName: 'table.status_changed',
                entity: 'restaurant_tables',
                entityId: result.entity_id,
                action: 'STATUS_CHANGED',
                version: result.server_version,
                originDeviceId: device_id,
                payload: {
                  table_id: result.entity_id,
                  version: result.server_version,
                  status: mutation.payload?.status,
                  active_order_id: mutation.payload?.active_order_id,
                },
              });
              this.kitchenGateway.emitRealtimeEnvelope(envelope);
            } catch (wsErr: any) {
              this.logger.warn(`Could not emit table event: ${wsErr?.message}`);
            }
          }
        }
      } catch (err: any) {
        const isUniqueConstraint =
          err?.code === 'P2002' ||
          (err.message && err.message.includes('Unique constraint failed'));

        if (isUniqueConstraint && mutation.operation_type === 'INSERT') {
          const target = err?.meta?.target;
          const targetStr = Array.isArray(target) ? target.join(',') : String(target || '');
          const isTargetMatch = (field: string) =>
            (Array.isArray(target) && target.some((t: any) => typeof t === 'string' && (t === field || t.toLowerCase().includes(field.toLowerCase())))) ||
            (typeof target === 'string' && (target === field || target.toLowerCase().includes(field.toLowerCase()))) ||
            (err.message && err.message.toLowerCase().includes(field.toLowerCase()));

          const isPkCollision = isTargetMatch('id') || isTargetMatch('pkey') || isTargetMatch('primary');
          const isOrderOrTokenNumberCollision = isTargetMatch('order_number') || isTargetMatch('token_number');

          // Case 1: Primary Key / ID duplicate
          if (isPkCollision) {
            let existingEntity: any = null;
            try {
              if (mutation.entity_type === 'order' && this.prisma.order?.findUnique) {
                existingEntity = await this.prisma.order.findUnique({ where: { id: mutation.entity_id } });
              } else if (mutation.entity_type === 'shift' && this.prisma.dailyCalculation?.findUnique) {
                existingEntity = await this.prisma.dailyCalculation.findUnique({ where: { id: mutation.entity_id } });
              } else if ((mutation.entity_type === 'table' || mutation.entity_type === 'restaurant_table') && this.prisma.restaurantTable?.findUnique) {
                existingEntity = await this.prisma.restaurantTable.findUnique({ where: { id: mutation.entity_id } });
              }
            } catch (queryErr: any) {
              this.logger.warn(`Failed to verify existing row on PK collision: ${queryErr?.message}`);
            }

            if (existingEntity) {
              this.logger.log(
                `Mutation ${mutation.operation_id} (${mutation.entity_type}:${mutation.entity_id}) verified existing in database — resolving as DUPLICATE`,
              );
              completedInBatch.add(mutation.operation_id);
              results.push({
                operation_id: mutation.operation_id,
                entity_id: mutation.entity_id,
                status: 'DUPLICATE',
                server_version: existingEntity.version ?? mutation.base_version ?? 1,
                server_timestamp: (existingEntity.updated_at || existingEntity.created_at || new Date()).toISOString(),
              });
              continue;
            } else {
              this.logger.error(
                `[SYNC-001] P2002 reported primary key collision for ${mutation.entity_id}, but row does not exist in database! Not acknowledging as DUPLICATE.`,
              );
              results.push({
                operation_id: mutation.operation_id,
                entity_id: mutation.entity_id,
                status: 'FAILED_RETRYABLE',
                server_version: mutation.base_version ?? 1,
                server_timestamp: new Date().toISOString(),
                error_message: 'Primary key conflict reported but existing row was not found',
              });
              continue;
            }
          }

          // Case 2: order_number or token_number collision -> resolve collision with new server-assigned identifier
          if (isOrderOrTokenNumberCollision && mutation.entity_type === 'order') {
            this.logger.warn(
              `[SYNC-001] Collision on unique constraint (${targetStr}) for order mutation ${mutation.operation_id} (device: ${device_id}, entity: ${mutation.entity_id}). Resolving collision with new server-assigned identifier...`,
            );

            let resolvedResult: any = null;
            const originalOrderNumber = mutation.payload?.order_number;
            const originalTokenNumber = mutation.payload?.token_number;

            for (let attempt = 1; attempt <= 5; attempt++) {
              try {
                const retriedPayload = { ...mutation.payload };
                if (originalOrderNumber) {
                  retriedPayload.order_number = `${originalOrderNumber}-${attempt}`;
                  retriedPayload.client_order_number = originalOrderNumber;
                }
                if (originalTokenNumber) {
                  retriedPayload.token_number = `${originalTokenNumber}-${attempt}`;
                }
                const retriedMutation = { ...mutation, payload: retriedPayload };

                resolvedResult = await this.prisma.$transaction(async (tx) => {
                  return await handler.handle(tx, retriedMutation, context);
                });

                if (resolvedResult) {
                  resolvedResult.status = 'APPLIED';
                  resolvedResult.client_order_number = originalOrderNumber;
                  break;
                }
              } catch (retryErr: any) {
                this.logger.warn(
                  `[SYNC-001] Retry attempt ${attempt} for mutation ${mutation.operation_id} failed: ${retryErr?.message}`,
                );
              }
            }

            if (resolvedResult) {
              results.push(resolvedResult);
              completedInBatch.add(mutation.operation_id);

              if (this.kitchenGateway) {
                try {
                  this.kitchenGateway.emitOrderCreated({
                    id: mutation.entity_id,
                    order_number: resolvedResult.order_number || mutation.payload?.order_number,
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
              continue;
            } else {
              this.logger.error(
                `[SYNC-001] Failed to automatically resolve unique collision for mutation ${mutation.operation_id} after 5 attempts`,
              );
              results.push({
                operation_id: mutation.operation_id,
                entity_id: mutation.entity_id,
                status: 'FAILED_RETRYABLE',
                server_version: mutation.base_version ?? 1,
                server_timestamp: new Date().toISOString(),
                error_message: 'Unique constraint collision resolution exceeded maximum retry attempts',
              });
              continue;
            }
          }

          // Case 3: Unknown or unhandled P2002 target (e.g. phone, customer unique, etc.)
          this.logger.warn(
            `[SYNC-001] Unique constraint P2002 on unhandled target (${targetStr}) for mutation ${mutation.operation_id} (device: ${device_id}). Returning FAILED_RETRYABLE to prevent silent order loss.`,
          );
          results.push({
            operation_id: mutation.operation_id,
            entity_id: mutation.entity_id,
            status: 'FAILED_RETRYABLE',
            server_version: mutation.base_version ?? 1,
            server_timestamp: new Date().toISOString(),
            error_message: `Unique constraint failed on unhandled target: ${targetStr}`,
          });
          continue;
        }

        // Standard error handling (non-P2002 or UPDATE/DELETE)
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
