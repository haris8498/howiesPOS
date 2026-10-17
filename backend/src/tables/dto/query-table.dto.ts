import { IsOptional, IsString } from 'class-validator';

export class QueryTableDto {
  @IsString()
  @IsOptional()
  status?: string;

  @IsString()
  @IsOptional()
  section?: string;

  @IsString()
  @IsOptional()
  search?: string;
}
