import * as crypto from 'crypto';
import * as argon2 from 'argon2';
import { wrapLegacyHashes } from '../../scripts/wrap-legacy-hashes';
import { PrismaClient } from '@prisma/client';

jest.mock('@prisma/client');

describe('wrapLegacyHashes bulk migration script', () => {
  const legacyPlain = 'CashierPass123';
  const legacyHashHex = crypto.createHash('sha256').update(legacyPlain).digest('hex');

  let mockFindMany: jest.Mock;
  let mockUpdate: jest.Mock;

  beforeEach(() => {
    mockFindMany = jest.fn();
    mockUpdate = jest.fn();

    (PrismaClient as unknown as jest.Mock).mockImplementation(() => ({
      staffUser: {
        findMany: mockFindMany,
        update: mockUpdate,
      },
      $disconnect: jest.fn().mockResolvedValue(undefined),
    }));
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  it('dry-run mode should report what would be wrapped without modifying database', async () => {
    const mockUsers = [
      { id: 'u1', username: 'legacy1', password_hash: legacyHashHex, plain_password: 'pass' },
      {
        id: 'u2',
        username: 'modern1',
        password_hash: '$argon2id$v=19$m=19456...',
        plain_password: null,
      },
      {
        id: 'u3',
        username: 'wrapped1',
        password_hash: 'argon2id-wrap$$argon2id$...',
        plain_password: null,
      },
    ];
    mockFindMany.mockResolvedValue(mockUsers);

    const result = await wrapLegacyHashes({ execute: false });

    expect(result.dryRun).toBe(true);
    expect(result.totalScanned).toBe(3);
    expect(result.alreadyProtected).toBe(2);
    expect(result.wrappedCount).toBe(1);
    expect(mockUpdate).not.toHaveBeenCalled();
  });

  it('execute mode should wrap legacy hashes, clear plain_password, and remain idempotent', async () => {
    const mockUsers = [
      { id: 'u1', username: 'legacy1', password_hash: legacyHashHex, plain_password: 'pass' },
      {
        id: 'u2',
        username: 'modern1',
        password_hash: '$argon2id$v=19$m=19456...',
        plain_password: null,
      },
    ];
    mockFindMany.mockResolvedValue(mockUsers);
    mockUpdate.mockResolvedValue({});

    const result = await wrapLegacyHashes({ execute: true });

    expect(result.dryRun).toBe(false);
    expect(result.totalScanned).toBe(2);
    expect(result.alreadyProtected).toBe(1);
    expect(result.wrappedCount).toBe(1);

    expect(mockUpdate).toHaveBeenCalledTimes(1);
    const updateCall = mockUpdate.mock.calls[0][0];
    expect(updateCall.where).toEqual({ id: 'u1' });
    expect(updateCall.data.password_hash.startsWith('argon2id-wrap$')).toBe(true);
    expect(updateCall.data.plain_password).toBeNull();

    // Verify inner hash verifies against legacyHashHex
    const innerHash = updateCall.data.password_hash.slice('argon2id-wrap$'.length);
    const valid = await argon2.verify(innerHash, legacyHashHex);
    expect(valid).toBe(true);
  });
});
