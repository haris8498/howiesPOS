import { IsBoolean, IsDateString, IsOptional, IsString } from 'class-validator';
import { Transform } from 'class-transformer';

export class QueryRiderDto {
  @IsString()
  @IsOptional()
  search?: string;

  @IsBoolean()
  @IsOptional()
  @Transform(({ value }) => {
    if (value === 'true' || value === true || value === 1 || value === '1') return true;
    if (value === 'false' || value === false || value === 0 || value === '0') return false;
    return undefined;
  })
  is_available?: boolean;

  @IsBoolean()
  @IsOptional()
  @Transform(({ value }) => {
    if (value === 'true' || value === true || value === 1 || value === '1') return true;
    if (value === 'false' || value === false || value === 0 || value === '0') return false;
    return undefined;
  })
  is_clocked_in?: boolean;
}

export class QueryDispatchDto {
  @IsString()
  @IsOptional()
  dispatch_status?: string;

  @IsString()
  @IsOptional()
  rider_id?: string;

  @IsString()
  @IsOptional()
  search?: string;

  @IsDateString()
  @IsOptional()
  from_date?: string;

  @IsDateString()
  @IsOptional()
  to_date?: string;
}
