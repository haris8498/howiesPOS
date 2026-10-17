import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../config/app_colors.dart';
import '../../data/auth_repository.dart';
import '../widgets/status_badge.dart';

class TopAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;

  const TopAppBar({
    super.key,
    required this.title,
    this.actions,
  });

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final authNotifier = ref.read(authProvider.notifier);
    final nowString = DateFormat('EEE, MMM d • hh:mm a').format(DateTime.now());

    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(
          bottom: BorderSide(color: AppColors.borderGray, width: 1),
        ),
      ),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 14),
          const StatusBadge(
            label: 'Branch #402',
            color: AppColors.primaryRed,
            icon: Icons.storefront_rounded,
          ),
          const Spacer(),
          Row(
            children: [
              const Icon(Icons.access_time_rounded, color: AppColors.textSecondary, size: 14),
              const SizedBox(width: 5),
              Text(
                nowString,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 14),

              // User Info & Role Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.offWhite,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.borderGray),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppColors.primaryRed,
                      radius: 12,
                      child: Text(
                        authState.currentUser.fullName[0],
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      authState.currentUser.fullName,
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 6),
                    StatusBadge(
                      label: authState.currentUser.role.name.toUpperCase(),
                      color: AppColors.primaryRed,
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 10),

              // Logout Button
              OutlinedButton.icon(
                icon: const Icon(Icons.logout_rounded, color: AppColors.danger, size: 15),
                label: const Text('Logout', style: TextStyle(color: AppColors.danger, fontSize: 12, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.danger),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onPressed: () async {
                  await authNotifier.logout();
                  if (context.mounted) {
                    context.go('/login');
                  }
                },
              ),

              if (actions != null) for (final a in actions!) a,
            ],
          ),
        ],
      ),
    );
  }
}
