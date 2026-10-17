import { IsIn, IsNotEmpty, IsNumber, IsOptional, IsString, MaxLength, Min } from 'class-validator';

export class CreateOptionDto {
  @IsString()
  @IsNotEmpty({ message: 'Option type is required' })
  @MaxLength(30)
  option_type!: string;

  @IsString()
  @IsNotEmpty({ message: 'Option name is required' })
  @MaxLength(50)
  option_name!: string;

  @IsNumber({}, { message: 'Additional price must be a number' })
  @Min(0, { message: 'Additional price cannot be negative' })
  @IsOptional()
  additional_price?: number;
}

export class UpdateOptionDto {
  @IsString()
  @IsOptional()
  @MaxLength(30)
  option_type?: string;

  @IsString()
  @IsOptional()
  @MaxLength(50)
  option_name?: string;

  @IsNumber({}, { message: 'Additional price must be a number' })
  @Min(0, { message: 'Additional price cannot be negative' })
  @IsOptional()
  additional_price?: number;
}
