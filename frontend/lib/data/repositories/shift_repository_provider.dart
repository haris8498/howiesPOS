import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/sync/sync_providers.dart';
import '../../domain/repositories/shift_repository.dart';
import 'drift_offline_first_shift_repository.dart';

/// Drift Offline-First Shift Repository provider (Spec §5.2, §7.3, §21 Decision 2).
final driftOfflineFirstShiftRepositoryProvider =
    Provider<DriftOfflineFirstShiftRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return DriftOfflineFirstShiftRepository(
    db: db,
    deviceId: 'POS-P1',
  );
});

/// Shift Repository Provider.
final shiftRepositoryProvider = Provider<IShiftRepository>((ref) {
  return ref.watch(driftOfflineFirstShiftRepositoryProvider);
});
