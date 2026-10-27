import { Prisma } from '@prisma/client';
import { SyncMutationDto } from '../dto/sync-push.dto';

export interface SyncMutationContext {
  deviceId: string;
  operationId: string;
  batchId?: string;
  receivedAt: Date;
  completedInBatch?: Set<string>;
}

export type SyncResultStatus = 'SYNCED' | 'CONFLICT' | 'FAILED_FATAL' | 'DUPLICATE' | 'FAILED_RETRYABLE' | 'APPLIED';

export interface SyncMutationResult {
  operation_id: string;
  entity_id: string;
  status: SyncResultStatus;
  server_version: number;
  server_timestamp: string;
  error_message?: string;
  order_number?: string;
  client_order_number?: string;
  reassigned_order_number?: string;
  reassigned_token_number?: string;
  token_number?: string;
  conflict_details?: any;
  warning_code?: string;
  warnings?: string[];
}

export interface SyncEntityHandler {
  readonly entityType: string;
  handle(
    tx: Prisma.TransactionClient,
    mutation: SyncMutationDto,
    context: SyncMutationContext,
  ): Promise<SyncMutationResult>;
}
