# Hungry Howie's POS — Backend (Phase 2: Database Integration)

This is the backend service for the **Hungry Howie's POS** system, built with NestJS, TypeScript, PostgreSQL, and Prisma ORM to power the Flutter POS frontend.

---

## 1. Project Purpose

Provide a clean, robust, and scalable backend REST API foundation for Hungry Howie's Single-Branch Point of Sale (POS) system.

---

## 2. Backend Stack

- **Runtime**: Node.js (v18+)
- **Framework**: NestJS (v10)
- **Language**: TypeScript (Strict Mode)
- **Database**: PostgreSQL
- **ORM**: Prisma ORM (v5)
- **Architecture**: Modular Monolith
- **Validation**: `class-validator` & `class-transformer`
- **Error Handling**: Global Exception Filter with uniform response structures
- **Configuration**: `@nestjs/config` with `.env` support

*Future Phase Integrations (Planned)*:
- Authentication: JWT & Role-Based Access Control (RBAC)
- Realtime: Socket.IO
- Background Jobs & Caching: Redis & BullMQ
- API Documentation: Swagger / OpenAPI

---

## 3. Database Schema (20 Finalized Tables)

The Prisma schema matches the finalized relational database schema:

1. `store_settings` — Singleton branch configuration, tax, and service charge rates
2. `staff_users` — System login credentials and roles
3. `role_permissions` — Granular role-based access control matrix
4. `staff_members` — Employee profiles, clock-in tracking, and payroll
5. `customers` — CRM directory, delivery addresses, and loyalty points
6. `restaurant_tables` — Floor plan tables, seating capacity, and occupancy
7. `menu_categories` — Menu category classification with badges and icons
8. `menu_items` — Food and drink product catalog with dietary flags
9. `menu_item_sizes` — Tiered price variants (Small, Medium, Large, Family)
10. `menu_item_options` — Customizations (crusts, toppings) with surcharges
11. `deals` — Combo packages and bundle pricing
12. `deal_components` — Bundled item components inside deals
13. `orders` — Unified sales transactions (Dine-In, Takeaway, Delivery, Online)
14. `order_items` — Snapshot line items with size, crust, extra toppings, and pricing
15. `delivery_riders` — Courier fleet profiles, shifts, and ratings
16. `delivery_zones` — Geographic delivery sectors with fixed fees
17. `delivery_dispatches` — Delivery lifecycle connecting orders, riders, and zones
18. `inventory_items` — Raw ingredient inventory with stock reorder levels
19. `stock_movements` — Audit trail for restocks, kitchen usage, and wastage
20. `expenses` — Store operational expenditure ledger

---

## 4. Requirements

- **Node.js**: `>= 18.x` (Tested with Node v24.x)
- **NPM**: `>= 9.x`
- **PostgreSQL**: `>= 14.x`

---

## 5. Installation & Setup

```bash
# Navigate to backend directory
cd backend

# Install dependencies
npm install

# Validate & generate Prisma Client
npx prisma validate
npx prisma generate
```

---

## 6. Environment Variables

Copy `.env.example` to `.env` and configure your local PostgreSQL connection:

```bash
cp .env.example .env
```

| Variable | Description | Default / Example |
| :--- | :--- | :--- |
| `NODE_ENV` | Environment mode (`development`, `production`, `test`) | `development` |
| `PORT` | HTTP server port | `3000` |
| `API_PREFIX` | Global API route prefix | `api` |
| `CORS_ORIGIN` | Allowed CORS origins (comma-separated or `*`) | `*` |
| `DATABASE_URL` | PostgreSQL connection string | `postgresql://postgres:password@localhost:5432/hungry_howies_pos?schema=public` |
| `JWT_SECRET` | Secret key for JWT signing (Future Phase) | `change-in-production` |
| `JWT_EXPIRES_IN` | JWT token lifetime (Future Phase) | `1d` |
| `REDIS_HOST` | Redis hostname (Future Phase) | `localhost` |
| `REDIS_PORT` | Redis port (Future Phase) | `6379` |
| `REDIS_PASSWORD`| Redis password (Future Phase) | *(empty)* |

---

## 7. Database Migration Commands

```bash
# Apply pending migrations
npx prisma migrate deploy

# Generate Prisma client
npx prisma generate
```

---

## 8. Available Scripts

### Development

```bash
npm run start:dev
```

### Production Build & Run

```bash
# Compile TypeScript to dist/
npm run build

# Start production server
npm run start:prod
```

### Code Quality & Testing

```bash
# Linting
npm run lint

# Format with Prettier
npm run format

# Unit tests
npm run test

# End-to-end tests
npm run test:e2e
```

---

## 9. Health Endpoint

Verify that the backend and database connection are operational:

- **Method**: `GET`
- **URL**: `http://localhost:3000/api/health`
- **Response Format**:
```json
{
  "success": true,
  "status": "ok",
  "service": "hungry-howies-pos-api",
  "database": "connected",
  "timestamp": "2026-09-26T14:45:00.000Z",
  "uptime": 42
}
```

---

## 10. Current Development Phase

> **Phase 2 — Database Integration (COMPLETED)**
> 
> Current milestone implemented Prisma ORM with PostgreSQL, all 20 relational database models derived from the Flutter POS UI schema, migration baseline, PrismaService integration, and database health checks.
> 
> *Subsequent phases will introduce authentication (Phase 3), RBAC, business domains (menu, orders, inventory, staff), Redis, Socket.IO, and BullMQ queues.*
