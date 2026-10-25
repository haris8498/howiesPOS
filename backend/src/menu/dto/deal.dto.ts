import {
  IsArray,
  IsBoolean,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  MaxLength,
  Min,
  MinLength,
  ValidateNested,
} from 'class-validator';
import { Type } from 'class-transformer';

export class CreateDealComponentDto {
  @IsString()
  @IsNotEmpty({ message: 'Component item name is required' })
  @MaxLength(100)
  item_name!: string;

  @IsString()
  @IsNotEmpty({ message: 'Component category is required' })
  @MaxLength(50)
  category!: string;

  @IsString()
  @IsOptional()
  @MaxLength(20)
  quantity?: string;
}

export class CreateDealDto {
  @IsString()
  @IsNotEmpty({ message: 'Deal title is required' })
  @MinLength(2)
  @MaxLength(100)
  title!: string;

  @IsString()
  @IsOptional()
  @MaxLength(150)
  subtitle?: string;

  @IsNumber({}, { message: 'Deal price must be a number' })
  @Min(0, { message: 'Deal price cannot be negative' })
  @IsNotEmpty({ message: 'Deal price is required' })
  deal_price!: number;

  @IsNumber({}, { message: 'Original price must be a number' })
  @Min(0, { message: 'Original price cannot be negative' })
  @IsOptional()
  original_price?: number;

  @IsString()
  @IsOptional()
  @MaxLength(30)
  badge_text?: string;

  @IsString()
  @IsOptional()
  image_path?: string;

  @IsString()
  @IsOptional()
  description?: string;

  @IsBoolean()
  @IsOptional()
  is_available?: boolean;

  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => CreateDealComponentDto)
  @IsOptional()
  components?: CreateDealComponentDto[];
}

export class UpdateDealDto {
  @IsString()
  @IsOptional()
  @MinLength(2)
  @MaxLength(100)
  title?: string;

  @IsString()
  @IsOptional()
  @MaxLength(150)
  subtitle?: string;

  @IsNumber({}, { message: 'Deal price must be a number' })
  @Min(0, { message: 'Deal price cannot be negative' })
  @IsOptional()
  deal_price?: number;

  @IsNumber({}, { message: 'Original price must be a number' })
  @Min(0, { message: 'Original price cannot be negative' })
  @IsOptional()
  original_price?: number;

  @IsString()
  @IsOptional()
  @MaxLength(30)
  badge_text?: string;

  @IsString()
  @IsOptional()
  image_path?: string;

  @IsString()
  @IsOptional()
  description?: string;

  @IsBoolean()
  @IsOptional()
  is_available?: boolean;

  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => CreateDealComponentDto)
  @IsOptional()
  components?: CreateDealComponentDto[];
}
