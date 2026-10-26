-- Migration: 20261026100000_terminal_scoped_active_shift_and_devices
-- Description: Drop single-shift global unique constraint, scope active shift per terminal (restaurant_id, terminal_id), and create devices table.

-- 1. Add restaurant_id and terminal_id to daily_calculations if missing
ALTER TABLE "daily_calculations" ADD COLUMN IF NOT EXISTS "restaurant_id" VARCHAR(50) NOT NULL DEFAULT 'default';
ALTER TABLE "daily_calculations" ADD COLUMN IF NOT EXISTS "terminal_id" VARCHAR(50) NOT NULL DEFAULT '1';

-- Backfill legacy records
UPDATE "daily_calculations" SET "terminal_id" = '1' WHERE "terminal_id" IS NULL OR "terminal_id" = '';
UPDATE "daily_calculations" SET "restaurant_id" = 'default' WHERE "restaurant_id" IS NULL OR "restaurant_id" = '';

-- 2. Drop the old store-wide unique active shift index
DROP INDEX IF EXISTS "unique_active_shift";

-- Ensure at most one active shift exists per (restaurant_id, terminal_id) before creating index
-- If multiple active shifts exist on the SAME terminal, close older active ones
UPDATE "daily_calculations"
SET "status" = 'CLOSED'
WHERE "status" = 'ACTIVE'
  AND "id" NOT IN (
    SELECT DISTINCT ON ("restaurant_id", "terminal_id") "id"
    FROM "daily_calculations"
    WHERE "status" = 'ACTIVE'
    ORDER BY "restaurant_id", "terminal_id", "created_at" DESC
  );

-- 3. Create new partial unique index scoped per terminal: unique (restaurant_id, terminal_id) WHERE status = 'ACTIVE'
CREATE UNIQUE INDEX IF NOT EXISTS "unique_active_shift_per_terminal"
ON "daily_calculations" ("restaurant_id", "terminal_id")
WHERE "status" = 'ACTIVE';

CREATE INDEX IF NOT EXISTS "daily_calculations_restaurant_id_terminal_id_idx"
ON "daily_calculations" ("restaurant_id", "terminal_id");

-- 4. Create devices table for device identity registration & validation
CREATE TABLE IF NOT EXISTS "devices" (
    "id" VARCHAR(36) NOT NULL,
    "device_id" VARCHAR(100) NOT NULL,
    "restaurant_id" VARCHAR(50) NOT NULL DEFAULT 'default',
    "terminal_id" VARCHAR(50) DEFAULT '1',
    "terminal_name" VARCHAR(100),
    "is_blocked" BOOLEAN NOT NULL DEFAULT false,
    "last_seen_at" TIMESTAMP,
    "created_at" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "devices_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX IF NOT EXISTS "devices_restaurant_id_device_id_key" ON "devices"("restaurant_id", "device_id");
CREATE INDEX IF NOT EXISTS "devices_restaurant_id_terminal_id_idx" ON "devices"("restaurant_id", "terminal_id");

-- Down / Rollback instructions:
-- To rollback this migration:
-- DROP INDEX IF EXISTS "unique_active_shift_per_terminal";
-- DROP INDEX IF EXISTS "daily_calculations_restaurant_id_terminal_id_idx";
-- CREATE UNIQUE INDEX IF NOT EXISTS "unique_active_shift" ON "daily_calculations" ("status") WHERE "status" = 'ACTIVE';
-- ALTER TABLE "daily_calculations" DROP COLUMN IF EXISTS "terminal_id";
-- ALTER TABLE "daily_calculations" DROP COLUMN IF EXISTS "restaurant_id";
-- DROP TABLE IF EXISTS "devices";
