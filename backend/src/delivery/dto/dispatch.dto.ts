import { IsDateString, IsIn, IsNotEmpty, IsOptional, IsString } from 'class-validator';

export class CreateDispatchDto {
  @IsString()
  @IsNotEmpty({ message: 'Order ID is required' })
  order_id!: string;

  @IsString()
  @IsOptional()
  rider_id?: string;

  @IsString()
  @IsOptional()
  @IsIn(
    [
      'pending',
      'accepted',
      'preparing',
      'readyForDispatch',
      'outForDelivery',
      'delivered',
      'cancelled',
    ],
    {
      message:
        'Dispatch status must be pending, accepted, preparing, readyForDispatch, outForDelivery, delivered, or cancelled',
    },
  )
  dispatch_status?: string;

  @IsDateString({}, { message: 'Estimated delivery time must be an ISO date string' })
  @IsOptional()
  estimated_delivery_time?: string;
}

export class AssignRiderDto {
  @IsString()
  @IsNotEmpty({ message: 'Rider ID is required' })
  rider_id!: string;
}

export class UpdateDispatchStatusDto {
  @IsString()
  @IsNotEmpty({ message: 'Dispatch status is required' })
  @IsIn(
    [
      'pending',
      'accepted',
      'preparing',
      'readyForDispatch',
      'outForDelivery',
      'delivered',
      'cancelled',
    ],
    {
      message:
        'Dispatch status must be pending, accepted, preparing, readyForDispatch, outForDelivery, delivered, or cancelled',
    },
  )
  dispatch_status!: string;
}
