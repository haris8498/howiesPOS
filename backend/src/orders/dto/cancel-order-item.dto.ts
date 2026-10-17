import { IsNotEmpty, IsNumber, IsOptional, IsString, Min } from 'class-validator';

export class CancelOrderItemDto {
  @IsNotEmpty()
  @IsString()
  item_id!: string;

  @IsOptional()
  @IsNumber()
  @Min(1)
  cancel_quantity?: number;

  @IsOptional()
  @IsString()
  reason?: string;

  @IsOptional()
  @IsString()
  cancelled_by?: string;
}
