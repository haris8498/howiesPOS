# Multi-User Real-Time Propagation & Urgency Analysis
**Phase 5 & Current State of Phase 12 / 13 Audit**

---

## Executive Summary

This report delivers a comprehensive audit of multi-user data propagation, real-time communication mechanisms, and entity synchronization urgency across the Hungry Howie's POS codebase (Flutter Windows client and NestJS/Prisma/PostgreSQL backend). 

The primary finding is that **the current system is almost entirely pull-based and multi-user blind**. Real-time bi-directional communication exists solely as a localized, partial implementation for the Kitchen Display System (`KitchenGateway` and `KitchenSocketService`). All other operational workflows—including Dine-In Table Status, Active Orders, Counter Takeaway Tokens, Delivery Dispatches, Inventory Deductions, Shift Reconciliations, and Role Permissions—rely on screen initialization (`initState`), manual user refresh (F5 / Ctrl+R / Sync button), or out-of-band screen switches.

Furthermore, the existing kitchen socket implementation directly mutates client in-memory state with incoming event payloads without validating against the database or invoking the Sync API, creating an **explicit violation of the Phase 13 architectural principle** (*"WebSocket = notification only; Sync API = reliable sync; events are never source of truth"*).

---

## 1. Inventory of Communication & Polling Mechanisms

### 1.1 Backend Communication Architecture

Inspection of `backend/package.json:29, 32, 44` reveals the installation of `@nestjs/platform-socket.io` (`^10.4.22`), `@nestjs/websockets` (`^10.4.22`), and `socket.io` (`^4.8.4`). 

Comprehensive code scanning of `backend/src/` identifies **exactly one** WebSocket gateway:

| Gateway | Location | Protocol / Namespace | Target Room | Handshake Auth | Emitted Events |
|---|---|---|---|---|---|
| `KitchenGateway` | `backend/src/kitchen/kitchen.gateway.ts:46-52` | Socket.IO v4 / Namespace `'/'` | `'kitchen'` | Bearer JWT validation | `order.created`, `kitchen.order_created`, `order.updated`, `kitchen.order_updated`, `order.status_changed`, `kitchen.status_changed`, `order.ready`, `kitchen.order_ready`, `order.cancelled`, `kitchen.ticket_sent` |

#### Backend Socket Injections & Event Emission Points
- **Order Placement**: `backend/src/orders/orders.service.ts:45, 459`:
  - When an order is created via `OrdersService.createOrder()`, it optionally injects `KitchenGateway` and emits `kitchenGateway?.emitOrderCreated(result)`.
- **Kitchen Actions**: `backend/src/kitchen/kitchen.service.ts:40, 160, 163, 165, 199, 220`:
  - `updateStatus()` emits `emitOrderStatusChanged()`, `emitOrderReady()`, or `emitOrderCancelled()`.
  - `updateCookingTime()` emits `emitOrderUpdated()`.
  - `sendKitchenTicket()` emits `emitKitchenTicketSent()`.

#### Missing Backend Real-Time Emission (Blind Spots)
- **Table Operations (`backend/src/tables/tables.service.ts`)**:
  - `updateTableReservation()` (lines 160–175) -> **NO socket emission**.
  - `updateTableStatus()` (lines 92–109) -> **NO socket emission**.
  - `releaseTable()` (lines 111–123) -> **NO socket emission**.
  - `transferTable()` (lines 125–158) -> **NO socket emission**.
  - `createTable()`, `deleteTable()`, `createZone()`, `deleteZone()` -> **NO socket emission**.
- **Order Status Updates outside Kitchen (`backend/src/orders/orders.service.ts`)**:
  - `updateOrder()` (lines 468–814) updates status, payment status, guest count, and line items, but **DOES NOT emit any event to any gateway**.
- **Delivery Dispatches (`backend/src/delivery/delivery.service.ts`)**:
  - Assigning rider, departing, or completing delivery -> **NO socket emission**.
- **Inventory & Stock (`backend/src/inventory/inventory.service.ts`)**:
  - Auto-deductions, restocks, or wastage -> **NO socket emission**.
- **Role Permissions & Users (`backend/src/permissions/permissions.service.ts`, `backend/src/users/users.service.ts`)**:
  - Updating permission matrix or locking staff -> **NO socket emission**.
