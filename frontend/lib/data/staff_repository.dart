import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/models/staff_model.dart';
import '../services/api/api_providers.dart';
import '../services/api/staff_api_service.dart';

class StaffState {
  final List<StaffMember> staffMembers;
  final DateTime selectedMonth;
  final bool isLoading;

  StaffState({
    required this.staffMembers,
    DateTime? selectedMonth,
    this.isLoading = false,
  }) : selectedMonth = selectedMonth ?? DateTime(DateTime.now().year, DateTime.now().month);

  String get selectedMonthYearKey =>
      '${selectedMonth.month.toString().padLeft(2, '0')}-${selectedMonth.year}';

  String get selectedMonthDisplayName {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[selectedMonth.month - 1]} ${selectedMonth.year}';
  }

  double get totalMonthlyPayroll => staffMembers.fold(0.0, (sum, s) => sum + s.netSalary);
  double get paidPayroll => staffMembers.where((s) => s.isSalaryPaid).fold(0.0, (sum, s) => sum + s.netSalary);
  double get pendingPayroll => staffMembers.where((s) => !s.isSalaryPaid).fold(0.0, (sum, s) => sum + s.netSalary);
  int get paidCount => staffMembers.where((s) => s.isSalaryPaid).length;
  int get pendingCount => staffMembers.where((s) => !s.isSalaryPaid).length;

  StaffState copyWith({
    List<StaffMember>? staffMembers,
    DateTime? selectedMonth,
    bool? isLoading,
  }) {
    return StaffState(
      staffMembers: staffMembers ?? this.staffMembers,
      selectedMonth: selectedMonth ?? this.selectedMonth,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class StaffNotifier extends StateNotifier<StaffState> {
  final StaffApiService _staffApiService;

  StaffNotifier({StaffApiService? staffApiService})
      : _staffApiService = staffApiService ?? StaffApiService(),
        super(StaffState(
          staffMembers: [],
        )) {
    loadStaff();
  }

  Future<void> loadStaff({DateTime? targetMonth}) async {
    final month = targetMonth ?? state.selectedMonth;
    final monthYearKey = '${month.month.toString().padLeft(2, '0')}-${month.year}';
    state = state.copyWith(isLoading: true, selectedMonth: month);
    try {
      final jsonList = await _staffApiService.listStaff(monthYear: monthYearKey);
      final staff = jsonList.map((j) => StaffMember.fromBackendJson(j)).toList();
      state = state.copyWith(staffMembers: staff, isLoading: false, selectedMonth: month);
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> selectMonth(DateTime newMonth) async {
    await loadStaff(targetMonth: newMonth);
  }

  Future<void> toggleSalaryPaid(String id) async {
    final monthYearKey = state.selectedMonthYearKey;
    try {
      final res = await _staffApiService.toggleSalary(id, monthYear: monthYearKey);
      if (res.isNotEmpty) {
        final updatedMember = StaffMember.fromBackendJson(res);
        final updated = state.staffMembers.map((s) {
          if (s.id == id) return updatedMember;
          return s;
        }).toList();
        state = state.copyWith(staffMembers: updated);
        return;
      }
    } catch (_) {}

    // Local fallback update and reload
    final updated = state.staffMembers.map((s) {
      if (s.id == id) {
        final newStatus = !s.isSalaryPaid;
        return s.copyWith(
          isSalaryPaid: newStatus,
          salaryPaidDate: newStatus ? DateTime.now() : null,
        );
      }
      return s;
    }).toList();
    state = state.copyWith(staffMembers: updated);
    await loadStaff();
  }

  Future<void> settleSalary(String id) async {
    final monthYearKey = state.selectedMonthYearKey;
    try {
      final res = await _staffApiService.settleSalary(id, monthYear: monthYearKey);
      if (res.isNotEmpty) {
        final updatedMember = StaffMember.fromBackendJson(res);
        final updated = state.staffMembers.map((s) {
          if (s.id == id) return updatedMember;
          return s;
        }).toList();
        state = state.copyWith(staffMembers: updated);
        return;
      }
    } catch (_) {}
    await loadStaff();
  }

  Future<void> addStaffMember(StaffMember member) async {
    try {
      final res = await _staffApiService.createStaff(
        fullName: member.fullName,
        phone: member.phone,
        role: member.role.name,
        assignedShift: member.assignedShift,
        monthlySalary: member.monthlySalary,
        hourlyRate: member.hourlyRate,
      );
      if (res.isNotEmpty) {
        await loadStaff();
        return;
      }
    } catch (_) {}
    await loadStaff();
  }

  Future<void> deleteStaffMember(String id) async {
    try {
      await _staffApiService.deleteStaff(id);
      final updated = state.staffMembers.where((s) => s.id != id).toList();
      state = state.copyWith(staffMembers: updated);
    } catch (_) {
      await loadStaff();
    }
  }
}

final staffProvider = StateNotifierProvider<StaffNotifier, StaffState>((ref) {
  final staffApi = ref.watch(staffApiServiceProvider);
  return StaffNotifier(staffApiService: staffApi);
});
