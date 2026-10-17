import { IsNotEmpty, IsString } from 'class-validator';

export class TransferTableDto {
  @IsString()
  @IsNotEmpty({ message: 'Source table ID (from_table_id) is required' })
  from_table_id!: string;

  @IsString()
  @IsNotEmpty({ message: 'Destination table ID (to_table_id) is required' })
  to_table_id!: string;
}
