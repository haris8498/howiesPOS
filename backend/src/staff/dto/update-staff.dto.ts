import {
  IsDateString,
  IsEmail,
  IsIn,
  IsNumber,
  IsOptional,
  IsString,
  Min,
  MinLength,
} from 'class-validator';

export class UpdateStaffDto {
  @IsString()
  @IsOptional()
  @MinLength(2, { message: 'Full name must be at least 2 characters long' })
  full_name?: string;

  @IsString()
  @IsOptional()
  phone?: string;

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

  @IsDateString({}, { message: 'Joining date must be a valid ISO-8601 date string' })
  @IsOptional()
  joining_date?: string;

  @IsString()
  @IsOptional()
  assigned_shift?: string;

  @IsNumber({}, { message: 'Monthly salary must be a number' })
  @Min(0, { message: 'Monthly salary cannot be negative' })
  @IsOptional()
  monthly_salary?: number;

  @IsNumber({}, { message: 'Hourly rate must be a number' })
  @Min(0, { message: 'Hourly rate cannot be negative' })
  @IsOptional()
  hourly_rate?: number;


  @IsString()
  @IsOptional()
  user_id?: string | null;
}
