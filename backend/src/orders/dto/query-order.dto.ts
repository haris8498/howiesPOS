import { IsBoolean, IsDateString, IsOptional, IsString } from 'class-validator';
import { Transform } from 'class-transformer';

export class QueryOrderDto {
  @IsString()
  @IsOptional()
  shift_id?: string;

  @IsString()
  @IsOptional()
  order_type?: string;

  @IsString()
  @IsOptional()
  status?: string;

  @IsBoolean()
  @IsOptional()
  @Transform(({ value }) => {
    if (value === 'true' || value === true || value === 1 || value === '1') return true;
    if (value === 'false' || value === false || value === 0 || value === '0') return false;
    return undefined;
  })
  is_held?: boolean;

  @IsBoolean()
  @IsOptional()
  @Transform(({ value }) => {
    if (value === 'true' || value === true || value === 1 || value === '1') return true;
    if (value === 'false' || value === false || value === 0 || value === '0') return false;
    return undefined;
  })
  is_paid?: boolean;

  @IsString()
  @IsOptional()
  table_id?: string;

  @IsString()
  @IsOptional()
  customer_id?: string;

  @IsString()
  @IsOptional()
  search?: string;

  @IsString()
  @IsOptional()
  order_source?: string;

  @IsDateString()
  @IsOptional()
  from_date?: string;

  @IsDateString()
  @IsOptional()
  to_date?: string;
}
