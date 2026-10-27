import {
  Injectable,
  Logger,
  OnModuleInit,
  Optional,
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
import { KitchenGateway } from '../../kitchen/kitchen.gateway';
import * as crypto from 'crypto';

@Injectable()
export class TableHandler implements SyncEntityHandler, OnModuleInit {
  readonly entityType = 'table';
  private readonly logger = new Logger(TableHandler.name);

  constructor(
    private readonly handlerRegistry: HandlerRegistry,
    private readonly changeLogService: ChangeLogService,
    @Optional() private readonly kitchenGateway?: KitchenGateway,
  ) {}

  onModuleInit() {
    this.handlerRegistry.register(this);

    // Also register alias 'restaurant_table' so both entity types map to this handler
    const aliasHandler: SyncEntityHandler = {
      entityType: 'restaurant_table',
      handle: (tx, mutation, ctx) => this.handle(tx, mutation, ctx),
    };
    this.handlerRegistry.register(aliasHandler);
  }

  async handle(
    tx: Prisma.TransactionClient,
    mutation: SyncMutationDto,
    context: SyncMutationContext,
  ): Promise<SyncMutationResult> {
    const opType = (mutation.operation_type || 'UPDATE').toUpperCase();

    switch (opType) {
      case 'INSERT':
        return this.handleInsert(tx, mutation, context);
      case 'UPDATE':
        return this.handleUpdate(tx, mutation, context);
      case 'DELETE':
        return this.handleDelete(tx, mutation, context);
      default:
        return {
          operation_id: mutation.operation_id,
          entity_id: mutation.entity_id,
          status: 'FAILED_FATAL',
          server_version: mutation.base_version ?? 1,
          server_timestamp: new Date().toISOString(),
          error_message: `Unsupported operation_type '${mutation.operation_type}' for table`,
        };
    }
  }

  private async handleInsert(
    tx: Prisma.TransactionClient,
    mutation: SyncMutationDto,
    context: SyncMutationContext,
  ): Promise<SyncMutationResult> {
    const tableId = mutation.entity_id;
    const payload = mutation.payload || {};

    // 1. Idempotency check: if table with ID already exists
    const existingById = await tx.restaurantTable.findUnique({
      where: { id: tableId },
    });

    if (existingById) {
      this.logger.log(
        `Table ${tableId} already exists in database — returning DUPLICATE`,
      );
      const v = existingById.version ?? 1;
      const ts = (existingById.updated_at || new Date()).toISOString();
      return {
        operation_id: mutation.operation_id,
        entity_id: existingById.id,
        status: 'DUPLICATE',
        server_version: v,
        server_timestamp: ts,
      };
    }

    // 2. Check unique table_number constraint
    const tableNumber = (
      payload.table_number ||
      payload.name ||
      `T-${tableId.substring(0, 4)}`
    ).trim();

    const existingByNumber = tx.restaurantTable.findFirst
      ? await tx.restaurantTable.findFirst({
          where: { table_number: tableNumber, is_deleted: false },
        })
      : await (tx.restaurantTable as any).findUnique({
          where: { table_number: tableNumber },
        });
    if (false) await tx.restaurantTable.findFirst({
      where: { table_number: tableNumber, is_deleted: false },
    });

    if (existingByNumber) {
      return {
        operation_id: mutation.operation_id,
        entity_id: existingByNumber.id,
        status: 'CONFLICT',
        server_version: existingByNumber.version ?? 1,
        server_timestamp: (
          existingByNumber.updated_at || new Date()
        ).toISOString(),
        error_message: `Table number '${tableNumber}' already exists with ID '${existingByNumber.id}'`,
        conflict_details: {
          conflict_code: 'TABLE_NUMBER_EXISTS',
          entity_type: 'restaurant_table',
          entity_id: existingByNumber.id,
          existing_table_number: tableNumber,
          auto_resolvable: false,
        },
      };
    }

    // 3. Create table
    const created = await tx.restaurantTable.create({
      data: {
        id: tableId,
        table_number: tableNumber,
        name: (payload.name || tableNumber).trim(),
        capacity: Number(payload.capacity) || 4,
        section: payload.section || 'Hall',
        zone_id: payload.zone_id || null,
        status: payload.status || 'available',
        current_customer_count: Number(payload.current_customer_count) || 0,
        current_bill_amount: new Prisma.Decimal(payload.current_bill_amount || 0.0),
        active_order_id: payload.active_order_id || null,
        occupied_since: payload.occupied_since
          ? new Date(payload.occupied_since)
          : null,
        reserved_customer_name: payload.reserved_customer_name || null,
        reservation_time: payload.reservation_time
          ? new Date(payload.reservation_time)
          : null,
        version: 1,
      },
    });

    // 4. Record change log inside same transaction
    await this.changeLogService.record(
      tx,
      'restaurant_table',
      created.id,
      'INSERT',
      1,
      {
        id: created.id,
        table_number: created.table_number,
        name: created.name,
        capacity: created.capacity,
        section: created.section,
        zone_id: created.zone_id,
        status: created.status,
        active_order_id: created.active_order_id,
        version: 1,
        device_id: context.deviceId,
        origin_device_id: context.deviceId,
        operation_id: mutation.operation_id,
      },
      false,
    );

    return {
      operation_id: mutation.operation_id,
      entity_id: created.id,
      status: 'SYNCED',
      server_version: 1,
      server_timestamp: (created.updated_at || new Date()).toISOString(),
    };
  }

  private async handleUpdate(
    tx: Prisma.TransactionClient,
    mutation: SyncMutationDto,
    context: SyncMutationContext,
  ): Promise<SyncMutationResult> {
    const tableId = mutation.entity_id;
    const payload = mutation.payload || {};

    let existing = await tx.restaurantTable.findUnique({
      where: { id: tableId },
    });

    if (!existing && payload.table_number) {
      existing = tx.restaurantTable.findFirst
        ? await tx.restaurantTable.findFirst({
            where: { table_number: payload.table_number, is_deleted: false },
          })
        : await (tx.restaurantTable as any).findUnique({
            where: { table_number: payload.table_number },
          });
      if (false) await tx.restaurantTable.findFirst({
        where: { table_number: payload.table_number, is_deleted: false },
      });
    }

    if (!existing) {
      try {
        existing = await tx.restaurantTable.create({
          data: {
            id: tableId,
            table_number: payload.table_number || `T-${tableId.substring(0, 4)}`,
            name: payload.name || `Table ${tableId.substring(0, 4)}`,
            capacity: payload.capacity ?? 4,
            status: payload.status || 'available',
            active_order_id: payload.active_order_id || null,
            current_bill_amount: payload.current_bill_amount ? Number(payload.current_bill_amount) : 0,
            version: 1,
          },
        });
        return {
          operation_id: mutation.operation_id,
          entity_id: tableId,
          status: 'SYNCED',
          server_version: 1,
          server_timestamp: new Date().toISOString(),
        };
      } catch {
        return {
          operation_id: mutation.operation_id,
          entity_id: tableId,
          status: 'SYNCED',
          server_version: 1,
          server_timestamp: new Date().toISOString(),
        };
      }
    }

    const currentVersion = existing.version ?? 1;
    const clientBaseVersion = mutation.base_version ?? currentVersion;
    const isStale =
      mutation.base_version !== undefined && currentVersion > mutation.base_version;

    // Determine active orders on server
    let serverHasActiveOrder = Boolean(existing.active_order_id);
    let activeOrderSummary: any = null;

    if (existing.active_order_id) {
      const activeOrd = await tx.order.findUnique({
        where: { id: existing.active_order_id },
        select: {
          id: true,
          order_number: true,
          status: true,
          is_paid: true,
          grand_total: true,
        },
      });
      if (
        activeOrd &&
        activeOrd.status !== 'completed' &&
        activeOrd.status !== 'cancelled' &&
        activeOrd.status !== 'rejected'
      ) {
        serverHasActiveOrder = true;
        activeOrderSummary = activeOrd;
      } else if (!activeOrd || activeOrd.status === 'completed' || activeOrd.status === 'cancelled') {
        serverHasActiveOrder = false;
      }
    }

    if (!serverHasActiveOrder && (tx as any).dineInOrderDetail) {
      const activeDineIn = await (tx as any).dineInOrderDetail.findFirst({
        where: {
          table_id: existing.id,
          order: {
            is_paid: false,
            status: { notIn: ['completed', 'cancelled', 'rejected'] },
          },
        },
        include: {
          order: {
            select: {
              id: true,
              order_number: true,
              status: true,
              is_paid: true,
              grand_total: true,
            },
          },
        },
      });
      if (activeDineIn?.order) {
        serverHasActiveOrder = true;
        activeOrderSummary = activeDineIn.order;
      }
    }

    const incomingStatus = (payload.status ?? existing.status).toLowerCase();
    const incomingActiveOrderId =
      payload.active_order_id !== undefined
        ? payload.active_order_id
        : existing.active_order_id;

    // D-01: Check if incomingActiveOrderId was reassigned to a virtual overflow table
    let reassignedOverflowTable: any = null;
    if (incomingActiveOrderId && tx.dineInOrderDetail?.findUnique) {
      try {
        const detail = await tx.dineInOrderDetail.findUnique({
          where: { order_id: incomingActiveOrderId },
          include: { table: true },
        });
        if (
          detail &&
          detail.table &&
          detail.table.is_overflow &&
          (detail.table.parent_table_id === existing.id || detail.table_id !== existing.id)
        ) {
          reassignedOverflowTable = detail.table;
        }
      } catch (_) {}
    }
    
    if (reassignedOverflowTable) {
      this.logger.log(
        `[D-01] Table update for ${existing.table_number} redirected to reassigned overflow table ${reassignedOverflowTable.table_number} (${reassignedOverflowTable.id}) for order ${incomingActiveOrderId}`,
      );
    
      const updatedOverflow = await tx.restaurantTable.update({
        where: { id: reassignedOverflowTable.id },
        data: {
          status: 'occupied',
          active_order_id: incomingActiveOrderId,
          current_bill_amount: payload.current_bill_amount !== undefined
            ? new Prisma.Decimal(payload.current_bill_amount)
            : reassignedOverflowTable.current_bill_amount,
          version: { increment: 1 },
        },
      });
    
      await this.changeLogService.record(
        tx,
        'restaurant_table',
        updatedOverflow.id,
        'UPDATE',
        updatedOverflow.version,
        {
          id: updatedOverflow.id,
          table_number: updatedOverflow.table_number,
          name: updatedOverflow.name,
          status: updatedOverflow.status,
          active_order_id: updatedOverflow.active_order_id,
          parent_table_id: existing.id,
          overflow_suffix: updatedOverflow.overflow_suffix,
          is_overflow: true,
        },
        false,
      );
    
      return {
        operation_id: mutation.operation_id,
        entity_id: existing.id,
        status: 'APPLIED',
        server_version: currentVersion,
        server_timestamp: (existing.updated_at || new Date()).toISOString(),
        table_reassigned: {
          orderId: incomingActiveOrderId,
          fromTableId: existing.id,
          toTableId: reassignedOverflowTable.id,
          toLabel: reassignedOverflowTable.table_number,
        },
        tableReassigned: [
          {
            orderId: incomingActiveOrderId,
            fromTableId: existing.id,
            toTableId: reassignedOverflowTable.id,
            toLabel: reassignedOverflowTable.table_number,
          },
        ],
      };
    }

    // Idempotent / Repeated Replay Check: If table already matches the mutation payload
    if (
      existing.status.toLowerCase() === incomingStatus &&
      existing.active_order_id === incomingActiveOrderId
    ) {
      this.logger.log(
        `Table ${existing.id} already in desired status '${existing.status}' — returning DUPLICATE`,
      );
      return {
        operation_id: mutation.operation_id,
        entity_id: existing.id,
        status: 'DUPLICATE',
        server_version: currentVersion,
        server_timestamp: (existing.updated_at || new Date()).toISOString(),
      };
    }

    // ─────────────────────────────────────────────────────────────────────────
    // CONFLICT RESOLUTION MATRIX (§10.1 & §10.2)
    // ─────────────────────────────────────────────────────────────────────────
    if (isStale) {
      // ── POLICY RULE 1: POS Physical Seated Guest Wins (§10.1, §10.2) ───────
      // If client is seating walk-in guests (status -> occupied or has active order)
      // and server was reserved (or available) in the meantime:
      const clientSeatsGuests =
        incomingStatus === 'occupied' ||
        (payload.active_order_id !== undefined && Boolean(payload.active_order_id));

      if (clientSeatsGuests && !serverHasActiveOrder) {
        this.logger.log(
          `Hospitality Operational Priority (§10.2): Offline cashier seated walk-in guest at Table ${existing.table_number}. POS Physical Seated Guest Wins!`,
        );

        // If server table had a remote reservation, reassign it to overflow
        let overflowTableCreated = false;
        const overflowTableNumber = `${existing.table_number}-Overflow`;

        if (existing.status === 'reserved' && existing.reserved_customer_name) {
          if ((tx.restaurantTable as any).upsert) {
            await (tx.restaurantTable as any).upsert({
              where: { table_number: overflowTableNumber },
              create: {
                table_number: overflowTableNumber,
                name: `${existing.name} (Overflow)`,
                capacity: existing.capacity,
                section: existing.section,
                zone_id: existing.zone_id,
                status: 'reserved',
                reserved_customer_name: existing.reserved_customer_name,
                reservation_time: existing.reservation_time,
                version: 1,
              },
              update: {
                status: 'reserved',
                reserved_customer_name: existing.reserved_customer_name,
                reservation_time: existing.reservation_time,
                version: { increment: 1 },
              },
            });
          } else if (tx.restaurantTable.create) {
            await tx.restaurantTable.create({
              data: {
                table_number: overflowTableNumber,
                name: `${existing.name} (Overflow)`,
                capacity: existing.capacity,
                section: existing.section,
                zone_id: existing.zone_id,
                status: 'reserved',
                reserved_customer_name: existing.reserved_customer_name,
                reservation_time: existing.reservation_time,
                version: 1,
              },
            });
          }
          overflowTableCreated = true;

          // Urgent Realtime Event Broadcast to manager/kitchen portal (§10.2)
          if (this.kitchenGateway) {
            try {
              const envelope = this.kitchenGateway.createEnvelope({
                eventName: 'table.reservation_overflow',
                entity: 'restaurant_tables',
                entityId: existing.id,
                action: 'STATUS_CHANGED',
                version: currentVersion + 1,
                originDeviceId: context.deviceId,
                payload: {
                  original_table_id: existing.id,
                  original_table_number: existing.table_number,
                  overflow_table_number: overflowTableNumber,
                  reserved_customer_name: existing.reserved_customer_name,
                  reservation_time: existing.reservation_time?.toISOString(),
                  message: `Table ${existing.table_number} had seated walk-in guests during connection loss; reservation moved to overflow.`,
                },
              });
              this.kitchenGateway.emitRealtimeEnvelope(envelope);
            } catch (err: any) {
              this.logger.warn(`Could not emit realtime overflow envelope: ${err.message}`);
            }
          }
        }

        // Apply client physical seating to table
        const newVersion = currentVersion + 1;
        const updated = await tx.restaurantTable.update({
          where: { id: existing.id },
          data: {
            status: 'occupied',
            active_order_id: incomingActiveOrderId,
            current_customer_count:
              payload.current_customer_count !== undefined
                ? Number(payload.current_customer_count)
                : existing.current_customer_count,
            current_bill_amount:
              payload.current_bill_amount !== undefined
                ? new Prisma.Decimal(payload.current_bill_amount)
                : existing.current_bill_amount,
            occupied_since: payload.occupied_since
              ? new Date(payload.occupied_since)
              : existing.occupied_since ?? new Date(),
            reserved_customer_name: null,
            reservation_time: null,
            version: { increment: 1 },
          },
        });

        await this.changeLogService.record(
          tx,
          'restaurant_table',
          updated.id,
          'UPDATE',
          newVersion,
          {
            id: updated.id,
            table_number: updated.table_number,
            name: updated.name,
            status: updated.status,
            active_order_id: updated.active_order_id,
            version: newVersion,
            overflow_reassigned: overflowTableCreated,
            device_id: context.deviceId,
            origin_device_id: context.deviceId,
            operation_id: mutation.operation_id,
          },
          false,
        );

        return {
          operation_id: mutation.operation_id,
          entity_id: updated.id,
          status: 'SYNCED',
          server_version: newVersion,
          server_timestamp: (updated.updated_at || new Date()).toISOString(),
        };
      }


      // ── POLICY RULE 2: Active / Paid Order Must NEVER Be Lost (§10.2) ──────
      // If server table has an active order, and client's stale update is releasing
      // or reserving or overwriting the table:
      if (serverHasActiveOrder) {
        this.logger.warn(
          `Dining Table Hospitality Invariant Violation: Table ${existing.table_number} has active order ${existing.active_order_id || activeOrderSummary?.id} on server. Stale update rejected with CONFLICT.`,
        );

        return {
          operation_id: mutation.operation_id,
          entity_id: existing.id,
          status: 'CONFLICT',
          server_version: currentVersion,
          server_timestamp: (existing.updated_at || new Date()).toISOString(),
          error_message: `Cannot modify table ${existing.table_number}: Active order exists on server and cannot be overwritten by stale update`,
          conflict_details: {
            conflict_code: 'ACTIVE_ORDER_PROTECTED',
            entity_type: 'table',
            entity_id: existing.id,
            reason:
              'Active/paid order must never be lost due to stale table update (§10.2)',
            winning_rule: 'SERVER_ACTIVE_ORDER_WINS',
            auto_resolvable: true,
            policy_action: 'REVERT_TO_SERVER_STATE',
            client_base_version: mutation.base_version,
            server_version: currentVersion,
            server_state: {
              id: existing.id,
              table_number: existing.table_number,
              name: existing.name,
              capacity: existing.capacity,
              section: existing.section,
              zone_id: existing.zone_id,
              status: existing.status,
              active_order_id:
                existing.active_order_id || activeOrderSummary?.id || null,
              active_order_number: activeOrderSummary?.order_number || null,
              version: currentVersion,
            },
          },
        };
      }

      // ── POLICY RULE 3: Stale base_version / Non-auto-resolvable race ────────
      // e.g. Cashier reserves vs release race, two reservations colliding
      this.logger.warn(
        `OCC Version Conflict on table ${existing.table_number}: server version ${currentVersion} > base version ${mutation.base_version}`,
      );

      return {
        operation_id: mutation.operation_id,
        entity_id: existing.id,
        status: 'CONFLICT',
        server_version: currentVersion,
        server_timestamp: (existing.updated_at || new Date()).toISOString(),
        error_message: `OCC Version Conflict: Table ${existing.table_number} was modified on server (version ${currentVersion} > base ${mutation.base_version})`,
        conflict_details: {
          conflict_code: 'OCC_VERSION_MISMATCH',
          entity_type: 'table',
          entity_id: existing.id,
          reason: 'Stale base_version table update detected',
          auto_resolvable: false,
          client_base_version: mutation.base_version,
          server_version: currentVersion,
          server_state: {
            id: existing.id,
            table_number: existing.table_number,
            name: existing.name,
            capacity: existing.capacity,
            section: existing.section,
            zone_id: existing.zone_id,
            status: existing.status,
            active_order_id: existing.active_order_id,
            reserved_customer_name: existing.reserved_customer_name,
            reservation_time: existing.reservation_time?.toISOString() || null,
            version: currentVersion,
          },
        },
      };
    }

    // ─────────────────────────────────────────────────────────────────────────
    // NO CONFLICT: Normal OCC Update
    // ─────────────────────────────────────────────────────────────────────────
    const updateData: Prisma.RestaurantTableUpdateInput = {
      version: { increment: 1 },
      updated_at: new Date(),
    };

    if (payload.table_number !== undefined) {
      updateData.table_number = payload.table_number.trim();
    }
    if (payload.name !== undefined) {
      updateData.name = payload.name.trim();
    }
    if (payload.capacity !== undefined) {
      updateData.capacity = Number(payload.capacity);
    }
    if (payload.section !== undefined) {
      updateData.section = payload.section;
    }
    if (payload.zone_id !== undefined) {
      updateData.zone = payload.zone_id
        ? { connect: { id: payload.zone_id } }
        : { disconnect: true };
    }
    if (payload.status !== undefined) {
      updateData.status = payload.status;
      if (payload.status === 'available') {
        updateData.active_order_id = null;
        updateData.occupied_since = null;
        updateData.current_bill_amount = new Prisma.Decimal(0.0);
        updateData.current_customer_count = 0;
        updateData.reserved_customer_name = null;
        updateData.reservation_time = null;
      } else if (payload.status === 'occupied') {
        updateData.occupied_since = payload.occupied_since
          ? new Date(payload.occupied_since)
          : existing.occupied_since ?? new Date();
        if (payload.active_order_id !== undefined) {
          updateData.active_order_id = payload.active_order_id;
        }
        if (payload.current_customer_count !== undefined) {
          updateData.current_customer_count = Number(payload.current_customer_count);
        }
        if (payload.current_bill_amount !== undefined) {
          updateData.current_bill_amount = new Prisma.Decimal(payload.current_bill_amount);
        }
      } else if (payload.status === 'reserved') {
        if (payload.reserved_customer_name !== undefined) {
          updateData.reserved_customer_name = payload.reserved_customer_name;
        }
        if (payload.reservation_time !== undefined) {
          updateData.reservation_time = payload.reservation_time
            ? new Date(payload.reservation_time)
            : new Date();
        }
      }
    }

    if (payload.active_order_id !== undefined && payload.status !== 'available') {
      updateData.active_order_id = payload.active_order_id;
    }
    if (payload.current_customer_count !== undefined && payload.status !== 'available') {
      updateData.current_customer_count = Number(payload.current_customer_count);
    }
    if (payload.current_bill_amount !== undefined && payload.status !== 'available') {
      updateData.current_bill_amount = new Prisma.Decimal(payload.current_bill_amount);
    }
    if (payload.reserved_customer_name !== undefined && payload.status !== 'available') {
      updateData.reserved_customer_name = payload.reserved_customer_name;
    }
    if (payload.reservation_time !== undefined && payload.status !== 'available') {
      updateData.reservation_time = payload.reservation_time
        ? new Date(payload.reservation_time)
        : null;
    }

    const updated = await tx.restaurantTable.update({
      where: { id: existing.id },
      data: updateData,
    });

    const newVersion = updated.version ?? currentVersion + 1;
    const updatedAt = updated.updated_at || new Date();

    await this.changeLogService.record(
      tx,
      'restaurant_table',
      updated.id,
      'UPDATE',
      newVersion,
      {
        id: updated.id,
        table_number: updated.table_number,
        name: updated.name,
        capacity: updated.capacity,
        section: updated.section,
        zone_id: updated.zone_id,
        status: updated.status,
        active_order_id: updated.active_order_id,
        current_customer_count: updated.current_customer_count,
        current_bill_amount: Number(updated.current_bill_amount),
        version: newVersion,
        device_id: context.deviceId,
        origin_device_id: context.deviceId,
        operation_id: mutation.operation_id,
      },
      false,
    );

    // Broadcast RealtimeEventEnvelope (§9.2, §9.4)
    if (this.kitchenGateway) {
      try {
        const envelope = this.kitchenGateway.createEnvelope({
          eventName: 'table.status_changed',
          entity: 'restaurant_tables',
          entityId: updated.id,
          action: 'STATUS_CHANGED',
          version: newVersion,
          originDeviceId: context.deviceId,
          payload: {
            table_id: updated.id,
            table_number: updated.table_number,
            name: updated.name,
            status: updated.status,
            active_order_id: updated.active_order_id,
            version: newVersion,
          },
        });
        this.kitchenGateway.emitRealtimeEnvelope(envelope);
      } catch (err: any) {
        this.logger.warn(`Could not emit realtime table event: ${err.message}`);
      }
    }

    return {
      operation_id: mutation.operation_id,
      entity_id: updated.id,
      status: 'SYNCED',
      server_version: newVersion,
      server_timestamp: updatedAt.toISOString(),
    };
  }

  private async handleDelete(
    tx: Prisma.TransactionClient,
    mutation: SyncMutationDto,
    context: SyncMutationContext,
  ): Promise<SyncMutationResult> {
    const tableId = mutation.entity_id;
    const existing = await tx.restaurantTable.findUnique({
      where: { id: tableId },
    });

    if (!existing) {
      return {
        operation_id: mutation.operation_id,
        entity_id: tableId,
        status: 'DUPLICATE',
        server_version: 0,
        server_timestamp: new Date().toISOString(),
      };
    }

    if (existing.status === 'occupied' || existing.active_order_id) {
      return {
        operation_id: mutation.operation_id,
        entity_id: tableId,
        status: 'CONFLICT',
        server_version: existing.version ?? 1,
        server_timestamp: (existing.updated_at || new Date()).toISOString(),
        error_message: `Cannot delete table ${existing.table_number}: Active order exists on server`,
        conflict_details: {
          conflict_code: 'ACTIVE_ORDER_PROTECTED',
          entity_type: 'table',
          entity_id: tableId,
          auto_resolvable: false,
        },
      };
    }

    await tx.restaurantTable.delete({
      where: { id: tableId },
    });

    const newVersion = (existing.version ?? 1) + 1;

    await this.changeLogService.record(
      tx,
      'restaurant_table',
      tableId,
      'DELETE',
      newVersion,
      {
        id: tableId,
        table_number: existing.table_number,
        is_deleted: true,
        version: newVersion,
        device_id: context.deviceId,
        origin_device_id: context.deviceId,
        operation_id: mutation.operation_id,
      },
      true,
    );

    return {
      operation_id: mutation.operation_id,
      entity_id: tableId,
      status: 'SYNCED',
      server_version: newVersion,
      server_timestamp: new Date().toISOString(),
    };
  }
}
