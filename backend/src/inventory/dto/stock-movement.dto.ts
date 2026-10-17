import {
  IsDateString,
  IsIn,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsPositive,
  IsString,
  MaxLength,
} from 'class-validator';

export class CreateStockInDto {
  @IsString()
  @IsNotEmpty({ message: 'Item ID is required' })
  item_id!: string;

  @IsNumber({}, { message: 'Quantity must be a number' })
  @IsPositive({ message: 'Quantity must be greater than 0' })
  quantity!: number;

  @IsString()
  @IsOptional()
  @MaxLength(255, { message: 'Reason cannot exceed 255 characters' })
  reason?: string;

  @IsString()
  @IsOptional()
  @MaxLength(100, { message: 'Supplier name cannot exceed 100 characters' })
  supplier_name?: string;

  @IsNumber({}, { message: 'Cost per unit must be a number' })
  @IsOptional()
  cost_per_unit?: number;

  @IsNumber({}, { message: 'Cost impact must be a number' })
  @IsOptional()
  cost_impact?: number;
}

export class CreateStockOutDto {
  @IsString()
  @IsNotEmpty({ message: 'Item ID is required' })
  item_id!: string;

  @IsNumber({}, { message: 'Quantity must be a number' })
  @IsPositive({ message: 'Quantity must be greater than 0' })
  quantity!: number;

  @IsString()
  @IsOptional()
  movement_type?: string;

  @IsString()
  @IsOptional()
  @MaxLength(255, { message: 'Reason cannot exceed 255 characters' })
  reason?: string;
}

export class CreateStockMovementDto {
  @IsString()
  @IsNotEmpty({ message: 'Item ID is required' })
  item_id!: string;

  @IsString()
  @IsNotEmpty({ message: 'Movement type is required' })
  movement_type!: string;

  @IsNumber({}, { message: 'Quantity must be a number' })
  @IsPositive({ message: 'Quantity must be greater than 0' })
  quantity!: number;

  @IsString()
  @IsOptional()
  @MaxLength(20, { message: 'Unit cannot exceed 20 characters' })
  unit?: string;

  @IsString()
  @IsOptional()
  @MaxLength(255, { message: 'Reason cannot exceed 255 characters' })
  reason?: string;

  @IsNumber({}, { message: 'Cost impact must be a number' })
  @IsOptional()
  cost_impact?: number;
}

export class QueryStockMovementDto {
  @IsString()
  @IsOptional()
  item_id?: string;

  @IsString()
  @IsOptional()
  movement_type?: string;

  @IsDateString()
  @IsOptional()
  from_date?: string;

  @IsDateString()
  @IsOptional()
  to_date?: string;

  @IsString()
  @IsOptional()
  search?: string;
}
