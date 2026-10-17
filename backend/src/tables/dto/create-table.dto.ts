import {
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsString,
  MaxLength,
  Min,
  MinLength,
} from 'class-validator';

export class CreateTableDto {
  @IsString()
  @IsNotEmpty({ message: 'Table number is required' })
  @MinLength(1, { message: 'Table number cannot be empty' })
  @MaxLength(20, { message: 'Table number cannot exceed 20 characters' })
  table_number!: string;

  @IsString()
  @IsNotEmpty({ message: 'Table name is required' })
  @MinLength(1, { message: 'Table name cannot be empty' })
  @MaxLength(50, { message: 'Table name cannot exceed 50 characters' })
  name!: string;

  @IsInt({ message: 'Capacity must be an integer' })
  @Min(1, { message: 'Capacity must be at least 1 person' })
  capacity!: number;

  @IsString()
  @IsOptional()
  @MaxLength(50, { message: 'Section cannot exceed 50 characters' })
  section?: string;

  @IsString()
  @IsOptional()
  @MaxLength(20)
  status?: string;
}
