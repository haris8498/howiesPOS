import { IsArray, IsBoolean, IsNotEmpty, IsOptional, IsString } from 'class-validator';

export class BatchSyncOrdersDto {
  @IsArray()
  @IsNotEmpty()
  orders!: any[];

  @IsString()
  @IsOptional()
  device_id?: string;
}

export class SyncSingleOrderDto {
  @IsString()
  @IsNotEmpty()
  order_id!: string;

  @IsString()
  @IsOptional()
  reason?: string;
}

export class ToggleSyncStatusDto {
  @IsString()
  @IsOptional()
  status?: string; // 'synced' | 'pending' | 'failed'
}

export class CreateSyncLogDto {
  @IsString()
  @IsOptional()
  order_id?: string;

  @IsString()
  @IsOptional()
  order_number?: string;

  @IsString()
  @IsOptional()
  sync_type?: string; // 'ORDER', 'EXPENSE', 'TABLE', 'INVENTORY'

  @IsString()
  @IsOptional()
  sync_status?: string; // 'synced', 'pending', 'failed'

  @IsBoolean()
  @IsOptional()
  is_synced?: boolean;

  @IsString()
  @IsOptional()
  source_storage?: string;

  @IsString()
  @IsOptional()
  target_storage?: string;

  @IsString()
  @IsOptional()
  device_id?: string;

  @IsString()
  @IsOptional()
  error_message?: string;

  @IsString()
  @IsOptional()
  payload_json?: string;
}

