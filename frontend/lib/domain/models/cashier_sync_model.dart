import 'package:flutter/material.dart';

class CashierShiftModel {
  final String id;
  final String shiftName;
  final String cashierId;
  final String cashierName;
  final String date;
  final String status; // 'ACTIVE', 'OFFLINE_CLOSED', 'CLOSED'
  final double startingCash;
  final DateTime createdAt;
  final DateTime? submittedAt;
  final int totalOrdersCount;

  const CashierShiftModel({
    required this.id,
    required this.shiftName,
    required this.cashierId,
    required this.cashierName,
    required this.date,
    required this.status,
    required this.startingCash,
    required this.createdAt,
    this.submittedAt,
    this.totalOrdersCount = 0,
  });

  bool get isActive => status == 'ACTIVE';

  factory CashierShiftModel.fromJson(Map<String, dynamic> json) {
    return CashierShiftModel(
      id: json['id']?.toString() ?? '',
      shiftName: json['shift_name']?.toString() ?? 'Full Day',
      cashierId: json['cashier_id']?.toString() ?? '',
      cashierName: json['cashier_name']?.toString() ?? 'Cashier',
      date: json['date']?.toString() ?? '',
      status: json['status']?.toString() ?? 'ACTIVE',
      startingCash: double.tryParse(json['starting_cash']?.toString() ?? '0') ?? 0.0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      submittedAt: json['submitted_at'] != null
          ? DateTime.tryParse(json['submitted_at'].toString())
          : null,
      totalOrdersCount: (json['total_orders_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class CashierShiftOrderModel {
  final String id;
  final String orderNumber;
  final String orderType;
  final String rawOrderType;
  final String? tableNumber;
  final String customerName;
  final String status;
  final bool isPaid;
  final double grandTotal;
  final String syncStatus; // 'synced', 'pending', 'failed'
  final bool isSynced;
  final DateTime createdAt;
  final DateTime? syncedAt;
  final String deviceId;
  final int retryCount;
  final String? errorMessage;
  final String? operationId;

  const CashierShiftOrderModel({
    required this.id,
    required this.orderNumber,
    required this.orderType,
    required this.rawOrderType,
    this.tableNumber,
    required this.customerName,
    required this.status,
    required this.isPaid,
    required this.grandTotal,
    required this.syncStatus,
    required this.isSynced,
    required this.createdAt,
    this.syncedAt,
    this.deviceId = 'POS-01',
    this.retryCount = 0,
    this.errorMessage,
    this.operationId,
  });

  factory CashierShiftOrderModel.fromJson(Map<String, dynamic> json) {
    return CashierShiftOrderModel(
      id: json['id']?.toString() ?? '',
      orderNumber: json['order_number']?.toString() ?? '',
      orderType: json['order_type']?.toString() ?? 'Dine-In',
      rawOrderType: json['raw_order_type']?.toString() ?? 'dineIn',
      tableNumber: json['table_number']?.toString(),
      customerName: json['customer_name']?.toString() ?? 'Guest',
      status: json['status']?.toString() ?? 'accepted',
      isPaid: json['is_paid'] == true,
      grandTotal: double.tryParse(json['grand_total']?.toString() ?? '0') ?? 0.0,
      syncStatus: json['sync_status']?.toString() ?? 'synced',
      isSynced: json['is_synced'] == true,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      syncedAt: json['synced_at'] != null
          ? DateTime.tryParse(json['synced_at'].toString())
          : null,
      deviceId: json['device_id']?.toString() ?? 'POS-01',
      retryCount: (json['retry_count'] as num?)?.toInt() ?? 0,
      errorMessage: json['error_message']?.toString(),
      operationId: json['operation_id']?.toString(),
    );
  }
}

class CashierSyncSummary {
  final int totalOrders;
  final int uploadedCount;
  final int pendingCount;
  final int failedCount;
  final String lastSyncTime;

  const CashierSyncSummary({
    this.totalOrders = 0,
    this.uploadedCount = 0,
    this.pendingCount = 0,
    this.failedCount = 0,
    this.lastSyncTime = '',
  });

  factory CashierSyncSummary.fromJson(Map<String, dynamic> json) {
    return CashierSyncSummary(
      totalOrders: (json['total_orders'] as num?)?.toInt() ?? 0,
      uploadedCount: (json['uploaded_count'] as num?)?.toInt() ?? 0,
      pendingCount: (json['pending_count'] as num?)?.toInt() ?? 0,
      failedCount: (json['failed_count'] as num?)?.toInt() ?? 0,
      lastSyncTime: json['last_sync_time']?.toString() ?? '',
    );
  }
}

class CashierSyncTimelineEvent {
  final DateTime time;
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  const CashierSyncTimelineEvent({
    required this.time,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}
