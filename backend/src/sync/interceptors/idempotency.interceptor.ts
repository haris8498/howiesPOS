import {
  CallHandler,
  ConflictException,
  ExecutionContext,
  Injectable,
  Logger,
  NestInterceptor,
  Optional,
} from '@nestjs/common';
import { Observable, from, of, throwError } from 'rxjs';
import { catchError, switchMap, tap } from 'rxjs/operators';
import { Request, Response } from 'express';
import * as crypto from 'crypto';
import { PrismaService } from '../../prisma/prisma.service';

export interface IdempotencyInterceptorOptions {
  staleTimeoutMs?: number;
  pollIntervalMs?: number;
  maxWaitMs?: number;
}

/**
 * Deterministically sort and canonicalize JSON objects for hashing.
 */
export function canonicalJson(obj: any): string {
  if (obj === null || obj === undefined) return '';
  if (typeof obj !== 'object') return JSON.stringify(obj);
  if (Array.isArray(obj)) {
    return '[' + obj.map(canonicalJson).join(',') + ']';
  }
  const keys = Object.keys(obj).sort();
  return '{' + keys.map((k) => JSON.stringify(k) + ':' + canonicalJson(obj[k])).join(',') + '}';
}

/**
 * Safely serialize response payloads (handling BigInt, Date, etc.)
 */
export function safeJsonSerialize(data: any): any {
  if (data === null || data === undefined) return null;
  return JSON.parse(
    JSON.stringify(data, (_, v) => (typeof v === 'bigint' ? v.toString() : v)),
  );
}

/**
 * Idempotency Interceptor (§8.2, §7.1, §15.2)
 *
 * Enforces server idempotency via the `processed_operations` ledger table:
 * 1. Intercepts write requests carrying X-Idempotency-Key or operation_id.
 * 2. SHA-256 request_hash prevents identical keys being used with differing payloads (409 Conflict).
 * 3. In-flight locking via status 'PROCESSING' prevents concurrent duplicate execution.
 * 4. Stale recovery (>30s) allows safe recovery if server previously crashed mid-processing.
 * 5. Returns cached response immediately if operation already COMPLETED.
 */
@Injectable()
export class IdempotencyInterceptor implements NestInterceptor {
  private readonly logger = new Logger(IdempotencyInterceptor.name);
  private readonly staleTimeoutMs: number;
  private readonly pollIntervalMs: number;
  private readonly maxWaitMs: number;

  constructor(
    @Optional() private readonly prisma?: PrismaService,
    @Optional() options?: IdempotencyInterceptorOptions,
  ) {
    this.staleTimeoutMs = options?.staleTimeoutMs ?? 30000; // 30 seconds
    this.pollIntervalMs = options?.pollIntervalMs ?? 50;    // 50 milliseconds
    this.maxWaitMs = options?.maxWaitMs ?? 3000;           // 3 seconds
  }

