import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as argon2 from 'argon2';
import * as crypto from 'crypto';

export const WRAPPED_LEGACY_PREFIX = 'argon2id-wrap$';
export const ARGON2ID_PREFIX = '$argon2id$';

@Injectable()
export class PasswordService {
  private readonly logger = new Logger(PasswordService.name);

  readonly memoryCost: number;
  readonly timeCost: number;
  readonly parallelism: number;

  constructor(private readonly configService: ConfigService) {
    // OWASP minimum recommendations for Argon2id: m=19456 KiB (19 MiB), t=2, p=1
    const rawMemory = this.configService.get<string | number>('ARGON2_MEMORY_COST');
    const rawTime = this.configService.get<string | number>('ARGON2_TIME_COST');
    const rawParallelism = this.configService.get<string | number>('ARGON2_PARALLELISM');

    this.memoryCost = rawMemory ? Number(rawMemory) : 19456;
    this.timeCost = rawTime ? Number(rawTime) : 2;
    this.parallelism = rawParallelism ? Number(rawParallelism) : 1;
  }

  /**
   * Hashes a password using Argon2id with OWASP-recommended parameters.
   * Returns a standard PHC formatted string ($argon2id$v=19$m=19456,p=1,t=2$...).
   */
  async hash(password: string): Promise<string> {
    return argon2.hash(password, {
      type: argon2.argon2id,
      memoryCost: this.memoryCost,
      timeCost: this.timeCost,
      parallelism: this.parallelism,
    });
  }

  /**
   * Verifies a candidate plaintext password against a stored password hash.
   *
   * Supports:
   * 1. Standard Argon2id PHC hashes ($argon2id$ prefix)
   * 2. Wrapped legacy hashes (argon2id-wrap$ prefix) -> verifies against wrapped legacy SHA-256 hex
   * 3. Legacy SHA-256 hex hashes -> verifies using constant-time timingSafeEqual
   */
  async verify(storedHash: string, plain: string): Promise<boolean> {
    if (!storedHash || typeof storedHash !== 'string' || !plain || typeof plain !== 'string') {
      return false;
    }

    const trimmedHash = storedHash.trim();

    // 1. Standard Argon2id
    if (trimmedHash.startsWith(ARGON2ID_PREFIX)) {
      try {
        return await argon2.verify(trimmedHash, plain);
      } catch (err: unknown) {
        this.logger.warn(`Argon2 verification failed: ${(err as Error)?.message ?? err}`);
        return false;
      }
    }

    // 2. Wrapped legacy hash: argon2id-wrap$ + argon2id(legacyHashHex)
    if (trimmedHash.startsWith(WRAPPED_LEGACY_PREFIX)) {
      try {
        const innerHash = trimmedHash.slice(WRAPPED_LEGACY_PREFIX.length);
        const legacyCandidateHex = crypto.createHash('sha256').update(plain).digest('hex');
        return await argon2.verify(innerHash, legacyCandidateHex);
      } catch (err: unknown) {
        this.logger.warn(`Wrapped legacy verification failed: ${(err as Error)?.message ?? err}`);
        return false;
      }
    }

    // 3. Legacy raw SHA-256 hex compared with timingSafeEqual
    try {
      const legacyCandidateHex = crypto.createHash('sha256').update(plain).digest('hex');
      const storedBuf = Buffer.from(trimmedHash.toLowerCase(), 'utf8');
      const candidateBuf = Buffer.from(legacyCandidateHex.toLowerCase(), 'utf8');

      if (storedBuf.length !== candidateBuf.length) {
        // Run dummy timingSafeEqual to avoid timing discrepancy leak
        crypto.timingSafeEqual(candidateBuf, candidateBuf);
        return false;
      }

      return crypto.timingSafeEqual(storedBuf, candidateBuf);
    } catch (err: unknown) {
      this.logger.warn(`Legacy hash comparison error: ${(err as Error)?.message ?? err}`);
      return false;
    }
  }

  /**
   * Determines if a stored hash needs re-hashing to the current Argon2id parameters.
   * True if:
   * - Hash is not Argon2id (e.g. legacy SHA-256 or wrapped legacy hash)
   * - Hash is Argon2id but was hashed with older/lower cost parameters
   */
  needsRehash(storedHash: string): boolean {
    if (!storedHash || typeof storedHash !== 'string') {
      return true;
    }

    const trimmedHash = storedHash.trim();

    // Legacy and wrapped hashes always need upgrade to native Argon2id
    if (!trimmedHash.startsWith(ARGON2ID_PREFIX)) {
      return true;
    }

    try {
      return argon2.needsRehash(trimmedHash, {
        memoryCost: this.memoryCost,
        timeCost: this.timeCost,
        parallelism: this.parallelism,
      });
    } catch {
      return true;
    }
  }

  /**
   * Wraps a legacy SHA-256 hex hash with Argon2id without needing the plaintext.
   * Stored format: argon2id-wrap$ + argon2id(legacyHashHex).
   * This is used by the bulk migration script.
   */
  async wrapLegacyHash(legacyHashHex: string): Promise<string> {
    const wrapped = await this.hash(legacyHashHex.trim().toLowerCase());
    return `${WRAPPED_LEGACY_PREFIX}${wrapped}`;
  }
}
