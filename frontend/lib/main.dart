import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'config/app_theme.dart';
import 'config/router.dart';

import 'config/feature_flags.dart';
import 'core/sync/outbox_drain_gate.dart';
import 'core/sync/sync_providers.dart';
import 'core/network/realtime_socket_service.dart';
import 'services/sync/realtime_sync_manager.dart';
import 'features/updater/auto_update_controller.dart';
import 'features/sync/outbox_drain_modal.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    const ProviderScope(
      child: HungryHowiesPosApp(),
    ),
  );
}

class HungryHowiesPosApp extends ConsumerStatefulWidget {
  const HungryHowiesPosApp({super.key});

  @override
  ConsumerState<HungryHowiesPosApp> createState() => _HungryHowiesPosAppState();
}

class _HungryHowiesPosAppState extends ConsumerState<HungryHowiesPosApp> {
  Timer? _updateTimer;
  bool _isDrainModalOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // Initialize Centralized Realtime Socket & State Synchronizer
      ref.read(realtimeSyncManagerProvider);
      ref.read(realtimeSocketServiceProvider).connect();

      if (FeatureFlags.offlineFirstEnabled) {
        ref.read(syncBackgroundWorkerProvider).start();
      }

      // Check OutboxDrainGate at startup (D-04 / SYNC-027)
      _checkDrainGateAtStartup();

      // Silent background update check after POS UI is rendered
      _updateTimer = Timer(const Duration(milliseconds: 600), () {
        if (mounted) {
          final navContext = rootNavigatorKey.currentContext ?? context;
          ref
              .read(autoUpdateControllerProvider.notifier)
              .startBackgroundCheck(navContext);
        }
      });
    });
  }

  void _checkDrainGateAtStartup() {
    final gate = ref.read(outboxDrainGateProvider);
    if (gate.shouldShowDrainModal && !_isDrainModalOpen) {
      _showDrainModal();
    }
  }

  void _showDrainModal() {
    final navContext = rootNavigatorKey.currentContext ?? context;
    _isDrainModalOpen = true;
    OutboxDrainModal.show(navContext).then((_) {
      _isDrainModalOpen = false;
    });
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Listen to OutboxDrainGate transitions at runtime (e.g. flag flipped or drain required)
    ref.listen<OutboxDrainGateState>(outboxDrainGateProvider, (prev, next) {
      if (next.shouldShowDrainModal &&
          !(prev?.shouldShowDrainModal ?? false) &&
          !_isDrainModalOpen) {
        _showDrainModal();
      }
    });

    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeProvider);

    return MaterialApp.router(
      title: 'Hungry Howie\'s Restaurant Management Portal',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      routerConfig: router,
    );
  }
}
