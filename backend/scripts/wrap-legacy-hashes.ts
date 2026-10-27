import { PrismaClient } from '@prisma/client';
import * as argon2 from 'argon2';

const WRAPPED_PREFIX = 'argon2id-wrap$';
const ARGON2ID_PREFIX = '$argon2id$';

export interface WrapResult {
  totalScanned: number;
  alreadyProtected: number;
  wrappedCount: number;
  dryRun: boolean;
}

export async function wrapLegacyHashes(options?: {
  execute?: boolean;
  prismaClient?: PrismaClient;
}): Promise<WrapResult> {
  const isDryRun =
    !options?.execute &&
    !process.argv.includes('--execute') &&
    !process.argv.includes('--apply');

  const prisma = options?.prismaClient || new PrismaClient();

  console.log(`\n======================================================`);
  console.log(`Hungry Howie's - Legacy Password Hash Wrapping Script`);
  console.log(
    `Mode: ${isDryRun ? 'DRY-RUN (no changes will be written)' : 'LIVE EXECUTION (database will be updated)'}`,
  );
  console.log(`======================================================\n`);

  const users = await prisma.staffUser.findMany({
    select: {
      id: true,
      username: true,
      password_hash: true,
      plain_password: true,
    },
    orderBy: { username: 'asc' },
  });

  let alreadyProtected = 0;
  let wrappedCount = 0;

  for (const user of users) {
    const hash = (user.password_hash || '').trim();

    // Idempotent: Skip if already native Argon2id or already wrapped
    if (hash.startsWith(ARGON2ID_PREFIX)) {
      console.log(`[SKIPPED] @${user.username} - Already native Argon2id.`);
      alreadyProtected++;
      continue;
    }

    if (hash.startsWith(WRAPPED_PREFIX)) {
      console.log(`[SKIPPED] @${user.username} - Already wrapped legacy hash.`);
      alreadyProtected++;
      continue;
    }

    // Hash is legacy SHA-256 (or other un-slowed legacy format)
    const cleanLegacyHash = hash.toLowerCase();
    const argon2OfLegacy = await argon2.hash(cleanLegacyHash, {
      type: argon2.argon2id,
      memoryCost: 19456,
      timeCost: 2,
      parallelism: 1,
    });

    const finalWrappedHash = `${WRAPPED_PREFIX}${argon2OfLegacy}`;

    if (isDryRun) {
      console.log(
        `[DRY-RUN] @${user.username} (id: ${user.id}): Would wrap legacy hash '${hash.slice(0, 12)}...' -> '${finalWrappedHash.slice(0, 28)}...' and set plain_password = null`,
      );
    } else {
      await prisma.staffUser.update({
        where: { id: user.id },
        data: {
          password_hash: finalWrappedHash,
          plain_password: null,
        },
      });
      console.log(
        `[APPLIED] @${user.username} (id: ${user.id}): Wrapped legacy hash and cleared plain_password`,
      );
    }
    wrappedCount++;
  }

  console.log(`\n------------------------------------------------------`);
  console.log(`Summary:`);
  console.log(`  Total users scanned: ${users.length}`);
  console.log(`  Already protected:   ${alreadyProtected}`);
  console.log(
    `  ${isDryRun ? 'Would wrap:' : 'Successfully wrapped:'}     ${wrappedCount}`,
  );
  if (isDryRun) {
    console.log(
      `\nNotice: This was a dry run. To execute against the database, pass --execute or --apply.`,
    );
  }
  console.log(`------------------------------------------------------\n`);

  if (!options?.prismaClient) {
    await prisma.$disconnect();
  }

  return {
    totalScanned: users.length,
    alreadyProtected,
    wrappedCount,
    dryRun: isDryRun,
  };
}

if (require.main === module) {
  wrapLegacyHashes().catch((err) => {
    console.error('Migration failed with error:', err);
    process.exit(1);
  });
}
