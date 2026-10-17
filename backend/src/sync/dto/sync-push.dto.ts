import { Type } from 'class-transformer';
import {
  IsArray,
  IsIn,
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsString,
  Min,
  ValidateNested,
} from 'class-validator';

export class SyncMutationDto {
  @IsString()
  @IsNotEmpty({ message: 'operation_id is required' })
  operation_id!: string;

  @IsString()
  @IsNotEmpty({ message: 'entity_type is required' })
  entity_type!: string;

  @IsString()
  @IsNotEmpty({ message: 'entity_id is required' })
  entity_id!: string;

  @IsString()
  @IsNotEmpty({ message: 'operation_type is required' })
  @IsIn(['INSERT', 'UPDATE', 'DELETE', 'insert', 'update', 'delete'])
  operation_type!: string;

  @IsInt()
  @IsOptional()
  base_version?: number;

  @IsInt()
  @IsOptional()
  @Min(0)
  dependency_order?: number;

  @IsOptional()
  created_at?: string;

  @IsNotEmpty({ message: 'payload is required' })
  payload!: any;
}

export class SyncPushDto {
  @IsString()
  @IsNotEmpty({ message: 'device_id is required' })
  device_id!: string;

  @IsString()
  @IsNotEmpty({ message: 'batch_id is required' })
  batch_id!: string;

  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => SyncMutationDto)
  mutations!: SyncMutationDto[];
}
