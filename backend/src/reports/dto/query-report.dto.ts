import { IsOptional, IsString } from 'class-validator';

export class QueryReportDto {
  @IsOptional()
  @IsString()
  period?: 'today' | 'yesterday' | 'thisWeek' | 'lastMonth' | 'thisMonth' | 'thisYear' | 'lastYear' | 'custom' | string;

  @IsOptional()
  @IsString()
  startDate?: string;

  @IsOptional()
  @IsString()
  start_date?: string;

  @IsOptional()
  @IsString()
  endDate?: string;

  @IsOptional()
  @IsString()
  end_date?: string;

  @IsOptional()
  @IsString()
  orderType?: string;

  @IsOptional()
  @IsString()
  order_type?: string;

  @IsOptional()
  @IsString()
  category?: string;

  @IsOptional()
  @IsString()
  search?: string;
}
