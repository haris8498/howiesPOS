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
      const isSatisfied = context.completedInBatch?.has(mutation.depends_on_operation_id);
      if (!isSatisfied) {
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

    const reqStatus = payload.status || 'ACTIVE';
    const isClosedStatus = reqStatus === 'OFFLINE_CLOSED' || reqStatus === 'CLOSED';

    const restaurantId = payload.restaurant_id || 'default';
    const terminalId = payload.terminal_id ? String(payload.terminal_id) : '1';

    if ((context && context.deviceId === 'POS-P1') || payload.device_id === 'POS-P1' || (mutation as any).device_id === 'POS-P1') {
      this.logger.warn(`Legacy deviceId 'POS-P1' detected for shift ${shiftId}; treating as legacy client on terminal ${terminalId}`);
    }

    // 2B. Guard: Only one active shift per terminal at a time (SYNC-005)
    if (!isClosedStatus) {
      const activeShift = tx.dailyCalculation.findFirst
        ? await tx.dailyCalculation.findFirst({
            where: {
              restaurant_id: restaurantId,
              terminal_id: terminalId,
              status: 'ACTIVE',
              id: { not: shiftId },
            },
          })
        : null;

      if (activeShift) {
        this.logger.warn(
          `Conflict sync shift open ${shiftId}: Terminal ${terminalId} already has active shift ${activeShift.id}. Preserving offline shift as OFFLINE_CLOSED.`,
        );
        const startingCash = Number(payload.starting_cash ?? payload.opening_float ?? 0);
        const dateObj = payload.date ? new Date(payload.date) : new Date();
        const createdConflict = await tx.dailyCalculation.create({
          data: {
            id: shiftId,
            date: dateObj,
            restaurant_id: restaurantId,
            terminal_id: terminalId,
            shift_name: payload.shift_name || 'Full Day',
            cashier_id: payload.cashier_id || 'UNKNOWN',
            cashier_name: payload.cashier_name || 'Cashier',
            starting_cash: new Prisma.Decimal(startingCash),
            opening_float: new Prisma.Decimal(startingCash),
            total_change_cash: new Prisma.Decimal(Number(payload.total_change_cash ?? startingCash)),
            status: 'OFFLINE_CLOSED',
            closing_notes: `Conflict: opened offline while active shift ${activeShift.id} was open on terminal ${terminalId}`,
            version: 1,
            created_at: payload.created_at ? new Date(payload.created_at) : new Date(),
          },
        });

        await this.changeLogService.record(
          tx,
          'shift',
          createdConflict.id,
          'INSERT',
          1,
          {
            id: createdConflict.id,
            status: 'OFFLINE_CLOSED',
            cashier_id: createdConflict.cashier_id,
            restaurant_id: restaurantId,
            terminal_id: terminalId,
            version: 1,
          },
          false,
        );

        return {
          operation_id: mutation.operation_id,
          entity_id: shiftId,
          status: 'CONFLICT',
          server_version: 1,
          server_timestamp: new Date().toISOString(),
          conflict_details: {
            code: 'ACTIVE_SHIFT_EXISTS',
            message: `Cannot open active shift: Terminal '${terminalId}' already has active shift '${activeShift.id}'. Preserved offline shift as OFFLINE_CLOSED.`,
            existing_active_shift_id: activeShift.id,
            terminal_id: terminalId,
            restaurant_id: restaurantId,
          },
        };
      }
    }

    // 3. Insert new shift
    const startingCash = Number(payload.starting_cash ?? payload.opening_float ?? 0);
    const dateObj = payload.date ? new Date(payload.date) : new Date();

    const created = await tx.dailyCalculation.create({
      data: {
        id: shiftId,
        date: dateObj,
        restaurant_id: restaurantId,
        terminal_id: terminalId,
        shift_name: payload.shift_name || 'Full Day',
        cashier_id: payload.cashier_id || 'UNKNOWN',
        cashier_name: payload.cashier_name || 'Cashier',
        starting_cash: new Prisma.Decimal(startingCash),
        opening_float: new Prisma.Decimal(startingCash),
        total_change_cash: new Prisma.Decimal(Number(payload.total_change_cash ?? startingCash)),
        status: reqStatus,
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
      const isSatisfied = context.completedInBatch?.has(mutation.depends_on_operation_id);
      if (!isSatisfied) {
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
    }

    // 2. Fetch existing shift (with self-healing if missing)
    let existing = await tx.dailyCalculation.findUnique({
      where: { id: shiftId },
      include: { expense_items: true },
    });

    const actualCash = payload.actual_cash_counted !== undefined
      ? Number(payload.actual_cash_counted)
      : (payload.cash_submitted !== undefined ? Number(payload.cash_submitted) : 0);
    const cashVariance = Number(payload.cash_variance ?? 0);
    const varianceReason = payload.variance_reason || null;
    const closingNotes = payload.closing_notes || existing?.closing_notes || null;
    const status = payload.status || 'CLOSED';
    const submittedAt = payload.submitted_at ? new Date(payload.submitted_at) : new Date();

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

    // 5. Permanently associate any orders from this session
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

    // Auto-resolve pending orders for this shift
    await tx.order.updateMany({
      where: {
        shift_id: existing.id,
        status: { notIn: ['completed', 'cancelled', 'rejected'] },
        is_paid: true,
      },
      data: { status: 'completed' },
    });
    // NOTE (SYNC-006): Do NOT auto-cancel unpaid orders (e.g. active dining tables, out-for-delivery).
    // Open unpaid orders remain active so subsequent shifts/cashiers can collect payment and settle bills.

    // Compute financial totals from orders
    // MNY-04: Only paid orders contribute to closed shift financial totals
    const shiftOrders = tx.order?.findMany
      ? await tx.order.findMany({
          where: {
            shift_id: existing.id,
            status: { notIn: ['cancelled', 'rejected'] },
            is_paid: true,
          },
          include: { payments: true },
        })
      : [];

    let totalGrossSales = 0;
    let totalCashSales = 0;
    let totalCardSales = 0;
    let totalOnlineSales = 0;
    let totalDiscounts = 0;
    let totalTax = 0;
    let dineInCount = 0;
    let takeawayCount = 0;
    let onlineCount = 0;

    for (const ord of shiftOrders) {
      const gTotal = Number(ord.grand_total || 0);
      totalGrossSales += gTotal;
      totalDiscounts += Number(ord.discount_amount || 0);
      totalTax += Number(ord.tax_amount || 0);

      const type = (ord.order_type || '').toLowerCase();
      if (type.includes('dine')) dineInCount++;
      else if (type.includes('takeaway')) takeawayCount++;
      else onlineCount++;

      if (ord.payments && ord.payments.length > 0) {
        let orderPaidSum = 0;
        for (const p of ord.payments) {
          const amt = Number(p.amount || 0);
          orderPaidSum += amt;
          const method = (p.payment_method || '').toLowerCase();
          if (method === 'cash') {
            totalCashSales += amt;
          } else if (method === 'card' || method === 'credit' || method === 'debit') {
            totalCardSales += amt;
          } else {
            totalOnlineSales += amt;
          }
        }
      }
    }

    const startingCashNum = Number(existing.starting_cash || 0);
    // Check cross-shift cash refunds processed during this shift
    const refundAdjustments = (tx as any).orderAdjustment?.findMany
      ? await (tx as any).orderAdjustment.findMany({
          where: {
            shift_id: existing.id,
            type: 'REFUND',
          },
          include: {
            order: {
              select: {
                id: true,
                shift_id: true,
                payments: true,
              },
            },
          },
        })
      : [];

    let cashRefundsTotal = 0;
    for (const adj of refundAdjustments) {
      const origShiftId = adj.order?.shift_id;
      if (!origShiftId || origShiftId !== existing.id) {
        const method = (adj.refund_method || '').toLowerCase();
        if (method === 'cash') {
          cashRefundsTotal += Number(adj.amount || 0);
        } else if (method === 'original') {
          const payments = adj.order?.payments || [];
          if (payments.length === 0) {
            cashRefundsTotal += Number(adj.amount || 0);
          } else {
            const cashPaid = payments
              .filter((p: any) => (p.payment_method || '').toLowerCase() === 'cash')
              .reduce((sum: number, p: any) => sum + Number(p.amount || 0), 0);
            if (cashPaid > 0) {
              cashRefundsTotal += Math.min(Number(adj.amount || 0), cashPaid);
            }
          }
        }
      }
    }

    const expectedCash = startingCashNum + totalCashSales - cashRefundsTotal;
    const finalVariance = payload.cash_variance !== undefined
      ? Number(payload.cash_variance)
      : (actualCash - expectedCash);

    const updated = await tx.dailyCalculation.update({
      where: { id: shiftId },
      data: {
        status,
        cash_submitted: new Prisma.Decimal(actualCash),
        cash_refunds_total: new Prisma.Decimal(cashRefundsTotal),
        expected_cash_in_hand: new Prisma.Decimal(expectedCash),
        cash_variance: new Prisma.Decimal(finalVariance),
        variance_amount: new Prisma.Decimal(payload.variance_amount !== undefined ? Number(payload.variance_amount) : finalVariance),
        variance_reason: varianceReason,
        closing_notes: closingNotes,
        submitted_at: submittedAt,
        total_gross_sales: new Prisma.Decimal(totalGrossSales),
        total_cash_sales: new Prisma.Decimal(totalCashSales),
        total_card_sales: new Prisma.Decimal(totalCardSales),
        total_online_sales: new Prisma.Decimal(totalOnlineSales),
        total_discounts: new Prisma.Decimal(totalDiscounts),
        total_tax: new Prisma.Decimal(totalTax),
        total_orders_count: shiftOrders.length,
        dine_in_count: dineInCount,
        takeaway_count: takeawayCount,
        online_count: onlineCount,
        version: { increment: 1 },
      } as any,
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
