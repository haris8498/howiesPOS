import 'user_role.dart';

class StaffMember {
  final String id;
  final String fullName;
  final String phone;
  final UserRole role;
  final double hourlyRate;
  final String assignedShift;
  final double monthlySalary;
  final bool isSalaryPaid;
  final DateTime? salaryPaidDate;
  final String status;
  final String joiningDate;
  final String? leavingDate;

  const StaffMember({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.role,
    required this.hourlyRate,
    required this.assignedShift,
    this.monthlySalary = 65000.0,
    this.isSalaryPaid = false,
    this.salaryPaidDate,
    this.status = 'Active',
    this.joiningDate = '01 Jan 2024',
    this.leavingDate,
  });

  double get netSalary => monthlySalary;

  StaffMember copyWith({
    String? id,
    String? fullName,
    String? phone,
    UserRole? role,
    double? hourlyRate,
    String? assignedShift,
    double? monthlySalary,
    bool? isSalaryPaid,
    DateTime? salaryPaidDate,
    String? status,
    String? joiningDate,
    String? leavingDate,
  }) {
    return StaffMember(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      hourlyRate: hourlyRate ?? this.hourlyRate,
      assignedShift: assignedShift ?? this.assignedShift,
      monthlySalary: monthlySalary ?? this.monthlySalary,
      isSalaryPaid: isSalaryPaid ?? this.isSalaryPaid,
      salaryPaidDate: salaryPaidDate ?? this.salaryPaidDate,
      status: status ?? this.status,
      joiningDate: joiningDate ?? this.joiningDate,
      leavingDate: leavingDate ?? this.leavingDate,
    );
  }

  factory StaffMember.fromBackendJson(Map<String, dynamic> json) {
    UserRole parsedRole = UserRole.cashier;
    final roleStr = json['role']?.toString().toLowerCase() ?? '';
    if (roleStr == 'owner' || roleStr == 'superadmin') {
      parsedRole = UserRole.owner;
    } else if (roleStr == 'manager' || roleStr == 'storemanager') {
      parsedRole = UserRole.manager;
    }

    DateTime? joiningDt;
    if (json['joining_date'] != null) {
      joiningDt = DateTime.tryParse(json['joining_date'].toString());
    }

    DateTime? leavingDt;
    if (json['leaving_date'] != null) {
      leavingDt = DateTime.tryParse(json['leaving_date'].toString());
    }

    String formattedJoining = '01 Jan 2024';
    if (joiningDt != null) {
      formattedJoining = '${joiningDt.day.toString().padLeft(2, '0')}/${joiningDt.month.toString().padLeft(2, '0')}/${joiningDt.year}';
    }

    String? formattedLeaving;
    if (leavingDt != null) {
      formattedLeaving = '${leavingDt.day.toString().padLeft(2, '0')}/${leavingDt.month.toString().padLeft(2, '0')}/${leavingDt.year}';
    }

    return StaffMember(
      id: json['id']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      role: parsedRole,
      hourlyRate: double.tryParse(json['hourly_rate']?.toString() ?? '406') ?? 406.0,
      assignedShift: json['assigned_shift']?.toString() ?? 'Morning Shift',
      monthlySalary: double.tryParse(json['monthly_salary']?.toString() ?? '65000') ?? 65000.0,
      isSalaryPaid: json['is_salary_paid'] == true,
      salaryPaidDate: json['salary_paid_date'] != null
          ? DateTime.tryParse(json['salary_paid_date'].toString())
          : null,
      status: json['status']?.toString() ?? 'Active',
      joiningDate: formattedJoining,
      leavingDate: formattedLeaving,
    );
  }
}
