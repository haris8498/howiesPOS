-- AlterTable
ALTER TABLE "processed_operations" ALTER COLUMN "operation_id" TYPE VARCHAR(128);
ALTER TABLE "processed_operations" ALTER COLUMN "entity_id" TYPE VARCHAR(128);

-- AlterTable
ALTER TABLE "system_change_logs" ALTER COLUMN "entity_id" TYPE VARCHAR(128);
