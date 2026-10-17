import { IsBoolean, IsNotEmpty } from 'class-validator';

export class UpdatePermissionDto {
  @IsBoolean()
  @IsNotEmpty()
  is_granted!: boolean;
}
