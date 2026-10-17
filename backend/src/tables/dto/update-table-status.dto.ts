import { IsIn, IsInt, IsNotEmpty, IsNumber, IsOptional, IsString, Min } from 'class-validator';

export class UpdateTableStatusDto {
  @IsString()
  @IsNotEmpty({ message: 'Table status is required' })
  @IsIn(['available', 'occupied', 'reserved'], {
    message: 'Status must be available, occupied, or reserved',
  })
  status!: string;

  @IsString()
  @IsOptional()
  active_order_id?: string;

  @IsNumber()
  @Min(0)
  @IsOptional()
  current_bill_amount?: number;

  @IsInt()
  @Min(0)
  @IsOptional()
  current_customer_count?: number;
}
