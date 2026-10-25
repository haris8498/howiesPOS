import { RealtimeGateway } from '../realtime/realtime.gateway';
import { BadRequestException, ConflictException, Injectable, NotFoundException, Optional } from '@nestjs/common';
import { InventoryItem, Prisma, StockMovement } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { CreateInventoryItemDto } from './dto/create-inventory-item.dto';
import { UpdateInventoryItemDto } from './dto/update-inventory-item.dto';
import { QueryInventoryDto } from './dto/query-inventory.dto';
import {
  CreateStockInDto,
  CreateStockOutDto,
  QueryStockMovementDto,
} from './dto/stock-movement.dto';

export type InventoryItemWithMovements = Prisma.InventoryItemGetPayload<{
  include: {
    stock_movements: true;
  };
}>;

@Injectable()
export class InventoryService {
  constructor(
    private readonly prisma: PrismaService,
    @Optional() private readonly realtimeGateway?: RealtimeGateway,
  ) {}

  async listItems(query?: QueryInventoryDto): Promise<InventoryItem[]> {
    const where: Prisma.InventoryItemWhereInput = {};

    if (query) {
      if (query.category && query.category !== 'All') {
        where.category = {
          equals: query.category,
          mode: 'insensitive',
        };
      }

      if (query.search) {
        const search = query.search.trim();
        where.OR = [
          { name: { contains: search, mode: 'insensitive' } },
          { sku_code: { contains: search, mode: 'insensitive' } },
          { supplier_name: { contains: search, mode: 'insensitive' } },
          { category: { contains: search, mode: 'insensitive' } },
        ];
      }
    }

    let items = await this.prisma.inventoryItem.findMany({
      where,
      orderBy: [{ name: 'asc' }],
    });

    if (query?.is_low_stock) {
      items = items.filter((item) => Number(item.current_stock) <= Number(item.min_threshold));
    }

    return items;
  }

  async getLowStockItems(): Promise<InventoryItem[]> {
    const items = await this.prisma.inventoryItem.findMany({
      orderBy: [{ name: 'asc' }],
    });

    return items.filter((item) => Number(item.current_stock) <= Number(item.min_threshold));
  }

  async getItemById(id: string): Promise<InventoryItemWithMovements> {
    const item = await this.prisma.inventoryItem.findUnique({
      where: { id },
      include: {
        stock_movements: {
          orderBy: { timestamp: 'desc' },
          take: 50,
        },
      },
    });

    if (!item) {
      throw new NotFoundException(`Inventory item with ID '${id}' not found`);
    }

    return item;
  }

  async createItem(dto: CreateInventoryItemDto): Promise<InventoryItem> {
    let sku = dto.sku_code?.trim();
    if (!sku) {
      sku = `SKU-${Date.now().toString().slice(-6)}${Math.floor(Math.random() * 90 + 10)}`;
    } else {
      const existingSku = await this.prisma.inventoryItem.findUnique({
        where: { sku_code: sku },
      });
      if (existingSku) {
        throw new ConflictException(`An inventory item with SKU '${sku}' already exists`);
      }
    }

    const initialStock = dto.initial_stock !== undefined
      ? dto.initial_stock
      : (dto.current_stock !== undefined ? dto.current_stock : 0);
    const currentStock = dto.current_stock !== undefined ? dto.current_stock : initialStock;
    const usedStock = dto.used_stock !== undefined ? dto.used_stock : 0.0;
    const minThreshold = dto.min_threshold !== undefined ? dto.min_threshold : 10.0;
    const costPerUnit = dto.cost_per_unit !== undefined ? dto.cost_per_unit : 0.0;
    const unit = dto.unit?.trim() || 'kg';
    const category = dto.category?.trim() || 'General';
    const supplierName = dto.supplier_name?.trim() || 'Central Depot';

    return this.prisma.$transaction(async (tx) => {
      const item = await tx.inventoryItem.create({
        data: {
          sku_code: sku,
          name: dto.name.trim(),
          category,
          initial_stock: new Prisma.Decimal(initialStock),
          used_stock: new Prisma.Decimal(usedStock),
          current_stock: new Prisma.Decimal(currentStock),
          min_threshold: new Prisma.Decimal(minThreshold),
          unit,
          cost_per_unit: new Prisma.Decimal(costPerUnit),
          supplier_name: supplierName,
          last_restocked_date: currentStock > 0 ? new Date() : null,
        },
      });

      if (currentStock > 0) {
        await tx.stockMovement.create({
          data: {
            item_id: item.id,
            item_name: item.name,
            movement_type: 'stockIn',
            quantity: new Prisma.Decimal(currentStock),
            unit: item.unit,
            reason: 'Initial Opening Stock',
            cost_impact: new Prisma.Decimal(currentStock * costPerUnit),
          },
        });
      }

      return item;
    });
  }

