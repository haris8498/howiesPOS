import { IsBoolean, IsIn, IsOptional, IsString } from 'class-validator';
import { Transform } from 'class-transformer';

export class QueryStaffDto {
  @IsString()
  @IsOptional()
  search?: string;

  @IsString()
  @IsOptional()
  @IsIn(['owner', 'manager', 'cashier'], {
    message: 'Role must be one of: owner, manager, cashier',
  })
  role?: 'owner' | 'manager' | 'cashier';

  @IsString()
  @IsOptional()
  @IsIn(['Active', 'Inactive'], {
    message: 'Status must be either Active or Inactive',
  })
  status?: string;

  @IsBoolean()
  @IsOptional()
  @Transform(({ value }) => {
    if (value === 'true' || value === true || value === 1 || value === '1') return true;
    if (value === 'false' || value === false || value === 0 || value === '0') return false;
    return undefined;
  })
  is_salary_paid?: boolean;

  @IsString()
  @IsOptional()
  month_year?: string;
}
