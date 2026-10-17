import { IsDateString, IsInt, IsNotEmpty, IsOptional, Min } from 'class-validator';

export class UpdateCookingTimeDto {
  @IsNotEmpty()
  @IsInt()
  @Min(0, { message: 'cooking_time_minutes must be a non-negative integer' })
  cooking_time_minutes!: number;

  @IsOptional()
  @IsDateString()
  estimated_ready_at?: string;
}
