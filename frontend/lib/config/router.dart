import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../services/sync/global_sync_controller.dart';
import '../data/auth_repository.dart';
import '../domain/models/user_role.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/unauthorized_screen.dart';
import '../features/customers/customers_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/delivery/delivery_screen.dart';
import '../features/expenses/expenses_screen.dart';
import '../features/kitchen/kitchen_screen.dart';
import '../features/menu/menu_screen.dart';
import '../features/online_orders/online_orders_screen.dart';
import '../features/passwords/password_management_screen.dart';
import '../features/pos/pos_screen.dart';
import '../features/reports/reports_screen.dart';
import '../features/rights/rights_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/staff/staff_screen.dart';
import '../features/stock/stock_in_out_screen.dart';
import '../features/stock/stock_screen.dart';
import '../features/tables/tables_screen.dart';
import '../features/takeaway/takeaway_screen.dart';
import '../features/daily_calculation/daily_calculation_screen.dart';
import '../features/daily_calculation/daily_calculation_admin_screen.dart';
import '../features/daily_calculation/widgets/starting_cash_dialog.dart';
import '../data/daily_calculation_repository.dart';
import '../features/sync/data_sync_screen.dart';
import '../shared/widgets/navigation_sidebar.dart';
import '../shared/widgets/cashier_top_navigation_bar.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
    refreshListenable: _RiverpodListenable(ref, authProvider),
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final isLoggedIn = authState.isAuthenticated;
      final location = state.matchedLocation;
      final role = authState.currentUser.role;

      // 1. Unauthenticated redirect to /login
      if (!isLoggedIn && location != '/login') {
        return '/login';
      }

      // 2. Authenticated user visiting /login -> redirect to role home
      if (isLoggedIn && location == '/login') {
        switch (role) {
          case UserRole.owner:
            return '/owner/tables';
          case UserRole.manager:
            return '/manager/dashboard';
          case UserRole.cashier:
            return '/sales/tables';
        }
      }

      // 3. Strict Permission Guards for Scoped Portals
      if (isLoggedIn) {
        if (location.startsWith('/owner') && role != UserRole.owner) {
          return '/unauthorized';
        }
        if (location.startsWith('/manager') && role != UserRole.owner && role != UserRole.manager) {
          return '/unauthorized';
        }
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) => _noAnimationPage(const LoginScreen(), state),
      ),
      GoRoute(
        path: '/unauthorized',
        pageBuilder: (context, state) => _noAnimationPage(const UnauthorizedScreen(), state),
      ),
      GoRoute(
        path: '/sync',
        redirect: (context, state) {
          final authState = ref.read(authProvider);
          return switch (authState.currentUser.role) {
            UserRole.owner => '/owner/data-sync',
            UserRole.manager => '/manager/data-sync',
            UserRole.cashier => '/sales/data-sync',
          };
        },
      ),

      // =========================================================
      // OWNER PORTAL ROUTES (/owner/...)
      // =========================================================
      ShellRoute(
        builder: (context, state, child) => _buildPortalShell(context, state, child),
        routes: [
          GoRoute(path: '/owner/dashboard', pageBuilder: (context, state) => _noAnimationPage(const DashboardScreen(), state)),
          GoRoute(path: '/owner/online-orders', pageBuilder: (context, state) => _noAnimationPage(const OnlineOrdersScreen(), state)),
          GoRoute(path: '/owner/sales', pageBuilder: (context, state) => _noAnimationPage(const PosScreen(), state)),
          GoRoute(path: '/owner/pos', pageBuilder: (context, state) => _noAnimationPage(const PosScreen(), state)),
          GoRoute(path: '/owner/tables', pageBuilder: (context, state) => _noAnimationPage(const TablesScreen(), state)),
          GoRoute(path: '/owner/takeaway', pageBuilder: (context, state) => _noAnimationPage(const TakeawayScreen(), state)),
          GoRoute(path: '/owner/kitchen', pageBuilder: (context, state) => _noAnimationPage(const KitchenScreen(), state)),
          GoRoute(path: '/owner/inventory', pageBuilder: (context, state) => _noAnimationPage(const StockScreen(), state)),
          GoRoute(path: '/owner/stock', pageBuilder: (context, state) => _noAnimationPage(const StockScreen(), state)),
          GoRoute(path: '/owner/stock-in-out', pageBuilder: (context, state) => _noAnimationPage(const StockInOutScreen(), state)),
          GoRoute(path: '/owner/menu', pageBuilder: (context, state) => _noAnimationPage(const MenuScreen(), state)),
          GoRoute(path: '/owner/customers', pageBuilder: (context, state) => _noAnimationPage(const CustomersScreen(), state)),
          GoRoute(path: '/owner/staff', pageBuilder: (context, state) => _noAnimationPage(const StaffScreen(), state)),
          GoRoute(path: '/owner/users', pageBuilder: (context, state) => _noAnimationPage(const StaffScreen(), state)),
          GoRoute(path: '/owner/passwords', pageBuilder: (context, state) => _noAnimationPage(const PasswordManagementScreen(), state)),
          GoRoute(path: '/owner/rights', pageBuilder: (context, state) => _noAnimationPage(const RightsScreen(), state)),
          GoRoute(path: '/owner/expenses', pageBuilder: (context, state) => _noAnimationPage(const ExpensesScreen(), state)),
          GoRoute(path: '/owner/daily-calculation', pageBuilder: (context, state) => _noAnimationPage(const DailyCalculationAdminScreen(), state)),
          GoRoute(path: '/owner/delivery', pageBuilder: (context, state) => _noAnimationPage(const DeliveryScreen(), state)),
          GoRoute(path: '/owner/reports', pageBuilder: (context, state) => _noAnimationPage(const ReportsScreen(), state)),
          GoRoute(path: '/owner/data-sync', pageBuilder: (context, state) => _noAnimationPage(const DataSyncScreen(), state)),
          GoRoute(path: '/owner/settings', pageBuilder: (context, state) => _noAnimationPage(const SettingsScreen(), state)),
        ],
      ),

      // =========================================================
      // MANAGER PORTAL ROUTES (/manager/...)
      // =========================================================
      ShellRoute(
        builder: (context, state, child) => _buildPortalShell(context, state, child),
        routes: [
          GoRoute(path: '/manager/dashboard', pageBuilder: (context, state) => _noAnimationPage(const DashboardScreen(), state)),
          GoRoute(path: '/manager/online-orders', pageBuilder: (context, state) => _noAnimationPage(const OnlineOrdersScreen(), state)),
          GoRoute(path: '/manager/pos', pageBuilder: (context, state) => _noAnimationPage(const PosScreen(), state)),
          GoRoute(path: '/manager/tables', pageBuilder: (context, state) => _noAnimationPage(const TablesScreen(), state)),
          GoRoute(path: '/manager/takeaway', pageBuilder: (context, state) => _noAnimationPage(const TakeawayScreen(), state)),
          GoRoute(path: '/manager/kitchen', pageBuilder: (context, state) => _noAnimationPage(const KitchenScreen(), state)),
          GoRoute(path: '/manager/inventory', pageBuilder: (context, state) => _noAnimationPage(const StockScreen(), state)),
          GoRoute(path: '/manager/stock', pageBuilder: (context, state) => _noAnimationPage(const StockScreen(), state)),
          GoRoute(path: '/manager/stock-in-out', pageBuilder: (context, state) => _noAnimationPage(const StockInOutScreen(), state)),
          GoRoute(path: '/manager/menu', pageBuilder: (context, state) => _noAnimationPage(const MenuScreen(), state)),
          GoRoute(path: '/manager/customers', pageBuilder: (context, state) => _noAnimationPage(const CustomersScreen(), state)),
          GoRoute(path: '/manager/staff', pageBuilder: (context, state) => _noAnimationPage(const StaffScreen(), state)),
          GoRoute(path: '/manager/users', pageBuilder: (context, state) => _noAnimationPage(const StaffScreen(), state)),
          GoRoute(path: '/manager/passwords', pageBuilder: (context, state) => _noAnimationPage(const PasswordManagementScreen(), state)),
          GoRoute(path: '/manager/rights', pageBuilder: (context, state) => _noAnimationPage(const RightsScreen(), state)),
          GoRoute(path: '/manager/expenses', pageBuilder: (context, state) => _noAnimationPage(const ExpensesScreen(), state)),
          GoRoute(path: '/manager/daily-calculation', pageBuilder: (context, state) => _noAnimationPage(const DailyCalculationAdminScreen(), state)),
          GoRoute(path: '/manager/delivery', pageBuilder: (context, state) => _noAnimationPage(const DeliveryScreen(), state)),
          GoRoute(path: '/manager/reports', pageBuilder: (context, state) => _noAnimationPage(const ReportsScreen(), state)),
          GoRoute(path: '/manager/data-sync', pageBuilder: (context, state) => _noAnimationPage(const DataSyncScreen(), state)),
        ],
      ),

      // =========================================================
      // SALES PERSON PORTAL ROUTES (/sales/...)
      // =========================================================
      ShellRoute(
        builder: (context, state, child) => _buildPortalShell(context, state, child),
        routes: [
          GoRoute(path: '/sales/dashboard', pageBuilder: (context, state) => _noAnimationPage(const DashboardScreen(), state)),
          GoRoute(path: '/sales/online-orders', pageBuilder: (context, state) => _noAnimationPage(const OnlineOrdersScreen(), state)),
          GoRoute(path: '/sales/pos', pageBuilder: (context, state) => _noAnimationPage(const PosScreen(), state)),
          GoRoute(path: '/sales/orders', pageBuilder: (context, state) => _noAnimationPage(const PosScreen(), state)),
          GoRoute(path: '/sales/tables', pageBuilder: (context, state) => _noAnimationPage(const TablesScreen(), state)),
          GoRoute(path: '/sales/takeaway', pageBuilder: (context, state) => _noAnimationPage(const TakeawayScreen(), state)),
          GoRoute(path: '/sales/kitchen', pageBuilder: (context, state) => _noAnimationPage(const KitchenScreen(), state)),
          GoRoute(path: '/sales/menu', pageBuilder: (context, state) => _noAnimationPage(const MenuScreen(), state)),
          GoRoute(path: '/sales/delivery', pageBuilder: (context, state) => _noAnimationPage(const DeliveryScreen(), state)),
          GoRoute(path: '/sales/inventory', pageBuilder: (context, state) => _noAnimationPage(const StockScreen(), state)),
          GoRoute(path: '/sales/stock', pageBuilder: (context, state) => _noAnimationPage(const StockScreen(), state)),
          GoRoute(path: '/sales/stock-in-out', pageBuilder: (context, state) => _noAnimationPage(const StockInOutScreen(), state)),
          GoRoute(path: '/sales/customers', pageBuilder: (context, state) => _noAnimationPage(const CustomersScreen(), state)),
          GoRoute(path: '/sales/staff', pageBuilder: (context, state) => _noAnimationPage(const StaffScreen(), state)),
          GoRoute(path: '/sales/users', pageBuilder: (context, state) => _noAnimationPage(const StaffScreen(), state)),
          GoRoute(path: '/sales/passwords', pageBuilder: (context, state) => _noAnimationPage(const PasswordManagementScreen(), state)),
          GoRoute(path: '/sales/rights', pageBuilder: (context, state) => _noAnimationPage(const RightsScreen(), state)),
          GoRoute(path: '/sales/expenses', pageBuilder: (context, state) => _noAnimationPage(const ExpensesScreen(), state)),
          GoRoute(path: '/sales/daily-calculation', pageBuilder: (context, state) => _noAnimationPage(const DailyCalculationScreen(), state)),
          GoRoute(path: '/sales/reports', pageBuilder: (context, state) => _noAnimationPage(const ReportsScreen(), state)),
          GoRoute(path: '/sales/data-sync', pageBuilder: (context, state) => _noAnimationPage(const DataSyncScreen(), state)),
        ],
      ),
    ],
  );
});

