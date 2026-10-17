import { IsNotEmpty, IsString, MinLength } from 'class-validator';

export class UpdatePasswordDto {
  @IsString()
  @IsNotEmpty({ message: 'New password is required' })
  @MinLength(4, { message: 'Password must be at least 4 characters long' })
  new_password!: string;
}