  async intercept(context: ExecutionContext, next: CallHandler): Promise<Observable<any>> {
    const httpCtx = context.switchToHttp();
    const req = httpCtx.getRequest<Request>();
    const res = httpCtx.getResponse<Response>();

    // 1. Extract idempotency key / operation_id
    const rawKey =
      (req.headers ? (req.headers['x-idempotency-key'] || req.headers['idempotency-key']) : undefined) ||
      req.body?.operation_id ||
      req.body?.batch_id;

    if (!rawKey || typeof rawKey !== 'string' || !rawKey.trim() || !this.prisma) {
      // No idempotency key provided or prisma unavailable — pass through without overhead
      return next.handle();
    }

    const prisma = this.prisma;
    const operationId = String(rawKey).trim();
    const requestHash = this.computeRequestHash(req);
    const deviceId =
      (req.headers ? (req.headers['x-device-id'] as string) : undefined) ||
      req.body?.device_id ||
      'UNKNOWN_DEVICE';
    const entityType = this.resolveEntityType(req);
    const entityId = String(
      req.body?.entity_id || req.body?.id || req.params?.id || operationId,
    );

    // 2. Query idempotency ledger
    const existing = await prisma.processedOperation.findUnique({
      where: { operation_id: operationId },
    });

    if (existing) {
      if (existing.status === 'COMPLETED') {
        // Verify payload hash matches
        if (existing.request_hash !== requestHash) {
          this.logger.warn(
            `Idempotency key collision on '${operationId}': request hash mismatch (existing=${existing.request_hash}, incoming=${requestHash})`,
          );
          throw new ConflictException(
            'Idempotency key reused with different request payload (request hash mismatch)',
          );
        }

        this.logger.log(`Idempotency cache hit for operation '${operationId}' — returning cached response`);
        if (res && typeof res.status === 'function') {
          res.status(existing.http_status || 200);
        }
        return of(existing.response_payload);
      }

      if (existing.status === 'PROCESSING') {
        const now = Date.now();
        const createdAt = existing.created_at ? new Date(existing.created_at).getTime() : now;
        const isStale = now - createdAt > this.staleTimeoutMs;

        if (isStale) {
          // Crash mid-processing recovery (§15.3): claim the stale lock and re-execute
          this.logger.warn(
            `Recovering stale PROCESSING operation '${operationId}' (created ${Math.round((now - createdAt) / 1000)}s ago)`,
          );
          await prisma.processedOperation.update({
            where: { operation_id: operationId },
            data: {
              status: 'PROCESSING',
              request_hash: requestHash,
              created_at: new Date(),
              device_id: deviceId,
              entity_type: entityType,
              entity_id: entityId,
              response_payload: undefined,
              completed_at: null,
            },
          });
        } else {
          // Concurrent duplicate in-flight (§15.2 Gate 4): wait for the current in-flight execution to complete
          return this.handleConcurrentInFlight(operationId, requestHash, res);
        }
      }
    } else {
      // 3. Insert 'PROCESSING' record
      try {
        await prisma.processedOperation.create({
          data: {
            operation_id: operationId,
            device_id: deviceId,
            entity_type: entityType,
            entity_id: entityId,
            request_hash: requestHash,
            status: 'PROCESSING',
            http_status: 200,
          },
        });
      } catch (err: any) {
        if (err?.code === 'P2002' || (err?.message && err.message.toLowerCase().includes('unique constraint'))) {
          // Concurrent race: another worker created the record at the exact same instant
          return this.handleConcurrentInFlight(operationId, requestHash, res);
        }
        throw err;
      }
    }

    // 4. Execute handler and store COMPLETED result upon success
    return next.handle().pipe(
      tap(async (responseBody) => {
        const httpStatus = res && res.statusCode ? res.statusCode : 200;
        try {
          await prisma.processedOperation.update({
            where: { operation_id: operationId },
            data: {
              status: 'COMPLETED',
              response_payload: safeJsonSerialize(responseBody),
              http_status: httpStatus,
              completed_at: new Date(),
            },
          });
        } catch (saveErr: any) {
          this.logger.error(
            `Failed to mark operation '${operationId}' as COMPLETED: ${saveErr?.message}`,
          );
        }
      }),
      catchError((err) => {
        // On error or transaction rollback, delete the lock record so subsequent retries are unblocked
        return from(
          prisma.processedOperation
            .delete({ where: { operation_id: operationId } })
            .catch(() => null),
        ).pipe(
          switchMap(() => throwError(() => err)),
        );
      }),
    );
  }

  /**
   * Handle concurrent in-flight duplicates: poll for completion within timeout.
   */
  private async handleConcurrentInFlight(
    operationId: string,
    requestHash: string,
    res?: Response,
  ): Promise<Observable<any>> {
    this.logger.log(`Concurrent duplicate detected for operation '${operationId}' — awaiting completion`);
    const completed = await this.waitForCompletion(operationId);

    if (completed) {
      if (completed.request_hash !== requestHash) {
        throw new ConflictException(
          'Idempotency key reused with different request payload (request hash mismatch)',
        );
      }
      if (res && typeof res.status === 'function') {
        res.status(completed.http_status || 200);
      }
      return of(completed.response_payload);
    }

    // Still in flight after max wait timeout
    throw new ConflictException(
      'A request with this idempotency key is currently being processed. Please retry shortly.',
    );
  }

  /**
   * Polls the database until the given operation completes or timeout expires.
   */
  private async waitForCompletion(operationId: string) {
    if (!this.prisma) return null;
    const startTime = Date.now();
    while (Date.now() - startTime < this.maxWaitMs) {
      await this.sleep(this.pollIntervalMs);
      if (!this.prisma) return null;
      const record = await this.prisma.processedOperation.findUnique({
        where: { operation_id: operationId },
      });
      if (record && record.status === 'COMPLETED') {
        return record;
      }
    }
    return null;
  }

  private sleep(ms: number): Promise<void> {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }

  /**
   * Computes a deterministic SHA-256 hash (64 hex characters) of the request.
   */
  computeRequestHash(req: Request): string {
    const method = req.method || 'POST';
    const path = req.originalUrl || req.url || req.path || '';
    const bodyStr = canonicalJson(req.body || {});
    const combined = `${method}:${path}:${bodyStr}`;
    return crypto.createHash('sha256').update(combined).digest('hex');
  }

  /**
   * Resolves entity type from request metadata.
   */
  private resolveEntityType(req: Request): string {
    if (req.body?.entity_type) return String(req.body.entity_type);
    const url = (req.originalUrl || req.url || '').toLowerCase();
    if (url.includes('/sync/push')) return 'sync_push';
    if (url.includes('/orders')) return 'order';
    if (url.includes('/daily-calculation')) return 'shift';
    if (url.includes('/tables')) return 'table';
    return 'generic';
  }
}
