import { IsDateString, IsOptional, IsString, MaxLength } from 'class-validator';

export class TableReservationDto {
  @IsString()
  @IsOptional()
  @MaxLength(100)
  reserved_customer_name?: string;

  @IsDateString({}, { message: 'Reservation time must be a valid ISO-8601 date string' })
  @IsOptional()
  reservation_time?: string;
}
