import { Test, TestingModule } from '@nestjs/testing';
import { ConfigService } from '@nestjs/config';
import * as crypto from 'crypto';
import * as argon2 from 'argon2';
import { PasswordService } from './password.service';

describe('PasswordService', () => {
  let service: PasswordService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        PasswordService,
        {
          provide: ConfigService,
          useValue: {
            get: jest.fn((key: string, defaultValue?: unknown) => {
              if (key === 'ARGON2_MEMORY_COST') return 19456;
              if (key === 'ARGON2_TIME_COST') return 2;
              if (key === 'ARGON2_PARALLELISM') return 1;
              return defaultValue;
            }),
          },
        },
      ],
    }).compile();

    service = module.get<PasswordService>(PasswordService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  describe('hash()', () => {
    it('should generate an Argon2id PHC string starting with $argon2id$', async () => {
      const password = 'SecurePassword123!';
      const hash = await service.hash(password);

      expect(hash).toBeDefined();
      expect(hash.startsWith('$argon2id$')).toBe(true);
      expect(hash).toContain('m=19456,p=1,t=2');
    });
  });

  describe('verify()', () => {
    it('should verify a valid password against an Argon2id hash', async () => {
      const password = 'CorrectPassword456!';
      const hash = await service.hash(password);

      const isValid = await service.verify(hash, password);
      expect(isValid).toBe(true);
    });

    it('should reject an invalid password against an Argon2id hash', async () => {
      const password = 'CorrectPassword456!';
      const hash = await service.hash(password);

      const isValid = await service.verify(hash, 'WrongPassword!');
      expect(isValid).toBe(false);
    });

    it('should verify a legacy SHA-256 hash using timingSafeEqual', async () => {
      const plain = 'LegacyPassword789!';
      const legacySha256Hex = crypto.createHash('sha256').update(plain).digest('hex');

      const isValid = await service.verify(legacySha256Hex, plain);
      expect(isValid).toBe(true);
    });

    it('should reject an incorrect password against a legacy SHA-256 hash', async () => {
      const plain = 'LegacyPassword789!';
      const legacySha256Hex = crypto.createHash('sha256').update(plain).digest('hex');

      const isValid = await service.verify(legacySha256Hex, 'InvalidPassword');
      expect(isValid).toBe(false);
    });

    it('should verify a wrapped legacy hash (argon2id-wrap$)', async () => {
      const plain = 'WrappedLegacyPassword!';
      const legacySha256Hex = crypto.createHash('sha256').update(plain).digest('hex');
      const wrappedHash = await service.wrapLegacyHash(legacySha256Hex);

      expect(wrappedHash.startsWith('argon2id-wrap$')).toBe(true);

      const isValid = await service.verify(wrappedHash, plain);
      expect(isValid).toBe(true);
    });

    it('should reject an incorrect password against a wrapped legacy hash', async () => {
      const plain = 'WrappedLegacyPassword!';
      const legacySha256Hex = crypto.createHash('sha256').update(plain).digest('hex');
      const wrappedHash = await service.wrapLegacyHash(legacySha256Hex);

      const isValid = await service.verify(wrappedHash, 'WrongPlainPassword');
      expect(isValid).toBe(false);
    });

    it('should return false for empty or invalid hashes', async () => {
      expect(await service.verify('', 'password')).toBe(false);
      expect(await service.verify(null as unknown as string, 'password')).toBe(false);
      expect(await service.verify('invalid-hash', '')).toBe(false);
    });
  });

  describe('needsRehash()', () => {
    it('should return true for legacy SHA-256 hashes', () => {
      const legacySha256Hex = crypto.createHash('sha256').update('pass').digest('hex');
      expect(service.needsRehash(legacySha256Hex)).toBe(true);
    });

    it('should return true for wrapped legacy hashes', async () => {
      const legacySha256Hex = crypto.createHash('sha256').update('pass').digest('hex');
      const wrapped = await service.wrapLegacyHash(legacySha256Hex);
      expect(service.needsRehash(wrapped)).toBe(true);
    });

    it('should return false for Argon2id hashes with matching cost parameters', async () => {
      const hash = await service.hash('MatchingParamsPassword');
      expect(service.needsRehash(hash)).toBe(false);
    });

    it('should return true if Argon2 parameters differ (e.g. higher memory)', async () => {
      // Create hash with different memory cost
      const oldHash = await argon2.hash('OldParamsPassword', {
        type: argon2.argon2id,
        memoryCost: 32768,
        timeCost: 3,
        parallelism: 2,
      });

      expect(service.needsRehash(oldHash)).toBe(true);
    });
  });

  describe('wrapLegacyHash()', () => {
    it('should wrap legacy hash as argon2id-wrap$ + argon2id(legacyHashHex)', async () => {
      const legacyHex = crypto.createHash('sha256').update('test').digest('hex');
      const wrapped = await service.wrapLegacyHash(legacyHex);

      expect(wrapped.startsWith('argon2id-wrap$')).toBe(true);
      const inner = wrapped.slice('argon2id-wrap$'.length);
      expect(inner.startsWith('$argon2id$')).toBe(true);

      const innerValid = await argon2.verify(inner, legacyHex);
      expect(innerValid).toBe(true);
    });
  });
});
