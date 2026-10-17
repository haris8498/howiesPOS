import {
  IsDateString,
  IsEmail,
  IsInt,
  IsOptional,
  IsString,
  MaxLength,
  Min,
  MinLength,
} from 'class-validator';

export class UpdateCustomerDto {
  @IsString()
  @IsOptional()
  @MinLength(2, { message: 'Full name must be at least 2 characters' })
  @MaxLength(100, { message: 'Full name cannot exceed 100 characters' })
  full_name?: string;

  @IsString()
  @IsOptional()
  @MinLength(5, { message: 'Phone number must be at least 5 characters' })
  @MaxLength(30, { message: 'Phone number cannot exceed 30 characters' })
  phone?: string;

  @IsEmail({}, { message: 'Please provide a valid email address' })
  @IsOptional()
  @MaxLength(100, { message: 'Email cannot exceed 100 characters' })
  email?: string;

  @IsString()
  @IsOptional()
  address?: string;

  @IsDateString({}, { message: 'Birth date must be a valid ISO-8601 date string' })
  @IsOptional()
  birth_date?: string;

  @IsInt({ message: 'Loyalty points must be an integer' })
  @Min(0, { message: 'Loyalty points cannot be negative' })
  @IsOptional()
  loyalty_points?: number;

  @IsString()
  @IsOptional()
  special_notes?: string;
}
