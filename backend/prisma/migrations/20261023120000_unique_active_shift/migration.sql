-- AlterTable: Add closed_by fields if not present
ALTER TABLE "daily_calculations" ADD COLUMN IF NOT EXISTS "closed_by_id" VARCHAR(36);
ALTER TABLE "daily_calculations" ADD COLUMN IF NOT EXISTS "closed_by_name" VARCHAR(100);

-- Ensure at most one active shift exists before creating index (close older active shifts if any)
UPDATE "daily_calculations"
SET "status" = 'CLOSED'
WHERE "status" = 'ACTIVE'
  AND "id" NOT IN (
    SELECT "id" FROM "daily_calculations"
    WHERE "status" = 'ACTIVE'
    ORDER BY "created_at" DESC
    LIMIT 1
  );

-- Create partial unique index so only ONE active shift can exist at a time
CREATE UNIQUE INDEX IF NOT EXISTS "unique_active_shift" ON "daily_calculations" ("status") WHERE "status" = 'ACTIVE';
