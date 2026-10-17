import { IsIn, IsNotEmpty, IsOptional, IsString } from 'class-validator';

export class UpdateOrderStatusDto {
  @IsString()
  @IsNotEmpty({ message: 'Status is required' })
  @IsIn(
    [
      'newOrder',
      'accepted',
      'preparing',
      'ready',
      'served',
      'completed',
      'cancelled',
      'pending',
      'rejected',
    ],
    {
      message:
        'Status must be newOrder, accepted, preparing, ready, served, completed, cancelled, pending, or rejected',
    },
  )
  status!: string;

  @IsString()
  @IsOptional()
  rejection_reason?: string;
}
