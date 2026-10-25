import {
  Injectable,
  Logger,
  OnModuleInit,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import {
  SyncEntityHandler,
  SyncMutationContext,
  SyncMutationResult,
} from './sync-entity.handler';
import { HandlerRegistry } from './handler-registry.service';
import { ChangeLogService } from '../change-log.service';
import { SyncMutationDto } from '../dto/sync-push.dto';

/**
 * Shift Sync Handler (Spec §7.3, §6.3, §8.3(3), §21 Decision 2)
 *
 * Responsibilities:
 * 1. Handles 'shift' and 'shifts' mutations (open and close).
 * 2. Topological ordering:
 *    - Level 0 (dependency_order: 0): Shift Session open (INSERT)
 *    - Level 5 (dependency_order: 5): Shift Close (UPDATE)
 * 3. Idempotent close:
 *    - If shift is already CLOSED or OFFLINE_CLOSED, returns DUPLICATE/SYNCED without error.
 * 4. Optimistic Concurrency Control (OCC):
 *    - Verifies base_version against current server version, returning CONFLICT if mismatched.
 * 5. Unsynced dependency verification:
 *    - If depends_on_operation_id is specified, verifies it has completed in processedOperation.
 * 6. Cash variance acceptance:
 *    - Stores cash_variance and variance_reason in PostgreSQL for supervisory audit.
 *    - Never blocks based on variance size.
 */
@Injectable()
export class ShiftHandler implements SyncEntityHandler, OnModuleInit {
  readonly entityType = 'shift';
  private readonly logger = new Logger(ShiftHandler.name);

  constructor(
    private readonly handlerRegistry: HandlerRegistry,
    private readonly changeLogService: ChangeLogService,
  ) {}

  onModuleInit() {
    this.handlerRegistry.register(this);
  }

  async handle(
    tx: Prisma.TransactionClient,
    mutation: SyncMutationDto,
    context: SyncMutationContext,
  ): Promise<SyncMutationResult> {
    const opType = (mutation.operation_type || 'INSERT').toUpperCase();

    switch (opType) {
      case 'INSERT':
        return this.handleInsert(tx, mutation, context);
      case 'UPDATE':
        return this.handleUpdate(tx, mutation, context);
      default:
        return {
          operation_id: mutation.operation_id,
          entity_id: mutation.entity_id,
          status: 'FAILED_FATAL',
          server_version: mutation.base_version ?? 1,
          server_timestamp: new Date().toISOString(),
          error_message: `Unsupported operation_type '${mutation.operation_type}' for shift`,
        };
    }
  }

  /**
   * Handle Shift Open (Level 0)
   */
  private async handleInsert(
    tx: Prisma.TransactionClient,
    mutation: SyncMutationDto,
    context: SyncMutationContext,
  ): Promise<SyncMutationResult> {
    const shiftId = mutation.entity_id;
    const payload = mutation.payload || {};

    // 1. Dependency check if specified
    if (mutation.depends_on_operation_id) {
      const dep = (tx as any).processedOperation?.findUnique
        ? await (tx as any).processedOperation.findUnique({
            where: { operation_id: mutation.depends_on_operation_id },
          })
        : null;

      if (!dep || dep.status !== 'COMPLETED') {
        return {
          operation_id: mutation.operation_id,
          entity_id: shiftId,
          status: 'FAILED_RETRYABLE',
          server_version: mutation.base_version ?? 1,
          server_timestamp: new Date().toISOString(),
          error_message: `Unsynced dependency: operation '${mutation.depends_on_operation_id}' has not been synced or completed yet`,
        };
      }
    }

    // 2. Idempotency check: shift already exists
    const existing = await tx.dailyCalculation.findUnique({
      where: { id: shiftId },
    });

    if (existing) {
      this.logger.log(`Shift ${shiftId} already exists — returning DUPLICATE (idempotent)`);
      const v = (existing as any).version ?? 1;
      const ts = (
        (existing as any).updated_at ||
        existing.created_at ||
        new Date()
      ).toISOString();
      return {
        operation_id: mutation.operation_id,
        entity_id: existing.id,
        status: 'DUPLICATE',
        server_version: v,
        server_timestamp: ts,
      };
    }

    // 2B. Guard: Only one active shift at a time store-wide
    const activeShift = tx.dailyCalculation.findFirst
      ? await tx.dailyCalculation.findFirst({
          where: {
            status: 'ACTIVE',
            id: { not: shiftId },
          },
        })
      : null;

    if (activeShift) {
      this.logger.warn(`Rejecting sync shift open ${shiftId}: Server already has active shift ${activeShift.id}`);
      return {
        operation_id: mutation.operation_id,
        entity_id: shiftId,
        status: 'FAILED_FATAL',
        server_version: mutation.base_version ?? 1,
        server_timestamp: new Date().toISOString(),
        error_message: 'Cannot open shift: An active shift already exists on the server.',
      };
    }

    // 3. Insert new shift
    const startingCash = Number(payload.starting_cash ?? payload.opening_float ?? 0);
    const dateObj = payload.date ? new Date(payload.date) : new Date();

    const created = await tx.dailyCalculation.create({
      data: {
        id: shiftId,
        date: dateObj,
        shift_name: payload.shift_name || 'Full Day',
        cashier_id: payload.cashier_id || 'UNKNOWN',
        cashier_name: payload.cashier_name || 'Cashier',
        starting_cash: new Prisma.Decimal(startingCash),
        opening_float: new Prisma.Decimal(startingCash),
        total_change_cash: new Prisma.Decimal(Number(payload.total_change_cash ?? startingCash)),
        status: payload.status || 'ACTIVE',
        version: 1,
        created_at: payload.created_at ? new Date(payload.created_at) : new Date(),
      },
    });

    const version = (created as any).version ?? 1;
    const updatedAt = (created as any).updated_at || created.created_at || new Date();

    // 4. Record change log
    await this.changeLogService.record(
      tx,
      'shift',
      created.id,
      'INSERT',
      version,
      {
        id: created.id,
        shift_name: created.shift_name,
        cashier_id: created.cashier_id,
        cashier_name: created.cashier_name,
        starting_cash: startingCash,
        status: created.status,
        version,
        created_at: created.created_at,
        updated_at: updatedAt,
      },
      false,
    );

    return {
      operation_id: mutation.operation_id,
      entity_id: created.id,
      status: 'SYNCED',
      server_version: version,
      server_timestamp: updatedAt.toISOString(),
    };
  }

  /**
   * Handle Shift Close (Level 5) with idempotent close + OCC version
   */
  private async handleUpdate(
    tx: Prisma.TransactionClient,
    mutation: SyncMutationDto,
    context: SyncMutationContext,
  ): Promise<SyncMutationResult> {
    const shiftId = mutation.entity_id;
    const payload = mutation.payload || {};

    // 1. Dependency check if specified
    if (mutation.depends_on_operation_id) {
      const dep = (tx as any).processedOperation?.findUnique
        ? await (tx as any).processedOperation.findUnique({
            where: { operation_id: mutation.depends_on_operation_id },
          })
        : null;

      if (!dep || dep.status !== 'COMPLETED') {
        return {
          operation_id: mutation.operation_id,
          entity_id: shiftId,
          status: 'FAILED_RETRYABLE',
          server_version: mutation.base_version ?? 1,
          server_timestamp: new Date().toISOString(),
          error_message: `Unsynced dependency: operation '${mutation.depends_on_operation_id}' has not been synced or completed yet`,
        };
      }
    }

    // 2. Fetch existing shift
    const existing = await tx.dailyCalculation.findUnique({
      where: { id: shiftId },
      include: { expense_items: true },
    });

    if (!existing) {
      return {
        operation_id: mutation.operation_id,
        entity_id: shiftId,
        status: 'FAILED_FATAL',
        server_version: 0,
        server_timestamp: new Date().toISOString(),
        error_message: `Shift '${shiftId}' not found for update`,
      };
    }

    const currentVersion = (existing as any).version ?? 1;

    // 3. Idempotent check: Shift is already closed
    if (
      existing.status === 'OFFLINE_CLOSED' ||
      existing.status === 'CLOSED' ||
      existing.status === 'SUBMITTED'
    ) {
      this.logger.log(`Shift ${shiftId} is already closed (${existing.status}) — returning DUPLICATE (idempotent)`);
      return {
        operation_id: mutation.operation_id,
        entity_id: existing.id,
        status: 'DUPLICATE',
        server_version: currentVersion,
        server_timestamp: (
          (existing as any).updated_at ||
          existing.created_at ||
          new Date()
        ).toISOString(),
      };
    }

    // 4. Check OCC version
    if (
      mutation.base_version !== undefined &&
      currentVersion > mutation.base_version
    ) {
      return {
        operation_id: mutation.operation_id,
        entity_id: shiftId,
        status: 'CONFLICT',
        server_version: currentVersion,
        server_timestamp: (
          (existing as any).updated_at || new Date()
        ).toISOString(),
        conflict_details: {
          message: 'OCC Version Conflict: Shift has been modified on server',
          client_base_version: mutation.base_version,
          server_version: currentVersion,
        },
      };
    }

    // 5. Update shift (Spec §7.3, §8.3(3), Decision 2: accept cash_variance, OFFLINE_CLOSED)
    const actualCash = payload.actual_cash_counted !== undefined
      ? Number(payload.actual_cash_counted)
      : (payload.cash_submitted !== undefined ? Number(payload.cash_submitted) : 0);
    const cashVariance = Number(payload.cash_variance ?? 0);
    const varianceReason = payload.variance_reason || null;
    const closingNotes = payload.closing_notes || existing.closing_notes || null;
    const status = payload.status || 'OFFLINE_CLOSED';
    const submittedAt = payload.submitted_at ? new Date(payload.submitted_at) : new Date();

    const updated = await tx.dailyCalculation.update({
      where: { id: shiftId },
      data: {
        status,
        cash_submitted: new Prisma.Decimal(actualCash),
        cash_variance: new Prisma.Decimal(cashVariance),
        variance_amount: new Prisma.Decimal(payload.variance_amount !== undefined ? Number(payload.variance_amount) : cashVariance),
        variance_reason: varianceReason,
        closing_notes: closingNotes,
        submitted_at: submittedAt,
        version: { increment: 1 },
      } as any,
    });

    // 6. Permanently associate any orders from this session
    await tx.order.updateMany({
      where: {
        OR: [
          { shift_id: existing.id },
          {
            shift_id: null,
            created_at: {
              gte: existing.created_at,
              lte: new Date(),
            },
          },
        ],
      },
      data: {
        shift_id: existing.id,
      },
    });

    const newVersion = (updated as any).version ?? currentVersion + 1;
    const updatedAt = (updated as any).updated_at || new Date();

    // 7. Change log stream
    await this.changeLogService.record(
      tx,
      'shift',
      updated.id,
      'UPDATE',
      newVersion,
      {
        id: updated.id,
        shift_name: updated.shift_name,
        status: updated.status,
        cash_variance: Number(updated.cash_variance),
        variance_reason: updated.variance_reason,
        cash_submitted: Number(updated.cash_submitted),
        version: newVersion,
        submitted_at: updated.submitted_at,
        updated_at: updatedAt,
      },
      false,
    );

    return {
      operation_id: mutation.operation_id,
      entity_id: updated.id,
      status: 'SYNCED',
      server_version: newVersion,
      server_timestamp: updatedAt.toISOString(),
    };
  }
}
