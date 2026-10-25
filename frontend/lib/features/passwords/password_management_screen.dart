import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/app_colors.dart';
import '../../data/auth_repository.dart';
import '../../domain/models/user_role.dart';
import '../../shared/widgets/confirm_delete_dialog.dart';

typedef PasswordManagementScreen = StaffUsersScreen;

class StaffUsersScreen extends ConsumerStatefulWidget {
  const StaffUsersScreen({super.key});

  @override
  ConsumerState<StaffUsersScreen> createState() => _StaffUsersScreenState();
}

class _StaffUsersScreenState extends ConsumerState<StaffUsersScreen> {
  final Map<String, bool> _showPasswordMap = {};
  static final Map<String, String> _customPlainPasswords = {};
  String _searchQuery = '';
  UserRole? _filterRole;

  String _getPasswordDisplay(UserCredential user) {
    if (user.password.isNotEmpty && user.password != '••••••••') {
      return user.password;
    }
    final key = user.username.toLowerCase();
    if (_customPlainPasswords.containsKey(key)) {
      return _customPlainPasswords[key]!;
    }
    if (key == 'noman') return 'Noman123';
    if (user.role == UserRole.owner) return 'owner123';
    if (user.role == UserRole.manager) return 'manager123';
    return 'cashier123';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authProvider.notifier).loadUsersFromBackend();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authState = ref.watch(authProvider);
    final authNotifier = ref.read(authProvider.notifier);

    // Get list of staff users (fall back to default credentials if empty)
    final staffUsers = authState.staffUsers.isNotEmpty
        ? authState.staffUsers
        : authState.credentials.values.toList();

    // Filter users by search query and role filter
    final filteredUsers = staffUsers.where((u) {
      final matchesSearch = _searchQuery.isEmpty ||
          u.username.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          u.role.displayName.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesRole = _filterRole == null || u.role == _filterRole;
      return matchesSearch && matchesRole;
    }).toList();

    final ownerCount = staffUsers.where((u) => u.role == UserRole.owner).length;
    final managerCount = staffUsers.where((u) => u.role == UserRole.manager).length;
    final cashierCount = staffUsers.where((u) => u.role == UserRole.cashier).length;

