import {
  IsDateString,
  IsNumber,
  IsOptional,
  IsPositive,
  IsString,
  MaxLength,
  MinLength,
} from 'class-validator';

export class UpdateExpenseDto {
  @IsString()
  @IsOptional()
  @MinLength(2, { message: 'Expense title must be at least 2 characters' })
  @MaxLength(150, { message: 'Expense title cannot exceed 150 characters' })
  title?: string;

  @IsString()
  @IsOptional()
  @MaxLength(50, { message: 'Category cannot exceed 50 characters' })
  category?: string;

  @IsNumber({}, { message: 'Amount must be a number' })
  @IsPositive({ message: 'Amount must be greater than 0' })
  @IsOptional()
  amount?: number;

  @IsDateString({}, { message: 'Date must be a valid ISO date string' })
  @IsOptional()
  date?: string;

  @IsString()
  @IsOptional()
  @MaxLength(100, { message: 'Recorded by cannot exceed 100 characters' })
  recorded_by?: string;

  @IsString()
  @IsOptional()
  @MaxLength(500, { message: 'Note cannot exceed 500 characters' })
  note?: string;
}
