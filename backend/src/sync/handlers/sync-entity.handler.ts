import { Prisma } from '@prisma/client';
import { SyncMutationDto } from '../dto/sync-push.dto';

export interface SyncMutationContext {
  deviceId: string;
  operationId: string;
  batchId?: string;
  receivedAt: Date;
}

export type SyncResultStatus = 'SYNCED' | 'CONFLICT' | 'FAILED_FATAL' | 'DUPLICATE';

export interface SyncMutationResult {
  operation_id: string;
  entity_id: string;
  status: SyncResultStatus;
  server_version: number;
  server_timestamp: string;
  error_message?: string;
  conflict_details?: any;
}

export interface SyncEntityHandler {
  readonly entityType: string;
  handle(
    tx: Prisma.TransactionClient,
    mutation: SyncMutationDto,
    context: SyncMutationContext,
  ): Promise<SyncMutationResult>;
}
