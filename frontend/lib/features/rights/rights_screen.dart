import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/app_colors.dart';
import '../../data/role_rights_repository.dart';
import '../../domain/models/role_rights_model.dart';
import '../../domain/models/user_role.dart';

class RightsScreen extends ConsumerStatefulWidget {
  const RightsScreen({super.key});

  @override
  ConsumerState<RightsScreen> createState() => _RightsScreenState();
}

class _RightsScreenState extends ConsumerState<RightsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(roleRightsProvider.notifier).loadPermissions();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rightsState = ref.watch(roleRightsProvider);
    final rightsNotifier = ref.read(roleRightsProvider.notifier);

    // Group permissions by module
    final Map<String, List<ModulePermission>> groupedPermissions = {};
    for (final p in rightsState.currentPermissions) {
      groupedPermissions.putIfAbsent(p.moduleName, () => []).add(p);
    }

    return Container(
      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8F9FA),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row (Matching Tables Screen Design)
          // Header Row (Responsive Layout)
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 1100;
              final headerLeft = Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryRed.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.admin_panel_settings_rounded,
                      color: AppColors.primaryRed,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${rightsState.selectedRole.displayName.toUpperCase()} PERMISSIONS & ACCESS PORTAL',
                          style: TextStyle(
                            color: isDark ? Colors.white : AppColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Configure allowed modules and feature access permissions for store personnel',
                          style: TextStyle(
                            color: isDark ? const Color(0xFF94A3B8) : AppColors.textMuted,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              );

              final presetButtons = Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.primaryRed),
                      foregroundColor: AppColors.primaryRed,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => rightsNotifier.applyPreset('STRICT'),
                    icon: const Icon(Icons.shield_rounded, size: 15),
                    label: const Text('STRICT PRESET', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.success),
                      foregroundColor: AppColors.success,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => rightsNotifier.applyPreset('FULL'),
                    icon: const Icon(Icons.check_circle_rounded, size: 15),
                    label: const Text('GRANT ALL ACCESS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? const Color(0xFF334155) : AppColors.lightGray,
                      foregroundColor: isDark ? Colors.white : AppColors.textPrimary,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: isDark ? const Color(0xFF475569) : AppColors.borderGray),
                      ),
                    ),
                    onPressed: () => rightsNotifier.applyPreset('DEFAULT'),
                    icon: const Icon(Icons.refresh_rounded, size: 15),
                    label: const Text('RESET DEFAULTS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                  ),
                ],
              );

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    headerLeft,
                    const SizedBox(height: 12),
                    presetButtons,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: headerLeft),
                  const SizedBox(width: 12),
                  presetButtons,
                ],
              );
            },
          ),

          const SizedBox(height: 14),

          // Role Selector Tabs & KPI Stat Cards Row
          LayoutBuilder(
            builder: (context, constraints) {
              final isTight = constraints.maxWidth < 1050;
              final roleTabs = Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : AppColors.borderGray),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _roleTabChip(context, ref, UserRole.manager, 'MANAGER', rightsState.selectedRole, isDark),
                    _roleTabChip(context, ref, UserRole.cashier, 'CASHIER', rightsState.selectedRole, isDark),
                  ],
                ),
              );

              if (isTight) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    roleTabs,
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _buildMiniStatCard(
                            'GRANTED RIGHTS',
                            '${rightsState.grantedCount} Enabled',
                            'Active Access Granted',
                            Icons.verified_user_rounded,
                            AppColors.success,
                            isDark,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildMiniStatCard(
                            'RESTRICTED ACTIONS',
                            '${rightsState.restrictedCount} Blocked',
                            'Owner Auth Required',
                            Icons.block_rounded,
                            AppColors.danger,
                            isDark,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildMiniStatCard(
                            'SENSITIVE RIGHTS',
                            '${rightsState.sensitiveCount} Active',
                            'High-Risk Permissions',
                            Icons.key_rounded,
                            AppColors.gold,
                            isDark,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  roleTabs,
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMiniStatCard(
                      'GRANTED RIGHTS',
                      '${rightsState.grantedCount} Enabled',
                      'Active Access Granted',
                      Icons.verified_user_rounded,
                      AppColors.success,
                      isDark,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMiniStatCard(
                      'RESTRICTED ACTIONS',
                      '${rightsState.restrictedCount} Blocked',
                      'Owner Auth Required',
                      Icons.block_rounded,
                      AppColors.danger,
                      isDark,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMiniStatCard(
                      'SENSITIVE RIGHTS',
                      '${rightsState.sensitiveCount} Active',
                      'High-Risk Permissions',
                      Icons.key_rounded,
                      AppColors.gold,
                      isDark,
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 14),

          Text(
            'MODULE PERMISSION MATRIX & OWNER ACCESS TOGGLES (${groupedPermissions.keys.length} MODULES)',
            style: TextStyle(
              color: isDark ? Colors.white70 : AppColors.primaryRed,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),

          // Modules Rights Grid / List
          Expanded(
            child: ListView.builder(
              itemCount: groupedPermissions.keys.length,
              itemBuilder: (context, index) {
                final moduleName = groupedPermissions.keys.elementAt(index);
                final permissions = groupedPermissions[moduleName]!;
                final grantedCount = permissions.where((p) => p.isGranted).length;

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : AppColors.borderGray),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Module Header Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryRed.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Icon(_getModuleIcon(moduleName), color: AppColors.primaryRed, size: 18),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        moduleName,
                                        style: TextStyle(
                                          color: isDark ? Colors.white : AppColors.textPrimary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        '$grantedCount of ${permissions.length} actions authorized for ${rightsState.selectedRole.displayName}',
                                        style: TextStyle(
                                          color: isDark ? const Color(0xFF94A3B8) : AppColors.textMuted,
                                          fontSize: 11,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: grantedCount == permissions.length
                                  ? AppColors.success.withValues(alpha: 0.15)
                                  : (grantedCount == 0
                                      ? AppColors.danger.withValues(alpha: 0.15)
                                      : AppColors.gold.withValues(alpha: 0.15)),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: grantedCount == permissions.length
                                    ? AppColors.success
                                    : (grantedCount == 0 ? AppColors.danger : AppColors.gold),
                              ),
                            ),
                            child: Text(
                              grantedCount == permissions.length
                                  ? 'FULL ACCESS'
                                  : (grantedCount == 0 ? 'NO ACCESS' : 'PARTIAL ($grantedCount/${permissions.length})'),
                              style: TextStyle(
                                color: grantedCount == permissions.length
                                    ? AppColors.success
                                    : (grantedCount == 0 ? AppColors.danger : AppColors.gold),
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ),

                      Divider(height: 18, color: isDark ? const Color(0xFF334155) : AppColors.borderGray),

                      // Action Toggles Grid
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: permissions.map((p) {
                          return SizedBox(
                            width: 330,
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: p.isGranted
                                    ? (isDark ? const Color(0xFF0F172A) : Colors.white)
                                    : (isDark ? const Color(0xFF0F172A).withValues(alpha: 0.5) : AppColors.lightGray),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: p.isGranted
                                      ? (p.isSensitive ? AppColors.gold : AppColors.success.withValues(alpha: 0.5))
                                      : (isDark ? const Color(0xFF334155) : AppColors.borderGray),
                                  width: p.isGranted ? 1.5 : 1.0,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                p.actionName,
                                                style: TextStyle(
                                                  color: p.isGranted
                                                      ? (isDark ? Colors.white : AppColors.textPrimary)
                                                      : (isDark ? const Color(0xFF64748B) : AppColors.textMuted),
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                            if (p.isSensitive)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                decoration: BoxDecoration(
                                                  color: AppColors.gold.withValues(alpha: 0.15),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: const Text(
                                                  'SENSITIVE',
                                                  style: TextStyle(color: AppColors.gold, fontSize: 8, fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          p.description,
                                          style: TextStyle(
                                            color: isDark ? const Color(0xFF94A3B8) : AppColors.textMuted,
                                            fontSize: 10,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Switch(
                                    value: p.isGranted,
                                    activeThumbColor: AppColors.success,
                                    onChanged: (val) {
                                      rightsNotifier.togglePermission(p.id);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStatCard(
    String label,
    String value,
    String sub,
    IconData icon,
    Color color,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? const Color(0xFF334155) : AppColors.borderGray),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: isDark ? const Color(0xFF94A3B8) : AppColors.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    color: isDark ? Colors.white : AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  sub,
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _roleTabChip(BuildContext context, WidgetRef ref, UserRole role, String label, UserRole activeRole, bool isDark) {
    final isSelected = activeRole == role;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: ChoiceChip(
        showCheckmark: false,
        label: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? Colors.white
                : (isDark ? const Color(0xFFCBD5E1) : AppColors.textSecondary),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 11,
          ),
        ),
        selected: isSelected,
        selectedColor: AppColors.primaryRed,
        backgroundColor: isDark ? const Color(0xFF334155) : AppColors.lightGray,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        onSelected: (selected) {
          if (selected) {
            ref.read(roleRightsProvider.notifier).selectRole(role);
          }
        },
      ),
    );
  }

  IconData _getModuleIcon(String moduleName) {
    switch (moduleName) {
      case 'Tables':
        return Icons.table_restaurant_rounded;
      case 'Menu Catalog':
        return Icons.restaurant_menu_rounded;
      case 'Delivery Tracking':
        return Icons.two_wheeler_rounded;
      case 'Stock Catalog':
        return Icons.inventory_2_rounded;
      case 'Stock In / Out':
        return Icons.compare_arrows_rounded;
      case 'Users':
        return Icons.people_alt_rounded;
      case 'Staff Permissions':
      case 'Manager Rights':
        return Icons.admin_panel_settings_rounded;
      case 'Reports':
        return Icons.analytics_rounded;
      default:
        return Icons.admin_panel_settings_rounded;
    }
  }
}