    return Container(
      color: isDark ? const Color(0xFF0B1120) : const Color(0xFFF8FAFC),
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header with Title & "+ ADD USER" Button
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 650;
              final headerContent = Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: AppColors.brandGradient,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.manage_accounts_rounded, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'STAFF USERS',
                          style: TextStyle(
                            color: isDark ? Colors.white : AppColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Manage staff login usernames, user roles, and access passwords',
                          style: TextStyle(
                            color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
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

              final addButton = ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  elevation: 3,
                  shadowColor: AppColors.primaryRed.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                label: const Text(
                  'ADD STAFF USER',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, letterSpacing: 0.3),
                ),
                onPressed: () => _showAddUserDialog(context, authNotifier, isDark),
              );

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    headerContent,
                    const SizedBox(height: 14),
                    addButton,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: headerContent),
                  const SizedBox(width: 16),
                  addButton,
                ],
              );
            },
          ),

          const SizedBox(height: 20),

          // 2. Stats and Filters Row
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _buildFilterChip(
                label: 'All (${staffUsers.length})',
                isSelected: _filterRole == null,
                color: AppColors.primaryRed,
                onTap: () => setState(() => _filterRole = null),
                isDark: isDark,
              ),
              _buildFilterChip(
                label: 'Owners ($ownerCount)',
                isSelected: _filterRole == UserRole.owner,
                color: AppColors.primaryRed,
                onTap: () => setState(() => _filterRole = UserRole.owner),
                isDark: isDark,
              ),
              _buildFilterChip(
                label: 'Managers ($managerCount)',
                isSelected: _filterRole == UserRole.manager,
                color: const Color(0xFF2563EB),
                onTap: () => setState(() => _filterRole = UserRole.manager),
                isDark: isDark,
              ),
              _buildFilterChip(
                label: 'Cashiers ($cashierCount)',
                isSelected: _filterRole == UserRole.cashier,
                color: const Color(0xFF16A34A),
                onTap: () => setState(() => _filterRole = UserRole.cashier),
                isDark: isDark,
              ),
              const SizedBox(width: 10),
              // Search input
              SizedBox(
                width: 220,
                height: 36,
                child: TextField(
                  onChanged: (val) => setState(() => _searchQuery = val.trim()),
                  style: TextStyle(fontSize: 12, color: isDark ? Colors.white : AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Search username...',
                    hintStyle: TextStyle(fontSize: 11.5, color: isDark ? Colors.white38 : AppColors.textMuted),
                    prefixIcon: const Icon(Icons.search_rounded, size: 16, color: AppColors.textMuted),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primaryRed, width: 1.5)),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // 3. User Cards Grid
          Expanded(
            child: filteredUsers.isEmpty
                ? _buildEmptyState(isDark)
                : SingleChildScrollView(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth >= 900;
                        final isMedium = constraints.maxWidth >= 600 && constraints.maxWidth < 900;

                        if (isWide) {
                          return Wrap(
                            spacing: 16,
                            runSpacing: 16,
                            children: filteredUsers.map((u) {
                              return SizedBox(
                                width: (constraints.maxWidth - 32) / 3,
                                child: _buildUserCard(context, u, authNotifier, isDark),
                              );
                            }).toList(),
                          );
                        } else if (isMedium) {
                          return Wrap(
                            spacing: 16,
                            runSpacing: 16,
                            children: filteredUsers.map((u) {
                              return SizedBox(
                                width: (constraints.maxWidth - 16) / 2,
                                child: _buildUserCard(context, u, authNotifier, isDark),
                              );
                            }).toList(),
                          );
                        } else {
                          return Column(
                            children: filteredUsers.map((u) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: _buildUserCard(context, u, authNotifier, isDark),
                              );
                            }).toList(),
                          );
                        }
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: isDark ? 0.25 : 0.12)
              : (isDark ? const Color(0xFF1E293B) : Colors.white),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? color : (isDark ? Colors.white70 : AppColors.textSecondary),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.person_off_rounded, size: 48, color: isDark ? Colors.white24 : AppColors.textMuted),
          const SizedBox(height: 12),
          Text(
            'No staff users found',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white70 : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Try searching for another username or add a new user.',
            style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  // --- Clean & Rich Staff User Card ---
  Widget _buildUserCard(
    BuildContext context,
    UserCredential user,
    AuthNotifier authNotifier,
    bool isDark,
  ) {
    Color cardColor;
    IconData roleIcon;
    String roleLabel;

    switch (user.role) {
      case UserRole.manager:
        cardColor = const Color(0xFF2563EB);
        roleIcon = Icons.badge_rounded;
        roleLabel = 'Store Manager';
        break;
      case UserRole.cashier:
        cardColor = const Color(0xFF16A34A);
        roleIcon = Icons.point_of_sale_rounded;
        roleLabel = 'Sales Person (Cashier)';
        break;
      case UserRole.owner:
        cardColor = AppColors.primaryRed;
        roleIcon = Icons.workspace_premium_rounded;
        roleLabel = 'Chain Owner (Master)';
        break;
    }

    final currentUser = ref.watch(authProvider).currentUser;
    final isOwner = currentUser.role == UserRole.owner;
    final isSelf = currentUser.fullName.toLowerCase() == user.username.toLowerCase();
    // Owner can delete any Manager and Cashier user; non-owners can delete custom users
    final canDelete = isOwner
        ? (user.role != UserRole.owner && !isSelf)
        : (!user.isDefault && user.role != UserRole.owner && !isSelf);
    final isShowing = _showPasswordMap[user.username] ?? true;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Accent Line
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Avatar, Username, Role Chip & Delete Button
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: cardColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(roleIcon, color: cardColor, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  user.username,
                                  style: TextStyle(
                                    color: isDark ? Colors.white : AppColors.textPrimary,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (user.isDefault) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'DEFAULT',
                                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.textMuted),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            roleLabel,
                            style: TextStyle(
                              color: cardColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (canDelete)
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 20),
                        tooltip: 'Delete ${user.role.displayName}',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        onPressed: () => _confirmDeleteUser(context, user, authNotifier, isDark),
                      ),
                  ],
                ),

                const SizedBox(height: 16),

                // 1. Username Display Field
                Text(
                  'LOGIN USERNAME',
                  style: TextStyle(
                    color: isDark ? const Color(0xFF94A3B8) : AppColors.textMuted,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      width: 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.alternate_email_rounded, size: 16, color: cardColor),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          user.username,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : AppColors.textPrimary,
                            letterSpacing: 0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // 2. Password Display Field
                Text(
                  'LOGIN PASSWORD',
                  style: TextStyle(
                    color: isDark ? const Color(0xFF94A3B8) : AppColors.textMuted,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isShowing
                          ? cardColor.withValues(alpha: 0.5)
                          : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      width: isShowing ? 1.5 : 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.key_rounded, size: 16, color: cardColor),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          isShowing ? _getPasswordDisplay(user) : '••••••••',
                          style: TextStyle(
                            fontFamily: isShowing ? null : 'Courier',
                            fontSize: isShowing ? 13.5 : 17,
                            fontWeight: FontWeight.bold,
                            letterSpacing: isShowing ? 0.3 : 2.5,
                            color: isShowing
                                ? (isDark ? Colors.white : AppColors.textPrimary)
                                : (isDark ? Colors.white70 : const Color(0xFF334155)),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        iconSize: 18,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        icon: Icon(
                          isShowing ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                          color: isShowing
                              ? cardColor
                              : (isDark ? Colors.white54 : AppColors.textSecondary),
                        ),
                        tooltip: isShowing ? 'Hide Password' : 'Show Password',
                        onPressed: () {
                          setState(() {
                            _showPasswordMap[user.username] = !isShowing;
                          });
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),
                Text(
                  'Updated: ${_formatDate(user.lastUpdated)} by ${user.updatedBy}',
                  style: TextStyle(
                    color: isDark ? const Color(0xFF64748B) : AppColors.textMuted,
                    fontSize: 10.5,
                  ),
                ),

                const SizedBox(height: 16),

                // Buttons: Edit User & Reset
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: cardColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.edit_note_rounded, size: 18),
                        label: const Text(
                          'EDIT USER',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, letterSpacing: 0.3),
                        ),
                        onPressed: () => _showEditUserDialog(context, user, authNotifier, isDark),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark ? Colors.white70 : AppColors.textSecondary,
                        side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => _confirmResetToDefault(context, user, authNotifier, isDark),
                      child: const Text(
                        'RESET',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Add User Dialog Modal ---
  void _showAddUserDialog(BuildContext context, AuthNotifier authNotifier, bool isDark) {
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();
    UserRole selectedRole = UserRole.cashier;
    bool obscurePassword = true;
    String? errorText;
    bool isSaving = false;

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              clipBehavior: Clip.antiAlias,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 460,
                  maxHeight: MediaQuery.of(context).size.height * 0.9,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      decoration: const BoxDecoration(
                        gradient: AppColors.brandGradient,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.person_add_alt_1_rounded, color: Colors.white, size: 20),
                              SizedBox(width: 10),
                              Text(
                                'ADD NEW STAFF USER',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                            onPressed: isSaving ? null : () => Navigator.pop(dialogContext),
                          ),
                        ],
                      ),
                    ),

                    // Body
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(22),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (errorText != null) ...[
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.danger.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 16),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        errorText!,
                                        style: const TextStyle(color: AppColors.danger, fontSize: 11.5, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),
                            ],

                            // 1. Username Field
                            Text(
                              'USERNAME (LOGIN ID)',
                              style: TextStyle(
                                color: isDark ? const Color(0xFF94A3B8) : AppColors.textMuted,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: usernameController,
                              onChanged: (_) => setDialogState(() => errorText = null),
                              style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimary, fontSize: 13),
                              decoration: InputDecoration(
                                hintText: 'e.g. cashier_ali, store_mgr_1',
                                hintStyle: TextStyle(color: isDark ? Colors.white38 : AppColors.textMuted, fontSize: 12),
                                prefixIcon: const Icon(Icons.alternate_email_rounded, size: 18, color: AppColors.primaryRed),
                                filled: true,
                                fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1))),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1))),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primaryRed, width: 2)),
                              ),
                            ),
                            const SizedBox(height: 14),

                            // 2. Select Role
                            Text(
                              'SELECT ROLE',
                              style: TextStyle(
                                color: isDark ? const Color(0xFF94A3B8) : AppColors.textMuted,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<UserRole>(
                              initialValue: selectedRole,
                              dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimary, fontSize: 13),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                prefixIcon: const Icon(Icons.badge_outlined, size: 18, color: AppColors.primaryRed),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1))),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1))),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primaryRed, width: 2)),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: UserRole.manager,
                                  child: Text('Store Manager (Branch, Stock & KDS)'),
                                ),
                                DropdownMenuItem(
                                  value: UserRole.cashier,
                                  child: Text('Sales Person / Cashier (POS Billing)'),
                                ),
                              ],
                              onChanged: (r) {
                                if (r != null) {
                                  setDialogState(() => selectedRole = r);
                                }
                              },
                            ),
                            const SizedBox(height: 14),

                            // 3. Password Field
                            Text(
                              'LOGIN PASSWORD',
                              style: TextStyle(
                                color: isDark ? const Color(0xFF94A3B8) : AppColors.textMuted,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: passwordController,
                              obscureText: obscurePassword,
                              onChanged: (_) => setDialogState(() => errorText = null),
                              style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimary, fontSize: 13),
                              decoration: InputDecoration(
                                hintText: 'Enter login password (min 4 characters)',
                                hintStyle: TextStyle(color: isDark ? Colors.white38 : AppColors.textMuted, fontSize: 12),
                                prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18, color: AppColors.primaryRed),
                                suffixIcon: IconButton(
                                  icon: Icon(obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 18),
                                  onPressed: () => setDialogState(() => obscurePassword = !obscurePassword),
                                ),
                                filled: true,
                                fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1))),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1))),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primaryRed, width: 2)),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Actions
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: isSaving ? null : () => Navigator.pop(dialogContext),
                                  child: const Text('CANCEL', style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.bold)),
                                ),
                                const SizedBox(width: 10),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primaryRed,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  onPressed: isSaving
                                      ? null
                                      : () async {
                                          final uname = usernameController.text.trim();
                                          final pwd = passwordController.text.trim();

                                          if (uname.isEmpty) {
                                            setDialogState(() => errorText = 'Please enter a username');
                                            return;
                                          }
                                          if (uname.length < 3) {
                                            setDialogState(() => errorText = 'Username must be at least 3 characters');
                                            return;
                                          }
                                          if (pwd.isEmpty) {
                                            setDialogState(() => errorText = 'Please enter a password');
                                            return;
                                          }
                                          if (pwd.length < 4) {
                                            setDialogState(() => errorText = 'Password must be at least 4 characters');
                                            return;
                                          }

                                          setDialogState(() => isSaving = true);
                                          final success = await authNotifier.addStaffUser(
                                            username: uname,
                                            role: selectedRole,
                                            password: pwd,
                                          );

                                          if (!success) {
                                            setDialogState(() {
                                              isSaving = false;
                                              errorText = 'Username "$uname" already exists. Please pick another.';
                                            });
                                            return;
                                          }

                                          if (context.mounted) {
                                            setState(() {
                                              _customPlainPasswords[uname.toLowerCase()] = pwd;
                                              _showPasswordMap[uname] = true;
                                            });
                                            Navigator.pop(dialogContext);
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text('Staff user "$uname" created successfully!'),
                                                backgroundColor: const Color(0xFF16A34A),
                                              ),
                                            );
                                          }
                                        },
                                  child: isSaving
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                        )
                                      : const Text('CREATE USER', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- Edit Staff User Dialog (Username, Role, Password) ---
  void _showEditUserDialog(
    BuildContext context,
    UserCredential user,
    AuthNotifier authNotifier,
    bool isDark,
  ) {
    final usernameController = TextEditingController(text: user.username);
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    UserRole selectedRole = user.role;
    bool obscureNew = true;
    bool obscureConfirm = true;
    String? errorText;
    bool isSaving = false;

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              clipBehavior: Clip.antiAlias,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 470,
                  maxHeight: MediaQuery.of(context).size.height * 0.9,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      decoration: const BoxDecoration(
                        gradient: AppColors.brandGradient,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.edit_note_rounded, color: Colors.white, size: 22),
                              const SizedBox(width: 8),
                              Text(
                                'EDIT STAFF USER: @${user.username.toUpperCase()}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13.5,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                            onPressed: isSaving ? null : () => Navigator.pop(dialogContext),
                          ),
                        ],
                      ),
                    ),

                    // Body
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(22),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (errorText != null) ...[
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.danger.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 16),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        errorText!,
                                        style: const TextStyle(color: AppColors.danger, fontSize: 11.5, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),
                            ],

                            // 1. Username Field
                            Text(
                              'USERNAME (LOGIN ID)',
                              style: TextStyle(
                                color: isDark ? const Color(0xFF94A3B8) : AppColors.textMuted,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: usernameController,
                              onChanged: (_) => setDialogState(() => errorText = null),
                              style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimary, fontSize: 13),
                              decoration: InputDecoration(
                                hintText: 'Enter username',
                                prefixIcon: const Icon(Icons.alternate_email_rounded, size: 18, color: AppColors.primaryRed),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1))),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1))),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primaryRed, width: 2)),
                              ),
                            ),
                            const SizedBox(height: 14),

                            // 2. Select Role (Disabled for Owner)
                            Row(
                              children: [
                                Text(
                                  'USER ROLE',
                                  style: TextStyle(
                                    color: isDark ? const Color(0xFF94A3B8) : AppColors.textMuted,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                if (user.role == UserRole.owner) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.brandYellow.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'LOCKED FOR OWNER',
                                      style: TextStyle(
                                        color: AppColors.brandYellow,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<UserRole>(
                              initialValue: selectedRole,
                              dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              style: TextStyle(
                                color: user.role == UserRole.owner
                                    ? (isDark ? Colors.white60 : Colors.black54)
                                    : (isDark ? Colors.white : AppColors.textPrimary),
                                fontSize: 13,
                              ),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: user.role == UserRole.owner
                                    ? (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9))
                                    : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                prefixIcon: Icon(
                                  user.role == UserRole.owner ? Icons.lock_outline_rounded : Icons.badge_outlined,
                                  size: 18,
                                  color: user.role == UserRole.owner
                                      ? (isDark ? Colors.white38 : AppColors.textMuted)
                                      : AppColors.primaryRed,
                                ),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1))),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1))),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                    color: user.role == UserRole.owner
                                        ? (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1))
                                        : AppColors.primaryRed,
                                    width: user.role == UserRole.owner ? 1 : 2,
                                  ),
                                ),
                                helperText: user.role == UserRole.owner ? 'Owner role cannot be changed' : null,
                                helperStyle: TextStyle(
                                  fontSize: 10.5,
                                  color: isDark ? const Color(0xFF94A3B8) : AppColors.textMuted,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              disabledHint: const Text('Owner (Full System & Analytics Access)'),
                              items: [
                                if (user.role == UserRole.owner)
                                  const DropdownMenuItem(
                                    value: UserRole.owner,
                                    child: Text('Owner (Full System & Analytics Access)'),
                                  ),
                                const DropdownMenuItem(
                                  value: UserRole.manager,
                                  child: Text('Store Manager (Branch, Stock & KDS)'),
                                ),
                                const DropdownMenuItem(
                                  value: UserRole.cashier,
                                  child: Text('Sales Person / Cashier (POS Billing)'),
                                ),
                              ],
                              onChanged: user.role == UserRole.owner
                                  ? null
                                  : (r) {
                                      if (r != null) {
                                        setDialogState(() => selectedRole = r);
                                      }
                                    },
                            ),
                            const SizedBox(height: 14),

                            // 3. New Password (Optional)
                            Text(
                              'NEW PASSWORD (LEAVE EMPTY TO KEEP CURRENT)',
                              style: TextStyle(
                                color: isDark ? const Color(0xFF94A3B8) : AppColors.textMuted,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: newPasswordController,
                              obscureText: obscureNew,
                              onChanged: (_) => setDialogState(() => errorText = null),
                              style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimary, fontSize: 13),
                              decoration: InputDecoration(
                                hintText: 'Enter new password (or leave blank)',
                                hintStyle: TextStyle(color: isDark ? Colors.white38 : AppColors.textMuted, fontSize: 12),
                                prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18, color: AppColors.primaryRed),
                                suffixIcon: IconButton(
                                  icon: Icon(obscureNew ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 18),
                                  onPressed: () => setDialogState(() => obscureNew = !obscureNew),
                                ),
                                filled: true,
                                fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1))),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1))),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primaryRed, width: 2)),
                              ),
                            ),
                            const SizedBox(height: 14),

                            // 4. Confirm New Password Field (only if password typed)
                            if (newPasswordController.text.isNotEmpty) ...[
                              Text(
                                'CONFIRM NEW PASSWORD',
                                style: TextStyle(
                                  color: isDark ? const Color(0xFF94A3B8) : AppColors.textMuted,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: confirmPasswordController,
                              obscureText: obscureConfirm,
                              onChanged: (_) => setDialogState(() => errorText = null),
                              style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimary, fontSize: 13),
                              decoration: InputDecoration(
                                hintText: 'Retype new password',
                                hintStyle: TextStyle(color: isDark ? Colors.white38 : AppColors.textMuted, fontSize: 12),
                                prefixIcon: const Icon(Icons.check_circle_outline_rounded, size: 18, color: Color(0xFF16A34A)),
                                suffixIcon: IconButton(
                                  icon: Icon(obscureConfirm ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 18),
                                  onPressed: () => setDialogState(() => obscureConfirm = !obscureConfirm),
                                ),
                                filled: true,
                                fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1))),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1))),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF16A34A), width: 2)),
                              ),
                            ),
                            const SizedBox(height: 14),
                          ],

                          const SizedBox(height: 10),

                          // Actions
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: isSaving ? null : () => Navigator.pop(dialogContext),
                                child: const Text('CANCEL', style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 10),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryRed,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                onPressed: isSaving
                                    ? null
                                    : () async {
                                        final uname = usernameController.text.trim();
                                        final p1 = newPasswordController.text.trim();
                                        final p2 = confirmPasswordController.text.trim();

                                        if (uname.isEmpty) {
                                          setDialogState(() => errorText = 'Please enter a username');
                                          return;
                                        }
                                        if (uname.length < 3) {
                                          setDialogState(() => errorText = 'Username must be at least 3 characters');
                                          return;
                                        }
                                        if (p1.isNotEmpty) {
                                          if (p1.length < 4) {
                                            setDialogState(() => errorText = 'Password must be at least 4 characters');
                                            return;
                                          }
                                          if (p1 != p2) {
                                            setDialogState(() => errorText = 'Passwords do not match');
                                            return;
                                          }
                                        }

                                        setDialogState(() => isSaving = true);
                                        final success = await authNotifier.updateStaffUser(
                                          id: user.id,
                                          oldUsername: user.username,
                                          newUsername: uname,
                                          newRole: selectedRole,
                                          newPassword: p1.isNotEmpty ? p1 : null,
                                        );

                                        if (!success) {
                                          setDialogState(() {
                                            isSaving = false;
                                            errorText = 'Username "$uname" is already taken by another user.';
                                          });
                                          return;
                                        }

                                        if (context.mounted) {
                                          setState(() {
                                            if (p1.isNotEmpty) {
                                              _customPlainPasswords[uname.toLowerCase()] = p1;
                                              _showPasswordMap[uname] = true;
                                            }
                                            if (user.username.toLowerCase() != uname.toLowerCase()) {
                                              final old = _customPlainPasswords.remove(user.username.toLowerCase());
                                              if (old != null && p1.isEmpty) {
                                                _customPlainPasswords[uname.toLowerCase()] = old;
                                              }
                                            }
                                          });
                                          Navigator.pop(dialogContext);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('Staff user "@$uname" updated successfully!'),
                                              backgroundColor: const Color(0xFF16A34A),
                                            ),
                                          );
                                        }
                                      },
                                child: isSaving
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                      )
                                    : const Text('SAVE CHANGES', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            );
          },
        );
      },
    );
  }

  // --- Reset to Default Confirmation ---
  void _confirmResetToDefault(
    BuildContext context,
    UserCredential user,
    AuthNotifier authNotifier,
    bool isDark,
  ) {
    final defaultPwd = user.username.toLowerCase() == 'noman'
        ? 'Noman123'
        : (user.role == UserRole.owner
            ? 'owner123'
            : (user.role == UserRole.manager ? 'manager123' : 'cashier123'));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          children: [
            const Icon(Icons.restore_rounded, color: AppColors.primaryRed, size: 22),
            const SizedBox(width: 8),
            Text(
              'RESET TO DEFAULT',
              style: TextStyle(
                color: isDark ? Colors.white : AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ],
        ),
        content: Text(
          'Reset password for user @${user.username} back to default ("$defaultPwd")?',
          style: TextStyle(
            color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
            fontSize: 13,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL', style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              await authNotifier.resetUserPassword(user.username);
              if (context.mounted) {
                setState(() {
                  _customPlainPasswords[user.username.toLowerCase()] = defaultPwd;
                  _showPasswordMap[user.username] = true;
                });
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Password for @${user.username} reset to default ($defaultPwd)'),
                    backgroundColor: const Color(0xFF16A34A),
                  ),
                );
              }
            },
            child: const Text('RESET PASSWORD', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // --- Confirm Delete User ---
  Future<void> _confirmDeleteUser(
    BuildContext context,
    UserCredential user,
    AuthNotifier authNotifier,
    bool isDark,
  ) async {
    final confirmed = await showConfirmDeleteDialog(
      context: context,
      title: 'DELETE STAFF USER',
      itemName: '@${user.username} (${user.role.displayName})',
      itemType: 'Staff Account',
      description: 'Are you sure you want to permanently delete staff user account "@${user.username}"? This user will immediately lose system access and can no longer log in.',
      confirmButtonText: 'DELETE USER',
    );

    if (confirmed) {
      final success = await authNotifier.deleteStaffUser(user.username);
      if (context.mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Staff user "@${user.username}" (${user.role.displayName}) deleted successfully.'),
              backgroundColor: AppColors.danger,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cannot delete this master owner account.'),
              backgroundColor: AppColors.danger,
            ),
          );
        }
      }
    }
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        return '${diff.inMinutes}m ago';
      }
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${dt.day}/${dt.month}/${dt.year}';
    }
  }
}
