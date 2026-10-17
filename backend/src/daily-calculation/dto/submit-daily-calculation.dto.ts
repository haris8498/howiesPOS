import { Type } from 'class-transformer';
import {
  IsArray,
  IsDateString,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  ValidateNested,
} from 'class-validator';

export class DailyExpenseItemDto {
  @IsOptional()
  @IsString()
  id?: string;

  @IsNotEmpty()
  @IsString()
  item_name!: string;

  @IsOptional()
  @IsString()
  category?: string;

  @IsNotEmpty()
  @IsNumber()
  amount!: number;

  @IsOptional()
  @IsString()
  receipt_number?: string;

  @IsOptional()
  @IsString()
  notes?: string;
}

export class SubmitDailyCalculationDto {
  @IsOptional()
  @IsDateString()
  date?: string; // YYYY-MM-DD (defaults to today)

  @IsOptional()
  @IsString()
  shift_name?: string;

  @IsOptional()
  @IsString()
  cashier_id?: string;

  @IsOptional()
  @IsString()
  cashier_name?: string;

  @IsOptional()
  @IsNumber()
  opening_float?: number;

  @IsOptional()
  @IsNumber()
  starting_cash?: number;

  @IsOptional()
  @IsNumber()
  cash_submitted?: number;

  @IsOptional()
  @IsNumber()
  total_cash?: number;

  @IsOptional()
  @IsNumber()
  cash_skimming?: number;

  @IsOptional()
  @IsNumber()
  total_cash_submitted?: number;

  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => DailyExpenseItemDto)
  expense_items?: DailyExpenseItemDto[];

  @IsOptional()
  @IsString()
  closing_notes?: string;
}
