import {
  ArrayMinSize,
  IsArray,
  IsBoolean,
  IsDateString,
  IsIn,
  IsInt,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  MaxLength,
  Min,
  ValidateNested,
} from 'class-validator';
import { Type } from 'class-transformer';

export class CreateOrderItemDto {
  @IsString()
  @IsOptional()
  id?: string;

  @IsDateString()
  @IsOptional()
  created_at?: string;

  @IsString()
  @IsOptional()
  menu_item_id?: string;

  @IsString()
  @IsNotEmpty({ message: 'Item name is required' })
  @MaxLength(100)
  item_name!: string;

  @IsInt({ message: 'Quantity must be an integer' })
  @Min(1, { message: 'Quantity must be at least 1' })
  quantity!: number;

  @IsNumber({}, { message: 'Unit price must be a number' })
  @Min(0, { message: 'Unit price cannot be negative' })
  unit_price!: number;

  @IsNumber({}, { message: 'Total price must be a number' })
  @IsOptional()
  total_price?: number;

  @IsString()
  @IsOptional()
  category?: string;

  @IsString()
  @IsOptional()
  @MaxLength(30)
  selected_size?: string;

  @IsString()
  @IsOptional()
  @MaxLength(50)
  selected_crust?: string;

  @IsString()
  @IsOptional()
  extra_toppings?: string;

  @IsString()
  @IsOptional()
  notes?: string;

  @IsBoolean()
  @IsOptional()
  is_cancelled?: boolean;

  @IsString()
  @IsOptional()
  cancel_reason?: string;

  @IsString()
  @IsOptional()
  cancelled_by?: string;

  @IsDateString()
  @IsOptional()
  cancelled_at?: string;

  // Append-only line-item ledger fields (SYNC-032 / D-05)
  @IsDateString()
  @IsOptional()
  voided_at?: string;

  @IsDateString()
  @IsOptional()
  voidedAt?: string;

  @IsString()
  @IsOptional()
  voided_by?: string;

  @IsString()
  @IsOptional()
  voidedBy?: string;

  @IsString()
  @IsOptional()
  supersedes_item_id?: string;

  @IsString()
  @IsOptional()
  supersedesItemId?: string;

  @IsString()
  @IsOptional()
  created_by_device_id?: string;

  @IsString()
  @IsOptional()
  createdByDeviceId?: string;

  @IsDateString()
  @IsOptional()
  client_created_at?: string;

  @IsDateString()
  @IsOptional()
  clientCreatedAt?: string;
}

export class CreateOrderDto {
  @IsString()
  @IsOptional()
  id?: string;

  @IsDateString()
  @IsOptional()
  created_at?: string;

  @IsString()
  @IsOptional()
  shift_id?: string;

  @IsString()
  @IsOptional()
  @MaxLength(30)
  order_number?: string;

  @IsString()
  @IsOptional()
  @MaxLength(30)
  client_order_number?: string;

  @IsString()
  @IsOptional()
  @MaxLength(20)
  token_number?: string;

  @IsString()
  @IsNotEmpty({ message: 'Order type is required' })
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
  order_type!: string;

  @IsString()
  @IsOptional()
  @MaxLength(30)
  order_source?: string;

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
  @Min(0)
  @IsOptional()
  delivery_fee?: number;

  @IsNumber()
  @IsOptional()
  grand_total?: number;

  @IsString()
  @IsOptional()
  approved_by_manager_id?: string;

  @IsString()
  @IsOptional()
  manager_credential?: string;

  @IsOptional()
  manager_approval?: any;

  @IsOptional()
  managerApproval?: any;

  @IsBoolean()
  @IsOptional()
  is_cashier_discount?: boolean;

  @IsBoolean()
  @IsOptional()
  isCashierDiscount?: boolean;

  @IsString()
  @IsOptional()
  cashier_id?: string;

  @IsString()
  @IsOptional()
  staff_id?: string;

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
  @ArrayMinSize(1, { message: 'Order must contain at least one order item' })
  @ValidateNested({ each: true })
  @Type(() => CreateOrderItemDto)
  items!: CreateOrderItemDto[];

  @IsArray()
  @IsOptional()
  @ValidateNested({ each: true })
  @Type(() => CreateOrderPaymentDto)
  payments?: CreateOrderPaymentDto[];
}

export class CreateOrderPaymentDto {
  @IsString()
  @IsOptional()
  id?: string;

  @IsDateString()
  @IsOptional()
  created_at?: string;

  @IsString()
  @IsNotEmpty({ message: 'Payment method is required' })
  @MaxLength(30)
  payment_method!: string; // 'cash', 'card', 'bankTransfer', 'other'

  @IsNumber({}, { message: 'Payment amount must be a number' })
  @Min(0.01, { message: 'Payment amount must be greater than zero' })
  amount!: number;

  @IsNumber()
  @Min(0)
  @IsOptional()
  tendered_amount?: number;

  @IsNumber()
  @Min(0)
  @IsOptional()
  change_returned?: number;

  @IsString()
  @IsOptional()
  @MaxLength(100)
  transaction_reference?: string;

  @IsString()
  @IsOptional()
  @MaxLength(4)
  card_last_four?: string;

  @IsString()
  @IsOptional()
  @MaxLength(50)
  bank_name?: string;

  @IsString()
  @IsOptional()
  @MaxLength(20)
  payment_status?: string;

  @IsString()
  @IsOptional()
  notes?: string;

  @IsString()
  @IsOptional()
  @MaxLength(50)
  received_by?: string;
}
