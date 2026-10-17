-- AlterTable
ALTER TABLE "dine_in_order_details" DROP COLUMN "seating_notes";

-- AlterTable
ALTER TABLE "online_order_details" DROP COLUMN "estimated_delivery_at",
DROP COLUMN "platform_order_ref",
DROP COLUMN "special_instructions";

-- AlterTable
ALTER TABLE "takeaway_order_details" DROP COLUMN "pickup_notes";

