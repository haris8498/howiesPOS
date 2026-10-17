import {
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  MaxLength,
  Min,
  MinLength,
} from 'class-validator';

export class CreateInventoryItemDto {
  @IsString()
  @IsOptional()
  @MaxLength(50, { message: 'SKU code cannot exceed 50 characters' })
  sku_code?: string;

  @IsString()
  @IsNotEmpty({ message: 'Item name is required' })
  @MinLength(2, { message: 'Item name must be at least 2 characters' })
  @MaxLength(100, { message: 'Item name cannot exceed 100 characters' })
  name!: string;

  @IsString()
  @IsOptional()
  @MaxLength(50, { message: 'Category cannot exceed 50 characters' })
  category?: string;

  @IsNumber({}, { message: 'Initial stock must be a number' })
  @Min(0, { message: 'Initial stock cannot be negative' })
  @IsOptional()
  initial_stock?: number;

  @IsNumber({}, { message: 'Current stock must be a number' })
  @Min(0, { message: 'Current stock cannot be negative' })
  @IsOptional()
  current_stock?: number;

  @IsNumber({}, { message: 'Used stock must be a number' })
  @Min(0, { message: 'Used stock cannot be negative' })
  @IsOptional()
  used_stock?: number;

  @IsNumber({}, { message: 'Minimum threshold must be a number' })
  @Min(0, { message: 'Minimum threshold cannot be negative' })
  @IsOptional()
  min_threshold?: number;

  @IsString()
  @IsOptional()
  @MaxLength(20, { message: 'Unit cannot exceed 20 characters' })
  unit?: string;

  @IsNumber({}, { message: 'Cost per unit must be a number' })
  @Min(0, { message: 'Cost per unit cannot be negative' })
  @IsOptional()
  cost_per_unit?: number;

  @IsString()
  @IsOptional()
  @MaxLength(100, { message: 'Supplier name cannot exceed 100 characters' })
  supplier_name?: string;
}

