import { IsOptional, IsString } from 'class-validator';

export class QueryKitchenDto {
  @IsOptional()
  @IsString()
  status?: string;

  @IsOptional()
  @IsString()
  order_type?: string;

  @IsOptional()
  @IsString()
  search?: string;
}
