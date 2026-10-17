import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/app_colors.dart';
import '../../data/auth_repository.dart';
import '../../data/role_rights_repository.dart';
import '../../data/staff_repository.dart';
import '../../domain/models/staff_model.dart';
import '../../domain/models/user_role.dart';
import '../../shared/widgets/confirm_delete_dialog.dart';

class StaffScreen extends ConsumerStatefulWidget {
  const StaffScreen({super.key});

  @override
  ConsumerState<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends ConsumerState<StaffScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _filterSalaryStatus = 'ALL'; // ALL, PAID, PENDING

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final staffState = ref.watch(staffProvider);
    final staffNotifier = ref.read(staffProvider.notifier);

    final filteredStaff = staffState.staffMembers.where((staff) {
      final matchesSearch = staff.fullName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          staff.role.displayName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          staff.phone.toLowerCase().contains(_searchQuery.toLowerCase());

      if (!matchesSearch) return false;

      if (_filterSalaryStatus == 'PAID') {
        return staff.isSalaryPaid;
      } else if (_filterSalaryStatus == 'PENDING') {
        return !staff.isSalaryPaid;
      }
      return true;
    }).toList();

    return Container(
      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8F9FA),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Header with Month Calendar Selector & Add User Button
          _buildHeader(context, staffState, isDark),
          const SizedBox(height: 14),

          // Mini Stat Cards KPI Row
          _buildMiniStatRow(staffState, isDark),
          const SizedBox(height: 14),

          // Search & Filter Bar
          _buildSearchAndFilterBar(isDark),
          const SizedBox(height: 14),