- **Data Synchronization (`backend/src/sync/sync.service.ts`)**:
  - Batch syncing or status toggling -> **NO socket emission**.

#### Alternative Push Technologies Check
- **Server-Sent Events (SSE)**: `NOT FOUND`. No SSE controller endpoints or `@Sse()` decorators exist anywhere in `backend/src/`.
- **Firebase Cloud Messaging (FCM)**: `NOT FOUND`. Neither backend nor frontend contains Firebase dependencies or initialization code.
- **Push Services (Pusher, WebPush, APNs)**: `NOT FOUND`.

---

### 1.2 Frontend Communication Architecture

The Flutter client declares `web_socket_channel: ^3.0.1` in `frontend/pubspec.yaml:37`. It does not use the official `socket_io_client` package, but rather a custom Engine.IO/Socket.IO v4 protocol parser over a raw WebSocket stream.

| Service | File Location | Consumer Provider | Connection Trigger | Lifecycle / Heartbeat |
|---|---|---|---|---|
| `KitchenSocketService` | `frontend/lib/core/network/kitchen_socket_service.dart:10-182` | `kitchenSocketServiceProvider` (`frontend/lib/services/api/api_providers.dart:25`) | Initialized by `KitchenNotifier._init()` (`frontend/lib/data/kitchen_repository.dart:103`) | 20s Engine.IO Ping (`'2'`) / Pong (`'3'`), 5s one-shot reconnect timer |

#### Isolation of Real-Time Socket
`kitchen_repository.dart` is the **only repository** in the entire Flutter client that consumes `KitchenSocketService`. 
No other repository (`table_repository.dart`, `pos_repository.dart`, `takeaway_repository.dart`, `delivery_repository.dart`, `online_orders_repository.dart`, `inventory_repository.dart`, `expense_repository.dart`, `staff_repository.dart`) listens to or interacts with any WebSocket.

---

### 1.3 Audit of All Timers, Refresh Hooks, and Invalidation Calls in Flutter

Below is an exhaustive catalog of every timer, auto-refresh, polling construct, and Riverpod cache invalidation across `frontend/lib/`:

| File & Line | Construct | Duration / Trigger | Purpose | Acts as Polling? |
|---|---|---|---|---|
| `frontend/lib/data/network_speed_provider.dart:64` | `Timer.periodic(const Duration(seconds: 15))` | 15 seconds | Pings cloud gateway / tests HTTP download speed for the network latency badge | **YES**, but strictly for network health telemetry, **not** entity data |
| `frontend/lib/core/network/kitchen_socket_service.dart:61` | `Timer.periodic(const Duration(seconds: 20))` | 20 seconds | Sends Engine.IO `'2'` keepalive ping frame to server | **NO** (Socket heartbeat) |
| `frontend/lib/core/network/kitchen_socket_service.dart:133` | `Timer(const Duration(seconds: 5))` | 5 seconds | Reconnects raw WebSocket when disconnected | **NO** (Connection retry) |
| `frontend/lib/config/router.dart:267-280` | `CallbackShortcuts` (`LogicalKeyboardKey.f5`, `LogicalKeyboardKey.keyR + Ctrl`) | User Keystroke | Triggers `GlobalSyncController.syncAndRefreshAll()` | **NO** (Manual shortcut) |
| `frontend/lib/shared/widgets/sync_button.dart:51` | `InkWell.onTap` | User Click | Triggers `GlobalSyncController.syncAndRefreshAll()` | **NO** (Manual button) |
| `frontend/lib/features/tables/tables_screen.dart:34` | `WidgetsBinding.instance.addPostFrameCallback` in `initState()` | Screen Navigation | Calls `ref.read(tableProvider.notifier).loadTables()` | **NO** (Single fetch on screen mount) |
| `frontend/lib/features/reports/reports_screen.dart:39-44, 53-56` | `ref.invalidate(...)` | User Click / Date Filter | Invalidates `reportSummaryProvider`, `reportProductsProvider`, `cancelledOrdersProvider` | **NO** (Manual UI invalidation) |
| `frontend/lib/data/daily_calculation_repository.dart:254, 361` | Direct provider calls | Shift Submission / Closure | Calls `tableProvider.notifier.loadTables()` and invalidates report providers | **NO** (Transactional side effect) |
| `frontend/lib/features/daily_calculation/daily_calculation_admin_screen.dart:47` | `IconButton.onPressed` | User Click | Calls `fetchLiveSummary()` | **NO** (Manual refresh button) |
| `frontend/lib/features/stock/stock_screen.dart:120` | `IconButton.onPressed` | User Click | Calls `loadInventoryData()` | **NO** (Manual refresh button) |
| `frontend/lib/features/settings/settings_screen.dart:60` | `ElevatedButton.onPressed` | User Click | Reloads store configuration | **NO** (Manual refresh button) |
| `frontend/lib/features/sync/data_sync_screen.dart:80` | `IconButton.onPressed` | User Click | Calls `dataSyncProvider.notifier.loadData()` | **NO** (Manual refresh button) |

