import { IsIn, IsOptional, IsString, MinLength } from 'class-validator';

export class UpdateUserDto {
  @IsString()
  @IsOptional()
  @MinLength(3, { message: 'Username must be at least 3 characters long' })
  username?: string;

  @IsString()
  @IsOptional()
  email?: string;

  @IsString()
  @IsOptional()
  full_name?: string;

  @IsString()
  @IsOptional()
  phone?: string;

  @IsString()
  @IsOptional()
  @MinLength(4, { message: 'Password must be at least 4 characters long' })
  password?: string;
  @IsString()
  @IsOptional()
  @IsIn(['owner', 'manager', 'cashier'], {
    message: 'Role must be one of: owner, manager, cashier',
  })
  role?: 'owner' | 'manager' | 'cashier';
}
