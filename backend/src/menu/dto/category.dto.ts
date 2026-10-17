import { IsNotEmpty, IsOptional, IsString, MaxLength, MinLength } from 'class-validator';

export class CreateCategoryDto {
  @IsString()
  @IsNotEmpty({ message: 'Category ID is required' })
  @MaxLength(36)
  id!: string;

  @IsString()
  @IsNotEmpty({ message: 'Category name is required' })
  @MinLength(2)
  @MaxLength(50)
  name!: string;

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

  @IsString()
  @IsOptional()
  @MaxLength(50)
  icon_name?: string;
}

export class UpdateCategoryDto {
  @IsString()
  @IsOptional()
  @MinLength(2)
  @MaxLength(50)
  name?: string;

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

  @IsString()
  @IsOptional()
  @MaxLength(50)
  icon_name?: string;
}
