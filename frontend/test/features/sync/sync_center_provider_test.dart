import 'package:flutter_test/flutter_test.dart';
import 'package:hungry_howies_pos/core/network/api_client.dart';
import 'package:hungry_howies_pos/core/network/realtime_socket_service.dart';
import 'package:hungry_howies_pos/core/sync/connectivity_notifier.dart';
import 'package:hungry_howies_pos/data/role_rights_repository.dart';
import 'package:hungry_howies_pos/domain/models/user_role.dart';
import 'package:hungry_howies_pos/features/sync/sync_center_provider.dart';
import 'package:hungry_howies_pos/services/api/sync_api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SYNC-039: SyncCenterNotifier Drift Guard Tests', () {
    test('instantiates cleanly without AppDatabase or SyncBackgroundWorker when flag is OFF', () async {
      final apiClient = ApiClient(baseUrl: 'http://localhost:3000');
      final connectivity = ConnectivityNotifier(
        apiClient: apiClient,
        probeTimeout: const Duration(milliseconds: 100),
      );
      final socket = RealtimeSocketService();
      final syncApi = SyncApiService(apiClient: apiClient);

      final notifier = SyncCenterNotifier(
        db: null,
        worker: null,
        syncApi: syncApi,
        connectivity: connectivity,
        socket: socket,
        roleRights: const RoleRightsState(managerPermissions: [], cashierPermissions: []),
        userRole: UserRole.owner,
      );

      expect(notifier.state.databaseConnected, isFalse);

      await Future.delayed(const Duration(milliseconds: 50));
      expect(notifier.state.isLoading, isFalse);

      notifier.dispose();
      connectivity.dispose();
      socket.dispose();
    });
  });
}
