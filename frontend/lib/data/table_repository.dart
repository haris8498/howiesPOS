import 'dart:convert';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../config/feature_flags.dart';
import '../core/database/app_database.dart';
import '../core/database/tables/sync_outbox_table.dart';
import '../core/sync/sync_providers.dart';
import '../domain/models/restaurant_table.dart';
import '../services/api/api_providers.dart';
import '../services/api/tables_api_service.dart';

class TableState {
  final List<RestaurantTable> tables;
  final List<String> zones;
  final String selectedSection;
  final List<WaitlistEntry> waitlist;
  final bool isLoading;

  const TableState({
    required this.tables,
    this.zones = const ['Hall', 'Family Hall', 'Office', 'Terrace'],
    this.selectedSection = 'All',
    this.waitlist = const [],
    this.isLoading = false,
  });

  int get availableCount => tables.where((t) => t.status == TableStatus.available).length;
  int get occupiedCount => tables.where((t) => t.status == TableStatus.occupied).length;
  int get reservedCount => tables.where((t) => t.status == TableStatus.reserved).length;

  TableState copyWith({
    List<RestaurantTable>? tables,
    List<String>? zones,
    String? selectedSection,
    List<WaitlistEntry>? waitlist,
    bool? isLoading,
  }) {
    return TableState(
      tables: tables ?? this.tables,
      zones: zones ?? this.zones,
      selectedSection: selectedSection ?? this.selectedSection,
      waitlist: waitlist ?? this.waitlist,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class TableNotifier extends StateNotifier<TableState> {
  final TablesApiService _tablesApiService;
  final AppDatabase? db;

  TableNotifier({TablesApiService? tablesApiService, this.db})
      : _tablesApiService = tablesApiService ?? TablesApiService(),
        super(const TableState(
          tables: [],
        )) {
    loadTables();
  }

  void setTablesForTesting(List<RestaurantTable> tables) {
    state = state.copyWith(tables: tables);
  }

  Future<void> loadTables({bool silent = false}) async {
    if (!silent && state.tables.isEmpty) {
      state = state.copyWith(isLoading: true);
    }
    final localDb = db;
    try {
      final jsonList = await _tablesApiService.listTables();
      final tables = jsonList.map((j) => RestaurantTable.fromBackendJson(j)).toList();
      final currentMap = {for (final t in state.tables) t.id: t};
      final mergedTables = await Future.wait(tables.map((st) async {
        var local = currentMap[st.id];
        // SYNC-031: On cold restart / app reload, check local SQLite table cache if state.tables was empty
        if (local == null && FeatureFlags.offlineFirstEnabled && localDb != null) {
          try {
            final dbTable = await (localDb.select(localDb.localRestaurantTables)..where((t) => t.id.equals(st.id))).getSingleOrNull();
            if (dbTable != null && (dbTable.status == 'occupied' || dbTable.status == 'reserved')) {
              local = RestaurantTable(
                id: dbTable.id,
                tableNumber: dbTable.tableNumber,
                name: dbTable.name,
                capacity: dbTable.capacity,
                status: dbTable.status == 'occupied' ? TableStatus.occupied : TableStatus.reserved,
                activeOrderId: dbTable.activeOrderId,
                section: st.section,
              );
            }
          } catch (_) {}
        }
        if (local != null) {
          if (local.status == TableStatus.occupied) {
            if (st.status == TableStatus.available) {
              // Local table has active occupation that server hasn't processed yet
              return local;
            }
            if (local.currentOrderItems.isNotEmpty && st.currentOrderItems.isEmpty) {
              // Server knows occupied but doesn't have order items breakdown yet
              return st.copyWith(
                currentOrderItems: local.currentOrderItems,
                currentBillAmount: st.currentBillAmount > 0 ? st.currentBillAmount : local.currentBillAmount,
                activeOrderId: st.activeOrderId ?? local.activeOrderId,
                activeOrderNumber: st.activeOrderNumber ?? local.activeOrderNumber,
              );
            }
          } else if (local.status == TableStatus.reserved && st.status == TableStatus.available) {
            // Local table has active reservation that server hasn't processed yet
            return local;
          }
        }
        // If table is occupied on server but order items are empty, check local SQLite ordersDao
        if (st.status == TableStatus.occupied && st.currentOrderItems.isEmpty && st.activeOrderId != null && localDb != null) {
          try {
            final localItems = await localDb.ordersDao.getOrderItems(st.activeOrderId!);
            if (localItems.isNotEmpty) {
              final mappedItems = localItems.map((item) => {
                'id': item.id,
                'name': item.itemName,
                'quantity': item.quantity,
                'price': item.unitPrice,
                'selected_size': item.sizeName ?? 'Regular',
                'notes': item.notes,
                'is_cancelled': item.isCancelled,
                'cancel_reason': item.cancelReason,
              }).toList();
              final localTotal = localItems.where((i) => !i.isCancelled).fold<double>(0.0, (acc, i) => acc + i.subtotal);
              return st.copyWith(
                currentOrderItems: mappedItems,
                currentBillAmount: st.currentBillAmount > 0 ? st.currentBillAmount : localTotal,
              );
            }
          } catch (_) {}
        }
        return st;
      }));

            // Preserve locally occupied soft-deleted tables so cashier can settle orders (§SYNC-012/TBL-12)
      if (FeatureFlags.offlineFirstEnabled && localDb != null) {
        try {
          final allLocal = await localDb.catalogDao.getAllTables(includeDeleted: true);
          for (final lt in allLocal) {
            if (lt.isDeleted && (lt.status == 'occupied' || lt.activeOrderId != null)) {
              final alreadyIn = mergedTables.any((mt) => mt.id == lt.id);
              if (!alreadyIn) {
                List<Map<String, dynamic>> items = const [];
                double bill = 0.0;
                if (lt.activeOrderId != null) {
                  final dbItems = await localDb.ordersDao.getOrderItems(lt.activeOrderId!);
                  if (dbItems.isNotEmpty) {
                    items = dbItems.map((i) => {
                      'id': i.id,
                      'name': i.itemName,
                      'quantity': i.quantity,
                      'price': i.unitPrice,
                      'selected_size': i.sizeName ?? 'Regular',
                      'notes': i.notes,
                      'is_cancelled': i.isCancelled,
                      'cancel_reason': i.cancelReason,
                    }).toList();
                    bill = dbItems.where((i) => !i.isCancelled).fold<double>(0.0, (acc, i) => acc + i.subtotal);
                  }
                }
                mergedTables.add(RestaurantTable(
                  id: lt.id,
                  tableNumber: lt.tableNumber,
                  name: lt.name,
                  capacity: lt.capacity,
                  section: 'Hall',
                  status: TableStatus.occupied,
                  activeOrderId: lt.activeOrderId,
                  currentBillAmount: bill,
                  currentOrderItems: items,
                  isDeleted: true,
                ));
              }
            }
          }
        } catch (_) {}
      }

      // Cache tables locally in Drift catalog
      if (FeatureFlags.offlineFirstEnabled && localDb != null && mergedTables.isNotEmpty) {
        final companions = mergedTables.map((t) => LocalRestaurantTablesCompanion(
          id: Value(t.id),
          tableNumber: Value(t.tableNumber),
          name: Value(t.name),
          capacity: Value(t.capacity),
          status: Value(t.status.name),
          activeOrderId: Value(t.activeOrderId),
          isDeleted: Value(t.isDeleted),
        )).toList();
        await localDb.catalogDao.upsertRestaurantTables(companions);
      }

      // Load distinct zones from backend floor_zones table
      List<String> zonesList = [];
      try {
        final zoneJson = await _tablesApiService.listZones();
        if (zoneJson.isNotEmpty) {
          zonesList = zoneJson.map((z) => z['name']?.toString() ?? '').where((n) => n.isNotEmpty).toList();
        }
      } catch (_) {}

      if (zonesList.isEmpty) {
        final dynamicZones = mergedTables.map((t) => t.section).where((s) => s.isNotEmpty).toSet();
        zonesList = {'Hall', 'Family Hall', 'Office', ...dynamicZones}.toList();
      }

      state = state.copyWith(tables: mergedTables, zones: zonesList, isLoading: false);
    } catch (_) {
      // Offline fallback: load from local SQLite catalog
      if (FeatureFlags.offlineFirstEnabled && localDb != null) {
        final localTables = await localDb.catalogDao.getAllTables(includeDeleted: true);
        if (localTables.isNotEmpty) {
          final currentMap = {for (final t in state.tables) t.id: t};
          final mapped = await Future.wait(localTables.map((lt) async {
            final local = currentMap[lt.id];
            List<Map<String, dynamic>> items = local?.currentOrderItems ?? const [];
            double bill = local?.currentBillAmount ?? 0.0;
            if (items.isEmpty && lt.activeOrderId != null) {
              try {
                final dbItems = await localDb.ordersDao.getOrderItems(lt.activeOrderId!);
                if (dbItems.isNotEmpty) {
                  items = dbItems.map((i) => {
                    'id': i.id,
                    'name': i.itemName,
                    'quantity': i.quantity,
                    'price': i.unitPrice,
                    'selected_size': i.sizeName ?? 'Regular',
                    'notes': i.notes,
                    'is_cancelled': i.isCancelled,
                    'cancel_reason': i.cancelReason,
                  }).toList();
                  bill = dbItems.where((i) => !i.isCancelled).fold<double>(0.0, (acc, i) => acc + i.subtotal);
                }
              } catch (_) {}
            }
            return RestaurantTable(
              id: lt.id,
              tableNumber: lt.tableNumber,
              name: lt.name,
              capacity: lt.capacity,
              section: local?.section ?? 'Hall',
              status: TableStatus.values.firstWhere(
                (s) => s.name.toLowerCase() == lt.status.toLowerCase(),
                orElse: () => TableStatus.available,
              ),
              activeOrderId: lt.activeOrderId ?? local?.activeOrderId,
              activeOrderNumber: local?.activeOrderNumber,
              currentBillAmount: bill,
              currentOrderItems: items,
              reservedCustomerName: local?.reservedCustomerName,
              reservationTime: local?.reservationTime,
              isDeleted: lt.isDeleted,
            );
          }));
          state = state.copyWith(tables: mapped, isLoading: false);
          return;
        }
      }
      state = state.copyWith(isLoading: false);
    }
  }

  void setSection(String section) {
    state = state.copyWith(selectedSection: section);
  }

  Future<void> updateTableStatus(String tableId, TableStatus newStatus, {String? activeOrderId}) async {
    final localDb = db;
    if (FeatureFlags.offlineFirstEnabled && localDb != null) {
      final existingLocal = await (localDb.select(localDb.localRestaurantTables)..where((t) => t.id.equals(tableId))).getSingleOrNull();
      final currentVer = existingLocal?.version ?? 1;
      final nextVer = currentVer + 1;

      await (localDb.update(localDb.localRestaurantTables)..where((t) => t.id.equals(tableId))).write(
        LocalRestaurantTablesCompanion(
          status: Value(newStatus.name),
          activeOrderId: Value(newStatus == TableStatus.occupied ? activeOrderId : null),
          version: Value(nextVer),
        ),
      );
      final opId = const Uuid().v7();
      await localDb.outboxDao.insertEntry(
        SyncOutboxCompanion(
          operationId: Value(opId),
          deviceId: const Value('POS-P1'),
          entityType: const Value('table'),
          entityId: Value(tableId),
          operationType: const Value('UPDATE'),
          baseVersion: Value(currentVer),
          schemaVersion: const Value(kCurrentOutboxPayloadVersion),
          dependencyOrder: const Value(3),
          status: const Value(SyncOutboxStatus.pending),
          payload: Value(jsonEncode({
            'id': tableId,
            'status': newStatus.name,
            'active_order_id': newStatus == TableStatus.occupied ? activeOrderId : null,
          })),
          createdAt: Value(DateTime.now()),
        ),
      );
    }

    final updated = state.tables.map((table) {
      if (table.id == tableId) {
        return table.copyWith(
          status: newStatus,
          activeOrderId: newStatus == TableStatus.occupied ? activeOrderId ?? table.activeOrderId : null,
        );
      }
      return table;
    }).toList();
    state = state.copyWith(tables: updated);

    try {
      await _tablesApiService.updateTableStatus(
        tableId,
        status: newStatus.name,
        activeOrderId: newStatus == TableStatus.occupied ? activeOrderId : null,
      );
      await loadTables();
    } catch (_) {}
  }

  Future<void> updateTableBillAndStatus(
    String tableId,
    double billAmount,
    TableStatus newStatus, {
    String? activeOrderId,
    String? activeOrderNumber,
    List<Map<String, dynamic>>? orderItems,
  }) async {
    final localDb = db;
    if (FeatureFlags.offlineFirstEnabled && localDb != null) {
      final existingLocal = await (localDb.select(localDb.localRestaurantTables)..where((t) => t.id.equals(tableId))).getSingleOrNull();
      final currentVer = existingLocal?.version ?? 1;
      final nextVer = currentVer + 1;

      await (localDb.update(localDb.localRestaurantTables)..where((t) => t.id.equals(tableId))).write(
        LocalRestaurantTablesCompanion(
          status: Value(newStatus.name),
          activeOrderId: Value(newStatus == TableStatus.occupied ? activeOrderId : null),
          version: Value(nextVer),
        ),
      );
      final opId = const Uuid().v7();
      await localDb.outboxDao.insertEntry(
        SyncOutboxCompanion(
          operationId: Value(opId),
          deviceId: const Value('POS-P1'),
          entityType: const Value('table'),
          entityId: Value(tableId),
          operationType: const Value('UPDATE'),
          baseVersion: Value(currentVer),
          schemaVersion: const Value(kCurrentOutboxPayloadVersion),
          dependencyOrder: const Value(3),
          status: const Value(SyncOutboxStatus.pending),
          payload: Value(jsonEncode({
            'id': tableId,
            'status': newStatus.name,
            'current_bill_amount': billAmount,
            'active_order_id': activeOrderId,
          })),
          createdAt: Value(DateTime.now()),
        ),
      );
    }

    final updated = state.tables.map((table) {
      if (table.id == tableId) {
        final fallbackNum = (int.tryParse(table.tableNumber) ?? 101).toString().padLeft(3, '0');
        return table.copyWith(
          status: newStatus,
          currentBillAmount: billAmount,
          activeOrderId: newStatus == TableStatus.occupied ? (activeOrderId ?? fallbackNum) : null,
          activeOrderNumber: newStatus == TableStatus.occupied ? (activeOrderNumber ?? (activeOrderId ?? fallbackNum)) : null,
          occupiedSince: newStatus == TableStatus.occupied ? DateTime.now() : null,
          currentOrderItems: newStatus == TableStatus.occupied
              ? (orderItems ?? table.currentOrderItems)
              : [],
        );
      }
      return table;
    }).toList();
    state = state.copyWith(tables: updated);

    try {
      await _tablesApiService.updateTableStatus(
        tableId,
        status: newStatus.name,
        currentBillAmount: billAmount,
        activeOrderId: activeOrderId,
      );
    } catch (_) {}
  }

  void updateTableOrderItems(String tableId, List<Map<String, dynamic>> items, double newBill) {
    final updated = state.tables.map((table) {
      if (table.id == tableId) {
        final fallbackNum = (int.tryParse(table.tableNumber) ?? 101).toString().padLeft(3, '0');
        return table.copyWith(
          currentOrderItems: items,
          currentBillAmount: newBill,
          status: TableStatus.occupied,
          activeOrderId: table.activeOrderId ?? fallbackNum,
          activeOrderNumber: table.activeOrderNumber ?? fallbackNum,
          occupiedSince: table.occupiedSince ?? DateTime.now(),
        );
      }
      return table;
    }).toList();
    state = state.copyWith(tables: updated);
  }

  Future<void> releaseTable(String tableId) async {
    final localDb = db;
    if (FeatureFlags.offlineFirstEnabled && localDb != null) {
      try {
        final existingLocal = await (localDb.select(localDb.localRestaurantTables)..where((t) => t.id.equals(tableId))).getSingleOrNull();
        final currentVer = existingLocal?.version ?? 1;
        final nextVer = currentVer + 1;

        await (localDb.update(localDb.localRestaurantTables)..where((t) => t.id.equals(tableId))).write(
          LocalRestaurantTablesCompanion(
            status: const Value('available'),
            activeOrderId: const Value(null),
            version: Value(nextVer),
          ),
        );
        final opId = const Uuid().v7();
        await localDb.outboxDao.insertEntry(
          SyncOutboxCompanion(
            operationId: Value(opId),
            deviceId: const Value('POS-P1'),
            entityType: const Value('table'),
            entityId: Value(tableId),
            operationType: const Value('UPDATE'),
            baseVersion: Value(currentVer),
            schemaVersion: const Value(kCurrentOutboxPayloadVersion),
            dependencyOrder: const Value(3),
            status: const Value(SyncOutboxStatus.pending),
            payload: Value(jsonEncode({
              'id': tableId,
              'status': TableStatus.available.name,
              'current_bill_amount': 0.0,
              'active_order_id': null,
            })),
            createdAt: Value(DateTime.now()),
          ),
        );
      } catch (_) {}
    }

    final updated = state.tables.map((table) {
      if (table.id == tableId) {
        return table.copyWith(
          status: TableStatus.available,
          activeOrderId: null,
          currentBillAmount: 0.0,
          currentCustomerCount: 0,
          currentOrderItems: [],
        );
      }
      return table;
    }).toList();
    state = state.copyWith(tables: updated);

    try {
      await _tablesApiService.releaseTable(tableId);
      await loadTables();
    } catch (_) {}
  }

  Future<void> transferTable(String fromTableId, String toTableId) async {
    try {
      await _tablesApiService.transferTable(fromTableId: fromTableId, toTableId: toTableId);
      await loadTables();
    } catch (_) {
      // SYNC-029 (TBL-03): Persist offline table transfer in local Drift and queue outbox mutations
      final localDb = db;
      if (FeatureFlags.offlineFirstEnabled && localDb != null) {
        try {
          final fromLocal = await (localDb.select(localDb.localRestaurantTables)..where((t) => t.id.equals(fromTableId))).getSingleOrNull();
          final toLocal = await (localDb.select(localDb.localRestaurantTables)..where((t) => t.id.equals(toTableId))).getSingleOrNull();

          final fromVer = fromLocal?.version ?? 1;
          final toVer = toLocal?.version ?? 1;

          await (localDb.update(localDb.localRestaurantTables)..where((t) => t.id.equals(fromTableId))).write(
            LocalRestaurantTablesCompanion(
              status: const Value('available'),
              activeOrderId: const Value(null),
              version: Value(fromVer + 1),
            ),
          );

          await (localDb.update(localDb.localRestaurantTables)..where((t) => t.id.equals(toTableId))).write(
            LocalRestaurantTablesCompanion(
              status: const Value('occupied'),
              activeOrderId: Value(fromLocal?.activeOrderId),
              version: Value(toVer + 1),
            ),
          );

          final opIdFrom = const Uuid().v7();
          await localDb.outboxDao.insertEntry(
            SyncOutboxCompanion(
              operationId: Value(opIdFrom),
              deviceId: const Value('POS-P1'),
              entityType: const Value('table'),
              entityId: Value(fromTableId),
              operationType: const Value('UPDATE'),
              baseVersion: Value(fromVer),
              schemaVersion: const Value(kCurrentOutboxPayloadVersion),
              dependencyOrder: const Value(3),
              status: const Value(SyncOutboxStatus.pending),
              payload: Value(jsonEncode({
                'id': fromTableId,
                'status': 'available',
                'active_order_id': null,
              })),
              createdAt: Value(DateTime.now()),
            ),
          );

          final opIdTo = const Uuid().v7();
          await localDb.outboxDao.insertEntry(
            SyncOutboxCompanion(
              operationId: Value(opIdTo),
              deviceId: const Value('POS-P1'),
              entityType: const Value('table'),
              entityId: Value(toTableId),
              operationType: const Value('UPDATE'),
              baseVersion: Value(toVer),
              schemaVersion: const Value(kCurrentOutboxPayloadVersion),
              dependencyOrder: const Value(3),
              status: const Value(SyncOutboxStatus.pending),
              payload: Value(jsonEncode({
                'id': toTableId,
                'status': 'occupied',
                'active_order_id': fromLocal?.activeOrderId,
              })),
              createdAt: Value(DateTime.now()),
            ),
          );
        } catch (_) {}
      }

      final fromTable = state.tables.where((t) => t.id == fromTableId).firstOrNull;
      if (fromTable == null) return;
      final updated = state.tables.map((table) {
        if (table.id == fromTableId) {
          return table.copyWith(
            status: TableStatus.available,
            activeOrderId: null,
            currentBillAmount: 0.0,
            currentOrderItems: [],
          );
        }
        if (table.id == toTableId) {
          return table.copyWith(
            status: TableStatus.occupied,
            activeOrderId: fromTable.activeOrderId,
            currentBillAmount: fromTable.currentBillAmount,
            occupiedSince: fromTable.occupiedSince,
            currentOrderItems: fromTable.currentOrderItems,
          );
        }
        return table;
      }).toList();
      state = state.copyWith(tables: updated);
    }
  }

  Future<void> reserveTable(String tableId, String customerName, DateTime reservationTime, {int partySize = 2}) async {
    final localDb = db;
    if (FeatureFlags.offlineFirstEnabled && localDb != null) {
      try {
        final existingLocal = await (localDb.select(localDb.localRestaurantTables)..where((t) => t.id.equals(tableId))).getSingleOrNull();
        final currentVer = existingLocal?.version ?? 1;
        final nextVer = currentVer + 1;

        await (localDb.update(localDb.localRestaurantTables)..where((t) => t.id.equals(tableId))).write(
          LocalRestaurantTablesCompanion(
            status: const Value('reserved'),
            version: Value(nextVer),
          ),
        );
        final opId = const Uuid().v7();
        await localDb.outboxDao.insertEntry(
          SyncOutboxCompanion(
            operationId: Value(opId),
            deviceId: const Value('POS-P1'),
            entityType: const Value('table'),
            entityId: Value(tableId),
            operationType: const Value('UPDATE'),
            baseVersion: Value(currentVer),
            schemaVersion: const Value(kCurrentOutboxPayloadVersion),
            dependencyOrder: const Value(3),
            status: const Value(SyncOutboxStatus.pending),
            payload: Value(jsonEncode({
              'id': tableId,
              'status': 'reserved',
              'reserved_customer_name': customerName,
              'reservation_time': reservationTime.toIso8601String(),
              'party_size': partySize,
            })),
            createdAt: Value(DateTime.now()),
          ),
        );
      } catch (_) {}
    }

    final updated = state.tables.map((table) {
      if (table.id == tableId) {
        return table.copyWith(
          status: TableStatus.reserved,
          reservedCustomerName: customerName,
          reservationTime: reservationTime,
        );
      }
      return table;
    }).toList();
    state = state.copyWith(tables: updated);

    try {
      await _tablesApiService.updateReservation(
        tableId,
        reservedCustomerName: customerName,
        reservationTime: reservationTime.toIso8601String(),
        partySize: partySize,
      );
      await loadTables();
    } catch (_) {}
  }

  void addWaitlistEntry(WaitlistEntry entry) {
    state = state.copyWith(waitlist: [...state.waitlist, entry]);
  }

  void removeWaitlistEntry(String id) {
    state = state.copyWith(waitlist: state.waitlist.where((w) => w.id != id).toList());
  }

  Future<void> addTable(RestaurantTable newTable) async {
    // 1. Immediately insert into in-memory state so frontend UI shows the table instantly
    final existingTables = state.tables.where((t) => t.id != newTable.id && t.name.toLowerCase() != newTable.name.toLowerCase()).toList();
    state = state.copyWith(tables: [...existingTables, newTable]);

    final localDb = db;
    if (FeatureFlags.offlineFirstEnabled && localDb != null) {
      try {
        await localDb.catalogDao.upsertRestaurantTables([
          LocalRestaurantTablesCompanion(
            id: Value(newTable.id),
            tableNumber: Value(newTable.tableNumber),
            name: Value(newTable.name),
            capacity: Value(newTable.capacity),
            status: Value(newTable.status.name),
          ),
        ]);
      } catch (_) {}
    }

    try {
      final res = await _tablesApiService.createTable({
        'table_number': newTable.tableNumber,
        'name': newTable.name,
        'capacity': newTable.capacity,
        'section': newTable.section,
        'status': newTable.status.name,
      });
      final created = RestaurantTable.fromBackendJson(res);
      // Replace with confirmed backend database record
      final updatedList = state.tables.map((t) => (t.id == newTable.id || t.name.toLowerCase() == created.name.toLowerCase()) ? created : t).toList();
      state = state.copyWith(tables: updatedList);
      await loadTables();
    } catch (e) {
      await loadTables();
      rethrow;
    }
  }

  Future<void> deleteTable(String tableId) async {
    try {
      await _tablesApiService.deleteTable(tableId);
      await loadTables();
    } catch (e) {
      state = state.copyWith(
        tables: state.tables.where((t) => t.id != tableId).toList(),
      );
    }
  }

  Future<void> addZone(String zoneName) async {
    final trimmed = zoneName.trim();
    if (trimmed.isEmpty) return;
    try {
      await _tablesApiService.createZone(trimmed);
      await loadTables();
    } catch (e) {
      if (!state.zones.contains(trimmed)) {
        state = state.copyWith(zones: [...state.zones, trimmed]);
      }
    }
  }

  Future<void> deleteSection(String sectionName) async {
    try {
      await _tablesApiService.deleteZone(sectionName);
    } catch (e) {
      final tablesInSec = state.tables.where((t) => t.section.toLowerCase() == sectionName.toLowerCase()).toList();
      for (final t in tablesInSec) {
        try {
          await _tablesApiService.deleteTable(t.id);
        } catch (_) {}
      }
    }
    if (state.selectedSection.toLowerCase() == sectionName.toLowerCase()) {
      state = state.copyWith(selectedSection: 'All');
    }
    await loadTables();
  }
}

final tableProvider = StateNotifierProvider<TableNotifier, TableState>((ref) {
  final tablesApi = ref.read(tablesApiServiceProvider);
  final db = FeatureFlags.offlineFirstEnabled ? ref.watch(appDatabaseProvider) : null;
  return TableNotifier(tablesApiService: tablesApi, db: db);
});
