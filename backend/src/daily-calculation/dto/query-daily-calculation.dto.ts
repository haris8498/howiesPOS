import { IsDateString, IsOptional, IsString } from 'class-validator';

export class QueryDailyCalculationDto {
  @IsOptional()
  @IsDateString()
  startDate?: string;

  @IsOptional()
  @IsDateString()
  endDate?: string;

  @IsOptional()
  @IsString()
  cashierId?: string;

  @IsOptional()
  @IsString()
  status?: string;
}
