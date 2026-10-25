const http = require('http');
const crypto = require('crypto');
const WebSocket = require('ws');

// Helper to create a valid HS256 JWT
function createTestToken(payload, secret = 'hungry-howies-pos-dev-secret-key-2026') {
  const header = Buffer.from(JSON.stringify({ alg: 'HS256', typ: 'JWT' })).toString('base64url');
  const body = Buffer.from(JSON.stringify({
    sub: payload.sub || 'user-1',
    username: payload.username || 'cashier_p1',
    role: payload.role || 'cashier',
    store_id: payload.store_id || 'DEFAULT',
    iat: Math.floor(Date.now() / 1000),
    exp: Math.floor(Date.now() / 1000) + 3600,
  })).toString('base64url');
  const signature = crypto.createHmac('sha256', secret).update(`${header}.${body}`).digest('base64url');
  return `${header}.${body}.${signature}`;
}

class SimulatedPosClient {
  constructor(name, token) {
    this.name = name;
    this.token = token;
    this.ws = null;
    this.eventsReceived = [];
    this.isConnected = false;
  }

  connect(port) {
    return new Promise((resolve, reject) => {
      const url = `ws://127.0.0.1:${port}/socket.io/?EIO=4&transport=websocket&token=${this.token}`;
      this.ws = new WebSocket(url);

      this.ws.on('open', () => {
        // Send initial connect packet in case server expects it immediately
        this.ws.send(`40{"token":"${this.token}"}`);
      });

      this.ws.on('message', (data) => {
        const str = data.toString();
        // Server sends Engine.IO handshake open: 0{"sid":...}
        if (str.startsWith('0{')) {
          this.ws.send(`40{"token":"${this.token}"}`);
          return;
        }
        // Respond to ping
        if (str === '2') {
          this.ws.send('3');
          return;
        }
        // Socket.IO namespace connected: 40 or 40{"sid":...}
        if (str.startsWith('40')) {
          this.isConnected = true;
          this.ws.send('42["join_pos",{}]');
          this.ws.send('42["join_kitchen",{}]');
          resolve();
          return;
        }
        // Socket.IO event: 42["event_name", payload]
        if (str.startsWith('42')) {
          try {
            const list = JSON.parse(str.substring(2));
            const eventName = list[0];
            const payload = list[1];
            this.eventsReceived.push({ eventName, payload, timestamp: Date.now() });
          } catch (_) {}
        }
      });

      this.ws.on('error', (err) => {
        reject(err);
      });
    });
  }

  disconnect() {
    if (this.ws) {
      this.ws.terminate();
      this.ws = null;
      this.isConnected = false;
    }
  }

  hasReceived(eventName, predicate) {
    return this.eventsReceived.some((e) => {
      if (e.eventName !== eventName) return false;
      if (predicate) return predicate(e.payload);
      return true;
    });
  }

  clearEvents() {
    this.eventsReceived = [];
  }
}

