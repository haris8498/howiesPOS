import { IsNotEmpty, IsNumber, IsOptional, IsString, MaxLength, Min } from 'class-validator';

export class CreateSizeDto {
  @IsString()
  @IsNotEmpty({ message: 'Size name is required' })
  @MaxLength(30)
  size_name!: string;

  @IsNumber({}, { message: 'Price must be a number' })
  @Min(0, { message: 'Price cannot be negative' })
  @IsNotEmpty({ message: 'Price is required' })
  price!: number;
}

export class UpdateSizeDto {
  @IsString()
  @IsOptional()
  @MaxLength(30)
  size_name?: string;

  @IsNumber({}, { message: 'Price must be a number' })
  @Min(0, { message: 'Price cannot be negative' })
  @IsOptional()
  price?: number;
}