#### Conclusion on Current Polling
There is **zero background polling for business entities in the Flutter app**. If a user stays on a screen without interacting with the refresh button or pressing F5, the screen data remains completely static indefinitely.

---

## 2. End-to-End Concrete Trace: Cashier Reserves Table 1

To demonstrate the propagation characteristics in the current codebase, we trace the scenario: **Cashier reserves Table 1 -> What does the Owner's laptop see, when, and how?**

```
+----------------------------+             +-------------------------------+             +---------------------------+
|      CASHIER LAPTOP        |             |      NESTJS / POSTGRESQL      |             |       OWNER LAPTOP        |
|  (User: Cashier / POS UI)  |             |      (Server Data Store)      |             |   (User: Owner / Portal)  |
+----------------------------+             +-------------------------------+             +---------------------------+
              |                                            |                                           |
              | 1. Tap Table 1 -> Reserve                  |                                           |
              |    Name: "John Doe", Time: 19:00           |                                           |
              |------------------------------------------->|                                           |
              | HTTP PATCH /api/tables/:id/reservation     |                                           |
              |                                            | 2. TablesService executes:                |
              |                                            |    prisma.restaurantTable.update(...)     |
              |                                            |    Status -> 'reserved'                   |
              |                                            |    (NO socket gateway emit!)              |
              |                                            |                                           |
              | 3. HTTP 200 OK                             |                                           |
              |<-------------------------------------------|                                           |
              |                                            |                                           |
              | 4. Cashier runs loadTables()               |                                           |
              |    Table 1 turns Amber ("Reserved")        |                                           |
              |                                            |                                           |
              |                                            |          [NO EVENT BROADCAST]             |
              |                                            |     - KitchenGateway not called           |
              |                                            |     - Owner not connected to WS           |
              |                                            |     - No table stream or timer            |
              |                                            |                                           |
              |                                            |                                           | 5. What Owner sees:
              |                                            |                                           |    Table 1 stays Green
              |                                            |                                           |    ("Available", Bill: 0)
              |                                            |                                           |    STALE INDEFINITELY!
              |                                            |                                           |
              |                                            |                                           | 6. Only updates when:
              |                                            |                                           |    a) Owner hits F5 / Ctrl+R
              |                                            |    HTTP GET /api/tables                   |    b) Clicks Sync Button
              |                                            |<------------------------------------------|    c) Navigates to another
              |                                            |                                           |       screen & returns
              |                                            |    HTTP 200 (fresh JSON)                  |
              |                                            |------------------------------------------>| 7. Now Table 1 shows Amber!
```

### Detailed Trace Steps

1. **Cashier Action (`frontend/lib/features/tables/tables_screen.dart:2074`)**:
   - The cashier opens the reservation dialog for Table 1 (ID: `table-t1-uuid`).
   - Form inputs: Customer `"John Doe"`, Arrival `2026-10-17 19:00:00`, Party Size `4`.
   - The UI invokes:
     `ref.read(tableProvider.notifier).reserveTable('table-t1-uuid', 'John Doe', DateTime(2026, 10, 17, 19, 0), partySize: 4)`.

