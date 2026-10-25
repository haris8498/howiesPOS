import { IsBoolean, IsNotEmpty, IsNumber, IsOptional, IsString } from 'class-validator';

export class StartSessionDto {
  @IsNotEmpty()
  @IsNumber()
  starting_cash!: number;

  @IsOptional()
  @IsBoolean()
  is_adjustment?: boolean;

  @IsOptional()
  @IsString()
  adjustment_type?: 'SET' | 'ADD' | 'SUBTRACT';

  @IsOptional()
  @IsNumber()
  adjustment_amount?: number;

  @IsOptional()
  @IsString()
  shift_name?: string;

  @IsOptional()
  @IsString()
  cashier_id?: string;

  @IsOptional()
  @IsString()
  cashier_name?: string;
}