Page<dynamic> _noAnimationPage(Widget child, GoRouterState state) {
  return NoTransitionPage(
    key: state.pageKey,
    child: child,
  );
}

Widget _buildPortalShell(BuildContext context, GoRouterState state, Widget child) {
  return _PortalShellWrapper(
    currentRoute: state.matchedLocation,
    child: child,
  );
}

class _PortalShellWrapper extends ConsumerStatefulWidget {
  final String currentRoute;
  final Widget child;

  const _PortalShellWrapper({
    required this.currentRoute,
    required this.child,
  });

  @override
  ConsumerState<_PortalShellWrapper> createState() => _PortalShellWrapperState();
}

class _PortalShellWrapperState extends ConsumerState<_PortalShellWrapper> {
  bool _dialogChecked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _checkStartingCashGate();
      }
    });
  }

  @override
  void didUpdateWidget(covariant _PortalShellWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  Future<void> _checkStartingCashGate() async {
    if (_dialogChecked) return;
    _dialogChecked = true;

    final authState = ref.read(authProvider);
    if (!authState.isAuthenticated) return;
    // Strictly only prompt cashiers for starting cash float
    if (authState.currentUser.role != UserRole.cashier) return;

    final cashierId = authState.currentUser.id;
    final hasActive = await ref.read(dailyCalculationProvider.notifier).checkActiveSession(cashierId: cashierId);

    if (!hasActive && mounted) {
      StartingCashDialog.show(context, isDismissible: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isCashier = authState.currentUser.role == UserRole.cashier || widget.currentRoute.startsWith('/sales');

    final Widget shellScaffold = isCashier
        ? Scaffold(
            body: Column(
              children: [
                CashierTopNavigationBar(currentRoute: widget.currentRoute),
                Expanded(child: widget.child),
              ],
            ),
          )
        : Scaffold(
            body: Row(
              children: [
                NavigationSidebar(currentRoute: widget.currentRoute),
                Expanded(child: widget.child),
              ],
            ),
          );

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.f5): () {
          GlobalSyncController.syncAndRefreshAll(
            ref: ref,
            context: context,
            currentRoute: widget.currentRoute,
          );
        },
        const SingleActivator(LogicalKeyboardKey.keyR, control: true): () {
          GlobalSyncController.syncAndRefreshAll(
            ref: ref,
            context: context,
            currentRoute: widget.currentRoute,
          );
        },
      },
      child: Focus(
        autofocus: true,
        child: shellScaffold,
      ),
    );
  }
}

class _RiverpodListenable extends ChangeNotifier {
  _RiverpodListenable(this.ref, this.provider) {
    ref.listen(provider, (previous, next) => notifyListeners());
  }

  final Ref ref;
  final ProviderBase provider;
}
