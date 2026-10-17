import { IsDateString, IsOptional, IsString } from 'class-validator';

export class QueryExpenseDto {
  @IsString()
  @IsOptional()
  category?: string;

  @IsDateString()
  @IsOptional()
  date?: string;

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
