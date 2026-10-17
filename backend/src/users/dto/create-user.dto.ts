import {
  IsBoolean,
  IsEmail,
  IsIn,
  IsNotEmpty,
  IsOptional,
  IsString,
  MinLength,
} from 'class-validator';

export class CreateUserDto {
  @IsString()
  @IsNotEmpty({ message: 'Username is required' })
  @MinLength(3, { message: 'Username must be at least 3 characters long' })
  username!: string;

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
  @IsNotEmpty({ message: 'Password is required' })
  @MinLength(4, { message: 'Password must be at least 4 characters long' })
  password!: string;

  @IsString()
  @IsNotEmpty({ message: 'Role is required' })
  @IsIn(['owner', 'manager', 'cashier'], {
    message: 'Role must be one of: owner, manager, cashier',
  })
  role!: 'owner' | 'manager' | 'cashier';

  @IsBoolean()
  @IsOptional()
  is_default?: boolean;
}
