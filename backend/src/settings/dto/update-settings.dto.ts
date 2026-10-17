import { IsNumber, IsOptional, IsString, Max, MaxLength, Min, MinLength } from 'class-validator';

export class UpdateSettingsDto {
  @IsString()
  @IsOptional()
  @MinLength(2, { message: 'Chain name must be at least 2 characters' })
  @MaxLength(100, { message: 'Chain name cannot exceed 100 characters' })
  chain_name?: string;

  @IsString()
  @IsOptional()
  @MinLength(1, { message: 'Branch code must be at least 1 character' })
  @MaxLength(50, { message: 'Branch code cannot exceed 50 characters' })
  branch_code?: string;

  @IsString()
  @IsOptional()
  @MinLength(2, { message: 'Branch name must be at least 2 characters' })
  @MaxLength(100, { message: 'Branch name cannot exceed 100 characters' })
  branch_name?: string;

  @IsString()
  @IsOptional()
  @MinLength(5, { message: 'Store phone must be at least 5 characters' })
  @MaxLength(30, { message: 'Store phone cannot exceed 30 characters' })
  store_phone?: string;
}
