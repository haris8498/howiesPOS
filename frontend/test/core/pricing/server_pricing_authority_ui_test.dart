import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hungry_howies_pos/core/security/offline_auth_service.dart';
import 'package:hungry_howies_pos/core/security/offline_credential_store.dart';
import 'package:hungry_howies_pos/core/security/local_credential_verifier.dart';
import 'package:hungry_howies_pos/core/sync/pricing_reconciliation_provider.dart';
import 'package:hungry_howies_pos/domain/models/order_model.dart';
import 'package:hungry_howies_pos/domain/models/menu_item.dart';
import 'package:hungry_howies_pos/shared/widgets/manager_approval_dialog.dart';

class FakeOfflineAuthService extends OfflineAuthService {
  final Map<String, OfflineCredential> _mockUsers = {};
  final Map<String, String> _passwords = {};

  FakeOfflineAuthService() : super(store: _FakeCredentialStore());

  void addMockUser({
    required String userId,
    required String username,
    required String role,
    required String password,
  }) {
    final cred = OfflineCredential(
      userId: userId,
      username: username,
      role: role,
      saltHex: '00112233445566778899aabbccddeeff',
      verifierHex: '00112233445566778899aabbccddeeff',
      params: const VerifierParams(),
      lastOnlineLoginAt: DateTime.now(),
    );
    _mockUsers[username.toLowerCase()] = cred;
    _mockUsers[userId.toLowerCase()] = cred;
    _passwords[username.toLowerCase()] = password;
    _passwords[userId.toLowerCase()] = password;
  }

  @override
  Future<OfflineAuthResult> verifyManagerCredential(
    String managerIdOrUsername,
    String credentialOrPin,
  ) async {
    final clean = managerIdOrUsername.trim().toLowerCase();
    if (!_mockUsers.containsKey(clean)) {
      return OfflineAuthResult.userNotFound(clean);
    }
    final cred = _mockUsers[clean]!;
    final role = cred.role.toLowerCase();
    if (role != 'manager' && role != 'owner' && role != 'superadmin' && role != 'admin') {
      return OfflineAuthResult.unauthorizedRole(cred.role);
    }
    if (_passwords[clean] != credentialOrPin) {
      return OfflineAuthResult.invalidCredentials(message: 'Invalid manager PIN or password.');
    }
    return OfflineAuthResult.success(cred);
  }
}

class _FakeCredentialStore implements OfflineCredentialStore {
  @override
  bool get isDpapiSupported => false;
  @override
  Future<bool> hasLegacyCacheKeys() async => false;
  @override
  Future<void> wipeAll() async {}
  @override
  Future<OfflineCredential?> getCredential(String idOrUsername) async => null;
  @override
  Future<List<OfflineCredential>> getAllCredentials() async => [];
  @override
  Future<void> saveCredential(OfflineCredential cred) async {}
  @override
  Future<void> removeCredential(String idOrUsername) async {}
  @override
  Future<void> clearAll() async {}
  @override
  Future<void> purgeLegacyCache() async {}
}

