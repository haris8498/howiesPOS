import { IsEnum, IsNotEmpty } from 'class-validator';

export class UpdateKitchenStatusDto {
  @IsNotEmpty()
  @IsEnum(
    ['newOrder', 'accepted', 'preparing', 'ready', 'served', 'completed', 'cancelled', 'rejected'],
    {
      message:
        'status must be one of: newOrder, accepted, preparing, ready, served, completed, cancelled, rejected',
    },
  )
  status!: string;
}
