import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'config/app_theme.dart';
import 'config/router.dart';

import 'config/feature_flags.dart';
import 'core/sync/sync_providers.dart';
import 'core/network/realtime_socket_service.dart';
import 'services/sync/realtime_sync_manager.dart';
import 'features/updater/auto_update_controller.dart';

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

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
