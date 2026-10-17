import { Injectable, Logger } from '@nestjs/common';
import { Prisma, SystemChangeLog } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class ChangeLogService {
  private readonly logger = new Logger(ChangeLogService.name);

  constructor(private readonly prisma: PrismaService) {}

  /**
   * Records a system change log entry inside the given transaction client.
   * This MUST be called inside the same transaction as the business write.
   */
  async record(
    tx: Prisma.TransactionClient | PrismaService,
    entity: string,
    id: string,
    op: 'INSERT' | 'UPDATE' | 'DELETE' | string,
    version: number = 1,
    payload: any = {},
    isDeleted: boolean = false,
  ): Promise<SystemChangeLog> {
    const sanitizedPayload =
      payload !== null && typeof payload === 'object'
        ? JSON.parse(JSON.stringify(payload))
        : payload ?? {};

    const entry = await tx.systemChangeLog.create({
      data: {
        entity_type: entity.toLowerCase(),
        entity_id: id,
        operation: op.toUpperCase(),
        record_version: version,
        is_deleted: isDeleted,
        payload: sanitizedPayload,
      },
    });

    return entry;
  }

  /**
   * Returns the current maximum global_sequence in the system change log.
   */
  async getMaxSequence(): Promise<bigint> {
    const latest = await this.prisma.systemChangeLog.findFirst({
      orderBy: { global_sequence: 'desc' },
      select: { global_sequence: true },
    });
    return latest?.global_sequence ?? BigInt(0);
  }
}
