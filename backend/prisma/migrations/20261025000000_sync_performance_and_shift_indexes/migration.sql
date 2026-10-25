-- CreateIndex
CREATE INDEX IF NOT EXISTS "orders_shift_id_idx" ON "orders"("shift_id");
CREATE INDEX IF NOT EXISTS "orders_status_idx" ON "orders"("status");
CREATE INDEX IF NOT EXISTS "orders_created_at_idx" ON "orders"("created_at");

-- CreateIndex
CREATE INDEX IF NOT EXISTS "daily_calculations_status_idx" ON "daily_calculations"("status");
CREATE INDEX IF NOT EXISTS "daily_calculations_date_idx" ON "daily_calculations"("date");
CREATE INDEX IF NOT EXISTS "daily_calculations_cashier_id_idx" ON "daily_calculations"("cashier_id");
