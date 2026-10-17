class CustomerModel {
  final String id;
  final String fullName;
  final String phone;
  final String email;
  final int loyaltyPoints;
  final int totalOrdersCount;
  final double totalSpent;
  final DateTime? birthDate;
  final String address;
  final String specialNotes;

  const CustomerModel({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.email,
    this.loyaltyPoints = 0,
    this.totalOrdersCount = 0,
    this.totalSpent = 0.0,
    this.birthDate,
    this.address = '',
    this.specialNotes = '',
  });

  bool get hasBirthdayOffer {
    if (birthDate == null) return false;
    final now = DateTime.now();
    return birthDate!.month == now.month && birthDate!.day == now.day;
  }

  factory CustomerModel.fromBackendJson(Map<String, dynamic> json) {
    return CustomerModel(
      id: json['id']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      loyaltyPoints: (json['loyalty_points'] as num?)?.toInt() ?? 0,
      totalOrdersCount: (json['total_orders_count'] as num?)?.toInt() ?? 0,
      totalSpent: double.tryParse(json['total_spent']?.toString() ?? '0') ?? 0.0,
      birthDate: json['birth_date'] != null
          ? DateTime.tryParse(json['birth_date'].toString())
          : null,
      address: json['address']?.toString() ?? '',
      specialNotes: json['special_notes']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toCreateDto() {
    return {
      'full_name': fullName,
      'phone': phone,
      'email': email,
      'address': address,
      if (birthDate != null) 'birth_date': birthDate!.toIso8601String().split('T')[0],
      'special_notes': specialNotes,
    };
  }
}
