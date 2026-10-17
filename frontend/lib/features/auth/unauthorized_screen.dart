import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/app_colors.dart';
import '../../data/auth_repository.dart';
import '../../domain/models/user_role.dart';
import '../../shared/widgets/glass_card.dart';

class UnauthorizedScreen extends ConsumerWidget {
  const UnauthorizedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final role = authState.currentUser.role;

    String redirectPath = '/sales/tables';
    if (role == UserRole.owner) redirectPath = '/owner/tables';
    if (role == UserRole.manager) redirectPath = '/manager/dashboard';

    return Scaffold(
      backgroundColor: AppColors.offWhite,
      body: Center(
        child: Container(
          width: 440,
          padding: const EdgeInsets.all(24),
          child: GlassCard(
            padding: const EdgeInsets.all(36),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: AppColors.offWhite,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.gpp_maybe_rounded, color: AppColors.danger, size: 56),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Access Restricted',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'You don\'t have permission to access this section.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: const Text('Back to Dashboard'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryRed,
                    minimumSize: const Size.fromHeight(44),
                  ),
                  onPressed: () => context.go(redirectPath),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
