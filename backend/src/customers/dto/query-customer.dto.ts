import { IsOptional, IsString } from 'class-validator';

export class QueryCustomerDto {
  @IsString()
  @IsOptional()
  search?: string;

  @IsString()
  @IsOptional()
  phone?: string;
}
