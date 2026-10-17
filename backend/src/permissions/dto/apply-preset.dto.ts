import { IsIn, IsNotEmpty, IsString } from 'class-validator';
import { PresetType } from '../../common/rbac/types/permission.types';

export class ApplyPresetDto {
  @IsString()
  @IsNotEmpty()
  @IsIn(['manager', 'cashier'], { message: 'Role must be either manager or cashier' })
  role!: 'manager' | 'cashier';

  @IsString()
  @IsNotEmpty()
  @IsIn(['STRICT', 'FULL', 'DEFAULT'], { message: 'Preset must be STRICT, FULL, or DEFAULT' })
  preset!: PresetType;
}
