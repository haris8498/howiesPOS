import { Type } from 'class-transformer';
import { IsInt, IsOptional, IsString, Min } from 'class-validator';

export class SyncPullDto {
  @IsOptional()
  @IsString()
  cursor?: string;

  @IsString()
  @IsOptional()
  device_id?: string;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  limit?: number;

  @IsString()
  @IsOptional()
  entity_type?: string;
}
