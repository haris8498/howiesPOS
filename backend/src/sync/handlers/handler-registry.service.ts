import { Injectable, Logger, Optional, Inject } from '@nestjs/common';
import { SyncEntityHandler } from './sync-entity.handler';

export const SYNC_ENTITY_HANDLERS = 'SYNC_ENTITY_HANDLERS';

@Injectable()
export class HandlerRegistry {
  private readonly logger = new Logger(HandlerRegistry.name);
  private readonly handlers = new Map<string, SyncEntityHandler>();

  constructor(
    @Optional()
    @Inject(SYNC_ENTITY_HANDLERS)
    injectedHandlers?: SyncEntityHandler[],
  ) {
    if (injectedHandlers) {
      for (const h of injectedHandlers) {
        this.register(h);
      }
    }
  }

  register(handler: SyncEntityHandler): void {
    const key = handler.entityType.toLowerCase().trim();
    this.handlers.set(key, handler);
    // Also register plural/singular alias if applicable (e.g. 'order' and 'orders')
    if (key.endsWith('s')) {
      this.handlers.set(key.slice(0, -1), handler);
    } else {
      this.handlers.set(`${key}s`, handler);
    }
    this.logger.log(`Registered sync entity handler for '${key}'`);
  }

  get(entityType: string): SyncEntityHandler | undefined {
    return this.handlers.get(entityType.toLowerCase().trim());
  }

  has(entityType: string): boolean {
    return this.handlers.has(entityType.toLowerCase().trim());
  }

  getRegisteredEntityTypes(): string[] {
    return Array.from(this.handlers.keys());
  }
}