  async updateItem(id: string, dto: UpdateInventoryItemDto): Promise<InventoryItem> {
    const item = await this.prisma.inventoryItem.findUnique({
      where: { id },
    });

    if (!item) {
      throw new NotFoundException(`Inventory item with ID '${id}' not found`);
    }

    if (dto.sku_code && dto.sku_code.trim() !== item.sku_code) {
      const existingSku = await this.prisma.inventoryItem.findUnique({
        where: { sku_code: dto.sku_code.trim() },
      });

      if (existingSku) {
        throw new ConflictException(
          `An inventory item with SKU '${dto.sku_code.trim()}' already exists`,
        );
      }
    }

    const data: Prisma.InventoryItemUpdateInput = {};

    if (dto.sku_code !== undefined) data.sku_code = dto.sku_code.trim();
    if (dto.name !== undefined) data.name = dto.name.trim();
    if (dto.category !== undefined) data.category = dto.category.trim();
    if (dto.initial_stock !== undefined) data.initial_stock = new Prisma.Decimal(dto.initial_stock);
    if (dto.current_stock !== undefined) data.current_stock = new Prisma.Decimal(dto.current_stock);
    if (dto.used_stock !== undefined) data.used_stock = new Prisma.Decimal(dto.used_stock);
    if (dto.min_threshold !== undefined) data.min_threshold = new Prisma.Decimal(dto.min_threshold);
    if (dto.unit !== undefined) data.unit = dto.unit.trim();
    if (dto.cost_per_unit !== undefined) data.cost_per_unit = new Prisma.Decimal(dto.cost_per_unit);
    if (dto.supplier_name !== undefined) data.supplier_name = dto.supplier_name.trim();

    return this.prisma.inventoryItem.update({
      where: { id },
      data,
    });
  }

  async deleteItem(id: string): Promise<{ message: string }> {
    const item = await this.prisma.inventoryItem.findUnique({
      where: { id },
      include: {
        stock_movements: { take: 1 },
      },
    });

    if (!item) {
      throw new NotFoundException(`Inventory item with ID '${id}' not found`);
    }

    if (item.stock_movements.length > 0) {
      throw new BadRequestException(
        `Cannot delete item '${item.name}' because it has recorded stock movement audit logs`,
      );
    }

    await this.prisma.inventoryItem.delete({
      where: { id },
    });

    return {
      message: `Inventory item '${item.name}' deleted successfully`,
    };
  }

  async stockIn(dto: CreateStockInDto): Promise<{ item: InventoryItem; movement: StockMovement }> {
    return this.prisma.$transaction(async (tx) => {
      const item = await tx.inventoryItem.findUnique({
        where: { id: dto.item_id },
      });

      if (!item) {
        throw new NotFoundException(`Inventory item with ID '${dto.item_id}' not found`);
      }

      const costPerUnit =
        dto.cost_per_unit !== undefined
          ? new Prisma.Decimal(dto.cost_per_unit)
          : item.cost_per_unit;

      const costImpact =
        dto.cost_impact !== undefined
          ? new Prisma.Decimal(dto.cost_impact)
          : new Prisma.Decimal(dto.quantity).mul(costPerUnit);
      const reason = dto.reason?.trim() || 'Restock / Inward Arrival';

      const updateData: Prisma.InventoryItemUpdateInput = {
        current_stock: { increment: dto.quantity },
        last_restocked_date: new Date(),
      };

      if (dto.cost_per_unit !== undefined) {
        updateData.cost_per_unit = costPerUnit;
      }
      if (dto.supplier_name) {
        updateData.supplier_name = dto.supplier_name.trim();
      }

      const updatedItem = await tx.inventoryItem.update({
        where: { id: item.id },
        data: updateData,
      });

      const movement = await tx.stockMovement.create({
        data: {
          item_id: item.id,
          item_name: item.name,
          movement_type: 'stockIn',
          quantity: new Prisma.Decimal(dto.quantity),
          unit: item.unit,
          reason,
          cost_impact: costImpact,
        },
      });

      return {
        item: updatedItem,
        movement,
      };
    });
  }