2. **Network Request Dispatched (`frontend/lib/data/table_repository.dart:210-218`)**:
   - `TableNotifier.reserveTable()` calls `_tablesApiService.updateReservation()`:
     ```dart
     // frontend/lib/services/api/tables_api_service.dart:102-114
     await _apiClient.patch('tables/$tableId/reservation', body: {
       'reserved_customer_name': customerName,
       'reservation_time': reservationTime,
       'party_size': partySize,
     });
     ```
   - An HTTP `PATCH /api/tables/table-t1-uuid/reservation` request is sent to the backend.

3. **Backend Processing (`backend/src/tables/tables.service.ts:160-175`)**:
   - `TablesController.updateTableReservation()` delegates to `TablesService.updateTableReservation()`:
     ```typescript
     // backend/src/tables/tables.service.ts:160-175
     const updated = await this.prisma.restaurantTable.update({
       where: { id },
       data: {
         status: 'reserved',
         reserved_customer_name: reservedName,
         reservation_time: resTime,
       },
     });
     this.logger.log(`Updated reservation for table '${updated.name}' - Reserved for '${reservedName ?? 'None'}'`);
     return updated;
     ```
   - PostgreSQL updates the table record.
   - **Crucial observation**: `TablesService` does not import or inject `KitchenGateway` or any gateway. No WebSocket packet is generated or emitted.

4. **Cashier Client UI Resolution (`frontend/lib/data/table_repository.dart:218`)**:
   - After the HTTP call completes, `TableNotifier` executes `await loadTables()`.
   - `loadTables()` re-fetches `GET /api/tables` and sets `state = state.copyWith(tables: tables)`.
   - Cashier's table card updates to Amber (`reserved`).

5. **What the Owner's Laptop Sees, When, and How**:
   - **What it sees**: The Owner's screen continues to show Table 1 as **`Available` (Green)** with `0` bill and no reservation details.
   - **When it sees it**: **Never automatically**. If the Owner leaves the laptop on the `/owner/tables` screen for hours, Table 1 will show as available for hours.
   - **How it finally updates**: The Owner only sees the updated state when an external action triggers `loadTables()`:
     1. Owner manually hits keyboard shortcut `F5` or `Ctrl+R` (`frontend/lib/config/router.dart:267-280`).
     2. Owner manually clicks the `SyncButton` on the top navbar or sidebar (`frontend/lib/shared/widgets/sync_button.dart:51`), which invokes `GlobalSyncController.syncAndRefreshAll(currentRoute: '/owner/tables')` (`frontend/lib/services/sync/global_sync_controller.dart:62-63`).
     3. Owner navigates away to another screen (e.g., Dashboard or Reports) and navigates back to Tables. This mounts a new `_TablesScreenState`, causing `initState()` -> `WidgetsBinding.instance.addPostFrameCallback` to execute `loadTables()` (`frontend/lib/features/tables/tables_screen.dart:34`).
     4. Owner performs a write action on their own terminal that calls `loadTables()` (e.g. creating another table or adding a zone).

### High-Risk Race Conditions & Failure Modes in Current Code
- **Double Seating / Walk-in Conflict**: While Table 1 is reserved by Cashier 1, Cashier 2 or Owner sees Table 1 as green and seats a walk-in party. In `TablesService.updateTableStatus()` (`backend/src/tables/tables.service.ts:92-109`), there is **no check for existing reservations** and **no optimistic locking (`version` field)**. The cashier seating the walk-in overwrites `status: 'occupied'` and wipes out the reservation without any concurrency warning.
- **Dine-In Checkout Desynchronization**: If Cashier 1 receives payment and marks Table 1 released (`backend/src/tables/tables.service.ts:111`), Cashier 2 still sees Table 1 occupied with the previous bill amount until manual refresh.

---

## 3. Analysis of Existing WebSocket Implementation

### 3.1 Socket Authentication Analysis

In `backend/src/kitchen/kitchen.gateway.ts:67-93`:
```typescript
async handleConnection(client: Socket) {
  try {
    const token =
      client.handshake.auth?.token ||
      client.handshake.headers?.authorization?.replace('Bearer ', '');

    if (!token) {
      this.logger.warn(`Socket connection rejected: No token provided (${client.id})`);
      client.disconnect(true);
      return;
    }

    const secret =
      this.configService.get<string>('JWT_SECRET') || 'hungry-howies-pos-dev-secret-key-2026';
    const payload = this.jwtService.verify(token, { secret });
    client.data.user = payload;

    // Automatically join the general kitchen room
    await client.join('kitchen');
    this.logger.log(`Client authenticated and connected to Kitchen Gateway: ${client.id}`);
  } catch (err: unknown) {
    this.logger.warn(`Socket connection unauthorized: ${(err as Error).message} (${client.id})`);
    client.disconnect(true);
  }
}
```

