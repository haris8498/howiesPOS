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
import { CreateSizeDto } from './size.dto';
import { CreateOptionDto } from './option.dto';

export class CreateMenuItemDto {
  @IsString()
  @IsNotEmpty({ message: 'Category ID is required' })
  @MaxLength(36)
  category_id!: string;

  @IsString()
  @IsNotEmpty({ message: 'Item name is required' })
  @MinLength(2)
  @MaxLength(100)
  name!: string;

  @IsString()
  @IsOptional()
  description?: string;

  @IsNumber({}, { message: 'Base price must be a number' })
  @Min(0, { message: 'Base price cannot be negative' })
  @IsNotEmpty({ message: 'Base price is required' })
  base_price!: number;

  @IsString()
  @IsOptional()
  image_url?: string;

  @IsBoolean()
  @IsOptional()
  is_veg?: boolean;

  @IsBoolean()
  @IsOptional()
  is_spicy?: boolean;

  @IsBoolean()
  @IsOptional()
  is_available?: boolean;

  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => CreateSizeDto)
  @IsOptional()
  sizes?: CreateSizeDto[];

  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => CreateOptionDto)
  @IsOptional()
  options?: CreateOptionDto[];
}

export class UpdateMenuItemDto {
  @IsString()
  @IsOptional()
  @MaxLength(36)
  category_id?: string;

  @IsString()
  @IsOptional()
  @MinLength(2)
  @MaxLength(100)
  name?: string;

  @IsString()
  @IsOptional()
  description?: string;

  @IsNumber({}, { message: 'Base price must be a number' })
  @Min(0, { message: 'Base price cannot be negative' })
  @IsOptional()
  base_price?: number;

  @IsString()
  @IsOptional()
  image_url?: string;

  @IsBoolean()
  @IsOptional()
  is_veg?: boolean;

  @IsBoolean()
  @IsOptional()
  is_spicy?: boolean;

  @IsBoolean()
  @IsOptional()
  is_available?: boolean;
}

export class UpdateAvailabilityDto {
  @IsBoolean()
  @IsNotEmpty()
  is_available!: boolean;
}