void main() {
  group('Decision D-03 / SYNC-016: Server Pricing Authority & Manager Approval Tests', () {
    test('ManagerApproval serializes to JSON and deserializes correctly', () {
      const approval = ManagerApproval(
        managerId: 'mgr-uuid-1',
        managerUsername: 'sarah_manager',
        deviceId: 'POS-01',
        approvedAt: '2026-10-27T12:00:00Z',
        reason: 'Customer Goodwill Discount',
      );

      final json = approval.toJson();
      expect(json['manager_id'], 'mgr-uuid-1');
      expect(json['manager_username'], 'sarah_manager');
      expect(json['device_id'], 'POS-01');
      expect(json['reason'], 'Customer Goodwill Discount');

      final fromJson = ManagerApproval.fromJson(json);
      expect(fromJson.managerId, approval.managerId);
      expect(fromJson.managerUsername, approval.managerUsername);
      expect(fromJson.deviceId, approval.deviceId);
      expect(fromJson.reason, approval.reason);
    });

    test('OrderModel attaches approvedByManagerId and managerApproval in toCreateOrderDto', () {
      const approval = ManagerApproval(
        managerId: 'mgr-uuid-1',
        managerUsername: 'sarah_manager',
        deviceId: 'POS-01',
        approvedAt: '2026-10-27T12:00:00Z',
        reason: 'VIP Customer',
      );

      final order = OrderModel(
        id: 'ord-uuid-101',
        orderNumber: 'P1-101',
        type: OrderType.takeaway,
        status: OrderStatus.accepted,
        createdAt: DateTime.now(),
        items: [
          OrderItem(
            id: 'item-1',
            item: const MenuItem(id: 'm1', name: 'Pepperoni Pizza', category: 'Pizza', description: '', basePrice: 1500.0, imageUrl: ''),
            quantity: 1,
            selectedSize: 'Large',
            backendUnitPrice: 1500.0,
          ),
        ],
        subtotalOverride: 1500.0,
        discountPercentage: 10.0,
        discountAmount: 150.0,
        grandTotalOverride: 1350.0,
        approvedByManagerId: approval.managerId,
        managerApproval: approval.toJson(),
      );

      final dto = order.toCreateOrderDto();
      expect(dto['approved_by_manager_id'], 'mgr-uuid-1');
      expect(dto['manager_approval'], isNotNull);
      expect(dto['manager_approval']['manager_id'], 'mgr-uuid-1');
      expect(dto['manager_approval']['reason'], 'VIP Customer');
      expect(dto['discount_percentage'], 10.0);
      expect(dto['discount_amount'], 150.0);
      expect(dto['grand_total'], 1350.0);
    });

    test('PricingReconciliationNotifier manages notifications and EventBus integration', () {
      final notifier = PricingReconciliationNotifier();

      expect(notifier.state, isEmpty);

      notifier.notify(
        orderId: 'ord-101',
        orderNumber: 'P1-101',
        clientTotal: 1000.0,
        serverTotal: 1200.0,
        pricingStatus: 'MISMATCH',
        difference: 200.0,
      );

      expect(notifier.state.length, 1);
      final notif = notifier.state.first;
      expect(notif.orderId, 'ord-101');
      expect(notif.pricingStatus, 'MISMATCH');
      expect(notif.difference, 200.0);

      // Duplicate prevention
      notifier.notify(
        orderId: 'ord-101',
        orderNumber: 'P1-101',
        clientTotal: 1000.0,
        serverTotal: 1200.0,
        pricingStatus: 'MISMATCH',
        difference: 200.0,
      );
      expect(notifier.state.length, 1);

      // Dismiss
      notifier.dismiss(notif);
      expect(notifier.state, isEmpty);
    });

    testWidgets('ManagerApprovalDialog validates manager credentials successfully', (tester) async {
      final fakeAuth = FakeOfflineAuthService();
      fakeAuth.addMockUser(
        userId: 'mgr-007',
        username: 'alice_manager',
        role: 'MANAGER',
        password: 'pin-1234',
      );

      ManagerApproval? resultApproval;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  resultApproval = await ManagerApprovalDialog.show(
                    context,
                    offlineAuthService: fakeAuth,
                    deviceId: 'POS-P1',
                    actionTitle: 'Takeaway Discount (10%)',
                    discountAmount: 150.0,
                    discountPercentage: 10.0,
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      // Open dialog
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Manager Approval Required'), findsOneWidget);
      expect(find.text('Takeaway Discount (10%)'), findsOneWidget);

      // Enter manager credentials
      await tester.enterText(find.byType(TextField).at(0), 'alice_manager');
      await tester.enterText(find.byType(TextField).at(1), 'pin-1234');

      // Click Verify & Approve
      await tester.tap(find.text('Verify & Approve'));
      await tester.pumpAndSettle();

      expect(resultApproval, isNotNull);
      expect(resultApproval!.managerId, 'mgr-007');
      expect(resultApproval!.managerUsername, 'alice_manager');
      expect(resultApproval!.deviceId, 'POS-P1');
    });

    testWidgets('ManagerApprovalDialog rejects cashier credentials', (tester) async {
      final fakeAuth = FakeOfflineAuthService();
      fakeAuth.addMockUser(
        userId: 'csh-001',
        username: 'bob_cashier',
        role: 'CASHIER',
        password: 'pin-9999',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => ManagerApprovalDialog.show(
                  context,
                  offlineAuthService: fakeAuth,
                ),
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), 'bob_cashier');
      await tester.enterText(find.byType(TextField).at(1), 'pin-9999');

      await tester.tap(find.text('Verify & Approve'));
      await tester.pumpAndSettle();

      expect(find.text('Role "CASHIER" is not authorized for manager approval.'), findsOneWidget);
    });
  });
}
