import { IsOptional, IsString } from 'class-validator';

export class VoidOrderItemDto {
  @IsString()
  @IsOptional()
  voided_by?: string;

  @IsString()
  @IsOptional()
  voidedBy?: string;

  @IsString()
  @IsOptional()
  reason?: string;

  @IsString()
  @IsOptional()
  cancel_reason?: string;
}
