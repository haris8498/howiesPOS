import re

path = 'c:/flutter/Howies POS/frontend/lib/data/staff_repository.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Remove Mock Initialization
content = content.replace("staffMembers: MockApiService.getInitialStaff(),", "staffMembers: [],")
content = content.replace("super(StaffState(", "super(const StaffState(")

# 2. Fix addStaffMember
old_add_staff = """  Future<void> addStaffMember(StaffMember member) async {
    try {
      final res = await _staffApiService.createStaff(
        fullName: member.fullName,
        email: member.email,
        phone: member.phone,
        role: member.role.name,
        assignedShift: member.assignedShift,
        monthlySalary: member.monthlySalary,
        hourlyRate: member.hourlyRate,
        allowance: member.allowance,
        deductions: member.deductions,
      );
      final created = StaffMember.fromBackendJson(res);
      state = state.copyWith(staffMembers: [...state.staffMembers, created]);
    } catch (_) {
      state = state.copyWith(staffMembers: [...state.staffMembers, member]);
    }
  }"""
new_add_staff = """  Future<void> addStaffMember(StaffMember member) async {
    final res = await _staffApiService.createStaff(
      fullName: member.fullName,
      email: member.email,
      phone: member.phone,
      role: member.role.name,
      assignedShift: member.assignedShift,
      monthlySalary: member.monthlySalary,
      hourlyRate: member.hourlyRate,
      allowance: member.allowance,
      deductions: member.deductions,
    );
    final created = StaffMember.fromBackendJson(res);
    state = state.copyWith(staffMembers: [...state.staffMembers, created]);
  }"""
content = content.replace(old_add_staff, new_add_staff)

# 3. Fix toggleClockIn
old_toggle_clock = """  Future<void> toggleClockIn(String id) async {
    try {
      await _staffApiService.toggleClock(id);
    } catch (_) {}

    final updated = state.staffMembers.map((s) {
      if (s.id == id) {
        return s.copyWith(
          isClockedIn: !s.isClockedIn,
          clockInTime: !s.isClockedIn ? DateTime.now() : null,
        );
      }
      return s;
    }).toList();
    state = state.copyWith(staffMembers: updated);
  }"""
new_toggle_clock = """  Future<void> toggleClockIn(String id) async {
    await _staffApiService.toggleClock(id);

    final updated = state.staffMembers.map((s) {
      if (s.id == id) {
        return s.copyWith(
          isClockedIn: !s.isClockedIn,
          clockInTime: !s.isClockedIn ? DateTime.now() : null,
        );
      }
      return s;
    }).toList();
    state = state.copyWith(staffMembers: updated);
  }"""
content = content.replace(old_toggle_clock, new_toggle_clock)

# 4. Fix toggleSalaryPaid
old_toggle_salary = """  Future<void> toggleSalaryPaid(String id) async {
    try {
      await _staffApiService.toggleSalary(id);
    } catch (_) {}

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
  }"""
new_toggle_salary = """  Future<void> toggleSalaryPaid(String id) async {
    await _staffApiService.toggleSalary(id);

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
  }"""
content = content.replace(old_toggle_salary, new_toggle_salary)

# 5. Fix deleteStaffMember
old_delete = """  Future<void> deleteStaffMember(String id) async {
    try {
      await _staffApiService.deleteStaff(id);
    } catch (_) {}
    final updated = state.staffMembers.where((s) => s.id != id).toList();
    state = state.copyWith(staffMembers: updated);
  }"""
new_delete = """  Future<void> deleteStaffMember(String id) async {
    await _staffApiService.deleteStaff(id);
    final updated = state.staffMembers.where((s) => s.id != id).toList();
    state = state.copyWith(staffMembers: updated);
  }"""
content = content.replace(old_delete, new_delete)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
