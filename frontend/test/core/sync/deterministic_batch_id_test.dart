import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hungry_howies_pos/core/database/app_database.dart';
import 'package:hungry_howies_pos/core/sync/sync_background_worker.dart';

void main() {
  group('SYNC-024: Deterministic Batch ID Tests', () {
    test('computeBatchId is deterministic and order-independent', () {
      final entry1 = SyncOutboxEntry(
        id: 1,
        operationId: '018f2d50-7111-7a2e-8392-111111111111',
        deviceId: 'POS-01',
        entityType: 'order',
        entityId: '018f2d50-7111-7a2e-8392-aaaaaaaaaaaa',
        operationType: 'INSERT',
        payload: '{}',
        dependencyOrder: 1,
        baseVersion: 1,
        status: 'PENDING',
        retryCount: 0,
        createdAt: DateTime.now(),
        schemaVersion: 1,
      );

      final entry2 = SyncOutboxEntry(
        id: 2,
        operationId: '018f2d50-7222-7a2e-8392-222222222222',
        deviceId: 'POS-01',
        entityType: 'order',
        entityId: '018f2d50-7222-7a2e-8392-bbbbbbbbbbbb',
        operationType: 'INSERT',
        payload: '{}',
        dependencyOrder: 2,
        baseVersion: 1,
        status: 'PENDING',
        retryCount: 0,
        createdAt: DateTime.now(),
        schemaVersion: 1,
      );

      final batchIdForward = SyncBackgroundWorker.computeBatchId([entry1, entry2]);
      final batchIdReverse = SyncBackgroundWorker.computeBatchId([entry2, entry1]);

      expect(batchIdForward, equals(batchIdReverse));

      // SHA-256 of sorted opIds
      final expectedSha = sha256
          .convert(utf8.encode(
              '018f2d50-7111-7a2e-8392-111111111111:018f2d50-7222-7a2e-8392-222222222222'))
          .toString();
      expect(batchIdForward, equals(expectedSha));
    });
  });
}