  async stockOut(
    dto: CreateStockOutDto,
  ): Promise<{ item: InventoryItem; movement: StockMovement }> {
    return this.prisma.$transaction(async (tx) => {
      const item = await tx.inventoryItem.findUnique({
        where: { id: dto.item_id },
      });

      if (!item) {
        throw new NotFoundException(`Inventory item with ID '${dto.item_id}' not found`);
      }

      const currentStockNum = Number(item.current_stock);
      if (currentStockNum < dto.quantity) {
        throw new BadRequestException(
          `Insufficient stock: item '${item.name}' has ${currentStockNum} ${item.unit} available, but ${dto.quantity} was requested`,
        );
      }

      const costImpact = new Prisma.Decimal(dto.quantity).mul(item.cost_per_unit);
      let movementType = 'stockOut';
      const mTypeStr = (dto.movement_type || '').toLowerCase();
      if (mTypeStr.includes('waste') || mTypeStr.includes('wastage')) {
        movementType = 'wastage';
      } else if (mTypeStr.includes('sale') || mTypeStr.includes('deduct') || mTypeStr.includes('auto')) {
        movementType = 'saleAutoDeduction';
      } else {
        movementType = 'stockOut';
      }

      const defaultReason =
        movementType === 'wastage'
          ? 'Wastage / Spoiled Stock'
          : movementType === 'saleAutoDeduction'
            ? 'Order Recipe Auto Deduction'
            : 'Kitchen Stock Out';
      const reason = dto.reason?.trim() || defaultReason;

      const updatedItem = await tx.inventoryItem.update({
        where: { id: item.id },
        data: {
          current_stock: { decrement: dto.quantity },
          used_stock: { increment: dto.quantity },
        },
      });

      const movement = await tx.stockMovement.create({
        data: {
          item_id: item.id,
          item_name: item.name,
          movement_type: movementType,
          quantity: new Prisma.Decimal(dto.quantity),
          unit: item.unit,
          reason,
          cost_impact: costImpact,
        },
      });

      return {
        item: updatedItem,
        movement,
      };
    });
  }

  async listMovements(query?: QueryStockMovementDto): Promise<StockMovement[]> {
    const where: Prisma.StockMovementWhereInput = {};

    if (query) {
      if (query.item_id) {
        where.item_id = query.item_id;
      }
      if (query.movement_type && query.movement_type !== 'ALL') {
        if (query.movement_type === 'OUT') {
          where.movement_type = { in: ['stockOut', 'saleAutoDeduction'] };
        } else if (query.movement_type === 'IN') {
          where.movement_type = 'stockIn';
        } else if (query.movement_type === 'WASTAGE') {
          where.movement_type = 'wastage';
        } else {
          where.movement_type = query.movement_type;
        }
      }
      if (query.from_date || query.to_date) {
        where.timestamp = {};
        if (query.from_date) {
          where.timestamp.gte = new Date(query.from_date);
        }
        if (query.to_date) {
          where.timestamp.lte = new Date(query.to_date);
        }
      }
      if (query.search) {
        const search = query.search.trim();
        where.OR = [
          { item_name: { contains: search, mode: 'insensitive' } },
          { reason: { contains: search, mode: 'insensitive' } },
        ];
      }
    }

    return this.prisma.stockMovement.findMany({
      where,
      orderBy: { timestamp: 'desc' },
      include: {
        item: true,
      },
    });
  }

  async getMovementsByItemId(itemId: string): Promise<StockMovement[]> {
    const item = await this.prisma.inventoryItem.findUnique({
      where: { id: itemId },
    });

    if (!item) {
      throw new NotFoundException(`Inventory item with ID '${itemId}' not found`);
    }

    return this.prisma.stockMovement.findMany({
      where: { item_id: itemId },
      orderBy: { timestamp: 'desc' },
    });
  }
}
