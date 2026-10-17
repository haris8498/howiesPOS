import { ChangeLogService } from './change-log.service';
import { PrismaService } from '../prisma/prisma.service';

describe('ChangeLogService', () => {
  let service: ChangeLogService;
  let mockPrisma: any;

  beforeEach(() => {
    mockPrisma = {
      systemChangeLog: {
        create: jest.fn(),
        findFirst: jest.fn(),
      },
    };
    service = new ChangeLogService(mockPrisma as PrismaService);
  });

  it('should record an entry inside the provided transaction client', async () => {
    const mockTx = {
      systemChangeLog: {
        create: jest.fn().mockResolvedValue({
          global_sequence: BigInt(42),
          entity_type: 'order',
          entity_id: 'ord-123',
          operation: 'INSERT',
          record_version: 1,
          is_deleted: false,
          payload: { grand_total: 50 },
        }),
      },
    };

    const result = await service.record(
      mockTx as any,
      'Order',
      'ord-123',
      'insert',
      1,
      { grand_total: 50 },
      false,
    );

    expect(mockTx.systemChangeLog.create).toHaveBeenCalledWith({
      data: {
        entity_type: 'order',
        entity_id: 'ord-123',
        operation: 'INSERT',
        record_version: 1,
        is_deleted: false,
        payload: { grand_total: 50 },
      },
    });
    expect(result.global_sequence).toBe(BigInt(42));
  });

  it('should get max sequence from system change logs', async () => {
    mockPrisma.systemChangeLog.findFirst.mockResolvedValue({
      global_sequence: BigInt(500),
    });

    const maxSeq = await service.getMaxSequence();
    expect(maxSeq).toBe(BigInt(500));
  });

  it('should return 0n if system change log is empty', async () => {
    mockPrisma.systemChangeLog.findFirst.mockResolvedValue(null);

    const maxSeq = await service.getMaxSequence();
    expect(maxSeq).toBe(BigInt(0));
  });
});
