import {
  IsArray,
  IsBoolean,
  IsDateString,
  IsIn,
  IsInt,
  IsNumber,
  IsOptional,
  IsString,
  MaxLength,
  Min,
  ValidateNested,
} from 'class-validator';
import { Type } from 'class-transformer';
import { CreateOrderItemDto, CreateOrderPaymentDto } from './create-order.dto';

export class UpdateOrderDto {
  @IsString()
  @IsOptional()
  @IsIn(
    [
      'dineIn',
      'takeAway',
      'takeaway',
      'delivery',
      'online',
      'quickOrder',
      'DINE_IN',
      'TAKEAWAY',
      'DELIVERY',
      'ONLINE',
      'QUICK_ORDER',
    ],
    {
      message: 'Order type must be dineIn, takeAway, takeaway, delivery, online, or quickOrder',
    },
  )
  order_type?: string;

  @IsString()
  @IsOptional()
  @MaxLength(30)
  status?: string;

  @IsString()
  @IsOptional()
  table_id?: string;

  @IsInt()
  @Min(1)
  @IsOptional()
  guest_count?: number;

  @IsString()
  @IsOptional()
  @MaxLength(50)
  waiter_name?: string;

  @IsString()
  @IsOptional()
  customer_id?: string;

  @IsString()
  @IsOptional()
  @MaxLength(100)
  customer_name?: string;

  @IsString()
  @IsOptional()
  @MaxLength(30)
  customer_phone?: string;

  @IsString()
  @IsOptional()
  delivery_address?: string;

  @IsNumber()
  @IsOptional()
  subtotal?: number;

  @IsNumber()
  @Min(0)
  @IsOptional()
  discount_percentage?: number;

  @IsNumber()
  @Min(0)
  @IsOptional()
  discount_amount?: number;

  @IsNumber()
  @Min(0)
  @IsOptional()
  tax_amount?: number;

  @IsNumber()
  @Min(0)
  @IsOptional()
  dine_in_tax?: number;

  @IsNumber()
  @IsOptional()
  grand_total?: number;

  @IsNumber()
  @Min(0)
  @IsOptional()
  delivery_fee?: number;

  @IsString()
  @IsOptional()
  @MaxLength(20)
  payment_status?: string;

  @IsString()
  @IsOptional()
  @MaxLength(30)
  payment_method?: string;

  @IsBoolean()
  @IsOptional()
  is_paid?: boolean;

  @IsBoolean()
  @IsOptional()
  is_held?: boolean;

  @IsBoolean()
  @IsOptional()
  kitchen_ticket_sent?: boolean;


  @IsString()
  @IsOptional()
  rejection_reason?: string;

  @IsInt()
  @Min(0)
  @IsOptional()
  cooking_time_minutes?: number;

  @IsDateString()
  @IsOptional()
  estimated_ready_at?: string;

  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => CreateOrderItemDto)
  @IsOptional()
  items?: CreateOrderItemDto[];

  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => CreateOrderPaymentDto)
  @IsOptional()
  payments?: CreateOrderPaymentDto[];
}