#### Observations & Risks:
1. **Fallback Secret Vulnerability**: If `JWT_SECRET` is unset in production, it defaults to a hardcoded string `'hungry-howies-pos-dev-secret-key-2026'` (`kitchen.gateway.ts:80`).
2. **Missing Token Expiry / Re-Auth on Long-Running Sockets**: Once connected, the socket connection remains active indefinitely. When the JWT token expires on the client (default 24h), the socket connection is **not revoked** until the socket drops and tries to reconnect.
3. **No Role Verification on Connection**: Any valid JWT (Cashier, Waiter, Rider) is permitted to connect and is automatically joined to the `'kitchen'` room (`kitchen.gateway.ts:85`). There is no guard restricting KDS event broadcasts to kitchen or manager accounts.

---

### 3.2 Reconnection Handling & Protocol Parsing

In `frontend/lib/core/network/kitchen_socket_service.dart:121-138`:
```dart
void _handleDisconnect() {
  _isConnected = false;
  _pingTimer?.cancel();
  if (!_isDisposed) {
    _scheduleReconnect();
  }
}

void _scheduleReconnect() {
  _isConnected = false;
  _pingTimer?.cancel();
  _reconnectTimer?.cancel();
  _reconnectTimer = Timer(const Duration(seconds: 5), () {
    if (!_isDisposed) {
      connect();
    }
  });
}
```

#### Deficiencies in Reconnection Strategy:
1. **Fixed Reconnect Timer (No Backoff / No Jitter)**: Uses a constant 5-second one-shot timer (`Duration(seconds: 5)`). If the server restarts or experiences network flapping with multiple terminals connected, all clients reconnect synchronously in lockstep, causing a thundering herd.
2. **Silent Event Loss (No Sequence Numbers / Missed Delta Sync)**: If the kitchen terminal drops Wi-Fi for 30 seconds and reconnects at $t=35$, any orders created or updated between $t=0$ and $t=35$ are **never delivered**. The client does not request a catch-up or missed-events buffer upon reconnection.
3. **Fragile Protocol Parser**: The client relies on raw string pattern matching (`data.startsWith('42')`, `jsonDecode(data.substring(2))`) in `_handleMessage()` (`kitchen_socket_service.dart:83-97`). If Socket.IO sends packet headers with binary attachments or namespaces (`42/kitchen,[...]`), the string slicing breaks or silently fails in the empty `catch (_) {}` block.

---

### 3.3 Violation of Phase 13 Principle: Events Treated as Source of Truth

The core architectural principle for Phase 13 states:
> **PostgreSQL = server source of truth; local DB = offline operational store; WebSocket = notification only; Sync API = reliable sync; events are never source of truth.**

#### Codebase Violations in `frontend/lib/data/kitchen_repository.dart`:

1. **Direct Payload Injection into In-Memory State**:
   ```dart
   // frontend/lib/data/kitchen_repository.dart:126-131
   void _onSocketOrderReceived(Map<String, dynamic> payload) {
     try {
       final order = OrderModel.fromBackendJson(payload);
       addIncomingOrder(order); // In-memory mutation!
     } catch (_) {}
   }
   ```
   When `order.created` arrives, the client decodes the raw socket JSON payload and directly inserts or updates `state.kitchenOrders`. 
   - It **does not persist** the order into a local database.
   - It **does not verify** with the server REST API whether the order is valid or already modified.
   - The socket event is treated as the definitive source of truth.

