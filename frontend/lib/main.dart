import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'config/app_theme.dart';
import 'config/router.dart';

import 'config/feature_flags.dart';
import 'core/sync/sync_providers.dart';

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
  @override
  void initState() {
    super.initState();
    if (FeatureFlags.offlineFirstEnabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(syncBackgroundWorkerProvider).start();
        }
      });
    }
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
