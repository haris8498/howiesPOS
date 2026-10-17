import { Prisma } from '@prisma/client';
import * as fs from 'fs';
import * as path from 'path';

describe('Offline Schema Additions (Stage 1 / Spec §7.1 - §7.3)', () => {
  const getModel = (name: string) => {
    const model = Prisma.dmmf.datamodel.models.find((m) => m.name === name);
    expect(model).toBeDefined();
    return model!;
  };

  const getField = (modelName: string, fieldName: string) => {
    const model = getModel(modelName);
    const field = model.fields.find((f) => f.name === fieldName);
    expect(field).toBeDefined();
    return field!;
  };

  describe('ProcessedOperation Model (§7.1)', () => {
    it('should define ProcessedOperation model with correct columns and types', () => {
      const model = getModel('ProcessedOperation');
      expect(model.dbName).toBe('processed_operations');

      const opId = getField('ProcessedOperation', 'operation_id');
      expect(opId.isId).toBe(true);
      expect(opId.type).toBe('String');

      const devId = getField('ProcessedOperation', 'device_id');
      expect(devId.type).toBe('String');

      const entityType = getField('ProcessedOperation', 'entity_type');
      expect(entityType.type).toBe('String');

      const entityId = getField('ProcessedOperation', 'entity_id');
      expect(entityId.type).toBe('String');

      const reqHash = getField('ProcessedOperation', 'request_hash');
      expect(reqHash.type).toBe('String');

      const status = getField('ProcessedOperation', 'status');
      expect(status.default).toBe('PROCESSING');

      const resPayload = getField('ProcessedOperation', 'response_payload');
      expect(resPayload.type).toBe('Json');
      expect(resPayload.isRequired).toBe(false);

      const httpStatus = getField('ProcessedOperation', 'http_status');
      expect(httpStatus.type).toBe('Int');
      expect(httpStatus.default).toBe(200);

      const createdAt = getField('ProcessedOperation', 'created_at');
      expect(createdAt.type).toBe('DateTime');

      const completedAt = getField('ProcessedOperation', 'completed_at');
      expect(completedAt.isRequired).toBe(false);
    });
  });

  describe('SystemChangeLog Model (§7.1)', () => {
    it('should define SystemChangeLog model with monotonic global_sequence', () => {
      const model = getModel('SystemChangeLog');
      expect(model.dbName).toBe('system_change_logs');

      const seq = getField('SystemChangeLog', 'global_sequence');
      expect(seq.isId).toBe(true);
      expect(seq.type).toBe('BigInt');
      expect(seq.default).toEqual({ name: 'autoincrement', args: [] });

      const entityType = getField('SystemChangeLog', 'entity_type');
      expect(entityType.type).toBe('String');

      const entityId = getField('SystemChangeLog', 'entity_id');
      expect(entityId.type).toBe('String');

      const operation = getField('SystemChangeLog', 'operation');
      expect(operation.type).toBe('String');

      const recordVersion = getField('SystemChangeLog', 'record_version');
      expect(recordVersion.type).toBe('Int');
      expect(recordVersion.default).toBe(1);

      const isDeleted = getField('SystemChangeLog', 'is_deleted');
      expect(isDeleted.type).toBe('Boolean');
      expect(isDeleted.default).toBe(false);

      const payload = getField('SystemChangeLog', 'payload');
      expect(payload.type).toBe('Json');

      const createdAt = getField('SystemChangeLog', 'created_at');
      expect(createdAt.type).toBe('DateTime');
    });
  });

  describe('OCC Versioning & Timestamps (§7.2)', () => {
    it('should have version and updated_at on Order', () => {
      const version = getField('Order', 'version');
      expect(version.type).toBe('Int');
      expect(version.default).toBe(1);

      const updatedAt = getField('Order', 'updated_at');
      expect(updatedAt.type).toBe('DateTime');
      expect(updatedAt.isUpdatedAt).toBe(true);
    });

    it('should have version and updated_at on RestaurantTable', () => {
      const version = getField('RestaurantTable', 'version');
      expect(version.type).toBe('Int');
      expect(version.default).toBe(1);

      const updatedAt = getField('RestaurantTable', 'updated_at');
      expect(updatedAt.type).toBe('DateTime');
      expect(updatedAt.isUpdatedAt).toBe(true);
    });

    it('should have version and updated_at on DailyCalculation', () => {
      const version = getField('DailyCalculation', 'version');
      expect(version.type).toBe('Int');
      expect(version.default).toBe(1);

      const updatedAt = getField('DailyCalculation', 'updated_at');
      expect(updatedAt.type).toBe('DateTime');
      expect(updatedAt.isUpdatedAt).toBe(true);
    });
  });

  describe('Soft-Delete Columns (§7.2)', () => {
    it('should have is_deleted and deleted_at on MenuItem', () => {
      const isDeleted = getField('MenuItem', 'is_deleted');
      expect(isDeleted.type).toBe('Boolean');
      expect(isDeleted.default).toBe(false);

      const deletedAt = getField('MenuItem', 'deleted_at');
      expect(deletedAt.type).toBe('DateTime');
      expect(deletedAt.isRequired).toBe(false);
    });

    it('should have is_deleted and deleted_at on Customer', () => {
      const isDeleted = getField('Customer', 'is_deleted');
      expect(isDeleted.type).toBe('Boolean');
      expect(isDeleted.default).toBe(false);

      const deletedAt = getField('Customer', 'deleted_at');
      expect(deletedAt.type).toBe('DateTime');
      expect(deletedAt.isRequired).toBe(false);
    });
  });

  describe('Shift Variance & Status (§7.3)', () => {
    it('should have cash_variance and variance_reason on DailyCalculation', () => {
      const cashVariance = getField('DailyCalculation', 'cash_variance');
      expect(cashVariance.type).toBe('Decimal');
      expect(Number(cashVariance.default)).toBe(0);

      const varianceReason = getField('DailyCalculation', 'variance_reason');
      expect(varianceReason.type).toBe('String');
      expect(varianceReason.isRequired).toBe(false);

      const status = getField('DailyCalculation', 'status');
      expect(status.type).toBe('String');
      expect(status.default).toBe('ACTIVE');
    });
  });

  describe('Additive Migration Script Verification', () => {
    it('should include all required tables and indexes in migration SQL', () => {
      const migrationPath = path.resolve(
        __dirname,
        '../../prisma/migrations/20261017000000_offline_sync_schema/migration.sql',
      );
      expect(fs.existsSync(migrationPath)).toBe(true);

      const sql = fs.readFileSync(migrationPath, 'utf8');
      expect(sql).toContain('CREATE TABLE "processed_operations"');
      expect(sql).toContain('CREATE TABLE "system_change_logs"');
      expect(sql).toContain('CREATE INDEX "processed_operations_device_id_created_at_idx"');
      expect(sql).toContain('CREATE INDEX "processed_operations_entity_type_entity_id_idx"');
      expect(sql).toContain('CREATE INDEX "system_change_logs_global_sequence_idx"');
      expect(sql).toContain('CREATE INDEX "system_change_logs_entity_type_entity_id_idx"');
      expect(sql).toContain('"updated_at" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP');
      expect(sql).toContain('"version" INTEGER NOT NULL DEFAULT 1');
      expect(sql).toContain('"cash_variance" DECIMAL(10,2) NOT NULL DEFAULT 0.00');
      expect(sql).toContain('"variance_reason" VARCHAR(255)');
      expect(sql).toContain('"is_deleted" BOOLEAN NOT NULL DEFAULT false');
      expect(sql).toContain('"deleted_at" TIMESTAMP');
    });
  });
});
