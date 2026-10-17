import { Module } from '@nestjs/common';
import { CategoriesController } from './categories/categories.controller';
import { CategoriesService } from './categories/categories.service';
import { ItemsController } from './items/items.controller';
import { ItemsService } from './items/items.service';
import { SizesController } from './sizes/sizes.controller';
import { SizesService } from './sizes/sizes.service';
import { OptionsController } from './options/options.controller';
import { OptionsService } from './options/options.service';
import { DealsController } from './deals/deals.controller';
import { DealsService } from './deals/deals.service';

@Module({
  controllers: [
    CategoriesController,
    ItemsController,
    SizesController,
    OptionsController,
    DealsController,
  ],
  providers: [CategoriesService, ItemsService, SizesService, OptionsService, DealsService],
  exports: [CategoriesService, ItemsService, SizesService, OptionsService, DealsService],
})
export class MenuModule {}