2. **Partial Status Mutations**:
   ```dart
   // frontend/lib/data/kitchen_repository.dart:133-148
   void _onSocketStatusChanged(Map<String, dynamic> payload) {
     try {
       final orderId = payload['orderId']?.toString() ?? payload['id']?.toString();
       final statusStr = payload['status']?.toString().toLowerCase() ?? '';
       if (orderId != null) {
         OrderStatus next = OrderStatus.accepted;
         if (statusStr == 'preparing') next = OrderStatus.preparing;
         if (statusStr == 'ready') next = OrderStatus.ready;
         // ...
         _applyStatusUpdate(orderId, next);
       }
     } catch (_) {}
   }
   ```
   `_applyStatusUpdate()` modifies only the `status` enum on the in-memory `OrderModel`. If another user also modified order items, guest count, or waiter notes in that same transaction, those changes are discarded/ignored because the client assumed the socket event payload was exhaustive.

3. **Incomplete Payload Schema**:
   `KitchenOrderEventPayload` (`backend/src/kitchen/kitchen.gateway.ts:14-44`) strips out discounts, sales tax, service charges, tendered payment methods, and historical payment IDs. If any screen attempts to use this payload for accounting or receipt printing, financial calculations will be corrupted.

---

## 4. Entity Classification by Real-Time Urgency

Based on operational store workflows, multi-terminal concurrency hazards, and offline-first data integrity requirements, all system entities from `DATABASE_TABLES_SCHEMA.md` and `backend/prisma/schema.prisma` are classified into three architectural tiers:

1. **REAL-TIME REQUIRED**: High-frequency operational entities where desynchronization between terminals leads to immediate business failure (double-booked tables, duplicate food preparation, lost customer orders, or conflicting cash settlements). Must propagate within $< 2$ seconds via WebSocket notifications followed by delta sync.
2. **EVENTUALLY CONSISTENT**: Operational and administrative entities that can tolerate propagation latencies ranging from seconds to minutes. Reconciled via periodic background sync, manual refresh, or outbox pull.
3. **SERVER-ONLY**: Analytical, historical, or heavyweight audit data that should not be maintained in real-time local stores and is queried on demand from PostgreSQL.

### Classification Matrix

