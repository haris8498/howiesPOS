import 'dart:io';

void main() {
  final file = File('frontend/lib/data/table_repository.dart');
  String content = file.readAsStringSync();

  // Fix releaseTable block
  final oldRelease = '''  Future<void> releaseTable(String tableId) async {
    if (db != null) {
      try {
        await db!.outboxDao.enqueueMutation(
          SyncOutboxCompanion.insert(
            operationId: const Uuid().v7(),
            entityType: 'table',
            entityId: tableId,
            mutationType: SyncMutationType.update,
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
    }''';

  final newRelease = '''  Future<void> releaseTable(String tableId) async {
    final localDb = _db;
    if (FeatureFlags.offlineFirstEnabled && localDb != null) {
      try {
        await (localDb.update(localDb.localRestaurantTables)..where((t) => t.id.equals(tableId))).write(
          const LocalRestaurantTablesCompanion(
            status: Value('available'),
            activeOrderId: Value(null),
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
    }''';

  if (!content.contains(oldRelease)) {
    print('ERROR: oldRelease not found in table_repository.dart');
    return;
  }
  content = content.replaceFirst(oldRelease, newRelease);

  // Fix localDb promotion in loadTables, updateTableStatus, updateTableBillAndStatus
  content = content.replaceAll('if (FeatureFlags.offlineFirstEnabled && _db != null && tables.isNotEmpty) {\n        final companions = tables.map((t) => LocalRestaurantTablesCompanion(\n          id: Value(t.id),\n          tableNumber: Value(t.tableNumber),\n          name: Value(t.name),\n          capacity: Value(t.capacity),\n          status: Value(t.status.name),\n          activeOrderId: Value(t.activeOrderId),\n        )).toList();\n        await _db!.catalogDao.upsertRestaurantTables(companions);\n      }',
      '''final localDb = _db;
      if (FeatureFlags.offlineFirstEnabled && localDb != null && tables.isNotEmpty) {
        final companions = tables.map((t) => LocalRestaurantTablesCompanion(
          id: Value(t.id),
          tableNumber: Value(t.tableNumber),
          name: Value(t.name),
          capacity: Value(t.capacity),
          status: Value(t.status.name),
          activeOrderId: Value(t.activeOrderId),
        )).toList();
        await localDb.catalogDao.upsertRestaurantTables(companions);
      }''');

  content = content.replaceAll('if (FeatureFlags.offlineFirstEnabled && _db != null) {\n        final localTables = await _db!.catalogDao.getAllTables();',
      '''final localDb = _db;
      if (FeatureFlags.offlineFirstEnabled && localDb != null) {
        final localTables = await localDb.catalogDao.getAllTables();''');

  content = content.replaceAll('if (FeatureFlags.offlineFirstEnabled && _db != null) {\n      await (_db!.update(_db!.localRestaurantTables)..where((t) => t.id.equals(tableId))).write(\n        LocalRestaurantTablesCompanion(\n          status: Value(newStatus.name),\n          activeOrderId: Value(newStatus == TableStatus.occupied ? activeOrderId : null),\n        ),\n      );\n      final opId = const Uuid().v7();\n      await _db!.outboxDao.insertEntry(',
      '''final localDb = _db;
    if (FeatureFlags.offlineFirstEnabled && localDb != null) {
      await (localDb.update(localDb.localRestaurantTables)..where((t) => t.id.equals(tableId))).write(
        LocalRestaurantTablesCompanion(
          status: Value(newStatus.name),
          activeOrderId: Value(newStatus == TableStatus.occupied ? activeOrderId : null),
        ),
      );
      final opId = const Uuid().v7();
      await localDb.outboxDao.insertEntry(''');

  file.writeAsStringSync(content);
  print('Successfully patched table_repository.dart!');
}