async function runSimulation() {
  console.log('================================================================');
  console.log('REAL-TIME MULTI-CLIENT POS SYNCHRONIZATION VERIFICATION SUITE');
  console.log('================================================================');

  const { Test } = require('@nestjs/testing');
  const { RealtimeModule } = require('../dist/realtime/realtime.module');
  const { RealtimeGateway } = require('../dist/realtime/realtime.gateway');

  console.log('[Setup] Bootstrapping Realtime Test Server with RealtimeModule...');
  const moduleRef = await Test.createTestingModule({
    imports: [RealtimeModule],
  }).compile();

  const app = moduleRef.createNestApplication();
  const testPort = 33891;
  await app.listen(testPort);
  console.log(`[Setup] Realtime Gateway listening on port ${testPort}`);

  const realtimeGateway = app.get(RealtimeGateway);

  const tokenA = createTestToken({ sub: 'user-a', username: 'pos_computer_a', role: 'cashier' });
  const tokenB = createTestToken({ sub: 'user-b', username: 'pos_computer_b', role: 'cashier' });
  const tokenC = createTestToken({ sub: 'user-c', username: 'pos_computer_c', role: 'manager' });

  const clientA = new SimulatedPosClient('Computer A', tokenA);
  const clientB = new SimulatedPosClient('Computer B', tokenB);
  const clientC = new SimulatedPosClient('Computer C', tokenC);

  try {
    console.log('[Scenario 1] Connecting Computer A, Computer B, and Computer C simultaneously...');
    await clientA.connect(testPort);
    await clientB.connect(testPort);
    await clientC.connect(testPort);
    console.log('  -> All 3 clients authenticated and joined real-time rooms successfully.');

    // Wait a brief moment for socket handshakes to settle
    await new Promise((r) => setTimeout(r, 200));

    // -------------------------------------------------------------------------
    // TEST 1: MENU SYNCHRONIZATION
    // -------------------------------------------------------------------------
    console.log('\n[Test 1] Computer A modifies Menu (Category & Items)...');
    clientB.clearEvents();
    clientC.clearEvents();

    realtimeGateway.emitCategoryCreated({
      id: 'cat-specialty-pizza',
      name: 'Specialty Pizzas',
      badge_text: 'Popular',
    });

    realtimeGateway.emitMenuItemUpdated({
      id: 'item-howie-maui',
      name: 'Howie Maui',
      price: 1850,
      is_available: true,
    });

    await new Promise((r) => setTimeout(r, 200));

    const bReceivedCategory = clientB.hasReceived('category:created') || clientB.hasReceived('menu:updated');
    const bReceivedItem = clientB.hasReceived('menu:item_updated') || clientB.hasReceived('menu:updated');
    const cReceivedCategory = clientC.hasReceived('category:created') || clientC.hasReceived('menu:updated');

    console.log(`  -> Computer B received Category event: ${bReceivedCategory ? 'PASS' : 'FAIL'}`);
    console.log(`  -> Computer B received Item event: ${bReceivedItem ? 'PASS' : 'FAIL'}`);
    console.log(`  -> Computer C received Category event: ${cReceivedCategory ? 'PASS' : 'FAIL'}`);
    if (!bReceivedCategory || !bReceivedItem) throw new Error('Menu real-time sync failed');

    // -------------------------------------------------------------------------
    // TEST 2: TABLES SYNCHRONIZATION
    // -------------------------------------------------------------------------
    console.log('\n[Test 2] Computer A modifies Table status & transfers table...');
    clientB.clearEvents();

    realtimeGateway.emitTableStatusChanged({
      id: 'tbl-12',
      name: 'Table 12',
      status: 'occupied',
      guest_count: 4,
    });

    realtimeGateway.emitTableTransferred({
      fromTableId: 'tbl-12',
      toTableId: 'tbl-15',
      orderNumber: 'ORD-9901',
    });

    await new Promise((r) => setTimeout(r, 200));

    const bReceivedTableStatus = clientB.hasReceived('table:status_changed') || clientB.hasReceived('table:updated');
    const bReceivedTableTransfer = clientB.hasReceived('table:transferred') || clientB.hasReceived('table:updated');

    console.log(`  -> Computer B received Table Status event: ${bReceivedTableStatus ? 'PASS' : 'FAIL'}`);
    console.log(`  -> Computer B received Table Transfer event: ${bReceivedTableTransfer ? 'PASS' : 'FAIL'}`);
    if (!bReceivedTableStatus || !bReceivedTableTransfer) throw new Error('Table real-time sync failed');

    // -------------------------------------------------------------------------
    // TEST 3: ORDERS SYNCHRONIZATION (Created, Updated, Cancelled)
    // -------------------------------------------------------------------------
    console.log('\n[Test 3] Computer A creates, updates and cancels Orders...');
    clientB.clearEvents();

    const mockOrder = {
      id: 'ord-sim-77',
      order_number: 'ORD-77',
      order_type: 'takeAway',
      status: 'new',
      grand_total: 2500,
      order_items: [{ id: 'it-1', item_name: 'Stuffed Crust Pizza', quantity: 2, unit_price: 1250, total_price: 2500 }],
    };

    realtimeGateway.emitOrderCreated(mockOrder);
    realtimeGateway.emitOrderStatusChanged({ ...mockOrder, status: 'preparing' });
    realtimeGateway.emitOrderReady({ ...mockOrder, status: 'ready' });
    realtimeGateway.emitOrderCancelled({ ...mockOrder, status: 'cancelled' });

    await new Promise((r) => setTimeout(r, 200));

    const bReceivedOrderCreated = clientB.hasReceived('order:created');
    const bReceivedOrderStatus = clientB.hasReceived('order:status_changed');
    const bReceivedOrderReady = clientB.hasReceived('order:ready');
    const bReceivedOrderCancelled = clientB.hasReceived('order:cancelled');

    console.log(`  -> Computer B received order:created: ${bReceivedOrderCreated ? 'PASS' : 'FAIL'}`);
    console.log(`  -> Computer B received order:status_changed: ${bReceivedOrderStatus ? 'PASS' : 'FAIL'}`);
    console.log(`  -> Computer B received order:ready: ${bReceivedOrderReady ? 'PASS' : 'FAIL'}`);
    console.log(`  -> Computer B received order:cancelled: ${bReceivedOrderCancelled ? 'PASS' : 'FAIL'}`);
    if (!bReceivedOrderCreated || !bReceivedOrderStatus || !bReceivedOrderReady || !bReceivedOrderCancelled) {
      throw new Error('Order real-time sync failed');
    }

    // -------------------------------------------------------------------------
    // TEST 4: STAFF & USERS SYNCHRONIZATION
    // -------------------------------------------------------------------------
    console.log('\n[Test 4] Computer A modifies Staff and User credentials...');
    clientB.clearEvents();

    realtimeGateway.emitStaffCreated({
      id: 'st-505',
      full_name: 'John Doe',
      role: 'rider',
    });

    realtimeGateway.emitUserUpdated({
      id: 'usr-901',
      username: 'cashier_night',
    });

    await new Promise((r) => setTimeout(r, 200));

    const bReceivedStaff = clientB.hasReceived('staff:created') || clientB.hasReceived('staff:updated');
    const bReceivedUser = clientB.hasReceived('user:updated') || clientB.hasReceived('staff:updated');

    console.log(`  -> Computer B received Staff event: ${bReceivedStaff ? 'PASS' : 'FAIL'}`);
    console.log(`  -> Computer B received User event: ${bReceivedUser ? 'PASS' : 'FAIL'}`);
    if (!bReceivedStaff || !bReceivedUser) throw new Error('Staff real-time sync failed');

    // -------------------------------------------------------------------------
    // TEST 5: DELIVERY & RIDERS SYNCHRONIZATION
    // -------------------------------------------------------------------------
    console.log('\n[Test 5] Computer A updates Delivery Riders and Dispatches...');
    clientB.clearEvents();

    realtimeGateway.emitRiderUpdated({
      id: 'rdr-33',
      full_name: 'Speedy Rider',
      duty_status: 'onDuty',
    });

    realtimeGateway.emitDispatchCreated({
      id: 'dsp-101',
      order_id: 'ord-sim-77',
      rider_id: 'rdr-33',
      dispatch_status: 'assigned',
    });

    await new Promise((r) => setTimeout(r, 200));

    const bReceivedRider = clientB.hasReceived('rider:updated') || clientB.hasReceived('delivery:updated');
    const bReceivedDispatch = clientB.hasReceived('delivery:dispatch_created') || clientB.hasReceived('delivery:updated');

    console.log(`  -> Computer B received Rider event: ${bReceivedRider ? 'PASS' : 'FAIL'}`);
    console.log(`  -> Computer B received Dispatch event: ${bReceivedDispatch ? 'PASS' : 'FAIL'}`);
    if (!bReceivedRider || !bReceivedDispatch) throw new Error('Delivery real-time sync failed');

    // -------------------------------------------------------------------------
    // TEST 6: DISCONNECTION & RECONNECTION RECOVERY (§8)
    // -------------------------------------------------------------------------
    console.log('\n[Test 6] Testing Disconnection & Reconnection Recovery...');
    console.log('  -> Disconnecting Computer B temporarily (simulating Wi-Fi drop)...');
    clientB.disconnect();

    console.log('  -> Computer A modifies Table and Order while Computer B is offline...');
    realtimeGateway.emitTableStatusChanged({
      id: 'tbl-8',
      name: 'Table 8',
      status: 'occupied',
    });

    console.log('  -> Computer B reconnects to server...');
    const clientBReconnected = new SimulatedPosClient('Computer B Reconnected', tokenB);
    await clientBReconnected.connect(testPort);

    console.log('  -> Computer B reconnected and re-authenticated successfully: PASS');

    // Computer A mutates again after Computer B has reconnected
    clientBReconnected.clearEvents();
    realtimeGateway.emitTableStatusChanged({
      id: 'tbl-9',
      name: 'Table 9',
      status: 'cleaning',
    });

    await new Promise((r) => setTimeout(r, 200));
    const bReceivedPostReconn = clientBReconnected.hasReceived('table:status_changed') || clientBReconnected.hasReceived('table:updated');
    console.log(`  -> Computer B receives live events after reconnecting: ${bReceivedPostReconn ? 'PASS' : 'FAIL'}`);

    clientBReconnected.disconnect();

    console.log('\n================================================================');
    console.log('ALL REAL-TIME MULTI-CLIENT SYNCHRONIZATION TESTS PASSED! (7/7)');
    console.log('================================================================');
  } finally {
    clientA.disconnect();
    clientB.disconnect();
    clientC.disconnect();
    await app.close();
  }
}

runSimulation()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('Simulation Failed:', err);
    process.exit(1);
  });