| Entity / Database Table | Classification | Required Latency | Concurrency / Multi-User Conflict Hazard | Architectural Rationale |
|---|---|---|---|---|
| `restaurant_tables` | **REAL-TIME REQUIRED** | $< 2$ seconds | **CRITICAL**: Double-booking, conflicting walk-in seating, duplicate bill payment | Multiple cashiers/waiters seat guests and process bills simultaneously. Table occupancy must be visible across all terminals instantly. |
| `floor_zones` | **EVENTUALLY CONSISTENT** | Minutes / On Load | Low: Zone layout created/deleted by owner/manager | Table layout changes happen rarely during active shift operations. |
| `orders` (Active / Open / In-Flight) | **REAL-TIME REQUIRED** | $< 1$ second | **CRITICAL**: Duplicate prep, late item cancellation, stale KOT | When an order is placed, updated, or cancelled, kitchen and POS cashiers must see state changes immediately. |
| `order_items` (Active) | **REAL-TIME REQUIRED** | $< 1$ second | **HIGH**: Kitchen preparing items that were cancelled at POS | Strikethrough item cancellations and extra notes must reach kitchen displays before cooking commences. |
| `dine_in_order_details` | **REAL-TIME REQUIRED** | $< 2$ seconds | **HIGH**: Table reassignments, split bills, guest headcount | Directly tied to live dining table state. |
| `takeaway_order_details` | **REAL-TIME REQUIRED** | $< 2$ seconds | **HIGH**: Duplicate token numbers, pickup counter confusion | Counter staff call customer tokens. Pickup status must match what cashier sees. |
| `online_order_details` | **REAL-TIME REQUIRED** | $< 3$ seconds | **HIGH**: Unaccepted online orders breaching SLA ($< 60$s) | Web / Mobile App orders require prompt acceptance or rejection by cashier. |
| `delivery_dispatches` | **REAL-TIME REQUIRED** | $< 3$ seconds | **HIGH**: Re-assigning orders to already departed riders | Dispatcher assigns orders to available riders. Active trip counts must update immediately. |
| `delivery_riders` | **EVENTUALLY CONSISTENT** | $15–30$ seconds | Medium: Stale availability or active delivery count | Clock-in and shift availability update when rider reports to store. Active delivery count can sync on dispatch creation. |
| `order_payments` | **REAL-TIME REQUIRED** | $< 2$ seconds | **HIGH**: Double charging customer or letting unpaid party leave | Cashier collecting payment changes table to paid/available. Other cashiers must know table is settled. |
| `inventory_items` | **EVENTUALLY CONSISTENT** | $30–60$ seconds | Medium: Stock auto-deduction race conditions on 86'd items | Ingredients auto-deduct in background upon order completion. Small propagation delay is acceptable unless stock reaches zero. |
| `stock_movements` | **EVENTUALLY CONSISTENT** | Batch / Minutes | Low: Append-only audit ledger | Historical transaction log of inventory adjustments. |
| `menu_items` (Availability Flag) | **REAL-TIME REQUIRED** | $< 3$ seconds | **HIGH**: Punching 86'd out-of-stock item | When an item is marked unavailable (86'd), all POS terminals must immediately block ordering that item. |
| `menu_items` (Catalog / Pricing) | **EVENTUALLY CONSISTENT** | On Load / Hours | Low: Price changes during shift are rare | Menu prices and recipe configurations change during off-peak hours or administrative maintenance. |
| `menu_categories`, `sizes`, `options`, `deals` | **EVENTUALLY CONSISTENT** | On Load / Hours | Low: Catalog definitions | Infrequent structural changes. |
| `customers` (CRM & Loyalty) | **EVENTUALLY CONSISTENT** | $15–60$ seconds | Low: Loyalty point accumulation | Customer profiles and address books can read from local cache; loyalty points reconcile via outbox sync. |
| `store_settings` | **EVENTUALLY CONSISTENT** | On Load / Shift Start | Low: Branch phone, address, tax rates | Static store configuration; changes require manager administrative save. |
| `staff_users` & `role_permissions` | **EVENTUALLY CONSISTENT** | $< 10$ seconds | **HIGH**: Revoked cashier continuing to process refunds | Permission matrix changes should trigger socket notification to force local token/permission invalidation. |
| `staff_members` (HR / Roster) | **EVENTUALLY CONSISTENT** | Minutes / On Load | Low: Employee profile management | HR record creation and monthly base salary edits. |
| `payslips` | **SERVER-ONLY** | On Demand Query | None: Back-office historical records | Monthly payroll documents queried only on the HR payslip screen. |
| `expenses` (Store Operations) | **EVENTUALLY CONSISTENT** | Outbox sync / Shift | Low: Cash expense records | Recorded locally and synced to central database. |
| `daily_calculations` (Active Shift) | **EVENTUALLY CONSISTENT** | Local Register / Close | **HIGH**: Two terminals operating on the same shift calculation | Active cash drawer is tied to a specific physical terminal and cashier ID. Reconciliation syncs on shift close. |
| `daily_calculations` (Historical) | **SERVER-ONLY** | On Demand Query | None | Historical register closures reviewed by owner/auditor. |
| `daily_expense_items` | **EVENTUALLY CONSISTENT** | With Shift Record | Low: Shift drawer expense vouchers | Linked directly to the active daily calculation shift. |
| `orders` (Completed / Closed) | **SERVER-ONLY** | On Demand / Archive | None: Immutable historical records | Once settled, historical orders can be queried on demand from PostgreSQL. |
| `reports` (Sales, Product, Taxes) | **SERVER-ONLY** | On Demand Aggregation | None: Complex PostgreSQL aggregation | Analytics calculated across the entire branch transaction history directly in PostgreSQL. |
| `data_sync_logs` | **SERVER-ONLY** | Real-time Audit Write | None: Diagnostic log table | Central server ledger of sync actions and payloads. |

---

## 5. Target Multi-User Architecture for Phase 12 / 13

To resolve the current real-time deficiencies without violating offline-first integrity, the target architecture establishes strict boundaries between Local State, Server State, Pending State, Synced State, and Conflict State:

