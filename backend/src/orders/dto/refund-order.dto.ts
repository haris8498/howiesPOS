import { IsIn, IsNotEmpty, IsOptional, IsString } from 'class-validator';

export class RefundOrderDto {
  @IsString()
  @IsNotEmpty({ message: 'Supervisor PIN is required' })
  supervisor_pin!: string;

  @IsString()
  @IsNotEmpty({ message: 'Refund reason is required' })
  reason!: string;

  @IsString()
  @IsIn(['cash', 'card', 'original'], {
    message: 'Refund method must be cash, card, or original',
  })
  refund_method!: 'cash' | 'card' | 'original';

  @IsString()
  @IsOptional()
  supervisor_id?: string;

  @IsString()
  @IsOptional()
  cashier_id?: string;

  @IsString()
  @IsOptional()
  device_id?: string;

  @IsString()
  @IsOptional()
  shift_id?: string;
}
