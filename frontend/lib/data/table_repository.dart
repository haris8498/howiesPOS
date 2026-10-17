import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  TableNotifier({TablesApiService? tablesApiService})
      : _tablesApiService = tablesApiService ?? TablesApiService(),
        super(const TableState(
          tables: [],
        )) {
    loadTables();
  }

  Future<void> loadTables() async {
    state = state.copyWith(isLoading: true);
    try {
      final jsonList = await _tablesApiService.listTables();
      final tables = jsonList.map((j) => RestaurantTable.fromBackendJson(j)).toList();

      // Load distinct zones from backend floor_zones table
      List<String> zonesList = [];
      try {
        final zoneJson = await _tablesApiService.listZones();
        if (zoneJson.isNotEmpty) {
          zonesList = zoneJson.map((z) => z['name']?.toString() ?? '').where((n) => n.isNotEmpty).toList();
        }
      } catch (_) {}

      if (zonesList.isEmpty) {
        final dynamicZones = tables.map((t) => t.section).where((s) => s.isNotEmpty).toSet();
        zonesList = {'Hall', 'Family Hall', 'Office', ...dynamicZones}.toList();
      }

      state = state.copyWith(tables: tables, zones: zonesList, isLoading: false);
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  void setSection(String section) {
    state = state.copyWith(selectedSection: section);
  }

  Future<void> updateTableStatus(String tableId, TableStatus newStatus, {String? activeOrderId}) async {
    try {
      await _tablesApiService.updateTableStatus(
        tableId,
        status: newStatus.name,
        activeOrderId: newStatus == TableStatus.occupied ? activeOrderId : null,
      );
      await loadTables();
    } catch (_) {
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
    }
  }

  Future<void> updateTableBillAndStatus(
    String tableId,
    double billAmount,
    TableStatus newStatus, {
    String? activeOrderId,
    String? activeOrderNumber,
    List<Map<String, dynamic>>? orderItems,
  }) async {
    try {
      await _tablesApiService.updateTableStatus(
        tableId,
        status: newStatus.name,
        currentBillAmount: billAmount,
        activeOrderId: activeOrderId,
      );
    } catch (_) {}

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
    try {
      await _tablesApiService.releaseTable(tableId);
      await loadTables();
    } catch (_) {
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
    }
  }

  Future<void> transferTable(String fromTableId, String toTableId) async {
    try {
      await _tablesApiService.transferTable(fromTableId: fromTableId, toTableId: toTableId);
      await loadTables();
    } catch (_) {
      final fromTable = state.tables.firstWhere((t) => t.id == fromTableId);
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
    try {
      await _tablesApiService.updateReservation(
        tableId,
        reservedCustomerName: customerName,
        reservationTime: reservationTime.toIso8601String(),
        partySize: partySize,
      );
      await loadTables();
    } catch (_) {
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
    }
  }

  void addWaitlistEntry(WaitlistEntry entry) {
    state = state.copyWith(waitlist: [...state.waitlist, entry]);
  }

  void removeWaitlistEntry(String id) {
    state = state.copyWith(waitlist: state.waitlist.where((w) => w.id != id).toList());
  }

  Future<void> addTable(RestaurantTable newTable) async {
    try {
      await _tablesApiService.createTable({
        'table_number': newTable.tableNumber,
        'name': newTable.name,
        'capacity': newTable.capacity,
        'section': newTable.section,
        'status': newTable.status.name,
      });
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
  return TableNotifier(tablesApiService: tablesApi);
});