```
[ Terminals A & B: Local Drift / SQLite Store ]
                      |
                      | 1. Local Write (Optimistic UI, Pending State)
                      v
             [ Outbox Sync Queue ]
                      |
                      | 2. Reliable REST Sync (Idempotent /api/sync/push)
                      v
          [ PostgreSQL Server (Source of Truth) ]
                      |
                      | 3. Broadcast Invalidation (Notification-Only)
                      v
       [ Central WebSocket Gateway (Socket.IO) ]
                      |
                      | 4. Lightweight Signal: { entity: "tables", id: "t1", v: 42 }
                      +---------------------------------------+
                      |                                       |
                      v                                       v
               [ Terminal A ]                           [ Terminal B ]
               (Originator)                             (Peer Terminal)
                      |                                       |
                      | (Already Synced)                      | 5. Pulls /api/sync/delta?since=...
                      |                                       v
                      |                                 [ Updates Drift DB ]
                      |                                       |
                      |                                       | 6. Reactive Stream
                      v                                       v
               [ Riverpod UI ]                         [ Riverpod UI ]
```

### 5.1 The Four Architecture Tenets for Multi-User Sync

1. **WebSocket = Notification Only (Signal Bus)**:
   - WebSocket packets **must never transmit authoritative entity bodies**.
   - Socket payloads are restricted to lightweight invalidation envelopes:
     ```json
     {
       "event": "entity.invalidated",
       "entity": "restaurant_table",
       "entity_id": "table-t1-uuid",
       "action": "UPDATE",
       "version": 42,
       "timestamp": "2026-10-17T19:00:00.000Z",
       "origin_device_id": "POS-TERMINAL-01"
     }
     ```
   - Terminal B inspects `origin_device_id`. If it originated the change, it ignores the signal. If from a peer, it schedules a background pull from the Sync API.

2. **Sync API = Authoritative Reconciliation**:
   - Clients pull changes via `GET /api/sync/delta?since=<high_water_mark>`.
   - Incoming server records are written directly to the local Drift/SQLite operational store.
   - Riverpod providers watch reactive Drift stream queries (`watchTables()`), ensuring automatic UI updates with zero manual provider invalidation.

3. **Reconnection & Catch-Up Protocol**:
   - When WebSocket reconnects after a network interruption, the client **must immediately invoke the delta sync endpoint** using its last persisted `sync_high_water_mark`.
   - This eliminates silent event loss during network partitions.

4. **Optimistic Locking & Concurrency Resolution**:
   - Every mutable table (`restaurant_tables`, `orders`, `inventory_items`) requires a `version INT DEFAULT 1` and `last_modified_at TIMESTAMP` column in PostgreSQL and Drift.
   - When a client pushes a status change, it passes `expected_version`. If another terminal updated the table first, PostgreSQL rejects the write with `409 Conflict`, prompting the local client to pull the latest state and alert the cashier before overwriting.

---

## 6. Questions for the Developer

The following questions cannot be resolved from code inspection alone and require developer/business input:

1. **Terminal Deployment Topology**:
   - In a standard restaurant branch, how many simultaneous client terminals are expected (e.g., 2 POS cashiers, 1 KDS screen, 1 manager back-office laptop), and do they operate on the same Local Area Network (LAN)?
   - *Context:* If all branch terminals share a local LAN, a local peer-to-peer notification bus or local master node could enable real-time sync between cashier and kitchen even when the store's broadband internet is completely severed.

2. **Table Reservation vs. Walk-In Conflict Policy**:
   - If Terminal A (offline) reserves Table 1, while Terminal B (offline) simultaneously seats a walk-in party at Table 1, which transaction wins when both reconnect to PostgreSQL?
   - *Options:*
     - A: First-write-wins (the earlier timestamp wins; the other terminal receives a conflict notification).
     - B: Seated guest always supersedes reservation (operational hospitality policy).
     - C: Reservation always supersedes walk-in (manager must manually re-seat walk-in party).

3. **Kitchen Display System (KDS) Target Hardware**:
   - Is the KDS deployed on Windows hardware (same codebase as POS), an Android tablet, or an iPad?
   - *Context:* Affects whether the KDS can run the shared Drift/SQLite database engine and background sync workers, or if it must remain a lightweight web/mobile client.

4. **Multi-Cashier Shift Drawer Policy**:
   - Do multiple cashiers share a single physical cash drawer (`daily_calculations`), or does each cashier/terminal maintain an independent opening float, cash skimming, and closure ledger?
   - *Context:* Affects whether `daily_calculations` must synchronize live cash variance between terminals in real time or remain strictly terminal-local until end-of-shift closure.