          // Expandable Users List Section
          Expanded(
            child: filteredStaff.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 48,
                          color: isDark ? const Color(0xFF64748B) : AppColors.textMuted,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No users found matching filters for ${staffState.selectedMonthDisplayName}.',
                          style: TextStyle(
                            color: isDark ? const Color(0xFF94A3B8) : AppColors.textMuted,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: filteredStaff.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final staff = filteredStaff[index];
                      return _buildExpandableUserTile(context, staff, staffNotifier, isDark, staffState.selectedMonthDisplayName);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // --- Header ---
  Widget _buildHeader(BuildContext context, StaffState staffState, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryRed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.people_alt_rounded,
                color: AppColors.primaryRed,
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'STORE USERS & PAYROLL MANAGEMENT',
                  style: TextStyle(
                    color: isDark ? Colors.white : AppColors.textPrimary,
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  'Viewing payroll & users for ${staffState.selectedMonthDisplayName}',
                  style: TextStyle(
                    color: isDark ? const Color(0xFF94A3B8) : AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        Row(
          children: [
            // Month Picker / Calendar Button
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                foregroundColor: isDark ? Colors.white : AppColors.textPrimary,
                side: BorderSide(
                  color: isDark ? const Color(0xFF475569) : AppColors.primaryRed.withValues(alpha: 0.4),
                  width: 1.5,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => _showMonthPickerCalendarDialog(context, ref, staffState, isDark),
              icon: const Icon(Icons.calendar_month_rounded, color: AppColors.primaryRed, size: 18),
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    staffState.selectedMonthDisplayName.toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 0.3),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_drop_down_rounded, size: 20, color: isDark ? Colors.white70 : AppColors.textSecondary),
                ],
              ),
            ),
            const SizedBox(width: 10),

            // Add New User Button
            Builder(
              builder: (context) {
                final role = ref.watch(authProvider).currentUser.role;
                final canAddUser = ref.watch(roleRightsProvider).isActionGranted(
                  role,
                  'users_add',
                  defaultIfMissing: role != UserRole.cashier,
                );
                if (!canAddUser) return const SizedBox.shrink();

                return ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryRed,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _showAddUserDialog(context, ref, isDark),
                  icon: const Icon(Icons.person_add_rounded, color: Colors.white, size: 18),
                  label: const Text(
                    '+ ADD NEW USER',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  // --- Month Picker Calendar Dialog ---
  void _showMonthPickerCalendarDialog(
    BuildContext context,
    WidgetRef ref,
    StaffState staffState,
    bool isDark,
  ) {
    int currentYear = staffState.selectedMonth.year;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            const shortMonthNames = [
              'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
              'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
            ];
            final now = DateTime.now();

            return Dialog(
              backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isDark ? const Color(0xFF334155) : AppColors.borderGray,
                  width: 1.5,
                ),
              ),
              child: Container(
                width: 440,
                padding: const EdgeInsets.all(22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primaryRed.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.calendar_month_rounded, color: AppColors.primaryRed, size: 22),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'SELECT PAYROLL MONTH',
                                  style: TextStyle(
                                    color: isDark ? Colors.white : AppColors.textPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                Text(
                                  'View month-wise users & salary records',
                                  style: TextStyle(
                                    color: isDark ? const Color(0xFF94A3B8) : AppColors.textMuted,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        IconButton(
                          icon: Icon(Icons.close_rounded, color: isDark ? const Color(0xFF94A3B8) : AppColors.textMuted),
                          onPressed: () => Navigator.pop(dialogContext),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),
                    Divider(height: 1, color: isDark ? const Color(0xFF334155) : AppColors.borderGray),
                    const SizedBox(height: 16),

                    // Year Selection Bar
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left_rounded, size: 26),
                            color: isDark ? Colors.white : AppColors.textPrimary,
                            onPressed: () {
                              setDialogState(() {
                                currentYear--;
                              });
                            },
                          ),
                          Row(
                            children: [
                              const Icon(Icons.event_note_rounded, color: AppColors.primaryRed, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                '$currentYear',
                                style: TextStyle(
                                  color: isDark ? Colors.white : AppColors.textPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_right_rounded, size: 26),
                            color: isDark ? Colors.white : AppColors.textPrimary,
                            onPressed: () {
                              setDialogState(() {
                                currentYear++;
                              });
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // 12-Month Grid
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 2.1,
                      ),
                      itemCount: 12,
                      itemBuilder: (context, index) {
                        final monthNum = index + 1;
                        final isSelected = (currentYear == staffState.selectedMonth.year && monthNum == staffState.selectedMonth.month);
                        final isCurrentMonth = (currentYear == now.year && monthNum == now.month);

                        return InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            final targetDate = DateTime(currentYear, monthNum);
                            ref.read(staffProvider.notifier).selectMonth(targetDate);
                            Navigator.pop(dialogContext);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primaryRed
                                  : (isCurrentMonth
                                      ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFFEF2F2))
                                      : (isDark ? const Color(0xFF1E293B) : Colors.white)),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primaryRed
                                    : (isCurrentMonth
                                        ? AppColors.primaryRed.withValues(alpha: 0.6)
                                        : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                                width: isSelected || isCurrentMonth ? 1.5 : 1,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: AppColors.primaryRed.withValues(alpha: 0.35),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      )
                                    ]
                                  : null,
                            ),
                            alignment: Alignment.center,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  shortMonthNames[index],
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : (isCurrentMonth
                                            ? AppColors.primaryRed
                                            : (isDark ? Colors.white : AppColors.textPrimary)),
                                    fontWeight: isSelected || isCurrentMonth ? FontWeight.w900 : FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                if (isCurrentMonth && !isSelected)
                                  const Text(
                                    'CURRENT',
                                    style: TextStyle(
                                      color: AppColors.primaryRed,
                                      fontSize: 8,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 18),
                    Divider(height: 1, color: isDark ? const Color(0xFF334155) : AppColors.borderGray),
                    const SizedBox(height: 14),

                    // Quick Jump Action Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          ),
                          onPressed: () {
                            final prevMonth = DateTime(staffState.selectedMonth.year, staffState.selectedMonth.month - 1);
                            ref.read(staffProvider.notifier).selectMonth(prevMonth);
                            Navigator.pop(dialogContext);
                          },
                          icon: const Icon(Icons.arrow_back_rounded, size: 14),
                          label: const Text('Prev Month', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                            foregroundColor: isDark ? Colors.white : AppColors.primaryRed,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                            ),
                          ),
                          onPressed: () {
                            final cur = DateTime(now.year, now.month);
                            ref.read(staffProvider.notifier).selectMonth(cur);
                            Navigator.pop(dialogContext);
                          },
                          icon: const Icon(Icons.today_rounded, size: 14),
                          label: const Text('This Month', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                        ),
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          ),
                          onPressed: () {
                            final nextMonth = DateTime(staffState.selectedMonth.year, staffState.selectedMonth.month + 1);
                            ref.read(staffProvider.notifier).selectMonth(nextMonth);
                            Navigator.pop(dialogContext);
                          },
                          icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                          label: const Text('Next Month', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ],
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

  // --- Mini Stat Cards Row ---
  Widget _buildMiniStatRow(StaffState staffState, bool isDark) {
    final monthName = staffState.selectedMonthDisplayName;
    return Row(
      children: [
        Expanded(
          child: _buildMiniStatCard(
            'TOTAL USERS',
            '${staffState.staffMembers.length}',
            'Registered Staff',
            Icons.group_rounded,
            AppColors.primaryRed,
            isDark,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildMiniStatCard(
            'MONTHLY PAYROLL',
            'PKR ${staffState.totalMonthlyPayroll.toStringAsFixed(0)}',
            monthName,
            Icons.payments_rounded,
            AppColors.gold,
            isDark,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildMiniStatCard(
            'SALARIES PAID',
            '${staffState.paidCount} Users',
            'PKR ${staffState.paidPayroll.toStringAsFixed(0)} ($monthName)',
            Icons.check_circle_rounded,
            AppColors.success,
            isDark,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildMiniStatCard(
            'SALARIES UNPAID',
            '${staffState.pendingCount} Users',
            'PKR ${staffState.pendingPayroll.toStringAsFixed(0)} ($monthName)',
            Icons.pending_actions_rounded,
            AppColors.danger,
            isDark,
          ),
        ),
      ],
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
                    fontSize: 15,
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

  // --- Search & Filter Bar ---
  Widget _buildSearchAndFilterBar(bool isDark) {
    return Row(
      children: [
        // Pill Search Input
        SizedBox(
          width: 300,
          height: 38,
          child: TextField(
            controller: _searchController,
            style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search user by name, phone, ID...',
              hintStyle: TextStyle(color: isDark ? const Color(0xFF64748B) : AppColors.textMuted, fontSize: 12),
              prefixIcon: Icon(Icons.search, color: isDark ? const Color(0xFF64748B) : AppColors.textMuted, size: 18),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 16),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : AppColors.borderGray),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : AppColors.borderGray),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: const BorderSide(color: AppColors.primaryRed),
              ),
            ),
            onChanged: (val) => setState(() => _searchQuery = val),
          ),
        ),
        const SizedBox(width: 12),

        // ChoiceChips Filter
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('ALL', 'All Users', isDark),
                const SizedBox(width: 6),
                _buildFilterChip('PAID', 'Salary Paid (YES)', isDark),
                const SizedBox(width: 6),
                _buildFilterChip('PENDING', 'Salary Unpaid (NO)', isDark),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String status, String label, bool isDark) {
    final isSelected = _filterSalaryStatus == status;
    return ChoiceChip(
      showCheckmark: false,
      label: Text(
        label,
        style: TextStyle(
          color: isSelected
              ? Colors.white
              : (isDark ? const Color(0xFFCBD5E1) : AppColors.textSecondary),
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 12,
        ),
      ),
      selected: isSelected,
      selectedColor: AppColors.primaryRed,
      backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
      side: BorderSide(
        color: isSelected
            ? AppColors.primaryRed
            : (isDark ? const Color(0xFF334155) : AppColors.borderGray),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      onSelected: (selected) {
        if (selected) {
          setState(() => _filterSalaryStatus = status);
        }
      },
    );
  }

  // --- Professional Expandable User Row Tile ---
  Widget _buildExpandableUserTile(
    BuildContext context,
    StaffMember staff,
    StaffNotifier staffNotifier,
    bool isDark,
    String selectedMonthName,
  ) {
    return Material(
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: staff.isSalaryPaid
              ? (isDark ? AppColors.success.withValues(alpha: 0.5) : AppColors.success.withValues(alpha: 0.3))
              : (isDark ? AppColors.danger.withValues(alpha: 0.5) : AppColors.danger.withValues(alpha: 0.3)),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          childrenPadding: const EdgeInsets.all(14),
          iconColor: isDark ? const Color(0xFFCBD5E1) : AppColors.textPrimary,
          collapsedIconColor: isDark ? const Color(0xFF64748B) : AppColors.textMuted,
          leading: CircleAvatar(
            backgroundColor: AppColors.primaryRed.withValues(alpha: 0.15),
            radius: 20,
            child: Text(
              staff.fullName.isNotEmpty ? staff.fullName[0].toUpperCase() : 'U',
              style: const TextStyle(color: AppColors.primaryRed, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          title: Row(
            children: [
              Text(
                staff.fullName,
                style: TextStyle(
                  color: isDark ? Colors.white : AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Row(
              children: [
                Icon(Icons.phone, size: 12, color: isDark ? const Color(0xFF64748B) : AppColors.textMuted),
                const SizedBox(width: 4),
                Text(
                  staff.phone,
                  style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : AppColors.textMuted, fontSize: 11),
                ),
                const SizedBox(width: 12),
                Icon(Icons.calendar_today_outlined, size: 12, color: isDark ? const Color(0xFF64748B) : AppColors.textMuted),
                const SizedBox(width: 4),
                Text(
                  'Joined ${staff.joiningDate}',
                  style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : AppColors.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'MONTHLY SALARY',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 9, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'PKR ${staff.monthlySalary.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: AppColors.gold,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),

              // Paid Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: staff.isSalaryPaid
                      ? AppColors.success.withValues(alpha: 0.15)
                      : AppColors.danger.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: staff.isSalaryPaid ? AppColors.success : AppColors.danger,
                  ),
                ),
                child: Text(
                  staff.isSalaryPaid ? 'PAID: YES' : 'PAID: NO',
                  style: TextStyle(
                    color: staff.isSalaryPaid ? AppColors.success : AppColors.danger,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isDark ? const Color(0xFF334155) : AppColors.borderGray),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section 1: User Profile Info Grid
                  Text(
                    'USER PROFILE INFORMATION',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : AppColors.primaryRed,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _buildInfoItem('Role', staff.role.displayName, isDark)),
                      Expanded(child: _buildInfoItem('Phone Number', staff.phone, isDark)),
                      Expanded(child: _buildInfoItem('Joining Date', staff.joiningDate, isDark)),
                    ],
                  ),

                  const Divider(height: 20, thickness: 1),

                  // Section 2: Salary Breakdown Grid
                  Text(
                    'MONTHLY SALARY & PAYROLL',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : AppColors.primaryRed,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _buildInfoItem('Monthly Salary', 'PKR ${staff.monthlySalary.toStringAsFixed(0)}', isDark, isBold: true)),
                      Expanded(child: _buildInfoItem('Hourly Rate (Est.)', 'PKR ${staff.hourlyRate.toStringAsFixed(0)} / hr', isDark)),
                      Expanded(child: _buildInfoItem('Payment Status', staff.isSalaryPaid ? 'PAID' : 'PENDING DISBURSEMENT', isDark)),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Section 3: Action Buttons
                  Builder(
                    builder: (context) {
                      final role = ref.watch(authProvider).currentUser.role;
                      final roleRights = ref.watch(roleRightsProvider);
                      final canDisburse = roleRights.isActionGranted(
                        role,
                        'users_salary_disburse',
                        defaultIfMissing: role != UserRole.cashier,
                      );
                      final canDelete = roleRights.isActionGranted(
                        role,
                        'users_delete',
                        defaultIfMissing: role == UserRole.owner,
                      );

                      return Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (canDisburse) ...[
                            // Toggle Paid/Unpaid for Selected Month
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: staff.isSalaryPaid ? AppColors.danger : AppColors.success,
                                ),
                                foregroundColor: staff.isSalaryPaid ? AppColors.danger : AppColors.success,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: () => staffNotifier.toggleSalaryPaid(staff.id),
                              icon: Icon(
                                staff.isSalaryPaid ? Icons.cancel_outlined : Icons.check_circle_outline,
                                size: 14,
                              ),
                              label: Text(
                                staff.isSalaryPaid ? 'MARK UNPAID ($selectedMonthName)' : 'MARK PAID ($selectedMonthName)',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],

                          // Full Payslip Modal Button
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDark ? const Color(0xFF334155) : AppColors.lightGray,
                              foregroundColor: isDark ? Colors.white : AppColors.textPrimary,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: BorderSide(color: isDark ? const Color(0xFF475569) : AppColors.borderGray),
                              ),
                            ),
                            onPressed: () => _showUserDetailsModal(context, staff, isDark, selectedMonthName),
                            icon: const Icon(Icons.receipt_long_rounded, size: 14),
                            label: const Text('FULL PAYSLIP', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          ),

                          if (canDelete) ...[
                            const SizedBox(width: 8),
                            // Delete User Button
                            IconButton(
                              tooltip: 'Delete User',
                              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 18),
                              onPressed: () => _confirmDeleteUser(context, staff, staffNotifier, isDark),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, bool isDark, {bool isBold = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: isDark ? const Color(0xFF64748B) : AppColors.textMuted,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: isBold ? AppColors.gold : (isDark ? Colors.white : AppColors.textPrimary),
            fontSize: 12,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  // --- Confirm Delete User ---
  Future<void> _confirmDeleteUser(BuildContext context, StaffMember staff, StaffNotifier notifier, bool isDark) async {
    final confirmed = await showConfirmDeleteDialog(
      context: context,
      title: 'DELETE STAFF MEMBER',
      itemName: '${staff.fullName} (${staff.role.displayName})',
      itemType: 'Staff Profile & Payroll',
      description: 'Are you sure you want to delete employee "${staff.fullName}"? They will be removed starting from this month onward, while all previous records and past salary history will remain safely preserved in the database.',
      confirmButtonText: 'DELETE FROM THIS MONTH ONWARD',
    );

    if (confirmed) {
      notifier.deleteStaffMember(staff.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Staff member "${staff.fullName}" deleted from current month onward.'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  // --- Full Details & Payslip Dialog ---
  void _showUserDetailsModal(BuildContext context, StaffMember staff, bool isDark, [String? selectedMonthName]) {
    final monthTitle = selectedMonthName ?? 'CURRENT MONTH';
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: isDark ? const Color(0xFF334155) : AppColors.borderGray),
          ),
          child: Container(
            width: 520,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Modal Title
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppColors.primaryRed,
                      radius: 20,
                      child: Text(
                        staff.fullName.isNotEmpty ? staff.fullName[0].toUpperCase() : 'U',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            staff.fullName,
                            style: TextStyle(
                              color: isDark ? Colors.white : AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                            ),
                          ),
                          Text(
                            'Monthly employee profile & payslip for $monthTitle',
                            style: TextStyle(
                              color: isDark ? const Color(0xFF94A3B8) : AppColors.textMuted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: isDark ? const Color(0xFF94A3B8) : AppColors.textMuted),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                Divider(height: 20, color: isDark ? const Color(0xFF334155) : AppColors.borderGray),

                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Salary Status Card
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: staff.isSalaryPaid
                                ? AppColors.success.withValues(alpha: isDark ? 0.2 : 0.1)
                                : AppColors.danger.withValues(alpha: isDark ? 0.2 : 0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: staff.isSalaryPaid ? AppColors.success : AppColors.danger,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'CURRENT SALARY STATUS',
                                    style: TextStyle(
                                      color: isDark ? const Color(0xFF94A3B8) : AppColors.textMuted,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    staff.isSalaryPaid ? 'SALARY PAID (YES)' : 'SALARY UNPAID (NO)',
                                    style: TextStyle(
                                      color: staff.isSalaryPaid ? AppColors.success : AppColors.danger,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                              if (staff.isSalaryPaid && staff.salaryPaidDate != null)
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'DISBURSED ON',
                                      style: TextStyle(
                                        color: isDark ? const Color(0xFF94A3B8) : AppColors.textMuted,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${staff.salaryPaidDate!.day}/${staff.salaryPaidDate!.month}/${staff.salaryPaidDate!.year}',
                                      style: TextStyle(
                                        color: isDark ? Colors.white : AppColors.textPrimary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),
                        const Text(
                          'USER PROFILE INFORMATION',
                          style: TextStyle(
                            color: AppColors.primaryRed,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),

                        _detailRow('Full Name', staff.fullName, isDark),
                        _detailRow('Role', staff.role.displayName, isDark),
                        _detailRow('Phone Number', staff.phone, isDark),
                        _detailRow('Joining Date', staff.joiningDate, isDark),

                        const SizedBox(height: 16),
                        const Text(
                          'PAYROLL & SALARY BREAKDOWN',
                          style: TextStyle(
                            color: AppColors.primaryRed,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),

                        _detailRow('Monthly Salary', 'PKR ${staff.monthlySalary.toStringAsFixed(0)}', isDark),
                        _detailRow('Hourly Equivalent', 'PKR ${staff.hourlyRate.toStringAsFixed(0)} / hr', isDark),

                        Divider(height: 20, color: isDark ? const Color(0xFF334155) : AppColors.borderGray),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'TOTAL MONTHLY SALARY',
                              style: TextStyle(
                                color: isDark ? Colors.white : AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              'PKR ${staff.monthlySalary.toStringAsFixed(0)}',
                              style: const TextStyle(
                                color: AppColors.gold,
                                fontWeight: FontWeight.bold,
                                fontSize: 17,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: TextStyleHelper.mutedText('CLOSE', isDark),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _detailRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : AppColors.textMuted, fontSize: 12)),
          Text(value, style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 12)),
        ],
      ),
    );
  }

  // --- Register New User Dialog (Professional Executive Redesign) ---
  void _showAddUserDialog(BuildContext context, WidgetRef ref, bool isDark) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final salaryController = TextEditingController(text: '65000');
    final employeeId = 'USR-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final baseSalary = double.tryParse(salaryController.text.trim()) ?? 0.0;
            final hourlyEst = (baseSalary > 0 ? (baseSalary / 160) : 0).toStringAsFixed(0);

            return Dialog(
              backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              clipBehavior: Clip.antiAlias,
              child: Container(
                width: 580,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.90,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Premium Brand Header
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
                      decoration: const BoxDecoration(
                        gradient: AppColors.brandGradient,
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                            ),
                            child: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white, size: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Text(
                                      'REGISTER NEW EMPLOYEE',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 16,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.brandYellow,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'HR & ACCESS',
                                        style: TextStyle(
                                          color: AppColors.deepRed,
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                 const SizedBox(height: 3),
                                Text(
                                  'Setup profile contact info and monthly salary package',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
                            onPressed: () => Navigator.pop(dialogContext),
                          ),
                        ],
                      ),
                    ),

                    // 2. Form Content Body
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(22),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Section 1: Personal & Contact Details
                            _buildSectionHeader('1. PERSONAL & CONTACT DETAILS', Icons.badge_outlined, isDark),
                            const SizedBox(height: 10),

                            _inputField('Full Legal Name', nameController, Icons.person_rounded, isDark, hintText: 'e.g. Farhan Tariq'),
                            const SizedBox(height: 10),

                            _inputField('Phone Number', phoneController, Icons.phone_rounded, isDark, hintText: 'e.g. +92 300 1234567'),
                            const SizedBox(height: 10),

                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.fingerprint_rounded, size: 16, color: AppColors.primaryRed),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Assigned ID: $employeeId',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? Colors.white : AppColors.textPrimary),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    'Status: Active (Joining Today)',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF86EFAC) : const Color(0xFF16A34A)),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 20),

                            // Section 2: Compensation & Payroll
                            _buildSectionHeader('2. COMPENSATION & SALARY', Icons.payments_outlined, isDark),
                            const SizedBox(height: 10),

                            _inputField(
                              'Monthly Base Salary (PKR)',
                              salaryController,
                              Icons.payments_rounded,
                              isDark,
                              isNumber: true,
                              hintText: 'e.g. 65000',
                              onChanged: (_) => setDialogState(() {}),
                            ),

                            const SizedBox(height: 12),

                            // Dynamic Net Salary Preview Card
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF142E18) : const Color(0xFFEBF7ED),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFF86EFAC)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.calculate_rounded, color: Color(0xFF16A34A), size: 22),
                                      const SizedBox(width: 10),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'OFFERED MONTHLY SALARY',
                                            style: TextStyle(
                                              color: Color(0xFF15803D),
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'PKR ${baseSalary.toStringAsFixed(0)} / month',
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF166534)),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '~PKR $hourlyEst / hr',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 14,
                                          color: Color(0xFF15803D),
                                        ),
                                      ),
                                      const Text(
                                        'Standard 160 hrs / mo',
                                        style: TextStyle(fontSize: 10, color: Color(0xFF166534)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // 3. Action Footer
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0B1120) : const Color(0xFFF8FAFC),
                        border: Border(top: BorderSide(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0))),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            child: const Text('CANCEL', style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            height: 44,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: AppColors.brandGradient,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primaryRed.withValues(alpha: 0.35),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  final name = nameController.text.trim();
                                  if (name.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Please enter employee full name!'), backgroundColor: AppColors.danger),
                                    );
                                    return;
                                  }

                                  final finalSalary = double.tryParse(salaryController.text.trim()) ?? 65000;

                                  final newStaff = StaffMember(
                                    id: employeeId,
                                    fullName: name,
                                    phone: phoneController.text.trim().isEmpty ? '+92 300 0000000' : phoneController.text.trim(),
                                    role: UserRole.cashier,
                                    hourlyRate: finalSalary / 160,
                                    assignedShift: 'Standard Shift',
                                    monthlySalary: finalSalary,
                                    isSalaryPaid: false,
                                    status: 'Active',
                                    joiningDate: 'Today',
                                  );

                                  ref.read(staffProvider.notifier).addStaffMember(newStaff);
                                  Navigator.pop(dialogContext);

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Employee "$name" registered successfully!'),
                                      backgroundColor: const Color(0xFF16A34A),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.check_circle_rounded, size: 18, color: Colors.white),
                                label: const Text(
                                  'REGISTER & ONBOARD USER',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  padding: const EdgeInsets.symmetric(horizontal: 20),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ),
                          ),
                        ],
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

  Widget _buildSectionHeader(String title, IconData icon, bool isDark) {
    return Row(
      children: [
        Icon(icon, size: 15, color: AppColors.primaryRed),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.6,
            color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _inputField(
    String label,
    TextEditingController controller,
    IconData icon,
    bool isDark, {
    bool isNumber = false,
    String? hintText,
    Function(String)? onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      onChanged: onChanged,
      style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary, fontSize: 12),
        hintText: hintText,
        hintStyle: TextStyle(color: isDark ? const Color(0xFF64748B) : AppColors.textMuted, fontSize: 12),
        prefixIcon: Icon(icon, color: AppColors.primaryRed, size: 18),
        filled: true,
        fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primaryRed, width: 2)),
      ),
    );
  }
}

class TextStyleHelper {
  static Widget mutedText(String text, bool isDark) {
    return Text(
      text,
      style: TextStyle(
        color: isDark ? Colors.white54 : AppColors.textMuted,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}
