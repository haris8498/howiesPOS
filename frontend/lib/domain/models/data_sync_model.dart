class DataSyncSummary {
  final int totalOrders;
  final double totalRevenue;
  final int syncedCount;
  final int pendingCount;
  final String lastSyncTimestamp;
  final String sqliteStorageStatus;
  final String cloudStorageStatus;

  const DataSyncSummary({
    this.totalOrders = 0,
    this.totalRevenue = 0.0,
    this.syncedCount = 0,
    this.pendingCount = 0,
    this.lastSyncTimestamp = '',
    this.sqliteStorageStatus = 'HEALTHY',
    this.cloudStorageStatus = 'CONNECTED',
  });

  factory DataSyncSummary.fromJson(Map<String, dynamic> json) {
    return DataSyncSummary(
      totalOrders: (json['total_orders'] as num?)?.toInt() ?? 0,
      totalRevenue: double.tryParse(json['total_revenue']?.toString() ?? '0') ?? 0.0,
      syncedCount: (json['synced_count'] as num?)?.toInt() ?? 0,
      pendingCount: (json['pending_count'] as num?)?.toInt() ?? 0,
      lastSyncTimestamp: json['last_sync_timestamp']?.toString() ?? '',
      sqliteStorageStatus: json['sqlite_storage_status']?.toString() ?? 'HEALTHY',
      cloudStorageStatus: json['cloud_storage_status']?.toString() ?? 'CONNECTED',
    );
  }
}

class DataSyncOrder {
  final String id;
  final String orderNumber;
  final String orderType;
  final String rawOrderType;
  final String typeAndTable;
  final String customerName;
  final String itemsSummary;
  final String paymentMethod;
  final String paymentStatus;
  final bool isPaid;
  final double totalAmount;
  final DateTime createdAt;
  final String syncStatus; // 'synced', 'pending', 'failed'
  final bool isSynced;
  final DateTime? syncedAt;
  final String localSqliteId;
  final String deviceId;
  final String sourceStorage;
  final String targetStorage;

  const DataSyncOrder({
    required this.id,
    required this.orderNumber,
    required this.orderType,
    required this.rawOrderType,
    required this.typeAndTable,
    required this.customerName,
    required this.itemsSummary,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.isPaid,
    required this.totalAmount,
    required this.createdAt,
    this.syncStatus = 'synced',
    this.isSynced = true,
    this.syncedAt,
    this.localSqliteId = 'SQLITE-01',
    this.deviceId = 'POS-TERMINAL-01',
    this.sourceStorage = 'SQLite Local',
    this.targetStorage = 'PostgreSQL Cloud',
  });

  factory DataSyncOrder.fromJson(Map<String, dynamic> json) {
    return DataSyncOrder(
      id: json['id']?.toString() ?? '',
      orderNumber: json['order_number']?.toString() ?? '',
      orderType: json['order_type']?.toString() ?? 'Dine-In',
      rawOrderType: json['raw_order_type']?.toString() ?? 'dineIn',
      typeAndTable: json['type_and_table']?.toString() ?? 'Main Hall',
      customerName: json['customer_name']?.toString() ?? 'Table Guest',
      itemsSummary: json['items_summary']?.toString() ?? '',
      paymentMethod: json['payment_method']?.toString() ?? 'Cash',
      paymentStatus: json['payment_status']?.toString() ?? 'PAID',
      isPaid: json['is_paid'] == true,
      totalAmount: double.tryParse(json['total_amount']?.toString() ?? '0') ?? 0.0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      syncStatus: json['sync_status']?.toString() ?? 'synced',
      isSynced: json['is_synced'] == true,
      syncedAt: json['synced_at'] != null ? DateTime.tryParse(json['synced_at'].toString()) : null,
      localSqliteId: json['local_sqlite_id']?.toString() ?? 'SQLITE-LOCAL',
      deviceId: json['device_id']?.toString() ?? 'POS-TERMINAL-01',
      sourceStorage: json['source_storage']?.toString() ?? 'SQLite Local',
      targetStorage: json['target_storage']?.toString() ?? 'PostgreSQL Cloud',
    );
  }
}
