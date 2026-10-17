import {
  IsBoolean,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
  MinLength,
} from 'class-validator';

export class CreateRiderDto {
  @IsString()
  @IsNotEmpty({ message: 'Rider name is required' })
  @MinLength(2, { message: 'Rider name must be at least 2 characters' })
  @MaxLength(100, { message: 'Rider name cannot exceed 100 characters' })
  name!: string;

  @IsString()
  @IsNotEmpty({ message: 'Phone number is required' })
  @MinLength(5, { message: 'Phone number must be at least 5 characters' })
  @MaxLength(30, { message: 'Phone number cannot exceed 30 characters' })
  phone!: string;

  @IsBoolean()
  @IsOptional()
  is_available?: boolean;

  @IsBoolean()
  @IsOptional()
  is_clocked_in?: boolean;

  @IsNumber()
  @Min(0)
  @Max(5)
  @IsOptional()
  rating?: number;
}

export class UpdateRiderDto {
  @IsString()
  @IsOptional()
  @MinLength(2, { message: 'Rider name must be at least 2 characters' })
  @MaxLength(100, { message: 'Rider name cannot exceed 100 characters' })
  name?: string;

  @IsString()
  @IsOptional()
  @MinLength(5, { message: 'Phone number must be at least 5 characters' })
  @MaxLength(30, { message: 'Phone number cannot exceed 30 characters' })
  phone?: string;

  @IsBoolean()
  @IsOptional()
  is_available?: boolean;

  @IsBoolean()
  @IsOptional()
  is_clocked_in?: boolean;

  @IsNumber()
  @Min(0)
  @Max(5)
  @IsOptional()
  rating?: number;
}

export class ToggleRiderDutyDto {
  @IsBoolean()
  @IsOptional()
  is_clocked_in?: boolean;

  @IsBoolean()
  @IsOptional()
  is_available?: boolean;
}
