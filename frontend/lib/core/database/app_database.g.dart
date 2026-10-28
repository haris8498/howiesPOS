// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $LocalOrdersTable extends LocalOrders
    with TableInfo<$LocalOrdersTable, LocalOrder> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalOrdersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 36,
      maxTextLength: 36,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _orderNumberMeta = const VerificationMeta(
    'orderNumber',
  );
  @override
  late final GeneratedColumn<String> orderNumber = GeneratedColumn<String>(
    'order_number',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 30,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _orderTypeMeta = const VerificationMeta(
    'orderType',
  );
  @override
  late final GeneratedColumn<String> orderType = GeneratedColumn<String>(
    'order_type',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 30,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _shiftIdMeta = const VerificationMeta(
    'shiftId',
  );
  @override
  late final GeneratedColumn<String> shiftId = GeneratedColumn<String>(
    'shift_id',
    aliasedName,
    true,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 36,
      maxTextLength: 36,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 30,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('newOrder'),
  );
  static const VerificationMeta _subtotalMeta = const VerificationMeta(
    'subtotal',
  );
  @override
  late final GeneratedColumn<double> subtotal = GeneratedColumn<double>(
    'subtotal',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _discountPercentageMeta =
      const VerificationMeta('discountPercentage');
  @override
  late final GeneratedColumn<double> discountPercentage =
      GeneratedColumn<double>(
        'discount_percentage',
        aliasedName,
        false,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
        defaultValue: const Constant(0.0),
      );
  static const VerificationMeta _discountAmountMeta = const VerificationMeta(
    'discountAmount',
  );
  @override
  late final GeneratedColumn<double> discountAmount = GeneratedColumn<double>(
    'discount_amount',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  static const VerificationMeta _taxAmountMeta = const VerificationMeta(
    'taxAmount',
  );
  @override
  late final GeneratedColumn<double> taxAmount = GeneratedColumn<double>(
    'tax_amount',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  static const VerificationMeta _grandTotalMeta = const VerificationMeta(
    'grandTotal',
  );
  @override
  late final GeneratedColumn<double> grandTotal = GeneratedColumn<double>(
    'grand_total',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _paymentStatusMeta = const VerificationMeta(
    'paymentStatus',
  );
  @override
  late final GeneratedColumn<String> paymentStatus = GeneratedColumn<String>(
    'payment_status',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 20,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('UNPAID'),
  );
  static const VerificationMeta _isPaidMeta = const VerificationMeta('isPaid');
  @override
  late final GeneratedColumn<bool> isPaid = GeneratedColumn<bool>(
    'is_paid',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_paid" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isHeldMeta = const VerificationMeta('isHeld');
  @override
  late final GeneratedColumn<bool> isHeld = GeneratedColumn<bool>(
    'is_held',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_held" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _kitchenTicketSentMeta = const VerificationMeta(
    'kitchenTicketSent',
  );
  @override
  late final GeneratedColumn<bool> kitchenTicketSent = GeneratedColumn<bool>(
    'kitchen_ticket_sent',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("kitchen_ticket_sent" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _rejectionReasonMeta = const VerificationMeta(
    'rejectionReason',
  );
  @override
  late final GeneratedColumn<String> rejectionReason = GeneratedColumn<String>(
    'rejection_reason',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 50,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<String> syncStatus = GeneratedColumn<String>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending_insert'),
  );
  static const VerificationMeta _serverVersionMeta = const VerificationMeta(
    'serverVersion',
  );
  @override
  late final GeneratedColumn<int> serverVersion = GeneratedColumn<int>(
    'server_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _clientUpdatedAtMeta = const VerificationMeta(
    'clientUpdatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> clientUpdatedAt =
      GeneratedColumn<DateTime>(
        'client_updated_at',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
        defaultValue: currentDateAndTime,
      );
  static const VerificationMeta _serverUpdatedAtMeta = const VerificationMeta(
    'serverUpdatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> serverUpdatedAt =
      GeneratedColumn<DateTime>(
        'server_updated_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    orderNumber,
    orderType,
    shiftId,
    status,
    subtotal,
    discountPercentage,
    discountAmount,
    taxAmount,
    grandTotal,
    paymentStatus,
    isPaid,
    isHeld,
    kitchenTicketSent,
    rejectionReason,
    deviceId,
    createdAt,
    syncStatus,
    serverVersion,
    clientUpdatedAt,
    serverUpdatedAt,
    isDeleted,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_orders';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalOrder> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('order_number')) {
      context.handle(
        _orderNumberMeta,
        orderNumber.isAcceptableOrUnknown(
          data['order_number']!,
          _orderNumberMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_orderNumberMeta);
    }
    if (data.containsKey('order_type')) {
      context.handle(
        _orderTypeMeta,
        orderType.isAcceptableOrUnknown(data['order_type']!, _orderTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_orderTypeMeta);
    }
    if (data.containsKey('shift_id')) {
      context.handle(
        _shiftIdMeta,
        shiftId.isAcceptableOrUnknown(data['shift_id']!, _shiftIdMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('subtotal')) {
      context.handle(
        _subtotalMeta,
        subtotal.isAcceptableOrUnknown(data['subtotal']!, _subtotalMeta),
      );
    } else if (isInserting) {
      context.missing(_subtotalMeta);
    }
    if (data.containsKey('discount_percentage')) {
      context.handle(
        _discountPercentageMeta,
        discountPercentage.isAcceptableOrUnknown(
          data['discount_percentage']!,
          _discountPercentageMeta,
        ),
      );
    }
    if (data.containsKey('discount_amount')) {
      context.handle(
        _discountAmountMeta,
        discountAmount.isAcceptableOrUnknown(
          data['discount_amount']!,
          _discountAmountMeta,
        ),
      );
    }
    if (data.containsKey('tax_amount')) {
      context.handle(
        _taxAmountMeta,
        taxAmount.isAcceptableOrUnknown(data['tax_amount']!, _taxAmountMeta),
      );
    }
    if (data.containsKey('grand_total')) {
      context.handle(
        _grandTotalMeta,
        grandTotal.isAcceptableOrUnknown(data['grand_total']!, _grandTotalMeta),
      );
    } else if (isInserting) {
      context.missing(_grandTotalMeta);
    }
    if (data.containsKey('payment_status')) {
      context.handle(
        _paymentStatusMeta,
        paymentStatus.isAcceptableOrUnknown(
          data['payment_status']!,
          _paymentStatusMeta,
        ),
      );
    }
    if (data.containsKey('is_paid')) {
      context.handle(
        _isPaidMeta,
        isPaid.isAcceptableOrUnknown(data['is_paid']!, _isPaidMeta),
      );
    }
    if (data.containsKey('is_held')) {
      context.handle(
        _isHeldMeta,
        isHeld.isAcceptableOrUnknown(data['is_held']!, _isHeldMeta),
      );
    }
    if (data.containsKey('kitchen_ticket_sent')) {
      context.handle(
        _kitchenTicketSentMeta,
        kitchenTicketSent.isAcceptableOrUnknown(
          data['kitchen_ticket_sent']!,
          _kitchenTicketSentMeta,
        ),
      );
    }
    if (data.containsKey('rejection_reason')) {
      context.handle(
        _rejectionReasonMeta,
        rejectionReason.isAcceptableOrUnknown(
          data['rejection_reason']!,
          _rejectionReasonMeta,
        ),
      );
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    if (data.containsKey('server_version')) {
      context.handle(
        _serverVersionMeta,
        serverVersion.isAcceptableOrUnknown(
          data['server_version']!,
          _serverVersionMeta,
        ),
      );
    }
    if (data.containsKey('client_updated_at')) {
      context.handle(
        _clientUpdatedAtMeta,
        clientUpdatedAt.isAcceptableOrUnknown(
          data['client_updated_at']!,
          _clientUpdatedAtMeta,
        ),
      );
    }
    if (data.containsKey('server_updated_at')) {
      context.handle(
        _serverUpdatedAtMeta,
        serverUpdatedAt.isAcceptableOrUnknown(
          data['server_updated_at']!,
          _serverUpdatedAtMeta,
        ),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalOrder map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalOrder(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      orderNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}order_number'],
      )!,
      orderType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}order_type'],
      )!,
      shiftId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}shift_id'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      subtotal: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}subtotal'],
      )!,
      discountPercentage: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}discount_percentage'],
      )!,
      discountAmount: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}discount_amount'],
      )!,
      taxAmount: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}tax_amount'],
      )!,
      grandTotal: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}grand_total'],
      )!,
      paymentStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payment_status'],
      )!,
      isPaid: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_paid'],
      )!,
      isHeld: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_held'],
      )!,
      kitchenTicketSent: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}kitchen_ticket_sent'],
      )!,
      rejectionReason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rejection_reason'],
      ),
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      syncStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_status'],
      )!,
      serverVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_version'],
      )!,
      clientUpdatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}client_updated_at'],
      )!,
      serverUpdatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}server_updated_at'],
      ),
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
    );
  }

  @override
  $LocalOrdersTable createAlias(String alias) {
    return $LocalOrdersTable(attachedDatabase, alias);
  }
}

class LocalOrder extends DataClass implements Insertable<LocalOrder> {
  final String id;
  final String orderNumber;
  final String orderType;
  final String? shiftId;
  final String status;
  final double subtotal;
  final double discountPercentage;
  final double discountAmount;
  final double taxAmount;
  final double grandTotal;
  final String paymentStatus;
  final bool isPaid;
  final bool isHeld;
  final bool kitchenTicketSent;
  final String? rejectionReason;
  final String deviceId;
  final DateTime createdAt;
  final String syncStatus;
  final int serverVersion;
  final DateTime clientUpdatedAt;
  final DateTime? serverUpdatedAt;
  final bool isDeleted;
  const LocalOrder({
    required this.id,
    required this.orderNumber,
    required this.orderType,
    this.shiftId,
    required this.status,
    required this.subtotal,
    required this.discountPercentage,
    required this.discountAmount,
    required this.taxAmount,
    required this.grandTotal,
    required this.paymentStatus,
    required this.isPaid,
    required this.isHeld,
    required this.kitchenTicketSent,
    this.rejectionReason,
    required this.deviceId,
    required this.createdAt,
    required this.syncStatus,
    required this.serverVersion,
    required this.clientUpdatedAt,
    this.serverUpdatedAt,
    required this.isDeleted,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['order_number'] = Variable<String>(orderNumber);
    map['order_type'] = Variable<String>(orderType);
    if (!nullToAbsent || shiftId != null) {
      map['shift_id'] = Variable<String>(shiftId);
    }
    map['status'] = Variable<String>(status);
    map['subtotal'] = Variable<double>(subtotal);
    map['discount_percentage'] = Variable<double>(discountPercentage);
    map['discount_amount'] = Variable<double>(discountAmount);
    map['tax_amount'] = Variable<double>(taxAmount);
    map['grand_total'] = Variable<double>(grandTotal);
    map['payment_status'] = Variable<String>(paymentStatus);
    map['is_paid'] = Variable<bool>(isPaid);
    map['is_held'] = Variable<bool>(isHeld);
    map['kitchen_ticket_sent'] = Variable<bool>(kitchenTicketSent);
    if (!nullToAbsent || rejectionReason != null) {
      map['rejection_reason'] = Variable<String>(rejectionReason);
    }
    map['device_id'] = Variable<String>(deviceId);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['sync_status'] = Variable<String>(syncStatus);
    map['server_version'] = Variable<int>(serverVersion);
    map['client_updated_at'] = Variable<DateTime>(clientUpdatedAt);
    if (!nullToAbsent || serverUpdatedAt != null) {
      map['server_updated_at'] = Variable<DateTime>(serverUpdatedAt);
    }
    map['is_deleted'] = Variable<bool>(isDeleted);
    return map;
  }

  LocalOrdersCompanion toCompanion(bool nullToAbsent) {
    return LocalOrdersCompanion(
      id: Value(id),
      orderNumber: Value(orderNumber),
      orderType: Value(orderType),
      shiftId: shiftId == null && nullToAbsent
          ? const Value.absent()
          : Value(shiftId),
      status: Value(status),
      subtotal: Value(subtotal),
      discountPercentage: Value(discountPercentage),
      discountAmount: Value(discountAmount),
      taxAmount: Value(taxAmount),
      grandTotal: Value(grandTotal),
      paymentStatus: Value(paymentStatus),
      isPaid: Value(isPaid),
      isHeld: Value(isHeld),
      kitchenTicketSent: Value(kitchenTicketSent),
      rejectionReason: rejectionReason == null && nullToAbsent
          ? const Value.absent()
          : Value(rejectionReason),
      deviceId: Value(deviceId),
      createdAt: Value(createdAt),
      syncStatus: Value(syncStatus),
      serverVersion: Value(serverVersion),
      clientUpdatedAt: Value(clientUpdatedAt),
      serverUpdatedAt: serverUpdatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(serverUpdatedAt),
      isDeleted: Value(isDeleted),
    );
  }

  factory LocalOrder.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalOrder(
      id: serializer.fromJson<String>(json['id']),
      orderNumber: serializer.fromJson<String>(json['orderNumber']),
      orderType: serializer.fromJson<String>(json['orderType']),
      shiftId: serializer.fromJson<String?>(json['shiftId']),
      status: serializer.fromJson<String>(json['status']),
      subtotal: serializer.fromJson<double>(json['subtotal']),
      discountPercentage: serializer.fromJson<double>(
        json['discountPercentage'],
      ),
      discountAmount: serializer.fromJson<double>(json['discountAmount']),
      taxAmount: serializer.fromJson<double>(json['taxAmount']),
      grandTotal: serializer.fromJson<double>(json['grandTotal']),
      paymentStatus: serializer.fromJson<String>(json['paymentStatus']),
      isPaid: serializer.fromJson<bool>(json['isPaid']),
      isHeld: serializer.fromJson<bool>(json['isHeld']),
      kitchenTicketSent: serializer.fromJson<bool>(json['kitchenTicketSent']),
      rejectionReason: serializer.fromJson<String?>(json['rejectionReason']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      syncStatus: serializer.fromJson<String>(json['syncStatus']),
      serverVersion: serializer.fromJson<int>(json['serverVersion']),
      clientUpdatedAt: serializer.fromJson<DateTime>(json['clientUpdatedAt']),
      serverUpdatedAt: serializer.fromJson<DateTime?>(json['serverUpdatedAt']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'orderNumber': serializer.toJson<String>(orderNumber),
      'orderType': serializer.toJson<String>(orderType),
      'shiftId': serializer.toJson<String?>(shiftId),
      'status': serializer.toJson<String>(status),
      'subtotal': serializer.toJson<double>(subtotal),
      'discountPercentage': serializer.toJson<double>(discountPercentage),
      'discountAmount': serializer.toJson<double>(discountAmount),
      'taxAmount': serializer.toJson<double>(taxAmount),
      'grandTotal': serializer.toJson<double>(grandTotal),
      'paymentStatus': serializer.toJson<String>(paymentStatus),
      'isPaid': serializer.toJson<bool>(isPaid),
      'isHeld': serializer.toJson<bool>(isHeld),
      'kitchenTicketSent': serializer.toJson<bool>(kitchenTicketSent),
      'rejectionReason': serializer.toJson<String?>(rejectionReason),
      'deviceId': serializer.toJson<String>(deviceId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'syncStatus': serializer.toJson<String>(syncStatus),
      'serverVersion': serializer.toJson<int>(serverVersion),
      'clientUpdatedAt': serializer.toJson<DateTime>(clientUpdatedAt),
      'serverUpdatedAt': serializer.toJson<DateTime?>(serverUpdatedAt),
      'isDeleted': serializer.toJson<bool>(isDeleted),
    };
  }

  LocalOrder copyWith({
    String? id,
    String? orderNumber,
    String? orderType,
    Value<String?> shiftId = const Value.absent(),
    String? status,
    double? subtotal,
    double? discountPercentage,
    double? discountAmount,
    double? taxAmount,
    double? grandTotal,
    String? paymentStatus,
    bool? isPaid,
    bool? isHeld,
    bool? kitchenTicketSent,
    Value<String?> rejectionReason = const Value.absent(),
    String? deviceId,
    DateTime? createdAt,
    String? syncStatus,
    int? serverVersion,
    DateTime? clientUpdatedAt,
    Value<DateTime?> serverUpdatedAt = const Value.absent(),
    bool? isDeleted,
  }) => LocalOrder(
    id: id ?? this.id,
    orderNumber: orderNumber ?? this.orderNumber,
    orderType: orderType ?? this.orderType,
    shiftId: shiftId.present ? shiftId.value : this.shiftId,
    status: status ?? this.status,
    subtotal: subtotal ?? this.subtotal,
    discountPercentage: discountPercentage ?? this.discountPercentage,
    discountAmount: discountAmount ?? this.discountAmount,
    taxAmount: taxAmount ?? this.taxAmount,
    grandTotal: grandTotal ?? this.grandTotal,
    paymentStatus: paymentStatus ?? this.paymentStatus,
    isPaid: isPaid ?? this.isPaid,
    isHeld: isHeld ?? this.isHeld,
    kitchenTicketSent: kitchenTicketSent ?? this.kitchenTicketSent,
    rejectionReason: rejectionReason.present
        ? rejectionReason.value
        : this.rejectionReason,
    deviceId: deviceId ?? this.deviceId,
    createdAt: createdAt ?? this.createdAt,
    syncStatus: syncStatus ?? this.syncStatus,
    serverVersion: serverVersion ?? this.serverVersion,
    clientUpdatedAt: clientUpdatedAt ?? this.clientUpdatedAt,
    serverUpdatedAt: serverUpdatedAt.present
        ? serverUpdatedAt.value
        : this.serverUpdatedAt,
    isDeleted: isDeleted ?? this.isDeleted,
  );
  LocalOrder copyWithCompanion(LocalOrdersCompanion data) {
    return LocalOrder(
      id: data.id.present ? data.id.value : this.id,
      orderNumber: data.orderNumber.present
          ? data.orderNumber.value
          : this.orderNumber,
      orderType: data.orderType.present ? data.orderType.value : this.orderType,
      shiftId: data.shiftId.present ? data.shiftId.value : this.shiftId,
      status: data.status.present ? data.status.value : this.status,
      subtotal: data.subtotal.present ? data.subtotal.value : this.subtotal,
      discountPercentage: data.discountPercentage.present
          ? data.discountPercentage.value
          : this.discountPercentage,
      discountAmount: data.discountAmount.present
          ? data.discountAmount.value
          : this.discountAmount,
      taxAmount: data.taxAmount.present ? data.taxAmount.value : this.taxAmount,
      grandTotal: data.grandTotal.present
          ? data.grandTotal.value
          : this.grandTotal,
      paymentStatus: data.paymentStatus.present
          ? data.paymentStatus.value
          : this.paymentStatus,
      isPaid: data.isPaid.present ? data.isPaid.value : this.isPaid,
      isHeld: data.isHeld.present ? data.isHeld.value : this.isHeld,
      kitchenTicketSent: data.kitchenTicketSent.present
          ? data.kitchenTicketSent.value
          : this.kitchenTicketSent,
      rejectionReason: data.rejectionReason.present
          ? data.rejectionReason.value
          : this.rejectionReason,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
      serverVersion: data.serverVersion.present
          ? data.serverVersion.value
          : this.serverVersion,
      clientUpdatedAt: data.clientUpdatedAt.present
          ? data.clientUpdatedAt.value
          : this.clientUpdatedAt,
      serverUpdatedAt: data.serverUpdatedAt.present
          ? data.serverUpdatedAt.value
          : this.serverUpdatedAt,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalOrder(')
          ..write('id: $id, ')
          ..write('orderNumber: $orderNumber, ')
          ..write('orderType: $orderType, ')
          ..write('shiftId: $shiftId, ')
          ..write('status: $status, ')
          ..write('subtotal: $subtotal, ')
          ..write('discountPercentage: $discountPercentage, ')
          ..write('discountAmount: $discountAmount, ')
          ..write('taxAmount: $taxAmount, ')
          ..write('grandTotal: $grandTotal, ')
          ..write('paymentStatus: $paymentStatus, ')
          ..write('isPaid: $isPaid, ')
          ..write('isHeld: $isHeld, ')
          ..write('kitchenTicketSent: $kitchenTicketSent, ')
          ..write('rejectionReason: $rejectionReason, ')
          ..write('deviceId: $deviceId, ')
          ..write('createdAt: $createdAt, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('serverVersion: $serverVersion, ')
          ..write('clientUpdatedAt: $clientUpdatedAt, ')
          ..write('serverUpdatedAt: $serverUpdatedAt, ')
          ..write('isDeleted: $isDeleted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    orderNumber,
    orderType,
    shiftId,
    status,
    subtotal,
    discountPercentage,
    discountAmount,
    taxAmount,
    grandTotal,
    paymentStatus,
    isPaid,
    isHeld,
    kitchenTicketSent,
    rejectionReason,
    deviceId,
    createdAt,
    syncStatus,
    serverVersion,
    clientUpdatedAt,
    serverUpdatedAt,
    isDeleted,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalOrder &&
          other.id == this.id &&
          other.orderNumber == this.orderNumber &&
          other.orderType == this.orderType &&
          other.shiftId == this.shiftId &&
          other.status == this.status &&
          other.subtotal == this.subtotal &&
          other.discountPercentage == this.discountPercentage &&
          other.discountAmount == this.discountAmount &&
          other.taxAmount == this.taxAmount &&
          other.grandTotal == this.grandTotal &&
          other.paymentStatus == this.paymentStatus &&
          other.isPaid == this.isPaid &&
          other.isHeld == this.isHeld &&
          other.kitchenTicketSent == this.kitchenTicketSent &&
          other.rejectionReason == this.rejectionReason &&
          other.deviceId == this.deviceId &&
          other.createdAt == this.createdAt &&
          other.syncStatus == this.syncStatus &&
          other.serverVersion == this.serverVersion &&
          other.clientUpdatedAt == this.clientUpdatedAt &&
          other.serverUpdatedAt == this.serverUpdatedAt &&
          other.isDeleted == this.isDeleted);
}

class LocalOrdersCompanion extends UpdateCompanion<LocalOrder> {
  final Value<String> id;
  final Value<String> orderNumber;
  final Value<String> orderType;
  final Value<String?> shiftId;
  final Value<String> status;
  final Value<double> subtotal;
  final Value<double> discountPercentage;
  final Value<double> discountAmount;
  final Value<double> taxAmount;
  final Value<double> grandTotal;
  final Value<String> paymentStatus;
  final Value<bool> isPaid;
  final Value<bool> isHeld;
  final Value<bool> kitchenTicketSent;
  final Value<String?> rejectionReason;
  final Value<String> deviceId;
  final Value<DateTime> createdAt;
  final Value<String> syncStatus;
  final Value<int> serverVersion;
  final Value<DateTime> clientUpdatedAt;
  final Value<DateTime?> serverUpdatedAt;
  final Value<bool> isDeleted;
  final Value<int> rowid;
  const LocalOrdersCompanion({
    this.id = const Value.absent(),
    this.orderNumber = const Value.absent(),
    this.orderType = const Value.absent(),
    this.shiftId = const Value.absent(),
    this.status = const Value.absent(),
    this.subtotal = const Value.absent(),
    this.discountPercentage = const Value.absent(),
    this.discountAmount = const Value.absent(),
    this.taxAmount = const Value.absent(),
    this.grandTotal = const Value.absent(),
    this.paymentStatus = const Value.absent(),
    this.isPaid = const Value.absent(),
    this.isHeld = const Value.absent(),
    this.kitchenTicketSent = const Value.absent(),
    this.rejectionReason = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.serverVersion = const Value.absent(),
    this.clientUpdatedAt = const Value.absent(),
    this.serverUpdatedAt = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalOrdersCompanion.insert({
    required String id,
    required String orderNumber,
    required String orderType,
    this.shiftId = const Value.absent(),
    this.status = const Value.absent(),
    required double subtotal,
    this.discountPercentage = const Value.absent(),
    this.discountAmount = const Value.absent(),
    this.taxAmount = const Value.absent(),
    required double grandTotal,
    this.paymentStatus = const Value.absent(),
    this.isPaid = const Value.absent(),
    this.isHeld = const Value.absent(),
    this.kitchenTicketSent = const Value.absent(),
    this.rejectionReason = const Value.absent(),
    required String deviceId,
    this.createdAt = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.serverVersion = const Value.absent(),
    this.clientUpdatedAt = const Value.absent(),
    this.serverUpdatedAt = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       orderNumber = Value(orderNumber),
       orderType = Value(orderType),
       subtotal = Value(subtotal),
       grandTotal = Value(grandTotal),
       deviceId = Value(deviceId);
  static Insertable<LocalOrder> custom({
    Expression<String>? id,
    Expression<String>? orderNumber,
    Expression<String>? orderType,
    Expression<String>? shiftId,
    Expression<String>? status,
    Expression<double>? subtotal,
    Expression<double>? discountPercentage,
    Expression<double>? discountAmount,
    Expression<double>? taxAmount,
    Expression<double>? grandTotal,
    Expression<String>? paymentStatus,
    Expression<bool>? isPaid,
    Expression<bool>? isHeld,
    Expression<bool>? kitchenTicketSent,
    Expression<String>? rejectionReason,
    Expression<String>? deviceId,
    Expression<DateTime>? createdAt,
    Expression<String>? syncStatus,
    Expression<int>? serverVersion,
    Expression<DateTime>? clientUpdatedAt,
    Expression<DateTime>? serverUpdatedAt,
    Expression<bool>? isDeleted,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (orderNumber != null) 'order_number': orderNumber,
      if (orderType != null) 'order_type': orderType,
      if (shiftId != null) 'shift_id': shiftId,
      if (status != null) 'status': status,
      if (subtotal != null) 'subtotal': subtotal,
      if (discountPercentage != null) 'discount_percentage': discountPercentage,
      if (discountAmount != null) 'discount_amount': discountAmount,
      if (taxAmount != null) 'tax_amount': taxAmount,
      if (grandTotal != null) 'grand_total': grandTotal,
      if (paymentStatus != null) 'payment_status': paymentStatus,
      if (isPaid != null) 'is_paid': isPaid,
      if (isHeld != null) 'is_held': isHeld,
      if (kitchenTicketSent != null) 'kitchen_ticket_sent': kitchenTicketSent,
      if (rejectionReason != null) 'rejection_reason': rejectionReason,
      if (deviceId != null) 'device_id': deviceId,
      if (createdAt != null) 'created_at': createdAt,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (serverVersion != null) 'server_version': serverVersion,
      if (clientUpdatedAt != null) 'client_updated_at': clientUpdatedAt,
      if (serverUpdatedAt != null) 'server_updated_at': serverUpdatedAt,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalOrdersCompanion copyWith({
    Value<String>? id,
    Value<String>? orderNumber,
    Value<String>? orderType,
    Value<String?>? shiftId,
    Value<String>? status,
    Value<double>? subtotal,
    Value<double>? discountPercentage,
    Value<double>? discountAmount,
    Value<double>? taxAmount,
    Value<double>? grandTotal,
    Value<String>? paymentStatus,
    Value<bool>? isPaid,
    Value<bool>? isHeld,
    Value<bool>? kitchenTicketSent,
    Value<String?>? rejectionReason,
    Value<String>? deviceId,
    Value<DateTime>? createdAt,
    Value<String>? syncStatus,
    Value<int>? serverVersion,
    Value<DateTime>? clientUpdatedAt,
    Value<DateTime?>? serverUpdatedAt,
    Value<bool>? isDeleted,
    Value<int>? rowid,
  }) {
    return LocalOrdersCompanion(
      id: id ?? this.id,
      orderNumber: orderNumber ?? this.orderNumber,
      orderType: orderType ?? this.orderType,
      shiftId: shiftId ?? this.shiftId,
      status: status ?? this.status,
      subtotal: subtotal ?? this.subtotal,
      discountPercentage: discountPercentage ?? this.discountPercentage,
      discountAmount: discountAmount ?? this.discountAmount,
      taxAmount: taxAmount ?? this.taxAmount,
      grandTotal: grandTotal ?? this.grandTotal,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      isPaid: isPaid ?? this.isPaid,
      isHeld: isHeld ?? this.isHeld,
      kitchenTicketSent: kitchenTicketSent ?? this.kitchenTicketSent,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      deviceId: deviceId ?? this.deviceId,
      createdAt: createdAt ?? this.createdAt,
      syncStatus: syncStatus ?? this.syncStatus,
      serverVersion: serverVersion ?? this.serverVersion,
      clientUpdatedAt: clientUpdatedAt ?? this.clientUpdatedAt,
      serverUpdatedAt: serverUpdatedAt ?? this.serverUpdatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (orderNumber.present) {
      map['order_number'] = Variable<String>(orderNumber.value);
    }
    if (orderType.present) {
      map['order_type'] = Variable<String>(orderType.value);
    }
    if (shiftId.present) {
      map['shift_id'] = Variable<String>(shiftId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (subtotal.present) {
      map['subtotal'] = Variable<double>(subtotal.value);
    }
    if (discountPercentage.present) {
      map['discount_percentage'] = Variable<double>(discountPercentage.value);
    }
    if (discountAmount.present) {
      map['discount_amount'] = Variable<double>(discountAmount.value);
    }
    if (taxAmount.present) {
      map['tax_amount'] = Variable<double>(taxAmount.value);
    }
    if (grandTotal.present) {
      map['grand_total'] = Variable<double>(grandTotal.value);
    }
    if (paymentStatus.present) {
      map['payment_status'] = Variable<String>(paymentStatus.value);
    }
    if (isPaid.present) {
      map['is_paid'] = Variable<bool>(isPaid.value);
    }
    if (isHeld.present) {
      map['is_held'] = Variable<bool>(isHeld.value);
    }
    if (kitchenTicketSent.present) {
      map['kitchen_ticket_sent'] = Variable<bool>(kitchenTicketSent.value);
    }
    if (rejectionReason.present) {
      map['rejection_reason'] = Variable<String>(rejectionReason.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(syncStatus.value);
    }
    if (serverVersion.present) {
      map['server_version'] = Variable<int>(serverVersion.value);
    }
    if (clientUpdatedAt.present) {
      map['client_updated_at'] = Variable<DateTime>(clientUpdatedAt.value);
    }
    if (serverUpdatedAt.present) {
      map['server_updated_at'] = Variable<DateTime>(serverUpdatedAt.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalOrdersCompanion(')
          ..write('id: $id, ')
          ..write('orderNumber: $orderNumber, ')
          ..write('orderType: $orderType, ')
          ..write('shiftId: $shiftId, ')
          ..write('status: $status, ')
          ..write('subtotal: $subtotal, ')
          ..write('discountPercentage: $discountPercentage, ')
          ..write('discountAmount: $discountAmount, ')
          ..write('taxAmount: $taxAmount, ')
          ..write('grandTotal: $grandTotal, ')
          ..write('paymentStatus: $paymentStatus, ')
          ..write('isPaid: $isPaid, ')
          ..write('isHeld: $isHeld, ')
          ..write('kitchenTicketSent: $kitchenTicketSent, ')
          ..write('rejectionReason: $rejectionReason, ')
          ..write('deviceId: $deviceId, ')
          ..write('createdAt: $createdAt, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('serverVersion: $serverVersion, ')
          ..write('clientUpdatedAt: $clientUpdatedAt, ')
          ..write('serverUpdatedAt: $serverUpdatedAt, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalOrderItemsTable extends LocalOrderItems
    with TableInfo<$LocalOrderItemsTable, LocalOrderItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalOrderItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 36,
      maxTextLength: 36,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _orderIdMeta = const VerificationMeta(
    'orderId',
  );
  @override
  late final GeneratedColumn<String> orderId = GeneratedColumn<String>(
    'order_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES local_orders (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _menuItemIdMeta = const VerificationMeta(
    'menuItemId',
  );
  @override
  late final GeneratedColumn<String> menuItemId = GeneratedColumn<String>(
    'menu_item_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _itemNameMeta = const VerificationMeta(
    'itemName',
  );
  @override
  late final GeneratedColumn<String> itemName = GeneratedColumn<String>(
    'item_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sizeNameMeta = const VerificationMeta(
    'sizeName',
  );
  @override
  late final GeneratedColumn<String> sizeName = GeneratedColumn<String>(
    'size_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _unitPriceMeta = const VerificationMeta(
    'unitPrice',
  );
  @override
  late final GeneratedColumn<double> unitPrice = GeneratedColumn<double>(
    'unit_price',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _quantityMeta = const VerificationMeta(
    'quantity',
  );
  @override
  late final GeneratedColumn<int> quantity = GeneratedColumn<int>(
    'quantity',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _subtotalMeta = const VerificationMeta(
    'subtotal',
  );
  @override
  late final GeneratedColumn<double> subtotal = GeneratedColumn<double>(
    'subtotal',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isCancelledMeta = const VerificationMeta(
    'isCancelled',
  );
  @override
  late final GeneratedColumn<bool> isCancelled = GeneratedColumn<bool>(
    'is_cancelled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_cancelled" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _cancelledAtMeta = const VerificationMeta(
    'cancelledAt',
  );
  @override
  late final GeneratedColumn<DateTime> cancelledAt = GeneratedColumn<DateTime>(
    'cancelled_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cancelReasonMeta = const VerificationMeta(
    'cancelReason',
  );
  @override
  late final GeneratedColumn<String> cancelReason = GeneratedColumn<String>(
    'cancel_reason',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _voidedAtMeta = const VerificationMeta(
    'voidedAt',
  );
  @override
  late final GeneratedColumn<DateTime> voidedAt = GeneratedColumn<DateTime>(
    'voided_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _voidedByMeta = const VerificationMeta(
    'voidedBy',
  );
  @override
  late final GeneratedColumn<String> voidedBy = GeneratedColumn<String>(
    'voided_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _supersedesItemIdMeta = const VerificationMeta(
    'supersedesItemId',
  );
  @override
  late final GeneratedColumn<String> supersedesItemId = GeneratedColumn<String>(
    'supersedes_item_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdByDeviceIdMeta = const VerificationMeta(
    'createdByDeviceId',
  );
  @override
  late final GeneratedColumn<String> createdByDeviceId =
      GeneratedColumn<String>(
        'created_by_device_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _clientCreatedAtMeta = const VerificationMeta(
    'clientCreatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> clientCreatedAt =
      GeneratedColumn<DateTime>(
        'client_created_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<String> syncStatus = GeneratedColumn<String>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending_insert'),
  );
  static const VerificationMeta _serverVersionMeta = const VerificationMeta(
    'serverVersion',
  );
  @override
  late final GeneratedColumn<int> serverVersion = GeneratedColumn<int>(
    'server_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    orderId,
    menuItemId,
    itemName,
    sizeName,
    unitPrice,
    quantity,
    subtotal,
    notes,
    isCancelled,
    cancelledAt,
    cancelReason,
    voidedAt,
    voidedBy,
    supersedesItemId,
    createdByDeviceId,
    clientCreatedAt,
    syncStatus,
    serverVersion,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_order_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalOrderItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('order_id')) {
      context.handle(
        _orderIdMeta,
        orderId.isAcceptableOrUnknown(data['order_id']!, _orderIdMeta),
      );
    } else if (isInserting) {
      context.missing(_orderIdMeta);
    }
    if (data.containsKey('menu_item_id')) {
      context.handle(
        _menuItemIdMeta,
        menuItemId.isAcceptableOrUnknown(
          data['menu_item_id']!,
          _menuItemIdMeta,
        ),
      );
    }
    if (data.containsKey('item_name')) {
      context.handle(
        _itemNameMeta,
        itemName.isAcceptableOrUnknown(data['item_name']!, _itemNameMeta),
      );
    } else if (isInserting) {
      context.missing(_itemNameMeta);
    }
    if (data.containsKey('size_name')) {
      context.handle(
        _sizeNameMeta,
        sizeName.isAcceptableOrUnknown(data['size_name']!, _sizeNameMeta),
      );
    }
    if (data.containsKey('unit_price')) {
      context.handle(
        _unitPriceMeta,
        unitPrice.isAcceptableOrUnknown(data['unit_price']!, _unitPriceMeta),
      );
    } else if (isInserting) {
      context.missing(_unitPriceMeta);
    }
    if (data.containsKey('quantity')) {
      context.handle(
        _quantityMeta,
        quantity.isAcceptableOrUnknown(data['quantity']!, _quantityMeta),
      );
    } else if (isInserting) {
      context.missing(_quantityMeta);
    }
    if (data.containsKey('subtotal')) {
      context.handle(
        _subtotalMeta,
        subtotal.isAcceptableOrUnknown(data['subtotal']!, _subtotalMeta),
      );
    } else if (isInserting) {
      context.missing(_subtotalMeta);
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('is_cancelled')) {
      context.handle(
        _isCancelledMeta,
        isCancelled.isAcceptableOrUnknown(
          data['is_cancelled']!,
          _isCancelledMeta,
        ),
      );
    }
    if (data.containsKey('cancelled_at')) {
      context.handle(
        _cancelledAtMeta,
        cancelledAt.isAcceptableOrUnknown(
          data['cancelled_at']!,
          _cancelledAtMeta,
        ),
      );
    }
    if (data.containsKey('cancel_reason')) {
      context.handle(
        _cancelReasonMeta,
        cancelReason.isAcceptableOrUnknown(
          data['cancel_reason']!,
          _cancelReasonMeta,
        ),
      );
    }
    if (data.containsKey('voided_at')) {
      context.handle(
        _voidedAtMeta,
        voidedAt.isAcceptableOrUnknown(data['voided_at']!, _voidedAtMeta),
      );
    }
    if (data.containsKey('voided_by')) {
      context.handle(
        _voidedByMeta,
        voidedBy.isAcceptableOrUnknown(data['voided_by']!, _voidedByMeta),
      );
    }
    if (data.containsKey('supersedes_item_id')) {
      context.handle(
        _supersedesItemIdMeta,
        supersedesItemId.isAcceptableOrUnknown(
          data['supersedes_item_id']!,
          _supersedesItemIdMeta,
        ),
      );
    }
    if (data.containsKey('created_by_device_id')) {
      context.handle(
        _createdByDeviceIdMeta,
        createdByDeviceId.isAcceptableOrUnknown(
          data['created_by_device_id']!,
          _createdByDeviceIdMeta,
        ),
      );
    }
    if (data.containsKey('client_created_at')) {
      context.handle(
        _clientCreatedAtMeta,
        clientCreatedAt.isAcceptableOrUnknown(
          data['client_created_at']!,
          _clientCreatedAtMeta,
        ),
      );
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    if (data.containsKey('server_version')) {
      context.handle(
        _serverVersionMeta,
        serverVersion.isAcceptableOrUnknown(
          data['server_version']!,
          _serverVersionMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalOrderItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalOrderItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      orderId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}order_id'],
      )!,
      menuItemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}menu_item_id'],
      ),
      itemName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_name'],
      )!,
      sizeName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}size_name'],
      ),
      unitPrice: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}unit_price'],
      )!,
      quantity: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}quantity'],
      )!,
      subtotal: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}subtotal'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      isCancelled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_cancelled'],
      )!,
      cancelledAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}cancelled_at'],
      ),
      cancelReason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cancel_reason'],
      ),
      voidedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}voided_at'],
      ),
      voidedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}voided_by'],
      ),
      supersedesItemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}supersedes_item_id'],
      ),
      createdByDeviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_by_device_id'],
      ),
      clientCreatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}client_created_at'],
      ),
      syncStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_status'],
      )!,
      serverVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_version'],
      )!,
    );
  }

  @override
  $LocalOrderItemsTable createAlias(String alias) {
    return $LocalOrderItemsTable(attachedDatabase, alias);
  }
}

class LocalOrderItem extends DataClass implements Insertable<LocalOrderItem> {
  final String id;
  final String orderId;
  final String? menuItemId;
  final String itemName;
  final String? sizeName;
  final double unitPrice;
  final int quantity;
  final double subtotal;
  final String? notes;
  final bool isCancelled;
  final DateTime? cancelledAt;
  final String? cancelReason;
  final DateTime? voidedAt;
  final String? voidedBy;
  final String? supersedesItemId;
  final String? createdByDeviceId;
  final DateTime? clientCreatedAt;
  final String syncStatus;
  final int serverVersion;
  const LocalOrderItem({
    required this.id,
    required this.orderId,
    this.menuItemId,
    required this.itemName,
    this.sizeName,
    required this.unitPrice,
    required this.quantity,
    required this.subtotal,
    this.notes,
    required this.isCancelled,
    this.cancelledAt,
    this.cancelReason,
    this.voidedAt,
    this.voidedBy,
    this.supersedesItemId,
    this.createdByDeviceId,
    this.clientCreatedAt,
    required this.syncStatus,
    required this.serverVersion,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['order_id'] = Variable<String>(orderId);
    if (!nullToAbsent || menuItemId != null) {
      map['menu_item_id'] = Variable<String>(menuItemId);
    }
    map['item_name'] = Variable<String>(itemName);
    if (!nullToAbsent || sizeName != null) {
      map['size_name'] = Variable<String>(sizeName);
    }
    map['unit_price'] = Variable<double>(unitPrice);
    map['quantity'] = Variable<int>(quantity);
    map['subtotal'] = Variable<double>(subtotal);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['is_cancelled'] = Variable<bool>(isCancelled);
    if (!nullToAbsent || cancelledAt != null) {
      map['cancelled_at'] = Variable<DateTime>(cancelledAt);
    }
    if (!nullToAbsent || cancelReason != null) {
      map['cancel_reason'] = Variable<String>(cancelReason);
    }
    if (!nullToAbsent || voidedAt != null) {
      map['voided_at'] = Variable<DateTime>(voidedAt);
    }
    if (!nullToAbsent || voidedBy != null) {
      map['voided_by'] = Variable<String>(voidedBy);
    }
    if (!nullToAbsent || supersedesItemId != null) {
      map['supersedes_item_id'] = Variable<String>(supersedesItemId);
    }
    if (!nullToAbsent || createdByDeviceId != null) {
      map['created_by_device_id'] = Variable<String>(createdByDeviceId);
    }
    if (!nullToAbsent || clientCreatedAt != null) {
      map['client_created_at'] = Variable<DateTime>(clientCreatedAt);
    }
    map['sync_status'] = Variable<String>(syncStatus);
    map['server_version'] = Variable<int>(serverVersion);
    return map;
  }

  LocalOrderItemsCompanion toCompanion(bool nullToAbsent) {
    return LocalOrderItemsCompanion(
      id: Value(id),
      orderId: Value(orderId),
      menuItemId: menuItemId == null && nullToAbsent
          ? const Value.absent()
          : Value(menuItemId),
      itemName: Value(itemName),
      sizeName: sizeName == null && nullToAbsent
          ? const Value.absent()
          : Value(sizeName),
      unitPrice: Value(unitPrice),
      quantity: Value(quantity),
      subtotal: Value(subtotal),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      isCancelled: Value(isCancelled),
      cancelledAt: cancelledAt == null && nullToAbsent
          ? const Value.absent()
          : Value(cancelledAt),
      cancelReason: cancelReason == null && nullToAbsent
          ? const Value.absent()
          : Value(cancelReason),
      voidedAt: voidedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(voidedAt),
      voidedBy: voidedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(voidedBy),
      supersedesItemId: supersedesItemId == null && nullToAbsent
          ? const Value.absent()
          : Value(supersedesItemId),
      createdByDeviceId: createdByDeviceId == null && nullToAbsent
          ? const Value.absent()
          : Value(createdByDeviceId),
      clientCreatedAt: clientCreatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(clientCreatedAt),
      syncStatus: Value(syncStatus),
      serverVersion: Value(serverVersion),
    );
  }

  factory LocalOrderItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalOrderItem(
      id: serializer.fromJson<String>(json['id']),
      orderId: serializer.fromJson<String>(json['orderId']),
      menuItemId: serializer.fromJson<String?>(json['menuItemId']),
      itemName: serializer.fromJson<String>(json['itemName']),
      sizeName: serializer.fromJson<String?>(json['sizeName']),
      unitPrice: serializer.fromJson<double>(json['unitPrice']),
      quantity: serializer.fromJson<int>(json['quantity']),
      subtotal: serializer.fromJson<double>(json['subtotal']),
      notes: serializer.fromJson<String?>(json['notes']),
      isCancelled: serializer.fromJson<bool>(json['isCancelled']),
      cancelledAt: serializer.fromJson<DateTime?>(json['cancelledAt']),
      cancelReason: serializer.fromJson<String?>(json['cancelReason']),
      voidedAt: serializer.fromJson<DateTime?>(json['voidedAt']),
      voidedBy: serializer.fromJson<String?>(json['voidedBy']),
      supersedesItemId: serializer.fromJson<String?>(json['supersedesItemId']),
      createdByDeviceId: serializer.fromJson<String?>(
        json['createdByDeviceId'],
      ),
      clientCreatedAt: serializer.fromJson<DateTime?>(json['clientCreatedAt']),
      syncStatus: serializer.fromJson<String>(json['syncStatus']),
      serverVersion: serializer.fromJson<int>(json['serverVersion']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'orderId': serializer.toJson<String>(orderId),
      'menuItemId': serializer.toJson<String?>(menuItemId),
      'itemName': serializer.toJson<String>(itemName),
      'sizeName': serializer.toJson<String?>(sizeName),
      'unitPrice': serializer.toJson<double>(unitPrice),
      'quantity': serializer.toJson<int>(quantity),
      'subtotal': serializer.toJson<double>(subtotal),
      'notes': serializer.toJson<String?>(notes),
      'isCancelled': serializer.toJson<bool>(isCancelled),
      'cancelledAt': serializer.toJson<DateTime?>(cancelledAt),
      'cancelReason': serializer.toJson<String?>(cancelReason),
      'voidedAt': serializer.toJson<DateTime?>(voidedAt),
      'voidedBy': serializer.toJson<String?>(voidedBy),
      'supersedesItemId': serializer.toJson<String?>(supersedesItemId),
      'createdByDeviceId': serializer.toJson<String?>(createdByDeviceId),
      'clientCreatedAt': serializer.toJson<DateTime?>(clientCreatedAt),
      'syncStatus': serializer.toJson<String>(syncStatus),
      'serverVersion': serializer.toJson<int>(serverVersion),
    };
  }

  LocalOrderItem copyWith({
    String? id,
    String? orderId,
    Value<String?> menuItemId = const Value.absent(),
    String? itemName,
    Value<String?> sizeName = const Value.absent(),
    double? unitPrice,
    int? quantity,
    double? subtotal,
    Value<String?> notes = const Value.absent(),
    bool? isCancelled,
    Value<DateTime?> cancelledAt = const Value.absent(),
    Value<String?> cancelReason = const Value.absent(),
    Value<DateTime?> voidedAt = const Value.absent(),
    Value<String?> voidedBy = const Value.absent(),
    Value<String?> supersedesItemId = const Value.absent(),
    Value<String?> createdByDeviceId = const Value.absent(),
    Value<DateTime?> clientCreatedAt = const Value.absent(),
    String? syncStatus,
    int? serverVersion,
  }) => LocalOrderItem(
    id: id ?? this.id,
    orderId: orderId ?? this.orderId,
    menuItemId: menuItemId.present ? menuItemId.value : this.menuItemId,
    itemName: itemName ?? this.itemName,
    sizeName: sizeName.present ? sizeName.value : this.sizeName,
    unitPrice: unitPrice ?? this.unitPrice,
    quantity: quantity ?? this.quantity,
    subtotal: subtotal ?? this.subtotal,
    notes: notes.present ? notes.value : this.notes,
    isCancelled: isCancelled ?? this.isCancelled,
    cancelledAt: cancelledAt.present ? cancelledAt.value : this.cancelledAt,
    cancelReason: cancelReason.present ? cancelReason.value : this.cancelReason,
    voidedAt: voidedAt.present ? voidedAt.value : this.voidedAt,
    voidedBy: voidedBy.present ? voidedBy.value : this.voidedBy,
    supersedesItemId: supersedesItemId.present
        ? supersedesItemId.value
        : this.supersedesItemId,
    createdByDeviceId: createdByDeviceId.present
        ? createdByDeviceId.value
        : this.createdByDeviceId,
    clientCreatedAt: clientCreatedAt.present
        ? clientCreatedAt.value
        : this.clientCreatedAt,
    syncStatus: syncStatus ?? this.syncStatus,
    serverVersion: serverVersion ?? this.serverVersion,
  );
  LocalOrderItem copyWithCompanion(LocalOrderItemsCompanion data) {
    return LocalOrderItem(
      id: data.id.present ? data.id.value : this.id,
      orderId: data.orderId.present ? data.orderId.value : this.orderId,
      menuItemId: data.menuItemId.present
          ? data.menuItemId.value
          : this.menuItemId,
      itemName: data.itemName.present ? data.itemName.value : this.itemName,
      sizeName: data.sizeName.present ? data.sizeName.value : this.sizeName,
      unitPrice: data.unitPrice.present ? data.unitPrice.value : this.unitPrice,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
      subtotal: data.subtotal.present ? data.subtotal.value : this.subtotal,
      notes: data.notes.present ? data.notes.value : this.notes,
      isCancelled: data.isCancelled.present
          ? data.isCancelled.value
          : this.isCancelled,
      cancelledAt: data.cancelledAt.present
          ? data.cancelledAt.value
          : this.cancelledAt,
      cancelReason: data.cancelReason.present
          ? data.cancelReason.value
          : this.cancelReason,
      voidedAt: data.voidedAt.present ? data.voidedAt.value : this.voidedAt,
      voidedBy: data.voidedBy.present ? data.voidedBy.value : this.voidedBy,
      supersedesItemId: data.supersedesItemId.present
          ? data.supersedesItemId.value
          : this.supersedesItemId,
      createdByDeviceId: data.createdByDeviceId.present
          ? data.createdByDeviceId.value
          : this.createdByDeviceId,
      clientCreatedAt: data.clientCreatedAt.present
          ? data.clientCreatedAt.value
          : this.clientCreatedAt,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
      serverVersion: data.serverVersion.present
          ? data.serverVersion.value
          : this.serverVersion,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalOrderItem(')
          ..write('id: $id, ')
          ..write('orderId: $orderId, ')
          ..write('menuItemId: $menuItemId, ')
          ..write('itemName: $itemName, ')
          ..write('sizeName: $sizeName, ')
          ..write('unitPrice: $unitPrice, ')
          ..write('quantity: $quantity, ')
          ..write('subtotal: $subtotal, ')
          ..write('notes: $notes, ')
          ..write('isCancelled: $isCancelled, ')
          ..write('cancelledAt: $cancelledAt, ')
          ..write('cancelReason: $cancelReason, ')
          ..write('voidedAt: $voidedAt, ')
          ..write('voidedBy: $voidedBy, ')
          ..write('supersedesItemId: $supersedesItemId, ')
          ..write('createdByDeviceId: $createdByDeviceId, ')
          ..write('clientCreatedAt: $clientCreatedAt, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('serverVersion: $serverVersion')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    orderId,
    menuItemId,
    itemName,
    sizeName,
    unitPrice,
    quantity,
    subtotal,
    notes,
    isCancelled,
    cancelledAt,
    cancelReason,
    voidedAt,
    voidedBy,
    supersedesItemId,
    createdByDeviceId,
    clientCreatedAt,
    syncStatus,
    serverVersion,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalOrderItem &&
          other.id == this.id &&
          other.orderId == this.orderId &&
          other.menuItemId == this.menuItemId &&
          other.itemName == this.itemName &&
          other.sizeName == this.sizeName &&
          other.unitPrice == this.unitPrice &&
          other.quantity == this.quantity &&
          other.subtotal == this.subtotal &&
          other.notes == this.notes &&
          other.isCancelled == this.isCancelled &&
          other.cancelledAt == this.cancelledAt &&
          other.cancelReason == this.cancelReason &&
          other.voidedAt == this.voidedAt &&
          other.voidedBy == this.voidedBy &&
          other.supersedesItemId == this.supersedesItemId &&
          other.createdByDeviceId == this.createdByDeviceId &&
          other.clientCreatedAt == this.clientCreatedAt &&
          other.syncStatus == this.syncStatus &&
          other.serverVersion == this.serverVersion);
}

class LocalOrderItemsCompanion extends UpdateCompanion<LocalOrderItem> {
  final Value<String> id;
  final Value<String> orderId;
  final Value<String?> menuItemId;
  final Value<String> itemName;
  final Value<String?> sizeName;
  final Value<double> unitPrice;
  final Value<int> quantity;
  final Value<double> subtotal;
  final Value<String?> notes;
  final Value<bool> isCancelled;
  final Value<DateTime?> cancelledAt;
  final Value<String?> cancelReason;
  final Value<DateTime?> voidedAt;
  final Value<String?> voidedBy;
  final Value<String?> supersedesItemId;
  final Value<String?> createdByDeviceId;
  final Value<DateTime?> clientCreatedAt;
  final Value<String> syncStatus;
  final Value<int> serverVersion;
  final Value<int> rowid;
  const LocalOrderItemsCompanion({
    this.id = const Value.absent(),
    this.orderId = const Value.absent(),
    this.menuItemId = const Value.absent(),
    this.itemName = const Value.absent(),
    this.sizeName = const Value.absent(),
    this.unitPrice = const Value.absent(),
    this.quantity = const Value.absent(),
    this.subtotal = const Value.absent(),
    this.notes = const Value.absent(),
    this.isCancelled = const Value.absent(),
    this.cancelledAt = const Value.absent(),
    this.cancelReason = const Value.absent(),
    this.voidedAt = const Value.absent(),
    this.voidedBy = const Value.absent(),
    this.supersedesItemId = const Value.absent(),
    this.createdByDeviceId = const Value.absent(),
    this.clientCreatedAt = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.serverVersion = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalOrderItemsCompanion.insert({
    required String id,
    required String orderId,
    this.menuItemId = const Value.absent(),
    required String itemName,
    this.sizeName = const Value.absent(),
    required double unitPrice,
    required int quantity,
    required double subtotal,
    this.notes = const Value.absent(),
    this.isCancelled = const Value.absent(),
    this.cancelledAt = const Value.absent(),
    this.cancelReason = const Value.absent(),
    this.voidedAt = const Value.absent(),
    this.voidedBy = const Value.absent(),
    this.supersedesItemId = const Value.absent(),
    this.createdByDeviceId = const Value.absent(),
    this.clientCreatedAt = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.serverVersion = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       orderId = Value(orderId),
       itemName = Value(itemName),
       unitPrice = Value(unitPrice),
       quantity = Value(quantity),
       subtotal = Value(subtotal);
  static Insertable<LocalOrderItem> custom({
    Expression<String>? id,
    Expression<String>? orderId,
    Expression<String>? menuItemId,
    Expression<String>? itemName,
    Expression<String>? sizeName,
    Expression<double>? unitPrice,
    Expression<int>? quantity,
    Expression<double>? subtotal,
    Expression<String>? notes,
    Expression<bool>? isCancelled,
    Expression<DateTime>? cancelledAt,
    Expression<String>? cancelReason,
    Expression<DateTime>? voidedAt,
    Expression<String>? voidedBy,
    Expression<String>? supersedesItemId,
    Expression<String>? createdByDeviceId,
    Expression<DateTime>? clientCreatedAt,
    Expression<String>? syncStatus,
    Expression<int>? serverVersion,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (orderId != null) 'order_id': orderId,
      if (menuItemId != null) 'menu_item_id': menuItemId,
      if (itemName != null) 'item_name': itemName,
      if (sizeName != null) 'size_name': sizeName,
      if (unitPrice != null) 'unit_price': unitPrice,
      if (quantity != null) 'quantity': quantity,
      if (subtotal != null) 'subtotal': subtotal,
      if (notes != null) 'notes': notes,
      if (isCancelled != null) 'is_cancelled': isCancelled,
      if (cancelledAt != null) 'cancelled_at': cancelledAt,
      if (cancelReason != null) 'cancel_reason': cancelReason,
      if (voidedAt != null) 'voided_at': voidedAt,
      if (voidedBy != null) 'voided_by': voidedBy,
      if (supersedesItemId != null) 'supersedes_item_id': supersedesItemId,
      if (createdByDeviceId != null) 'created_by_device_id': createdByDeviceId,
      if (clientCreatedAt != null) 'client_created_at': clientCreatedAt,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (serverVersion != null) 'server_version': serverVersion,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalOrderItemsCompanion copyWith({
    Value<String>? id,
    Value<String>? orderId,
    Value<String?>? menuItemId,
    Value<String>? itemName,
    Value<String?>? sizeName,
    Value<double>? unitPrice,
    Value<int>? quantity,
    Value<double>? subtotal,
    Value<String?>? notes,
    Value<bool>? isCancelled,
    Value<DateTime?>? cancelledAt,
    Value<String?>? cancelReason,
    Value<DateTime?>? voidedAt,
    Value<String?>? voidedBy,
    Value<String?>? supersedesItemId,
    Value<String?>? createdByDeviceId,
    Value<DateTime?>? clientCreatedAt,
    Value<String>? syncStatus,
    Value<int>? serverVersion,
    Value<int>? rowid,
  }) {
    return LocalOrderItemsCompanion(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      menuItemId: menuItemId ?? this.menuItemId,
      itemName: itemName ?? this.itemName,
      sizeName: sizeName ?? this.sizeName,
      unitPrice: unitPrice ?? this.unitPrice,
      quantity: quantity ?? this.quantity,
      subtotal: subtotal ?? this.subtotal,
      notes: notes ?? this.notes,
      isCancelled: isCancelled ?? this.isCancelled,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      cancelReason: cancelReason ?? this.cancelReason,
      voidedAt: voidedAt ?? this.voidedAt,
      voidedBy: voidedBy ?? this.voidedBy,
      supersedesItemId: supersedesItemId ?? this.supersedesItemId,
      createdByDeviceId: createdByDeviceId ?? this.createdByDeviceId,
      clientCreatedAt: clientCreatedAt ?? this.clientCreatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      serverVersion: serverVersion ?? this.serverVersion,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (orderId.present) {
      map['order_id'] = Variable<String>(orderId.value);
    }
    if (menuItemId.present) {
      map['menu_item_id'] = Variable<String>(menuItemId.value);
    }
    if (itemName.present) {
      map['item_name'] = Variable<String>(itemName.value);
    }
    if (sizeName.present) {
      map['size_name'] = Variable<String>(sizeName.value);
    }
    if (unitPrice.present) {
      map['unit_price'] = Variable<double>(unitPrice.value);
    }
    if (quantity.present) {
      map['quantity'] = Variable<int>(quantity.value);
    }
    if (subtotal.present) {
      map['subtotal'] = Variable<double>(subtotal.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (isCancelled.present) {
      map['is_cancelled'] = Variable<bool>(isCancelled.value);
    }
    if (cancelledAt.present) {
      map['cancelled_at'] = Variable<DateTime>(cancelledAt.value);
    }
    if (cancelReason.present) {
      map['cancel_reason'] = Variable<String>(cancelReason.value);
    }
    if (voidedAt.present) {
      map['voided_at'] = Variable<DateTime>(voidedAt.value);
    }
    if (voidedBy.present) {
      map['voided_by'] = Variable<String>(voidedBy.value);
    }
    if (supersedesItemId.present) {
      map['supersedes_item_id'] = Variable<String>(supersedesItemId.value);
    }
    if (createdByDeviceId.present) {
      map['created_by_device_id'] = Variable<String>(createdByDeviceId.value);
    }
    if (clientCreatedAt.present) {
      map['client_created_at'] = Variable<DateTime>(clientCreatedAt.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(syncStatus.value);
    }
    if (serverVersion.present) {
      map['server_version'] = Variable<int>(serverVersion.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalOrderItemsCompanion(')
          ..write('id: $id, ')
          ..write('orderId: $orderId, ')
          ..write('menuItemId: $menuItemId, ')
          ..write('itemName: $itemName, ')
          ..write('sizeName: $sizeName, ')
          ..write('unitPrice: $unitPrice, ')
          ..write('quantity: $quantity, ')
          ..write('subtotal: $subtotal, ')
          ..write('notes: $notes, ')
          ..write('isCancelled: $isCancelled, ')
          ..write('cancelledAt: $cancelledAt, ')
          ..write('cancelReason: $cancelReason, ')
          ..write('voidedAt: $voidedAt, ')
          ..write('voidedBy: $voidedBy, ')
          ..write('supersedesItemId: $supersedesItemId, ')
          ..write('createdByDeviceId: $createdByDeviceId, ')
          ..write('clientCreatedAt: $clientCreatedAt, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('serverVersion: $serverVersion, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalOrderPaymentsTable extends LocalOrderPayments
    with TableInfo<$LocalOrderPaymentsTable, LocalOrderPayment> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalOrderPaymentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 36,
      maxTextLength: 36,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _orderIdMeta = const VerificationMeta(
    'orderId',
  );
  @override
  late final GeneratedColumn<String> orderId = GeneratedColumn<String>(
    'order_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES local_orders (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _paymentMethodMeta = const VerificationMeta(
    'paymentMethod',
  );
  @override
  late final GeneratedColumn<String> paymentMethod = GeneratedColumn<String>(
    'payment_method',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<double> amount = GeneratedColumn<double>(
    'amount',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tenderedAmountMeta = const VerificationMeta(
    'tenderedAmount',
  );
  @override
  late final GeneratedColumn<double> tenderedAmount = GeneratedColumn<double>(
    'tendered_amount',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _changeReturnedMeta = const VerificationMeta(
    'changeReturned',
  );
  @override
  late final GeneratedColumn<double> changeReturned = GeneratedColumn<double>(
    'change_returned',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _transactionReferenceMeta =
      const VerificationMeta('transactionReference');
  @override
  late final GeneratedColumn<String> transactionReference =
      GeneratedColumn<String>(
        'transaction_reference',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _cardLastFourMeta = const VerificationMeta(
    'cardLastFour',
  );
  @override
  late final GeneratedColumn<String> cardLastFour = GeneratedColumn<String>(
    'card_last_four',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bankNameMeta = const VerificationMeta(
    'bankName',
  );
  @override
  late final GeneratedColumn<String> bankName = GeneratedColumn<String>(
    'bank_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _paymentStatusMeta = const VerificationMeta(
    'paymentStatus',
  );
  @override
  late final GeneratedColumn<String> paymentStatus = GeneratedColumn<String>(
    'payment_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('COMPLETED'),
  );
  static const VerificationMeta _receivedByMeta = const VerificationMeta(
    'receivedBy',
  );
  @override
  late final GeneratedColumn<String> receivedBy = GeneratedColumn<String>(
    'received_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<String> syncStatus = GeneratedColumn<String>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending_insert'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    orderId,
    paymentMethod,
    amount,
    tenderedAmount,
    changeReturned,
    transactionReference,
    cardLastFour,
    bankName,
    paymentStatus,
    receivedBy,
    createdAt,
    syncStatus,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_order_payments';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalOrderPayment> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('order_id')) {
      context.handle(
        _orderIdMeta,
        orderId.isAcceptableOrUnknown(data['order_id']!, _orderIdMeta),
      );
    } else if (isInserting) {
      context.missing(_orderIdMeta);
    }
    if (data.containsKey('payment_method')) {
      context.handle(
        _paymentMethodMeta,
        paymentMethod.isAcceptableOrUnknown(
          data['payment_method']!,
          _paymentMethodMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_paymentMethodMeta);
    }
    if (data.containsKey('amount')) {
      context.handle(
        _amountMeta,
        amount.isAcceptableOrUnknown(data['amount']!, _amountMeta),
      );
    } else if (isInserting) {
      context.missing(_amountMeta);
    }
    if (data.containsKey('tendered_amount')) {
      context.handle(
        _tenderedAmountMeta,
        tenderedAmount.isAcceptableOrUnknown(
          data['tendered_amount']!,
          _tenderedAmountMeta,
        ),
      );
    }
    if (data.containsKey('change_returned')) {
      context.handle(
        _changeReturnedMeta,
        changeReturned.isAcceptableOrUnknown(
          data['change_returned']!,
          _changeReturnedMeta,
        ),
      );
    }
    if (data.containsKey('transaction_reference')) {
      context.handle(
        _transactionReferenceMeta,
        transactionReference.isAcceptableOrUnknown(
          data['transaction_reference']!,
          _transactionReferenceMeta,
        ),
      );
    }
    if (data.containsKey('card_last_four')) {
      context.handle(
        _cardLastFourMeta,
        cardLastFour.isAcceptableOrUnknown(
          data['card_last_four']!,
          _cardLastFourMeta,
        ),
      );
    }
    if (data.containsKey('bank_name')) {
      context.handle(
        _bankNameMeta,
        bankName.isAcceptableOrUnknown(data['bank_name']!, _bankNameMeta),
      );
    }
    if (data.containsKey('payment_status')) {
      context.handle(
        _paymentStatusMeta,
        paymentStatus.isAcceptableOrUnknown(
          data['payment_status']!,
          _paymentStatusMeta,
        ),
      );
    }
    if (data.containsKey('received_by')) {
      context.handle(
        _receivedByMeta,
        receivedBy.isAcceptableOrUnknown(data['received_by']!, _receivedByMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalOrderPayment map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalOrderPayment(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      orderId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}order_id'],
      )!,
      paymentMethod: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payment_method'],
      )!,
      amount: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}amount'],
      )!,
      tenderedAmount: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}tendered_amount'],
      ),
      changeReturned: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}change_returned'],
      ),
      transactionReference: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}transaction_reference'],
      ),
      cardLastFour: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}card_last_four'],
      ),
      bankName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bank_name'],
      ),
      paymentStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payment_status'],
      )!,
      receivedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}received_by'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      syncStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_status'],
      )!,
    );
  }

  @override
  $LocalOrderPaymentsTable createAlias(String alias) {
    return $LocalOrderPaymentsTable(attachedDatabase, alias);
  }
}

class LocalOrderPayment extends DataClass
    implements Insertable<LocalOrderPayment> {
  final String id;
  final String orderId;
  final String paymentMethod;
  final double amount;
  final double? tenderedAmount;
  final double? changeReturned;
  final String? transactionReference;
  final String? cardLastFour;
  final String? bankName;
  final String paymentStatus;
  final String? receivedBy;
  final DateTime createdAt;
  final String syncStatus;
  const LocalOrderPayment({
    required this.id,
    required this.orderId,
    required this.paymentMethod,
    required this.amount,
    this.tenderedAmount,
    this.changeReturned,
    this.transactionReference,
    this.cardLastFour,
    this.bankName,
    required this.paymentStatus,
    this.receivedBy,
    required this.createdAt,
    required this.syncStatus,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['order_id'] = Variable<String>(orderId);
    map['payment_method'] = Variable<String>(paymentMethod);
    map['amount'] = Variable<double>(amount);
    if (!nullToAbsent || tenderedAmount != null) {
      map['tendered_amount'] = Variable<double>(tenderedAmount);
    }
    if (!nullToAbsent || changeReturned != null) {
      map['change_returned'] = Variable<double>(changeReturned);
    }
    if (!nullToAbsent || transactionReference != null) {
      map['transaction_reference'] = Variable<String>(transactionReference);
    }
    if (!nullToAbsent || cardLastFour != null) {
      map['card_last_four'] = Variable<String>(cardLastFour);
    }
    if (!nullToAbsent || bankName != null) {
      map['bank_name'] = Variable<String>(bankName);
    }
    map['payment_status'] = Variable<String>(paymentStatus);
    if (!nullToAbsent || receivedBy != null) {
      map['received_by'] = Variable<String>(receivedBy);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['sync_status'] = Variable<String>(syncStatus);
    return map;
  }

  LocalOrderPaymentsCompanion toCompanion(bool nullToAbsent) {
    return LocalOrderPaymentsCompanion(
      id: Value(id),
      orderId: Value(orderId),
      paymentMethod: Value(paymentMethod),
      amount: Value(amount),
      tenderedAmount: tenderedAmount == null && nullToAbsent
          ? const Value.absent()
          : Value(tenderedAmount),
      changeReturned: changeReturned == null && nullToAbsent
          ? const Value.absent()
          : Value(changeReturned),
      transactionReference: transactionReference == null && nullToAbsent
          ? const Value.absent()
          : Value(transactionReference),
      cardLastFour: cardLastFour == null && nullToAbsent
          ? const Value.absent()
          : Value(cardLastFour),
      bankName: bankName == null && nullToAbsent
          ? const Value.absent()
          : Value(bankName),
      paymentStatus: Value(paymentStatus),
      receivedBy: receivedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(receivedBy),
      createdAt: Value(createdAt),
      syncStatus: Value(syncStatus),
    );
  }

  factory LocalOrderPayment.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalOrderPayment(
      id: serializer.fromJson<String>(json['id']),
      orderId: serializer.fromJson<String>(json['orderId']),
      paymentMethod: serializer.fromJson<String>(json['paymentMethod']),
      amount: serializer.fromJson<double>(json['amount']),
      tenderedAmount: serializer.fromJson<double?>(json['tenderedAmount']),
      changeReturned: serializer.fromJson<double?>(json['changeReturned']),
      transactionReference: serializer.fromJson<String?>(
        json['transactionReference'],
      ),
      cardLastFour: serializer.fromJson<String?>(json['cardLastFour']),
      bankName: serializer.fromJson<String?>(json['bankName']),
      paymentStatus: serializer.fromJson<String>(json['paymentStatus']),
      receivedBy: serializer.fromJson<String?>(json['receivedBy']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      syncStatus: serializer.fromJson<String>(json['syncStatus']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'orderId': serializer.toJson<String>(orderId),
      'paymentMethod': serializer.toJson<String>(paymentMethod),
      'amount': serializer.toJson<double>(amount),
      'tenderedAmount': serializer.toJson<double?>(tenderedAmount),
      'changeReturned': serializer.toJson<double?>(changeReturned),
      'transactionReference': serializer.toJson<String?>(transactionReference),
      'cardLastFour': serializer.toJson<String?>(cardLastFour),
      'bankName': serializer.toJson<String?>(bankName),
      'paymentStatus': serializer.toJson<String>(paymentStatus),
      'receivedBy': serializer.toJson<String?>(receivedBy),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'syncStatus': serializer.toJson<String>(syncStatus),
    };
  }

  LocalOrderPayment copyWith({
    String? id,
    String? orderId,
    String? paymentMethod,
    double? amount,
    Value<double?> tenderedAmount = const Value.absent(),
    Value<double?> changeReturned = const Value.absent(),
    Value<String?> transactionReference = const Value.absent(),
    Value<String?> cardLastFour = const Value.absent(),
    Value<String?> bankName = const Value.absent(),
    String? paymentStatus,
    Value<String?> receivedBy = const Value.absent(),
    DateTime? createdAt,
    String? syncStatus,
  }) => LocalOrderPayment(
    id: id ?? this.id,
    orderId: orderId ?? this.orderId,
    paymentMethod: paymentMethod ?? this.paymentMethod,
    amount: amount ?? this.amount,
    tenderedAmount: tenderedAmount.present
        ? tenderedAmount.value
        : this.tenderedAmount,
    changeReturned: changeReturned.present
        ? changeReturned.value
        : this.changeReturned,
    transactionReference: transactionReference.present
        ? transactionReference.value
        : this.transactionReference,
    cardLastFour: cardLastFour.present ? cardLastFour.value : this.cardLastFour,
    bankName: bankName.present ? bankName.value : this.bankName,
    paymentStatus: paymentStatus ?? this.paymentStatus,
    receivedBy: receivedBy.present ? receivedBy.value : this.receivedBy,
    createdAt: createdAt ?? this.createdAt,
    syncStatus: syncStatus ?? this.syncStatus,
  );
  LocalOrderPayment copyWithCompanion(LocalOrderPaymentsCompanion data) {
    return LocalOrderPayment(
      id: data.id.present ? data.id.value : this.id,
      orderId: data.orderId.present ? data.orderId.value : this.orderId,
      paymentMethod: data.paymentMethod.present
          ? data.paymentMethod.value
          : this.paymentMethod,
      amount: data.amount.present ? data.amount.value : this.amount,
      tenderedAmount: data.tenderedAmount.present
          ? data.tenderedAmount.value
          : this.tenderedAmount,
      changeReturned: data.changeReturned.present
          ? data.changeReturned.value
          : this.changeReturned,
      transactionReference: data.transactionReference.present
          ? data.transactionReference.value
          : this.transactionReference,
      cardLastFour: data.cardLastFour.present
          ? data.cardLastFour.value
          : this.cardLastFour,
      bankName: data.bankName.present ? data.bankName.value : this.bankName,
      paymentStatus: data.paymentStatus.present
          ? data.paymentStatus.value
          : this.paymentStatus,
      receivedBy: data.receivedBy.present
          ? data.receivedBy.value
          : this.receivedBy,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalOrderPayment(')
          ..write('id: $id, ')
          ..write('orderId: $orderId, ')
          ..write('paymentMethod: $paymentMethod, ')
          ..write('amount: $amount, ')
          ..write('tenderedAmount: $tenderedAmount, ')
          ..write('changeReturned: $changeReturned, ')
          ..write('transactionReference: $transactionReference, ')
          ..write('cardLastFour: $cardLastFour, ')
          ..write('bankName: $bankName, ')
          ..write('paymentStatus: $paymentStatus, ')
          ..write('receivedBy: $receivedBy, ')
          ..write('createdAt: $createdAt, ')
          ..write('syncStatus: $syncStatus')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    orderId,
    paymentMethod,
    amount,
    tenderedAmount,
    changeReturned,
    transactionReference,
    cardLastFour,
    bankName,
    paymentStatus,
    receivedBy,
    createdAt,
    syncStatus,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalOrderPayment &&
          other.id == this.id &&
          other.orderId == this.orderId &&
          other.paymentMethod == this.paymentMethod &&
          other.amount == this.amount &&
          other.tenderedAmount == this.tenderedAmount &&
          other.changeReturned == this.changeReturned &&
          other.transactionReference == this.transactionReference &&
          other.cardLastFour == this.cardLastFour &&
          other.bankName == this.bankName &&
          other.paymentStatus == this.paymentStatus &&
          other.receivedBy == this.receivedBy &&
          other.createdAt == this.createdAt &&
          other.syncStatus == this.syncStatus);
}

class LocalOrderPaymentsCompanion extends UpdateCompanion<LocalOrderPayment> {
  final Value<String> id;
  final Value<String> orderId;
  final Value<String> paymentMethod;
  final Value<double> amount;
  final Value<double?> tenderedAmount;
  final Value<double?> changeReturned;
  final Value<String?> transactionReference;
  final Value<String?> cardLastFour;
  final Value<String?> bankName;
  final Value<String> paymentStatus;
  final Value<String?> receivedBy;
  final Value<DateTime> createdAt;
  final Value<String> syncStatus;
  final Value<int> rowid;
  const LocalOrderPaymentsCompanion({
    this.id = const Value.absent(),
    this.orderId = const Value.absent(),
    this.paymentMethod = const Value.absent(),
    this.amount = const Value.absent(),
    this.tenderedAmount = const Value.absent(),
    this.changeReturned = const Value.absent(),
    this.transactionReference = const Value.absent(),
    this.cardLastFour = const Value.absent(),
    this.bankName = const Value.absent(),
    this.paymentStatus = const Value.absent(),
    this.receivedBy = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalOrderPaymentsCompanion.insert({
    required String id,
    required String orderId,
    required String paymentMethod,
    required double amount,
    this.tenderedAmount = const Value.absent(),
    this.changeReturned = const Value.absent(),
    this.transactionReference = const Value.absent(),
    this.cardLastFour = const Value.absent(),
    this.bankName = const Value.absent(),
    this.paymentStatus = const Value.absent(),
    this.receivedBy = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       orderId = Value(orderId),
       paymentMethod = Value(paymentMethod),
       amount = Value(amount);
  static Insertable<LocalOrderPayment> custom({
    Expression<String>? id,
    Expression<String>? orderId,
    Expression<String>? paymentMethod,
    Expression<double>? amount,
    Expression<double>? tenderedAmount,
    Expression<double>? changeReturned,
    Expression<String>? transactionReference,
    Expression<String>? cardLastFour,
    Expression<String>? bankName,
    Expression<String>? paymentStatus,
    Expression<String>? receivedBy,
    Expression<DateTime>? createdAt,
    Expression<String>? syncStatus,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (orderId != null) 'order_id': orderId,
      if (paymentMethod != null) 'payment_method': paymentMethod,
      if (amount != null) 'amount': amount,
      if (tenderedAmount != null) 'tendered_amount': tenderedAmount,
      if (changeReturned != null) 'change_returned': changeReturned,
      if (transactionReference != null)
        'transaction_reference': transactionReference,
      if (cardLastFour != null) 'card_last_four': cardLastFour,
      if (bankName != null) 'bank_name': bankName,
      if (paymentStatus != null) 'payment_status': paymentStatus,
      if (receivedBy != null) 'received_by': receivedBy,
      if (createdAt != null) 'created_at': createdAt,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalOrderPaymentsCompanion copyWith({
    Value<String>? id,
    Value<String>? orderId,
    Value<String>? paymentMethod,
    Value<double>? amount,
    Value<double?>? tenderedAmount,
    Value<double?>? changeReturned,
    Value<String?>? transactionReference,
    Value<String?>? cardLastFour,
    Value<String?>? bankName,
    Value<String>? paymentStatus,
    Value<String?>? receivedBy,
    Value<DateTime>? createdAt,
    Value<String>? syncStatus,
    Value<int>? rowid,
  }) {
    return LocalOrderPaymentsCompanion(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      amount: amount ?? this.amount,
      tenderedAmount: tenderedAmount ?? this.tenderedAmount,
      changeReturned: changeReturned ?? this.changeReturned,
      transactionReference: transactionReference ?? this.transactionReference,
      cardLastFour: cardLastFour ?? this.cardLastFour,
      bankName: bankName ?? this.bankName,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      receivedBy: receivedBy ?? this.receivedBy,
      createdAt: createdAt ?? this.createdAt,
      syncStatus: syncStatus ?? this.syncStatus,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (orderId.present) {
      map['order_id'] = Variable<String>(orderId.value);
    }
    if (paymentMethod.present) {
      map['payment_method'] = Variable<String>(paymentMethod.value);
    }
    if (amount.present) {
      map['amount'] = Variable<double>(amount.value);
    }
    if (tenderedAmount.present) {
      map['tendered_amount'] = Variable<double>(tenderedAmount.value);
    }
    if (changeReturned.present) {
      map['change_returned'] = Variable<double>(changeReturned.value);
    }
    if (transactionReference.present) {
      map['transaction_reference'] = Variable<String>(
        transactionReference.value,
      );
    }
    if (cardLastFour.present) {
      map['card_last_four'] = Variable<String>(cardLastFour.value);
    }
    if (bankName.present) {
      map['bank_name'] = Variable<String>(bankName.value);
    }
    if (paymentStatus.present) {
      map['payment_status'] = Variable<String>(paymentStatus.value);
    }
    if (receivedBy.present) {
      map['received_by'] = Variable<String>(receivedBy.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(syncStatus.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalOrderPaymentsCompanion(')
          ..write('id: $id, ')
          ..write('orderId: $orderId, ')
          ..write('paymentMethod: $paymentMethod, ')
          ..write('amount: $amount, ')
          ..write('tenderedAmount: $tenderedAmount, ')
          ..write('changeReturned: $changeReturned, ')
          ..write('transactionReference: $transactionReference, ')
          ..write('cardLastFour: $cardLastFour, ')
          ..write('bankName: $bankName, ')
          ..write('paymentStatus: $paymentStatus, ')
          ..write('receivedBy: $receivedBy, ')
          ..write('createdAt: $createdAt, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncOutboxTable extends SyncOutbox
    with TableInfo<$SyncOutboxTable, SyncOutboxEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncOutboxTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _operationIdMeta = const VerificationMeta(
    'operationId',
  );
  @override
  late final GeneratedColumn<String> operationId = GeneratedColumn<String>(
    'operation_id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 36,
      maxTextLength: 36,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 50,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityTypeMeta = const VerificationMeta(
    'entityType',
  );
  @override
  late final GeneratedColumn<String> entityType = GeneratedColumn<String>(
    'entity_type',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 50,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityIdMeta = const VerificationMeta(
    'entityId',
  );
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
    'entity_id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 36,
      maxTextLength: 36,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _operationTypeMeta = const VerificationMeta(
    'operationType',
  );
  @override
  late final GeneratedColumn<String> operationType = GeneratedColumn<String>(
    'operation_type',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 20,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _baseVersionMeta = const VerificationMeta(
    'baseVersion',
  );
  @override
  late final GeneratedColumn<int> baseVersion = GeneratedColumn<int>(
    'base_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dependsOnOperationIdMeta =
      const VerificationMeta('dependsOnOperationId');
  @override
  late final GeneratedColumn<String> dependsOnOperationId =
      GeneratedColumn<String>(
        'depends_on_operation_id',
        aliasedName,
        true,
        additionalChecks: GeneratedColumn.checkTextLength(
          minTextLength: 36,
          maxTextLength: 36,
        ),
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _dependencyOrderMeta = const VerificationMeta(
    'dependencyOrder',
  );
  @override
  late final GeneratedColumn<int> dependencyOrder = GeneratedColumn<int>(
    'dependency_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 20,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('PENDING'),
  );
  static const VerificationMeta _retryCountMeta = const VerificationMeta(
    'retryCount',
  );
  @override
  late final GeneratedColumn<int> retryCount = GeneratedColumn<int>(
    'retry_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _nextRetryAtMeta = const VerificationMeta(
    'nextRetryAt',
  );
  @override
  late final GeneratedColumn<DateTime> nextRetryAt = GeneratedColumn<DateTime>(
    'next_retry_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _sentAtMeta = const VerificationMeta('sentAt');
  @override
  late final GeneratedColumn<DateTime> sentAt = GeneratedColumn<DateTime>(
    'sent_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ackedAtMeta = const VerificationMeta(
    'ackedAt',
  );
  @override
  late final GeneratedColumn<DateTime> ackedAt = GeneratedColumn<DateTime>(
    'acked_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _conflictDetailsMeta = const VerificationMeta(
    'conflictDetails',
  );
  @override
  late final GeneratedColumn<String> conflictDetails = GeneratedColumn<String>(
    'conflict_details',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _schemaVersionMeta = const VerificationMeta(
    'schemaVersion',
  );
  @override
  late final GeneratedColumn<int> schemaVersion = GeneratedColumn<int>(
    'schema_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(kCurrentOutboxPayloadVersion),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    operationId,
    deviceId,
    entityType,
    entityId,
    operationType,
    baseVersion,
    payload,
    dependsOnOperationId,
    dependencyOrder,
    status,
    retryCount,
    nextRetryAt,
    createdAt,
    sentAt,
    ackedAt,
    lastError,
    conflictDetails,
    schemaVersion,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_outbox';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncOutboxEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('operation_id')) {
      context.handle(
        _operationIdMeta,
        operationId.isAcceptableOrUnknown(
          data['operation_id']!,
          _operationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_operationIdMeta);
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('entity_type')) {
      context.handle(
        _entityTypeMeta,
        entityType.isAcceptableOrUnknown(data['entity_type']!, _entityTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_entityTypeMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('operation_type')) {
      context.handle(
        _operationTypeMeta,
        operationType.isAcceptableOrUnknown(
          data['operation_type']!,
          _operationTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_operationTypeMeta);
    }
    if (data.containsKey('base_version')) {
      context.handle(
        _baseVersionMeta,
        baseVersion.isAcceptableOrUnknown(
          data['base_version']!,
          _baseVersionMeta,
        ),
      );
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('depends_on_operation_id')) {
      context.handle(
        _dependsOnOperationIdMeta,
        dependsOnOperationId.isAcceptableOrUnknown(
          data['depends_on_operation_id']!,
          _dependsOnOperationIdMeta,
        ),
      );
    }
    if (data.containsKey('dependency_order')) {
      context.handle(
        _dependencyOrderMeta,
        dependencyOrder.isAcceptableOrUnknown(
          data['dependency_order']!,
          _dependencyOrderMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('retry_count')) {
      context.handle(
        _retryCountMeta,
        retryCount.isAcceptableOrUnknown(data['retry_count']!, _retryCountMeta),
      );
    }
    if (data.containsKey('next_retry_at')) {
      context.handle(
        _nextRetryAtMeta,
        nextRetryAt.isAcceptableOrUnknown(
          data['next_retry_at']!,
          _nextRetryAtMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('sent_at')) {
      context.handle(
        _sentAtMeta,
        sentAt.isAcceptableOrUnknown(data['sent_at']!, _sentAtMeta),
      );
    }
    if (data.containsKey('acked_at')) {
      context.handle(
        _ackedAtMeta,
        ackedAt.isAcceptableOrUnknown(data['acked_at']!, _ackedAtMeta),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    if (data.containsKey('conflict_details')) {
      context.handle(
        _conflictDetailsMeta,
        conflictDetails.isAcceptableOrUnknown(
          data['conflict_details']!,
          _conflictDetailsMeta,
        ),
      );
    }
    if (data.containsKey('schema_version')) {
      context.handle(
        _schemaVersionMeta,
        schemaVersion.isAcceptableOrUnknown(
          data['schema_version']!,
          _schemaVersionMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncOutboxEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncOutboxEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      operationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation_id'],
      )!,
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      entityType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_type'],
      )!,
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      )!,
      operationType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation_type'],
      )!,
      baseVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}base_version'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      dependsOnOperationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}depends_on_operation_id'],
      ),
      dependencyOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}dependency_order'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      retryCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}retry_count'],
      )!,
      nextRetryAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}next_retry_at'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      sentAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}sent_at'],
      ),
      ackedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}acked_at'],
      ),
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
      conflictDetails: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conflict_details'],
      ),
      schemaVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}schema_version'],
      )!,
    );
  }

  @override
  $SyncOutboxTable createAlias(String alias) {
    return $SyncOutboxTable(attachedDatabase, alias);
  }
}

class SyncOutboxEntry extends DataClass implements Insertable<SyncOutboxEntry> {
  final int id;
  final String operationId;
  final String deviceId;
  final String entityType;
  final String entityId;
  final String operationType;
  final int baseVersion;
  final String payload;
  final String? dependsOnOperationId;
  final int dependencyOrder;
  final String status;
  final int retryCount;
  final DateTime? nextRetryAt;
  final DateTime createdAt;
  final DateTime? sentAt;
  final DateTime? ackedAt;
  final String? lastError;
  final String? conflictDetails;
  final int schemaVersion;
  const SyncOutboxEntry({
    required this.id,
    required this.operationId,
    required this.deviceId,
    required this.entityType,
    required this.entityId,
    required this.operationType,
    required this.baseVersion,
    required this.payload,
    this.dependsOnOperationId,
    required this.dependencyOrder,
    required this.status,
    required this.retryCount,
    this.nextRetryAt,
    required this.createdAt,
    this.sentAt,
    this.ackedAt,
    this.lastError,
    this.conflictDetails,
    required this.schemaVersion,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['operation_id'] = Variable<String>(operationId);
    map['device_id'] = Variable<String>(deviceId);
    map['entity_type'] = Variable<String>(entityType);
    map['entity_id'] = Variable<String>(entityId);
    map['operation_type'] = Variable<String>(operationType);
    map['base_version'] = Variable<int>(baseVersion);
    map['payload'] = Variable<String>(payload);
    if (!nullToAbsent || dependsOnOperationId != null) {
      map['depends_on_operation_id'] = Variable<String>(dependsOnOperationId);
    }
    map['dependency_order'] = Variable<int>(dependencyOrder);
    map['status'] = Variable<String>(status);
    map['retry_count'] = Variable<int>(retryCount);
    if (!nullToAbsent || nextRetryAt != null) {
      map['next_retry_at'] = Variable<DateTime>(nextRetryAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || sentAt != null) {
      map['sent_at'] = Variable<DateTime>(sentAt);
    }
    if (!nullToAbsent || ackedAt != null) {
      map['acked_at'] = Variable<DateTime>(ackedAt);
    }
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    if (!nullToAbsent || conflictDetails != null) {
      map['conflict_details'] = Variable<String>(conflictDetails);
    }
    map['schema_version'] = Variable<int>(schemaVersion);
    return map;
  }

  SyncOutboxCompanion toCompanion(bool nullToAbsent) {
    return SyncOutboxCompanion(
      id: Value(id),
      operationId: Value(operationId),
      deviceId: Value(deviceId),
      entityType: Value(entityType),
      entityId: Value(entityId),
      operationType: Value(operationType),
      baseVersion: Value(baseVersion),
      payload: Value(payload),
      dependsOnOperationId: dependsOnOperationId == null && nullToAbsent
          ? const Value.absent()
          : Value(dependsOnOperationId),
      dependencyOrder: Value(dependencyOrder),
      status: Value(status),
      retryCount: Value(retryCount),
      nextRetryAt: nextRetryAt == null && nullToAbsent
          ? const Value.absent()
          : Value(nextRetryAt),
      createdAt: Value(createdAt),
      sentAt: sentAt == null && nullToAbsent
          ? const Value.absent()
          : Value(sentAt),
      ackedAt: ackedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(ackedAt),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      conflictDetails: conflictDetails == null && nullToAbsent
          ? const Value.absent()
          : Value(conflictDetails),
      schemaVersion: Value(schemaVersion),
    );
  }

  factory SyncOutboxEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncOutboxEntry(
      id: serializer.fromJson<int>(json['id']),
      operationId: serializer.fromJson<String>(json['operationId']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      entityType: serializer.fromJson<String>(json['entityType']),
      entityId: serializer.fromJson<String>(json['entityId']),
      operationType: serializer.fromJson<String>(json['operationType']),
      baseVersion: serializer.fromJson<int>(json['baseVersion']),
      payload: serializer.fromJson<String>(json['payload']),
      dependsOnOperationId: serializer.fromJson<String?>(
        json['dependsOnOperationId'],
      ),
      dependencyOrder: serializer.fromJson<int>(json['dependencyOrder']),
      status: serializer.fromJson<String>(json['status']),
      retryCount: serializer.fromJson<int>(json['retryCount']),
      nextRetryAt: serializer.fromJson<DateTime?>(json['nextRetryAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      sentAt: serializer.fromJson<DateTime?>(json['sentAt']),
      ackedAt: serializer.fromJson<DateTime?>(json['ackedAt']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      conflictDetails: serializer.fromJson<String?>(json['conflictDetails']),
      schemaVersion: serializer.fromJson<int>(json['schemaVersion']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'operationId': serializer.toJson<String>(operationId),
      'deviceId': serializer.toJson<String>(deviceId),
      'entityType': serializer.toJson<String>(entityType),
      'entityId': serializer.toJson<String>(entityId),
      'operationType': serializer.toJson<String>(operationType),
      'baseVersion': serializer.toJson<int>(baseVersion),
      'payload': serializer.toJson<String>(payload),
      'dependsOnOperationId': serializer.toJson<String?>(dependsOnOperationId),
      'dependencyOrder': serializer.toJson<int>(dependencyOrder),
      'status': serializer.toJson<String>(status),
      'retryCount': serializer.toJson<int>(retryCount),
      'nextRetryAt': serializer.toJson<DateTime?>(nextRetryAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'sentAt': serializer.toJson<DateTime?>(sentAt),
      'ackedAt': serializer.toJson<DateTime?>(ackedAt),
      'lastError': serializer.toJson<String?>(lastError),
      'conflictDetails': serializer.toJson<String?>(conflictDetails),
      'schemaVersion': serializer.toJson<int>(schemaVersion),
    };
  }

  SyncOutboxEntry copyWith({
    int? id,
    String? operationId,
    String? deviceId,
    String? entityType,
    String? entityId,
    String? operationType,
    int? baseVersion,
    String? payload,
    Value<String?> dependsOnOperationId = const Value.absent(),
    int? dependencyOrder,
    String? status,
    int? retryCount,
    Value<DateTime?> nextRetryAt = const Value.absent(),
    DateTime? createdAt,
    Value<DateTime?> sentAt = const Value.absent(),
    Value<DateTime?> ackedAt = const Value.absent(),
    Value<String?> lastError = const Value.absent(),
    Value<String?> conflictDetails = const Value.absent(),
    int? schemaVersion,
  }) => SyncOutboxEntry(
    id: id ?? this.id,
    operationId: operationId ?? this.operationId,
    deviceId: deviceId ?? this.deviceId,
    entityType: entityType ?? this.entityType,
    entityId: entityId ?? this.entityId,
    operationType: operationType ?? this.operationType,
    baseVersion: baseVersion ?? this.baseVersion,
    payload: payload ?? this.payload,
    dependsOnOperationId: dependsOnOperationId.present
        ? dependsOnOperationId.value
        : this.dependsOnOperationId,
    dependencyOrder: dependencyOrder ?? this.dependencyOrder,
    status: status ?? this.status,
    retryCount: retryCount ?? this.retryCount,
    nextRetryAt: nextRetryAt.present ? nextRetryAt.value : this.nextRetryAt,
    createdAt: createdAt ?? this.createdAt,
    sentAt: sentAt.present ? sentAt.value : this.sentAt,
    ackedAt: ackedAt.present ? ackedAt.value : this.ackedAt,
    lastError: lastError.present ? lastError.value : this.lastError,
    conflictDetails: conflictDetails.present
        ? conflictDetails.value
        : this.conflictDetails,
    schemaVersion: schemaVersion ?? this.schemaVersion,
  );
  SyncOutboxEntry copyWithCompanion(SyncOutboxCompanion data) {
    return SyncOutboxEntry(
      id: data.id.present ? data.id.value : this.id,
      operationId: data.operationId.present
          ? data.operationId.value
          : this.operationId,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      entityType: data.entityType.present
          ? data.entityType.value
          : this.entityType,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      operationType: data.operationType.present
          ? data.operationType.value
          : this.operationType,
      baseVersion: data.baseVersion.present
          ? data.baseVersion.value
          : this.baseVersion,
      payload: data.payload.present ? data.payload.value : this.payload,
      dependsOnOperationId: data.dependsOnOperationId.present
          ? data.dependsOnOperationId.value
          : this.dependsOnOperationId,
      dependencyOrder: data.dependencyOrder.present
          ? data.dependencyOrder.value
          : this.dependencyOrder,
      status: data.status.present ? data.status.value : this.status,
      retryCount: data.retryCount.present
          ? data.retryCount.value
          : this.retryCount,
      nextRetryAt: data.nextRetryAt.present
          ? data.nextRetryAt.value
          : this.nextRetryAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      sentAt: data.sentAt.present ? data.sentAt.value : this.sentAt,
      ackedAt: data.ackedAt.present ? data.ackedAt.value : this.ackedAt,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      conflictDetails: data.conflictDetails.present
          ? data.conflictDetails.value
          : this.conflictDetails,
      schemaVersion: data.schemaVersion.present
          ? data.schemaVersion.value
          : this.schemaVersion,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncOutboxEntry(')
          ..write('id: $id, ')
          ..write('operationId: $operationId, ')
          ..write('deviceId: $deviceId, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('operationType: $operationType, ')
          ..write('baseVersion: $baseVersion, ')
          ..write('payload: $payload, ')
          ..write('dependsOnOperationId: $dependsOnOperationId, ')
          ..write('dependencyOrder: $dependencyOrder, ')
          ..write('status: $status, ')
          ..write('retryCount: $retryCount, ')
          ..write('nextRetryAt: $nextRetryAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('sentAt: $sentAt, ')
          ..write('ackedAt: $ackedAt, ')
          ..write('lastError: $lastError, ')
          ..write('conflictDetails: $conflictDetails, ')
          ..write('schemaVersion: $schemaVersion')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    operationId,
    deviceId,
    entityType,
    entityId,
    operationType,
    baseVersion,
    payload,
    dependsOnOperationId,
    dependencyOrder,
    status,
    retryCount,
    nextRetryAt,
    createdAt,
    sentAt,
    ackedAt,
    lastError,
    conflictDetails,
    schemaVersion,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncOutboxEntry &&
          other.id == this.id &&
          other.operationId == this.operationId &&
          other.deviceId == this.deviceId &&
          other.entityType == this.entityType &&
          other.entityId == this.entityId &&
          other.operationType == this.operationType &&
          other.baseVersion == this.baseVersion &&
          other.payload == this.payload &&
          other.dependsOnOperationId == this.dependsOnOperationId &&
          other.dependencyOrder == this.dependencyOrder &&
          other.status == this.status &&
          other.retryCount == this.retryCount &&
          other.nextRetryAt == this.nextRetryAt &&
          other.createdAt == this.createdAt &&
          other.sentAt == this.sentAt &&
          other.ackedAt == this.ackedAt &&
          other.lastError == this.lastError &&
          other.conflictDetails == this.conflictDetails &&
          other.schemaVersion == this.schemaVersion);
}

class SyncOutboxCompanion extends UpdateCompanion<SyncOutboxEntry> {
  final Value<int> id;
  final Value<String> operationId;
  final Value<String> deviceId;
  final Value<String> entityType;
  final Value<String> entityId;
  final Value<String> operationType;
  final Value<int> baseVersion;
  final Value<String> payload;
  final Value<String?> dependsOnOperationId;
  final Value<int> dependencyOrder;
  final Value<String> status;
  final Value<int> retryCount;
  final Value<DateTime?> nextRetryAt;
  final Value<DateTime> createdAt;
  final Value<DateTime?> sentAt;
  final Value<DateTime?> ackedAt;
  final Value<String?> lastError;
  final Value<String?> conflictDetails;
  final Value<int> schemaVersion;
  const SyncOutboxCompanion({
    this.id = const Value.absent(),
    this.operationId = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.entityType = const Value.absent(),
    this.entityId = const Value.absent(),
    this.operationType = const Value.absent(),
    this.baseVersion = const Value.absent(),
    this.payload = const Value.absent(),
    this.dependsOnOperationId = const Value.absent(),
    this.dependencyOrder = const Value.absent(),
    this.status = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.nextRetryAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.sentAt = const Value.absent(),
    this.ackedAt = const Value.absent(),
    this.lastError = const Value.absent(),
    this.conflictDetails = const Value.absent(),
    this.schemaVersion = const Value.absent(),
  });
  SyncOutboxCompanion.insert({
    this.id = const Value.absent(),
    required String operationId,
    required String deviceId,
    required String entityType,
    required String entityId,
    required String operationType,
    this.baseVersion = const Value.absent(),
    required String payload,
    this.dependsOnOperationId = const Value.absent(),
    this.dependencyOrder = const Value.absent(),
    this.status = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.nextRetryAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.sentAt = const Value.absent(),
    this.ackedAt = const Value.absent(),
    this.lastError = const Value.absent(),
    this.conflictDetails = const Value.absent(),
    this.schemaVersion = const Value.absent(),
  }) : operationId = Value(operationId),
       deviceId = Value(deviceId),
       entityType = Value(entityType),
       entityId = Value(entityId),
       operationType = Value(operationType),
       payload = Value(payload);
  static Insertable<SyncOutboxEntry> custom({
    Expression<int>? id,
    Expression<String>? operationId,
    Expression<String>? deviceId,
    Expression<String>? entityType,
    Expression<String>? entityId,
    Expression<String>? operationType,
    Expression<int>? baseVersion,
    Expression<String>? payload,
    Expression<String>? dependsOnOperationId,
    Expression<int>? dependencyOrder,
    Expression<String>? status,
    Expression<int>? retryCount,
    Expression<DateTime>? nextRetryAt,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? sentAt,
    Expression<DateTime>? ackedAt,
    Expression<String>? lastError,
    Expression<String>? conflictDetails,
    Expression<int>? schemaVersion,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (operationId != null) 'operation_id': operationId,
      if (deviceId != null) 'device_id': deviceId,
      if (entityType != null) 'entity_type': entityType,
      if (entityId != null) 'entity_id': entityId,
      if (operationType != null) 'operation_type': operationType,
      if (baseVersion != null) 'base_version': baseVersion,
      if (payload != null) 'payload': payload,
      if (dependsOnOperationId != null)
        'depends_on_operation_id': dependsOnOperationId,
      if (dependencyOrder != null) 'dependency_order': dependencyOrder,
      if (status != null) 'status': status,
      if (retryCount != null) 'retry_count': retryCount,
      if (nextRetryAt != null) 'next_retry_at': nextRetryAt,
      if (createdAt != null) 'created_at': createdAt,
      if (sentAt != null) 'sent_at': sentAt,
      if (ackedAt != null) 'acked_at': ackedAt,
      if (lastError != null) 'last_error': lastError,
      if (conflictDetails != null) 'conflict_details': conflictDetails,
      if (schemaVersion != null) 'schema_version': schemaVersion,
    });
  }

  SyncOutboxCompanion copyWith({
    Value<int>? id,
    Value<String>? operationId,
    Value<String>? deviceId,
    Value<String>? entityType,
    Value<String>? entityId,
    Value<String>? operationType,
    Value<int>? baseVersion,
    Value<String>? payload,
    Value<String?>? dependsOnOperationId,
    Value<int>? dependencyOrder,
    Value<String>? status,
    Value<int>? retryCount,
    Value<DateTime?>? nextRetryAt,
    Value<DateTime>? createdAt,
    Value<DateTime?>? sentAt,
    Value<DateTime?>? ackedAt,
    Value<String?>? lastError,
    Value<String?>? conflictDetails,
    Value<int>? schemaVersion,
  }) {
    return SyncOutboxCompanion(
      id: id ?? this.id,
      operationId: operationId ?? this.operationId,
      deviceId: deviceId ?? this.deviceId,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      operationType: operationType ?? this.operationType,
      baseVersion: baseVersion ?? this.baseVersion,
      payload: payload ?? this.payload,
      dependsOnOperationId: dependsOnOperationId ?? this.dependsOnOperationId,
      dependencyOrder: dependencyOrder ?? this.dependencyOrder,
      status: status ?? this.status,
      retryCount: retryCount ?? this.retryCount,
      nextRetryAt: nextRetryAt ?? this.nextRetryAt,
      createdAt: createdAt ?? this.createdAt,
      sentAt: sentAt ?? this.sentAt,
      ackedAt: ackedAt ?? this.ackedAt,
      lastError: lastError ?? this.lastError,
      conflictDetails: conflictDetails ?? this.conflictDetails,
      schemaVersion: schemaVersion ?? this.schemaVersion,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (operationId.present) {
      map['operation_id'] = Variable<String>(operationId.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (entityType.present) {
      map['entity_type'] = Variable<String>(entityType.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (operationType.present) {
      map['operation_type'] = Variable<String>(operationType.value);
    }
    if (baseVersion.present) {
      map['base_version'] = Variable<int>(baseVersion.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (dependsOnOperationId.present) {
      map['depends_on_operation_id'] = Variable<String>(
        dependsOnOperationId.value,
      );
    }
    if (dependencyOrder.present) {
      map['dependency_order'] = Variable<int>(dependencyOrder.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (retryCount.present) {
      map['retry_count'] = Variable<int>(retryCount.value);
    }
    if (nextRetryAt.present) {
      map['next_retry_at'] = Variable<DateTime>(nextRetryAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (sentAt.present) {
      map['sent_at'] = Variable<DateTime>(sentAt.value);
    }
    if (ackedAt.present) {
      map['acked_at'] = Variable<DateTime>(ackedAt.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (conflictDetails.present) {
      map['conflict_details'] = Variable<String>(conflictDetails.value);
    }
    if (schemaVersion.present) {
      map['schema_version'] = Variable<int>(schemaVersion.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncOutboxCompanion(')
          ..write('id: $id, ')
          ..write('operationId: $operationId, ')
          ..write('deviceId: $deviceId, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('operationType: $operationType, ')
          ..write('baseVersion: $baseVersion, ')
          ..write('payload: $payload, ')
          ..write('dependsOnOperationId: $dependsOnOperationId, ')
          ..write('dependencyOrder: $dependencyOrder, ')
          ..write('status: $status, ')
          ..write('retryCount: $retryCount, ')
          ..write('nextRetryAt: $nextRetryAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('sentAt: $sentAt, ')
          ..write('ackedAt: $ackedAt, ')
          ..write('lastError: $lastError, ')
          ..write('conflictDetails: $conflictDetails, ')
          ..write('schemaVersion: $schemaVersion')
          ..write(')'))
        .toString();
  }
}

class $TerminalSequencesTable extends TerminalSequences
    with TableInfo<$TerminalSequencesTable, TerminalSequence> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TerminalSequencesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _sequenceKeyMeta = const VerificationMeta(
    'sequenceKey',
  );
  @override
  late final GeneratedColumn<String> sequenceKey = GeneratedColumn<String>(
    'sequence_key',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 30,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _businessDateMeta = const VerificationMeta(
    'businessDate',
  );
  @override
  late final GeneratedColumn<String> businessDate = GeneratedColumn<String>(
    'business_date',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 8,
      maxTextLength: 10,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currentValueMeta = const VerificationMeta(
    'currentValue',
  );
  @override
  late final GeneratedColumn<int> currentValue = GeneratedColumn<int>(
    'current_value',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    sequenceKey,
    businessDate,
    currentValue,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'terminal_sequences';
  @override
  VerificationContext validateIntegrity(
    Insertable<TerminalSequence> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('sequence_key')) {
      context.handle(
        _sequenceKeyMeta,
        sequenceKey.isAcceptableOrUnknown(
          data['sequence_key']!,
          _sequenceKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sequenceKeyMeta);
    }
    if (data.containsKey('business_date')) {
      context.handle(
        _businessDateMeta,
        businessDate.isAcceptableOrUnknown(
          data['business_date']!,
          _businessDateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_businessDateMeta);
    }
    if (data.containsKey('current_value')) {
      context.handle(
        _currentValueMeta,
        currentValue.isAcceptableOrUnknown(
          data['current_value']!,
          _currentValueMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_currentValueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {sequenceKey};
  @override
  TerminalSequence map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TerminalSequence(
      sequenceKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sequence_key'],
      )!,
      businessDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}business_date'],
      )!,
      currentValue: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}current_value'],
      )!,
    );
  }

  @override
  $TerminalSequencesTable createAlias(String alias) {
    return $TerminalSequencesTable(attachedDatabase, alias);
  }
}

class TerminalSequence extends DataClass
    implements Insertable<TerminalSequence> {
  final String sequenceKey;
  final String businessDate;
  final int currentValue;
  const TerminalSequence({
    required this.sequenceKey,
    required this.businessDate,
    required this.currentValue,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['sequence_key'] = Variable<String>(sequenceKey);
    map['business_date'] = Variable<String>(businessDate);
    map['current_value'] = Variable<int>(currentValue);
    return map;
  }

  TerminalSequencesCompanion toCompanion(bool nullToAbsent) {
    return TerminalSequencesCompanion(
      sequenceKey: Value(sequenceKey),
      businessDate: Value(businessDate),
      currentValue: Value(currentValue),
    );
  }

  factory TerminalSequence.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TerminalSequence(
      sequenceKey: serializer.fromJson<String>(json['sequenceKey']),
      businessDate: serializer.fromJson<String>(json['businessDate']),
      currentValue: serializer.fromJson<int>(json['currentValue']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'sequenceKey': serializer.toJson<String>(sequenceKey),
      'businessDate': serializer.toJson<String>(businessDate),
      'currentValue': serializer.toJson<int>(currentValue),
    };
  }

  TerminalSequence copyWith({
    String? sequenceKey,
    String? businessDate,
    int? currentValue,
  }) => TerminalSequence(
    sequenceKey: sequenceKey ?? this.sequenceKey,
    businessDate: businessDate ?? this.businessDate,
    currentValue: currentValue ?? this.currentValue,
  );
  TerminalSequence copyWithCompanion(TerminalSequencesCompanion data) {
    return TerminalSequence(
      sequenceKey: data.sequenceKey.present
          ? data.sequenceKey.value
          : this.sequenceKey,
      businessDate: data.businessDate.present
          ? data.businessDate.value
          : this.businessDate,
      currentValue: data.currentValue.present
          ? data.currentValue.value
          : this.currentValue,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TerminalSequence(')
          ..write('sequenceKey: $sequenceKey, ')
          ..write('businessDate: $businessDate, ')
          ..write('currentValue: $currentValue')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(sequenceKey, businessDate, currentValue);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TerminalSequence &&
          other.sequenceKey == this.sequenceKey &&
          other.businessDate == this.businessDate &&
          other.currentValue == this.currentValue);
}

class TerminalSequencesCompanion extends UpdateCompanion<TerminalSequence> {
  final Value<String> sequenceKey;
  final Value<String> businessDate;
  final Value<int> currentValue;
  final Value<int> rowid;
  const TerminalSequencesCompanion({
    this.sequenceKey = const Value.absent(),
    this.businessDate = const Value.absent(),
    this.currentValue = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TerminalSequencesCompanion.insert({
    required String sequenceKey,
    required String businessDate,
    required int currentValue,
    this.rowid = const Value.absent(),
  }) : sequenceKey = Value(sequenceKey),
       businessDate = Value(businessDate),
       currentValue = Value(currentValue);
  static Insertable<TerminalSequence> custom({
    Expression<String>? sequenceKey,
    Expression<String>? businessDate,
    Expression<int>? currentValue,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (sequenceKey != null) 'sequence_key': sequenceKey,
      if (businessDate != null) 'business_date': businessDate,
      if (currentValue != null) 'current_value': currentValue,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TerminalSequencesCompanion copyWith({
    Value<String>? sequenceKey,
    Value<String>? businessDate,
    Value<int>? currentValue,
    Value<int>? rowid,
  }) {
    return TerminalSequencesCompanion(
      sequenceKey: sequenceKey ?? this.sequenceKey,
      businessDate: businessDate ?? this.businessDate,
      currentValue: currentValue ?? this.currentValue,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (sequenceKey.present) {
      map['sequence_key'] = Variable<String>(sequenceKey.value);
    }
    if (businessDate.present) {
      map['business_date'] = Variable<String>(businessDate.value);
    }
    if (currentValue.present) {
      map['current_value'] = Variable<int>(currentValue.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TerminalSequencesCompanion(')
          ..write('sequenceKey: $sequenceKey, ')
          ..write('businessDate: $businessDate, ')
          ..write('currentValue: $currentValue, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OfflinePrintJobsTable extends OfflinePrintJobs
    with TableInfo<$OfflinePrintJobsTable, OfflinePrintJob> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OfflinePrintJobsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _jobTypeMeta = const VerificationMeta(
    'jobType',
  );
  @override
  late final GeneratedColumn<String> jobType = GeneratedColumn<String>(
    'job_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _orderIdMeta = const VerificationMeta(
    'orderId',
  );
  @override
  late final GeneratedColumn<String> orderId = GeneratedColumn<String>(
    'order_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _printerTargetMeta = const VerificationMeta(
    'printerTarget',
  );
  @override
  late final GeneratedColumn<String> printerTarget = GeneratedColumn<String>(
    'printer_target',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rawEscPosDataMeta = const VerificationMeta(
    'rawEscPosData',
  );
  @override
  late final GeneratedColumn<Uint8List> rawEscPosData =
      GeneratedColumn<Uint8List>(
        'raw_esc_pos_data',
        aliasedName,
        false,
        type: DriftSqlType.blob,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('QUEUED'),
  );
  static const VerificationMeta _retryCountMeta = const VerificationMeta(
    'retryCount',
  );
  @override
  late final GeneratedColumn<int> retryCount = GeneratedColumn<int>(
    'retry_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    jobType,
    orderId,
    printerTarget,
    rawEscPosData,
    status,
    retryCount,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'offline_print_jobs';
  @override
  VerificationContext validateIntegrity(
    Insertable<OfflinePrintJob> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('job_type')) {
      context.handle(
        _jobTypeMeta,
        jobType.isAcceptableOrUnknown(data['job_type']!, _jobTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_jobTypeMeta);
    }
    if (data.containsKey('order_id')) {
      context.handle(
        _orderIdMeta,
        orderId.isAcceptableOrUnknown(data['order_id']!, _orderIdMeta),
      );
    }
    if (data.containsKey('printer_target')) {
      context.handle(
        _printerTargetMeta,
        printerTarget.isAcceptableOrUnknown(
          data['printer_target']!,
          _printerTargetMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_printerTargetMeta);
    }
    if (data.containsKey('raw_esc_pos_data')) {
      context.handle(
        _rawEscPosDataMeta,
        rawEscPosData.isAcceptableOrUnknown(
          data['raw_esc_pos_data']!,
          _rawEscPosDataMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_rawEscPosDataMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('retry_count')) {
      context.handle(
        _retryCountMeta,
        retryCount.isAcceptableOrUnknown(data['retry_count']!, _retryCountMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OfflinePrintJob map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OfflinePrintJob(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      jobType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}job_type'],
      )!,
      orderId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}order_id'],
      ),
      printerTarget: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}printer_target'],
      )!,
      rawEscPosData: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}raw_esc_pos_data'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      retryCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}retry_count'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $OfflinePrintJobsTable createAlias(String alias) {
    return $OfflinePrintJobsTable(attachedDatabase, alias);
  }
}

class OfflinePrintJob extends DataClass implements Insertable<OfflinePrintJob> {
  final int id;
  final String jobType;
  final String? orderId;
  final String printerTarget;
  final Uint8List rawEscPosData;
  final String status;
  final int retryCount;
  final DateTime createdAt;
  const OfflinePrintJob({
    required this.id,
    required this.jobType,
    this.orderId,
    required this.printerTarget,
    required this.rawEscPosData,
    required this.status,
    required this.retryCount,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['job_type'] = Variable<String>(jobType);
    if (!nullToAbsent || orderId != null) {
      map['order_id'] = Variable<String>(orderId);
    }
    map['printer_target'] = Variable<String>(printerTarget);
    map['raw_esc_pos_data'] = Variable<Uint8List>(rawEscPosData);
    map['status'] = Variable<String>(status);
    map['retry_count'] = Variable<int>(retryCount);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  OfflinePrintJobsCompanion toCompanion(bool nullToAbsent) {
    return OfflinePrintJobsCompanion(
      id: Value(id),
      jobType: Value(jobType),
      orderId: orderId == null && nullToAbsent
          ? const Value.absent()
          : Value(orderId),
      printerTarget: Value(printerTarget),
      rawEscPosData: Value(rawEscPosData),
      status: Value(status),
      retryCount: Value(retryCount),
      createdAt: Value(createdAt),
    );
  }

  factory OfflinePrintJob.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OfflinePrintJob(
      id: serializer.fromJson<int>(json['id']),
      jobType: serializer.fromJson<String>(json['jobType']),
      orderId: serializer.fromJson<String?>(json['orderId']),
      printerTarget: serializer.fromJson<String>(json['printerTarget']),
      rawEscPosData: serializer.fromJson<Uint8List>(json['rawEscPosData']),
      status: serializer.fromJson<String>(json['status']),
      retryCount: serializer.fromJson<int>(json['retryCount']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'jobType': serializer.toJson<String>(jobType),
      'orderId': serializer.toJson<String?>(orderId),
      'printerTarget': serializer.toJson<String>(printerTarget),
      'rawEscPosData': serializer.toJson<Uint8List>(rawEscPosData),
      'status': serializer.toJson<String>(status),
      'retryCount': serializer.toJson<int>(retryCount),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  OfflinePrintJob copyWith({
    int? id,
    String? jobType,
    Value<String?> orderId = const Value.absent(),
    String? printerTarget,
    Uint8List? rawEscPosData,
    String? status,
    int? retryCount,
    DateTime? createdAt,
  }) => OfflinePrintJob(
    id: id ?? this.id,
    jobType: jobType ?? this.jobType,
    orderId: orderId.present ? orderId.value : this.orderId,
    printerTarget: printerTarget ?? this.printerTarget,
    rawEscPosData: rawEscPosData ?? this.rawEscPosData,
    status: status ?? this.status,
    retryCount: retryCount ?? this.retryCount,
    createdAt: createdAt ?? this.createdAt,
  );
  OfflinePrintJob copyWithCompanion(OfflinePrintJobsCompanion data) {
    return OfflinePrintJob(
      id: data.id.present ? data.id.value : this.id,
      jobType: data.jobType.present ? data.jobType.value : this.jobType,
      orderId: data.orderId.present ? data.orderId.value : this.orderId,
      printerTarget: data.printerTarget.present
          ? data.printerTarget.value
          : this.printerTarget,
      rawEscPosData: data.rawEscPosData.present
          ? data.rawEscPosData.value
          : this.rawEscPosData,
      status: data.status.present ? data.status.value : this.status,
      retryCount: data.retryCount.present
          ? data.retryCount.value
          : this.retryCount,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OfflinePrintJob(')
          ..write('id: $id, ')
          ..write('jobType: $jobType, ')
          ..write('orderId: $orderId, ')
          ..write('printerTarget: $printerTarget, ')
          ..write('rawEscPosData: $rawEscPosData, ')
          ..write('status: $status, ')
          ..write('retryCount: $retryCount, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    jobType,
    orderId,
    printerTarget,
    $driftBlobEquality.hash(rawEscPosData),
    status,
    retryCount,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OfflinePrintJob &&
          other.id == this.id &&
          other.jobType == this.jobType &&
          other.orderId == this.orderId &&
          other.printerTarget == this.printerTarget &&
          $driftBlobEquality.equals(other.rawEscPosData, this.rawEscPosData) &&
          other.status == this.status &&
          other.retryCount == this.retryCount &&
          other.createdAt == this.createdAt);
}

class OfflinePrintJobsCompanion extends UpdateCompanion<OfflinePrintJob> {
  final Value<int> id;
  final Value<String> jobType;
  final Value<String?> orderId;
  final Value<String> printerTarget;
  final Value<Uint8List> rawEscPosData;
  final Value<String> status;
  final Value<int> retryCount;
  final Value<DateTime> createdAt;
  const OfflinePrintJobsCompanion({
    this.id = const Value.absent(),
    this.jobType = const Value.absent(),
    this.orderId = const Value.absent(),
    this.printerTarget = const Value.absent(),
    this.rawEscPosData = const Value.absent(),
    this.status = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  OfflinePrintJobsCompanion.insert({
    this.id = const Value.absent(),
    required String jobType,
    this.orderId = const Value.absent(),
    required String printerTarget,
    required Uint8List rawEscPosData,
    this.status = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : jobType = Value(jobType),
       printerTarget = Value(printerTarget),
       rawEscPosData = Value(rawEscPosData);
  static Insertable<OfflinePrintJob> custom({
    Expression<int>? id,
    Expression<String>? jobType,
    Expression<String>? orderId,
    Expression<String>? printerTarget,
    Expression<Uint8List>? rawEscPosData,
    Expression<String>? status,
    Expression<int>? retryCount,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (jobType != null) 'job_type': jobType,
      if (orderId != null) 'order_id': orderId,
      if (printerTarget != null) 'printer_target': printerTarget,
      if (rawEscPosData != null) 'raw_esc_pos_data': rawEscPosData,
      if (status != null) 'status': status,
      if (retryCount != null) 'retry_count': retryCount,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  OfflinePrintJobsCompanion copyWith({
    Value<int>? id,
    Value<String>? jobType,
    Value<String?>? orderId,
    Value<String>? printerTarget,
    Value<Uint8List>? rawEscPosData,
    Value<String>? status,
    Value<int>? retryCount,
    Value<DateTime>? createdAt,
  }) {
    return OfflinePrintJobsCompanion(
      id: id ?? this.id,
      jobType: jobType ?? this.jobType,
      orderId: orderId ?? this.orderId,
      printerTarget: printerTarget ?? this.printerTarget,
      rawEscPosData: rawEscPosData ?? this.rawEscPosData,
      status: status ?? this.status,
      retryCount: retryCount ?? this.retryCount,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (jobType.present) {
      map['job_type'] = Variable<String>(jobType.value);
    }
    if (orderId.present) {
      map['order_id'] = Variable<String>(orderId.value);
    }
    if (printerTarget.present) {
      map['printer_target'] = Variable<String>(printerTarget.value);
    }
    if (rawEscPosData.present) {
      map['raw_esc_pos_data'] = Variable<Uint8List>(rawEscPosData.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (retryCount.present) {
      map['retry_count'] = Variable<int>(retryCount.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OfflinePrintJobsCompanion(')
          ..write('id: $id, ')
          ..write('jobType: $jobType, ')
          ..write('orderId: $orderId, ')
          ..write('printerTarget: $printerTarget, ')
          ..write('rawEscPosData: $rawEscPosData, ')
          ..write('status: $status, ')
          ..write('retryCount: $retryCount, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $SyncCursorsTable extends SyncCursors
    with TableInfo<$SyncCursorsTable, SyncCursor> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncCursorsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _feedKeyMeta = const VerificationMeta(
    'feedKey',
  );
  @override
  late final GeneratedColumn<String> feedKey = GeneratedColumn<String>(
    'feed_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastPulledSequenceMeta =
      const VerificationMeta('lastPulledSequence');
  @override
  late final GeneratedColumn<int> lastPulledSequence = GeneratedColumn<int>(
    'last_pulled_sequence',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastSyncAttemptMeta = const VerificationMeta(
    'lastSyncAttempt',
  );
  @override
  late final GeneratedColumn<DateTime> lastSyncAttempt =
      GeneratedColumn<DateTime>(
        'last_sync_attempt',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _lastSuccessfulSyncMeta =
      const VerificationMeta('lastSuccessfulSync');
  @override
  late final GeneratedColumn<DateTime> lastSuccessfulSync =
      GeneratedColumn<DateTime>(
        'last_successful_sync',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    feedKey,
    lastPulledSequence,
    lastSyncAttempt,
    lastSuccessfulSync,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_cursors';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncCursor> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('feed_key')) {
      context.handle(
        _feedKeyMeta,
        feedKey.isAcceptableOrUnknown(data['feed_key']!, _feedKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_feedKeyMeta);
    }
    if (data.containsKey('last_pulled_sequence')) {
      context.handle(
        _lastPulledSequenceMeta,
        lastPulledSequence.isAcceptableOrUnknown(
          data['last_pulled_sequence']!,
          _lastPulledSequenceMeta,
        ),
      );
    }
    if (data.containsKey('last_sync_attempt')) {
      context.handle(
        _lastSyncAttemptMeta,
        lastSyncAttempt.isAcceptableOrUnknown(
          data['last_sync_attempt']!,
          _lastSyncAttemptMeta,
        ),
      );
    }
    if (data.containsKey('last_successful_sync')) {
      context.handle(
        _lastSuccessfulSyncMeta,
        lastSuccessfulSync.isAcceptableOrUnknown(
          data['last_successful_sync']!,
          _lastSuccessfulSyncMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {feedKey};
  @override
  SyncCursor map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncCursor(
      feedKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}feed_key'],
      )!,
      lastPulledSequence: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_pulled_sequence'],
      )!,
      lastSyncAttempt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_sync_attempt'],
      ),
      lastSuccessfulSync: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_successful_sync'],
      ),
    );
  }

  @override
  $SyncCursorsTable createAlias(String alias) {
    return $SyncCursorsTable(attachedDatabase, alias);
  }
}

class SyncCursor extends DataClass implements Insertable<SyncCursor> {
  final String feedKey;
  final int lastPulledSequence;
  final DateTime? lastSyncAttempt;
  final DateTime? lastSuccessfulSync;
  const SyncCursor({
    required this.feedKey,
    required this.lastPulledSequence,
    this.lastSyncAttempt,
    this.lastSuccessfulSync,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['feed_key'] = Variable<String>(feedKey);
    map['last_pulled_sequence'] = Variable<int>(lastPulledSequence);
    if (!nullToAbsent || lastSyncAttempt != null) {
      map['last_sync_attempt'] = Variable<DateTime>(lastSyncAttempt);
    }
    if (!nullToAbsent || lastSuccessfulSync != null) {
      map['last_successful_sync'] = Variable<DateTime>(lastSuccessfulSync);
    }
    return map;
  }

  SyncCursorsCompanion toCompanion(bool nullToAbsent) {
    return SyncCursorsCompanion(
      feedKey: Value(feedKey),
      lastPulledSequence: Value(lastPulledSequence),
      lastSyncAttempt: lastSyncAttempt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSyncAttempt),
      lastSuccessfulSync: lastSuccessfulSync == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSuccessfulSync),
    );
  }

  factory SyncCursor.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncCursor(
      feedKey: serializer.fromJson<String>(json['feedKey']),
      lastPulledSequence: serializer.fromJson<int>(json['lastPulledSequence']),
      lastSyncAttempt: serializer.fromJson<DateTime?>(json['lastSyncAttempt']),
      lastSuccessfulSync: serializer.fromJson<DateTime?>(
        json['lastSuccessfulSync'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'feedKey': serializer.toJson<String>(feedKey),
      'lastPulledSequence': serializer.toJson<int>(lastPulledSequence),
      'lastSyncAttempt': serializer.toJson<DateTime?>(lastSyncAttempt),
      'lastSuccessfulSync': serializer.toJson<DateTime?>(lastSuccessfulSync),
    };
  }

  SyncCursor copyWith({
    String? feedKey,
    int? lastPulledSequence,
    Value<DateTime?> lastSyncAttempt = const Value.absent(),
    Value<DateTime?> lastSuccessfulSync = const Value.absent(),
  }) => SyncCursor(
    feedKey: feedKey ?? this.feedKey,
    lastPulledSequence: lastPulledSequence ?? this.lastPulledSequence,
    lastSyncAttempt: lastSyncAttempt.present
        ? lastSyncAttempt.value
        : this.lastSyncAttempt,
    lastSuccessfulSync: lastSuccessfulSync.present
        ? lastSuccessfulSync.value
        : this.lastSuccessfulSync,
  );
  SyncCursor copyWithCompanion(SyncCursorsCompanion data) {
    return SyncCursor(
      feedKey: data.feedKey.present ? data.feedKey.value : this.feedKey,
      lastPulledSequence: data.lastPulledSequence.present
          ? data.lastPulledSequence.value
          : this.lastPulledSequence,
      lastSyncAttempt: data.lastSyncAttempt.present
          ? data.lastSyncAttempt.value
          : this.lastSyncAttempt,
      lastSuccessfulSync: data.lastSuccessfulSync.present
          ? data.lastSuccessfulSync.value
          : this.lastSuccessfulSync,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncCursor(')
          ..write('feedKey: $feedKey, ')
          ..write('lastPulledSequence: $lastPulledSequence, ')
          ..write('lastSyncAttempt: $lastSyncAttempt, ')
          ..write('lastSuccessfulSync: $lastSuccessfulSync')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    feedKey,
    lastPulledSequence,
    lastSyncAttempt,
    lastSuccessfulSync,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncCursor &&
          other.feedKey == this.feedKey &&
          other.lastPulledSequence == this.lastPulledSequence &&
          other.lastSyncAttempt == this.lastSyncAttempt &&
          other.lastSuccessfulSync == this.lastSuccessfulSync);
}

class SyncCursorsCompanion extends UpdateCompanion<SyncCursor> {
  final Value<String> feedKey;
  final Value<int> lastPulledSequence;
  final Value<DateTime?> lastSyncAttempt;
  final Value<DateTime?> lastSuccessfulSync;
  final Value<int> rowid;
  const SyncCursorsCompanion({
    this.feedKey = const Value.absent(),
    this.lastPulledSequence = const Value.absent(),
    this.lastSyncAttempt = const Value.absent(),
    this.lastSuccessfulSync = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncCursorsCompanion.insert({
    required String feedKey,
    this.lastPulledSequence = const Value.absent(),
    this.lastSyncAttempt = const Value.absent(),
    this.lastSuccessfulSync = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : feedKey = Value(feedKey);
  static Insertable<SyncCursor> custom({
    Expression<String>? feedKey,
    Expression<int>? lastPulledSequence,
    Expression<DateTime>? lastSyncAttempt,
    Expression<DateTime>? lastSuccessfulSync,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (feedKey != null) 'feed_key': feedKey,
      if (lastPulledSequence != null)
        'last_pulled_sequence': lastPulledSequence,
      if (lastSyncAttempt != null) 'last_sync_attempt': lastSyncAttempt,
      if (lastSuccessfulSync != null)
        'last_successful_sync': lastSuccessfulSync,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncCursorsCompanion copyWith({
    Value<String>? feedKey,
    Value<int>? lastPulledSequence,
    Value<DateTime?>? lastSyncAttempt,
    Value<DateTime?>? lastSuccessfulSync,
    Value<int>? rowid,
  }) {
    return SyncCursorsCompanion(
      feedKey: feedKey ?? this.feedKey,
      lastPulledSequence: lastPulledSequence ?? this.lastPulledSequence,
      lastSyncAttempt: lastSyncAttempt ?? this.lastSyncAttempt,
      lastSuccessfulSync: lastSuccessfulSync ?? this.lastSuccessfulSync,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (feedKey.present) {
      map['feed_key'] = Variable<String>(feedKey.value);
    }
    if (lastPulledSequence.present) {
      map['last_pulled_sequence'] = Variable<int>(lastPulledSequence.value);
    }
    if (lastSyncAttempt.present) {
      map['last_sync_attempt'] = Variable<DateTime>(lastSyncAttempt.value);
    }
    if (lastSuccessfulSync.present) {
      map['last_successful_sync'] = Variable<DateTime>(
        lastSuccessfulSync.value,
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncCursorsCompanion(')
          ..write('feedKey: $feedKey, ')
          ..write('lastPulledSequence: $lastPulledSequence, ')
          ..write('lastSyncAttempt: $lastSyncAttempt, ')
          ..write('lastSuccessfulSync: $lastSuccessfulSync, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncConflictsTable extends SyncConflicts
    with TableInfo<$SyncConflictsTable, SyncConflict> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncConflictsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 36,
      maxTextLength: 36,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _operationIdMeta = const VerificationMeta(
    'operationId',
  );
  @override
  late final GeneratedColumn<String> operationId = GeneratedColumn<String>(
    'operation_id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 36,
      maxTextLength: 36,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityTypeMeta = const VerificationMeta(
    'entityType',
  );
  @override
  late final GeneratedColumn<String> entityType = GeneratedColumn<String>(
    'entity_type',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 50,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityIdMeta = const VerificationMeta(
    'entityId',
  );
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
    'entity_id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 36,
      maxTextLength: 36,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _conflictTypeMeta = const VerificationMeta(
    'conflictType',
  );
  @override
  late final GeneratedColumn<String> conflictType = GeneratedColumn<String>(
    'conflict_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _resolutionStatusMeta = const VerificationMeta(
    'resolutionStatus',
  );
  @override
  late final GeneratedColumn<String> resolutionStatus = GeneratedColumn<String>(
    'resolution_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('PENDING'),
  );
  static const VerificationMeta _errorMessageMeta = const VerificationMeta(
    'errorMessage',
  );
  @override
  late final GeneratedColumn<String> errorMessage = GeneratedColumn<String>(
    'error_message',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _serverStateMeta = const VerificationMeta(
    'serverState',
  );
  @override
  late final GeneratedColumn<String> serverState = GeneratedColumn<String>(
    'server_state',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _resolvedAtMeta = const VerificationMeta(
    'resolvedAt',
  );
  @override
  late final GeneratedColumn<DateTime> resolvedAt = GeneratedColumn<DateTime>(
    'resolved_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    operationId,
    entityType,
    entityId,
    conflictType,
    resolutionStatus,
    errorMessage,
    payload,
    serverState,
    createdAt,
    resolvedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_conflicts';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncConflict> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('operation_id')) {
      context.handle(
        _operationIdMeta,
        operationId.isAcceptableOrUnknown(
          data['operation_id']!,
          _operationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_operationIdMeta);
    }
    if (data.containsKey('entity_type')) {
      context.handle(
        _entityTypeMeta,
        entityType.isAcceptableOrUnknown(data['entity_type']!, _entityTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_entityTypeMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('conflict_type')) {
      context.handle(
        _conflictTypeMeta,
        conflictType.isAcceptableOrUnknown(
          data['conflict_type']!,
          _conflictTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_conflictTypeMeta);
    }
    if (data.containsKey('resolution_status')) {
      context.handle(
        _resolutionStatusMeta,
        resolutionStatus.isAcceptableOrUnknown(
          data['resolution_status']!,
          _resolutionStatusMeta,
        ),
      );
    }
    if (data.containsKey('error_message')) {
      context.handle(
        _errorMessageMeta,
        errorMessage.isAcceptableOrUnknown(
          data['error_message']!,
          _errorMessageMeta,
        ),
      );
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('server_state')) {
      context.handle(
        _serverStateMeta,
        serverState.isAcceptableOrUnknown(
          data['server_state']!,
          _serverStateMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('resolved_at')) {
      context.handle(
        _resolvedAtMeta,
        resolvedAt.isAcceptableOrUnknown(data['resolved_at']!, _resolvedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncConflict map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncConflict(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      operationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation_id'],
      )!,
      entityType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_type'],
      )!,
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      )!,
      conflictType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conflict_type'],
      )!,
      resolutionStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}resolution_status'],
      )!,
      errorMessage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_message'],
      ),
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      serverState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_state'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      resolvedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}resolved_at'],
      ),
    );
  }

  @override
  $SyncConflictsTable createAlias(String alias) {
    return $SyncConflictsTable(attachedDatabase, alias);
  }
}

class SyncConflict extends DataClass implements Insertable<SyncConflict> {
  final String id;
  final String operationId;
  final String entityType;
  final String entityId;
  final String conflictType;
  final String resolutionStatus;
  final String? errorMessage;
  final String payload;
  final String? serverState;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  const SyncConflict({
    required this.id,
    required this.operationId,
    required this.entityType,
    required this.entityId,
    required this.conflictType,
    required this.resolutionStatus,
    this.errorMessage,
    required this.payload,
    this.serverState,
    required this.createdAt,
    this.resolvedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['operation_id'] = Variable<String>(operationId);
    map['entity_type'] = Variable<String>(entityType);
    map['entity_id'] = Variable<String>(entityId);
    map['conflict_type'] = Variable<String>(conflictType);
    map['resolution_status'] = Variable<String>(resolutionStatus);
    if (!nullToAbsent || errorMessage != null) {
      map['error_message'] = Variable<String>(errorMessage);
    }
    map['payload'] = Variable<String>(payload);
    if (!nullToAbsent || serverState != null) {
      map['server_state'] = Variable<String>(serverState);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || resolvedAt != null) {
      map['resolved_at'] = Variable<DateTime>(resolvedAt);
    }
    return map;
  }

  SyncConflictsCompanion toCompanion(bool nullToAbsent) {
    return SyncConflictsCompanion(
      id: Value(id),
      operationId: Value(operationId),
      entityType: Value(entityType),
      entityId: Value(entityId),
      conflictType: Value(conflictType),
      resolutionStatus: Value(resolutionStatus),
      errorMessage: errorMessage == null && nullToAbsent
          ? const Value.absent()
          : Value(errorMessage),
      payload: Value(payload),
      serverState: serverState == null && nullToAbsent
          ? const Value.absent()
          : Value(serverState),
      createdAt: Value(createdAt),
      resolvedAt: resolvedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(resolvedAt),
    );
  }

  factory SyncConflict.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncConflict(
      id: serializer.fromJson<String>(json['id']),
      operationId: serializer.fromJson<String>(json['operationId']),
      entityType: serializer.fromJson<String>(json['entityType']),
      entityId: serializer.fromJson<String>(json['entityId']),
      conflictType: serializer.fromJson<String>(json['conflictType']),
      resolutionStatus: serializer.fromJson<String>(json['resolutionStatus']),
      errorMessage: serializer.fromJson<String?>(json['errorMessage']),
      payload: serializer.fromJson<String>(json['payload']),
      serverState: serializer.fromJson<String?>(json['serverState']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      resolvedAt: serializer.fromJson<DateTime?>(json['resolvedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'operationId': serializer.toJson<String>(operationId),
      'entityType': serializer.toJson<String>(entityType),
      'entityId': serializer.toJson<String>(entityId),
      'conflictType': serializer.toJson<String>(conflictType),
      'resolutionStatus': serializer.toJson<String>(resolutionStatus),
      'errorMessage': serializer.toJson<String?>(errorMessage),
      'payload': serializer.toJson<String>(payload),
      'serverState': serializer.toJson<String?>(serverState),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'resolvedAt': serializer.toJson<DateTime?>(resolvedAt),
    };
  }

  SyncConflict copyWith({
    String? id,
    String? operationId,
    String? entityType,
    String? entityId,
    String? conflictType,
    String? resolutionStatus,
    Value<String?> errorMessage = const Value.absent(),
    String? payload,
    Value<String?> serverState = const Value.absent(),
    DateTime? createdAt,
    Value<DateTime?> resolvedAt = const Value.absent(),
  }) => SyncConflict(
    id: id ?? this.id,
    operationId: operationId ?? this.operationId,
    entityType: entityType ?? this.entityType,
    entityId: entityId ?? this.entityId,
    conflictType: conflictType ?? this.conflictType,
    resolutionStatus: resolutionStatus ?? this.resolutionStatus,
    errorMessage: errorMessage.present ? errorMessage.value : this.errorMessage,
    payload: payload ?? this.payload,
    serverState: serverState.present ? serverState.value : this.serverState,
    createdAt: createdAt ?? this.createdAt,
    resolvedAt: resolvedAt.present ? resolvedAt.value : this.resolvedAt,
  );
  SyncConflict copyWithCompanion(SyncConflictsCompanion data) {
    return SyncConflict(
      id: data.id.present ? data.id.value : this.id,
      operationId: data.operationId.present
          ? data.operationId.value
          : this.operationId,
      entityType: data.entityType.present
          ? data.entityType.value
          : this.entityType,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      conflictType: data.conflictType.present
          ? data.conflictType.value
          : this.conflictType,
      resolutionStatus: data.resolutionStatus.present
          ? data.resolutionStatus.value
          : this.resolutionStatus,
      errorMessage: data.errorMessage.present
          ? data.errorMessage.value
          : this.errorMessage,
      payload: data.payload.present ? data.payload.value : this.payload,
      serverState: data.serverState.present
          ? data.serverState.value
          : this.serverState,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      resolvedAt: data.resolvedAt.present
          ? data.resolvedAt.value
          : this.resolvedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncConflict(')
          ..write('id: $id, ')
          ..write('operationId: $operationId, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('conflictType: $conflictType, ')
          ..write('resolutionStatus: $resolutionStatus, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('payload: $payload, ')
          ..write('serverState: $serverState, ')
          ..write('createdAt: $createdAt, ')
          ..write('resolvedAt: $resolvedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    operationId,
    entityType,
    entityId,
    conflictType,
    resolutionStatus,
    errorMessage,
    payload,
    serverState,
    createdAt,
    resolvedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncConflict &&
          other.id == this.id &&
          other.operationId == this.operationId &&
          other.entityType == this.entityType &&
          other.entityId == this.entityId &&
          other.conflictType == this.conflictType &&
          other.resolutionStatus == this.resolutionStatus &&
          other.errorMessage == this.errorMessage &&
          other.payload == this.payload &&
          other.serverState == this.serverState &&
          other.createdAt == this.createdAt &&
          other.resolvedAt == this.resolvedAt);
}

class SyncConflictsCompanion extends UpdateCompanion<SyncConflict> {
  final Value<String> id;
  final Value<String> operationId;
  final Value<String> entityType;
  final Value<String> entityId;
  final Value<String> conflictType;
  final Value<String> resolutionStatus;
  final Value<String?> errorMessage;
  final Value<String> payload;
  final Value<String?> serverState;
  final Value<DateTime> createdAt;
  final Value<DateTime?> resolvedAt;
  final Value<int> rowid;
  const SyncConflictsCompanion({
    this.id = const Value.absent(),
    this.operationId = const Value.absent(),
    this.entityType = const Value.absent(),
    this.entityId = const Value.absent(),
    this.conflictType = const Value.absent(),
    this.resolutionStatus = const Value.absent(),
    this.errorMessage = const Value.absent(),
    this.payload = const Value.absent(),
    this.serverState = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.resolvedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncConflictsCompanion.insert({
    required String id,
    required String operationId,
    required String entityType,
    required String entityId,
    required String conflictType,
    this.resolutionStatus = const Value.absent(),
    this.errorMessage = const Value.absent(),
    required String payload,
    this.serverState = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.resolvedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       operationId = Value(operationId),
       entityType = Value(entityType),
       entityId = Value(entityId),
       conflictType = Value(conflictType),
       payload = Value(payload);
  static Insertable<SyncConflict> custom({
    Expression<String>? id,
    Expression<String>? operationId,
    Expression<String>? entityType,
    Expression<String>? entityId,
    Expression<String>? conflictType,
    Expression<String>? resolutionStatus,
    Expression<String>? errorMessage,
    Expression<String>? payload,
    Expression<String>? serverState,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? resolvedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (operationId != null) 'operation_id': operationId,
      if (entityType != null) 'entity_type': entityType,
      if (entityId != null) 'entity_id': entityId,
      if (conflictType != null) 'conflict_type': conflictType,
      if (resolutionStatus != null) 'resolution_status': resolutionStatus,
      if (errorMessage != null) 'error_message': errorMessage,
      if (payload != null) 'payload': payload,
      if (serverState != null) 'server_state': serverState,
      if (createdAt != null) 'created_at': createdAt,
      if (resolvedAt != null) 'resolved_at': resolvedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncConflictsCompanion copyWith({
    Value<String>? id,
    Value<String>? operationId,
    Value<String>? entityType,
    Value<String>? entityId,
    Value<String>? conflictType,
    Value<String>? resolutionStatus,
    Value<String?>? errorMessage,
    Value<String>? payload,
    Value<String?>? serverState,
    Value<DateTime>? createdAt,
    Value<DateTime?>? resolvedAt,
    Value<int>? rowid,
  }) {
    return SyncConflictsCompanion(
      id: id ?? this.id,
      operationId: operationId ?? this.operationId,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      conflictType: conflictType ?? this.conflictType,
      resolutionStatus: resolutionStatus ?? this.resolutionStatus,
      errorMessage: errorMessage ?? this.errorMessage,
      payload: payload ?? this.payload,
      serverState: serverState ?? this.serverState,
      createdAt: createdAt ?? this.createdAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (operationId.present) {
      map['operation_id'] = Variable<String>(operationId.value);
    }
    if (entityType.present) {
      map['entity_type'] = Variable<String>(entityType.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (conflictType.present) {
      map['conflict_type'] = Variable<String>(conflictType.value);
    }
    if (resolutionStatus.present) {
      map['resolution_status'] = Variable<String>(resolutionStatus.value);
    }
    if (errorMessage.present) {
      map['error_message'] = Variable<String>(errorMessage.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (serverState.present) {
      map['server_state'] = Variable<String>(serverState.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (resolvedAt.present) {
      map['resolved_at'] = Variable<DateTime>(resolvedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncConflictsCompanion(')
          ..write('id: $id, ')
          ..write('operationId: $operationId, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('conflictType: $conflictType, ')
          ..write('resolutionStatus: $resolutionStatus, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('payload: $payload, ')
          ..write('serverState: $serverState, ')
          ..write('createdAt: $createdAt, ')
          ..write('resolvedAt: $resolvedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalDailyCalculationsTable extends LocalDailyCalculations
    with TableInfo<$LocalDailyCalculationsTable, LocalDailyCalculation> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalDailyCalculationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 36,
      maxTextLength: 36,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cashierIdMeta = const VerificationMeta(
    'cashierId',
  );
  @override
  late final GeneratedColumn<String> cashierId = GeneratedColumn<String>(
    'cashier_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cashierNameMeta = const VerificationMeta(
    'cashierName',
  );
  @override
  late final GeneratedColumn<String> cashierName = GeneratedColumn<String>(
    'cashier_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startingCashMeta = const VerificationMeta(
    'startingCash',
  );
  @override
  late final GeneratedColumn<double> startingCash = GeneratedColumn<double>(
    'starting_cash',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _expectedCashDrawerMeta =
      const VerificationMeta('expectedCashDrawer');
  @override
  late final GeneratedColumn<double> expectedCashDrawer =
      GeneratedColumn<double>(
        'expected_cash_drawer',
        aliasedName,
        false,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
        defaultValue: const Constant(0.0),
      );
  static const VerificationMeta _actualCashCountedMeta = const VerificationMeta(
    'actualCashCounted',
  );
  @override
  late final GeneratedColumn<double> actualCashCounted =
      GeneratedColumn<double>(
        'actual_cash_counted',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _cashVarianceMeta = const VerificationMeta(
    'cashVariance',
  );
  @override
  late final GeneratedColumn<double> cashVariance = GeneratedColumn<double>(
    'cash_variance',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('ACTIVE'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _submittedAtMeta = const VerificationMeta(
    'submittedAt',
  );
  @override
  late final GeneratedColumn<DateTime> submittedAt = GeneratedColumn<DateTime>(
    'submitted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _closingNotesMeta = const VerificationMeta(
    'closingNotes',
  );
  @override
  late final GeneratedColumn<String> closingNotes = GeneratedColumn<String>(
    'closing_notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<String> syncStatus = GeneratedColumn<String>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending_insert'),
  );
  static const VerificationMeta _serverVersionMeta = const VerificationMeta(
    'serverVersion',
  );
  @override
  late final GeneratedColumn<int> serverVersion = GeneratedColumn<int>(
    'server_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    cashierId,
    cashierName,
    startingCash,
    expectedCashDrawer,
    actualCashCounted,
    cashVariance,
    status,
    createdAt,
    submittedAt,
    closingNotes,
    syncStatus,
    serverVersion,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_daily_calculations';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalDailyCalculation> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('cashier_id')) {
      context.handle(
        _cashierIdMeta,
        cashierId.isAcceptableOrUnknown(data['cashier_id']!, _cashierIdMeta),
      );
    } else if (isInserting) {
      context.missing(_cashierIdMeta);
    }
    if (data.containsKey('cashier_name')) {
      context.handle(
        _cashierNameMeta,
        cashierName.isAcceptableOrUnknown(
          data['cashier_name']!,
          _cashierNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_cashierNameMeta);
    }
    if (data.containsKey('starting_cash')) {
      context.handle(
        _startingCashMeta,
        startingCash.isAcceptableOrUnknown(
          data['starting_cash']!,
          _startingCashMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_startingCashMeta);
    }
    if (data.containsKey('expected_cash_drawer')) {
      context.handle(
        _expectedCashDrawerMeta,
        expectedCashDrawer.isAcceptableOrUnknown(
          data['expected_cash_drawer']!,
          _expectedCashDrawerMeta,
        ),
      );
    }
    if (data.containsKey('actual_cash_counted')) {
      context.handle(
        _actualCashCountedMeta,
        actualCashCounted.isAcceptableOrUnknown(
          data['actual_cash_counted']!,
          _actualCashCountedMeta,
        ),
      );
    }
    if (data.containsKey('cash_variance')) {
      context.handle(
        _cashVarianceMeta,
        cashVariance.isAcceptableOrUnknown(
          data['cash_variance']!,
          _cashVarianceMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('submitted_at')) {
      context.handle(
        _submittedAtMeta,
        submittedAt.isAcceptableOrUnknown(
          data['submitted_at']!,
          _submittedAtMeta,
        ),
      );
    }
    if (data.containsKey('closing_notes')) {
      context.handle(
        _closingNotesMeta,
        closingNotes.isAcceptableOrUnknown(
          data['closing_notes']!,
          _closingNotesMeta,
        ),
      );
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    if (data.containsKey('server_version')) {
      context.handle(
        _serverVersionMeta,
        serverVersion.isAcceptableOrUnknown(
          data['server_version']!,
          _serverVersionMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalDailyCalculation map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalDailyCalculation(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      cashierId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cashier_id'],
      )!,
      cashierName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cashier_name'],
      )!,
      startingCash: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}starting_cash'],
      )!,
      expectedCashDrawer: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}expected_cash_drawer'],
      )!,
      actualCashCounted: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}actual_cash_counted'],
      ),
      cashVariance: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}cash_variance'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      submittedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}submitted_at'],
      ),
      closingNotes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}closing_notes'],
      ),
      syncStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_status'],
      )!,
      serverVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_version'],
      )!,
    );
  }

  @override
  $LocalDailyCalculationsTable createAlias(String alias) {
    return $LocalDailyCalculationsTable(attachedDatabase, alias);
  }
}

class LocalDailyCalculation extends DataClass
    implements Insertable<LocalDailyCalculation> {
  final String id;
  final String cashierId;
  final String cashierName;
  final double startingCash;
  final double expectedCashDrawer;
  final double? actualCashCounted;
  final double cashVariance;
  final String status;
  final DateTime createdAt;
  final DateTime? submittedAt;
  final String? closingNotes;
  final String syncStatus;
  final int serverVersion;
  const LocalDailyCalculation({
    required this.id,
    required this.cashierId,
    required this.cashierName,
    required this.startingCash,
    required this.expectedCashDrawer,
    this.actualCashCounted,
    required this.cashVariance,
    required this.status,
    required this.createdAt,
    this.submittedAt,
    this.closingNotes,
    required this.syncStatus,
    required this.serverVersion,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['cashier_id'] = Variable<String>(cashierId);
    map['cashier_name'] = Variable<String>(cashierName);
    map['starting_cash'] = Variable<double>(startingCash);
    map['expected_cash_drawer'] = Variable<double>(expectedCashDrawer);
    if (!nullToAbsent || actualCashCounted != null) {
      map['actual_cash_counted'] = Variable<double>(actualCashCounted);
    }
    map['cash_variance'] = Variable<double>(cashVariance);
    map['status'] = Variable<String>(status);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || submittedAt != null) {
      map['submitted_at'] = Variable<DateTime>(submittedAt);
    }
    if (!nullToAbsent || closingNotes != null) {
      map['closing_notes'] = Variable<String>(closingNotes);
    }
    map['sync_status'] = Variable<String>(syncStatus);
    map['server_version'] = Variable<int>(serverVersion);
    return map;
  }

  LocalDailyCalculationsCompanion toCompanion(bool nullToAbsent) {
    return LocalDailyCalculationsCompanion(
      id: Value(id),
      cashierId: Value(cashierId),
      cashierName: Value(cashierName),
      startingCash: Value(startingCash),
      expectedCashDrawer: Value(expectedCashDrawer),
      actualCashCounted: actualCashCounted == null && nullToAbsent
          ? const Value.absent()
          : Value(actualCashCounted),
      cashVariance: Value(cashVariance),
      status: Value(status),
      createdAt: Value(createdAt),
      submittedAt: submittedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(submittedAt),
      closingNotes: closingNotes == null && nullToAbsent
          ? const Value.absent()
          : Value(closingNotes),
      syncStatus: Value(syncStatus),
      serverVersion: Value(serverVersion),
    );
  }

  factory LocalDailyCalculation.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalDailyCalculation(
      id: serializer.fromJson<String>(json['id']),
      cashierId: serializer.fromJson<String>(json['cashierId']),
      cashierName: serializer.fromJson<String>(json['cashierName']),
      startingCash: serializer.fromJson<double>(json['startingCash']),
      expectedCashDrawer: serializer.fromJson<double>(
        json['expectedCashDrawer'],
      ),
      actualCashCounted: serializer.fromJson<double?>(
        json['actualCashCounted'],
      ),
      cashVariance: serializer.fromJson<double>(json['cashVariance']),
      status: serializer.fromJson<String>(json['status']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      submittedAt: serializer.fromJson<DateTime?>(json['submittedAt']),
      closingNotes: serializer.fromJson<String?>(json['closingNotes']),
      syncStatus: serializer.fromJson<String>(json['syncStatus']),
      serverVersion: serializer.fromJson<int>(json['serverVersion']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'cashierId': serializer.toJson<String>(cashierId),
      'cashierName': serializer.toJson<String>(cashierName),
      'startingCash': serializer.toJson<double>(startingCash),
      'expectedCashDrawer': serializer.toJson<double>(expectedCashDrawer),
      'actualCashCounted': serializer.toJson<double?>(actualCashCounted),
      'cashVariance': serializer.toJson<double>(cashVariance),
      'status': serializer.toJson<String>(status),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'submittedAt': serializer.toJson<DateTime?>(submittedAt),
      'closingNotes': serializer.toJson<String?>(closingNotes),
      'syncStatus': serializer.toJson<String>(syncStatus),
      'serverVersion': serializer.toJson<int>(serverVersion),
    };
  }

  LocalDailyCalculation copyWith({
    String? id,
    String? cashierId,
    String? cashierName,
    double? startingCash,
    double? expectedCashDrawer,
    Value<double?> actualCashCounted = const Value.absent(),
    double? cashVariance,
    String? status,
    DateTime? createdAt,
    Value<DateTime?> submittedAt = const Value.absent(),
    Value<String?> closingNotes = const Value.absent(),
    String? syncStatus,
    int? serverVersion,
  }) => LocalDailyCalculation(
    id: id ?? this.id,
    cashierId: cashierId ?? this.cashierId,
    cashierName: cashierName ?? this.cashierName,
    startingCash: startingCash ?? this.startingCash,
    expectedCashDrawer: expectedCashDrawer ?? this.expectedCashDrawer,
    actualCashCounted: actualCashCounted.present
        ? actualCashCounted.value
        : this.actualCashCounted,
    cashVariance: cashVariance ?? this.cashVariance,
    status: status ?? this.status,
    createdAt: createdAt ?? this.createdAt,
    submittedAt: submittedAt.present ? submittedAt.value : this.submittedAt,
    closingNotes: closingNotes.present ? closingNotes.value : this.closingNotes,
    syncStatus: syncStatus ?? this.syncStatus,
    serverVersion: serverVersion ?? this.serverVersion,
  );
  LocalDailyCalculation copyWithCompanion(
    LocalDailyCalculationsCompanion data,
  ) {
    return LocalDailyCalculation(
      id: data.id.present ? data.id.value : this.id,
      cashierId: data.cashierId.present ? data.cashierId.value : this.cashierId,
      cashierName: data.cashierName.present
          ? data.cashierName.value
          : this.cashierName,
      startingCash: data.startingCash.present
          ? data.startingCash.value
          : this.startingCash,
      expectedCashDrawer: data.expectedCashDrawer.present
          ? data.expectedCashDrawer.value
          : this.expectedCashDrawer,
      actualCashCounted: data.actualCashCounted.present
          ? data.actualCashCounted.value
          : this.actualCashCounted,
      cashVariance: data.cashVariance.present
          ? data.cashVariance.value
          : this.cashVariance,
      status: data.status.present ? data.status.value : this.status,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      submittedAt: data.submittedAt.present
          ? data.submittedAt.value
          : this.submittedAt,
      closingNotes: data.closingNotes.present
          ? data.closingNotes.value
          : this.closingNotes,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
      serverVersion: data.serverVersion.present
          ? data.serverVersion.value
          : this.serverVersion,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalDailyCalculation(')
          ..write('id: $id, ')
          ..write('cashierId: $cashierId, ')
          ..write('cashierName: $cashierName, ')
          ..write('startingCash: $startingCash, ')
          ..write('expectedCashDrawer: $expectedCashDrawer, ')
          ..write('actualCashCounted: $actualCashCounted, ')
          ..write('cashVariance: $cashVariance, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('submittedAt: $submittedAt, ')
          ..write('closingNotes: $closingNotes, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('serverVersion: $serverVersion')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    cashierId,
    cashierName,
    startingCash,
    expectedCashDrawer,
    actualCashCounted,
    cashVariance,
    status,
    createdAt,
    submittedAt,
    closingNotes,
    syncStatus,
    serverVersion,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalDailyCalculation &&
          other.id == this.id &&
          other.cashierId == this.cashierId &&
          other.cashierName == this.cashierName &&
          other.startingCash == this.startingCash &&
          other.expectedCashDrawer == this.expectedCashDrawer &&
          other.actualCashCounted == this.actualCashCounted &&
          other.cashVariance == this.cashVariance &&
          other.status == this.status &&
          other.createdAt == this.createdAt &&
          other.submittedAt == this.submittedAt &&
          other.closingNotes == this.closingNotes &&
          other.syncStatus == this.syncStatus &&
          other.serverVersion == this.serverVersion);
}

class LocalDailyCalculationsCompanion
    extends UpdateCompanion<LocalDailyCalculation> {
  final Value<String> id;
  final Value<String> cashierId;
  final Value<String> cashierName;
  final Value<double> startingCash;
  final Value<double> expectedCashDrawer;
  final Value<double?> actualCashCounted;
  final Value<double> cashVariance;
  final Value<String> status;
  final Value<DateTime> createdAt;
  final Value<DateTime?> submittedAt;
  final Value<String?> closingNotes;
  final Value<String> syncStatus;
  final Value<int> serverVersion;
  final Value<int> rowid;
  const LocalDailyCalculationsCompanion({
    this.id = const Value.absent(),
    this.cashierId = const Value.absent(),
    this.cashierName = const Value.absent(),
    this.startingCash = const Value.absent(),
    this.expectedCashDrawer = const Value.absent(),
    this.actualCashCounted = const Value.absent(),
    this.cashVariance = const Value.absent(),
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.submittedAt = const Value.absent(),
    this.closingNotes = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.serverVersion = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalDailyCalculationsCompanion.insert({
    required String id,
    required String cashierId,
    required String cashierName,
    required double startingCash,
    this.expectedCashDrawer = const Value.absent(),
    this.actualCashCounted = const Value.absent(),
    this.cashVariance = const Value.absent(),
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.submittedAt = const Value.absent(),
    this.closingNotes = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.serverVersion = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       cashierId = Value(cashierId),
       cashierName = Value(cashierName),
       startingCash = Value(startingCash);
  static Insertable<LocalDailyCalculation> custom({
    Expression<String>? id,
    Expression<String>? cashierId,
    Expression<String>? cashierName,
    Expression<double>? startingCash,
    Expression<double>? expectedCashDrawer,
    Expression<double>? actualCashCounted,
    Expression<double>? cashVariance,
    Expression<String>? status,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? submittedAt,
    Expression<String>? closingNotes,
    Expression<String>? syncStatus,
    Expression<int>? serverVersion,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (cashierId != null) 'cashier_id': cashierId,
      if (cashierName != null) 'cashier_name': cashierName,
      if (startingCash != null) 'starting_cash': startingCash,
      if (expectedCashDrawer != null)
        'expected_cash_drawer': expectedCashDrawer,
      if (actualCashCounted != null) 'actual_cash_counted': actualCashCounted,
      if (cashVariance != null) 'cash_variance': cashVariance,
      if (status != null) 'status': status,
      if (createdAt != null) 'created_at': createdAt,
      if (submittedAt != null) 'submitted_at': submittedAt,
      if (closingNotes != null) 'closing_notes': closingNotes,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (serverVersion != null) 'server_version': serverVersion,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalDailyCalculationsCompanion copyWith({
    Value<String>? id,
    Value<String>? cashierId,
    Value<String>? cashierName,
    Value<double>? startingCash,
    Value<double>? expectedCashDrawer,
    Value<double?>? actualCashCounted,
    Value<double>? cashVariance,
    Value<String>? status,
    Value<DateTime>? createdAt,
    Value<DateTime?>? submittedAt,
    Value<String?>? closingNotes,
    Value<String>? syncStatus,
    Value<int>? serverVersion,
    Value<int>? rowid,
  }) {
    return LocalDailyCalculationsCompanion(
      id: id ?? this.id,
      cashierId: cashierId ?? this.cashierId,
      cashierName: cashierName ?? this.cashierName,
      startingCash: startingCash ?? this.startingCash,
      expectedCashDrawer: expectedCashDrawer ?? this.expectedCashDrawer,
      actualCashCounted: actualCashCounted ?? this.actualCashCounted,
      cashVariance: cashVariance ?? this.cashVariance,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      submittedAt: submittedAt ?? this.submittedAt,
      closingNotes: closingNotes ?? this.closingNotes,
      syncStatus: syncStatus ?? this.syncStatus,
      serverVersion: serverVersion ?? this.serverVersion,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (cashierId.present) {
      map['cashier_id'] = Variable<String>(cashierId.value);
    }
    if (cashierName.present) {
      map['cashier_name'] = Variable<String>(cashierName.value);
    }
    if (startingCash.present) {
      map['starting_cash'] = Variable<double>(startingCash.value);
    }
    if (expectedCashDrawer.present) {
      map['expected_cash_drawer'] = Variable<double>(expectedCashDrawer.value);
    }
    if (actualCashCounted.present) {
      map['actual_cash_counted'] = Variable<double>(actualCashCounted.value);
    }
    if (cashVariance.present) {
      map['cash_variance'] = Variable<double>(cashVariance.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (submittedAt.present) {
      map['submitted_at'] = Variable<DateTime>(submittedAt.value);
    }
    if (closingNotes.present) {
      map['closing_notes'] = Variable<String>(closingNotes.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(syncStatus.value);
    }
    if (serverVersion.present) {
      map['server_version'] = Variable<int>(serverVersion.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalDailyCalculationsCompanion(')
          ..write('id: $id, ')
          ..write('cashierId: $cashierId, ')
          ..write('cashierName: $cashierName, ')
          ..write('startingCash: $startingCash, ')
          ..write('expectedCashDrawer: $expectedCashDrawer, ')
          ..write('actualCashCounted: $actualCashCounted, ')
          ..write('cashVariance: $cashVariance, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('submittedAt: $submittedAt, ')
          ..write('closingNotes: $closingNotes, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('serverVersion: $serverVersion, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalMenuCategoriesTable extends LocalMenuCategories
    with TableInfo<$LocalMenuCategoriesTable, LocalMenuCategory> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalMenuCategoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _displayOrderMeta = const VerificationMeta(
    'displayOrder',
  );
  @override
  late final GeneratedColumn<int> displayOrder = GeneratedColumn<int>(
    'display_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, displayOrder, isActive];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_menu_categories';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalMenuCategory> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('display_order')) {
      context.handle(
        _displayOrderMeta,
        displayOrder.isAcceptableOrUnknown(
          data['display_order']!,
          _displayOrderMeta,
        ),
      );
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalMenuCategory map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalMenuCategory(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      displayOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}display_order'],
      )!,
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
    );
  }

  @override
  $LocalMenuCategoriesTable createAlias(String alias) {
    return $LocalMenuCategoriesTable(attachedDatabase, alias);
  }
}

class LocalMenuCategory extends DataClass
    implements Insertable<LocalMenuCategory> {
  final String id;
  final String name;
  final int displayOrder;
  final bool isActive;
  const LocalMenuCategory({
    required this.id,
    required this.name,
    required this.displayOrder,
    required this.isActive,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['display_order'] = Variable<int>(displayOrder);
    map['is_active'] = Variable<bool>(isActive);
    return map;
  }

  LocalMenuCategoriesCompanion toCompanion(bool nullToAbsent) {
    return LocalMenuCategoriesCompanion(
      id: Value(id),
      name: Value(name),
      displayOrder: Value(displayOrder),
      isActive: Value(isActive),
    );
  }

  factory LocalMenuCategory.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalMenuCategory(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      displayOrder: serializer.fromJson<int>(json['displayOrder']),
      isActive: serializer.fromJson<bool>(json['isActive']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'displayOrder': serializer.toJson<int>(displayOrder),
      'isActive': serializer.toJson<bool>(isActive),
    };
  }

  LocalMenuCategory copyWith({
    String? id,
    String? name,
    int? displayOrder,
    bool? isActive,
  }) => LocalMenuCategory(
    id: id ?? this.id,
    name: name ?? this.name,
    displayOrder: displayOrder ?? this.displayOrder,
    isActive: isActive ?? this.isActive,
  );
  LocalMenuCategory copyWithCompanion(LocalMenuCategoriesCompanion data) {
    return LocalMenuCategory(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      displayOrder: data.displayOrder.present
          ? data.displayOrder.value
          : this.displayOrder,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalMenuCategory(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('displayOrder: $displayOrder, ')
          ..write('isActive: $isActive')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, displayOrder, isActive);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalMenuCategory &&
          other.id == this.id &&
          other.name == this.name &&
          other.displayOrder == this.displayOrder &&
          other.isActive == this.isActive);
}

class LocalMenuCategoriesCompanion extends UpdateCompanion<LocalMenuCategory> {
  final Value<String> id;
  final Value<String> name;
  final Value<int> displayOrder;
  final Value<bool> isActive;
  final Value<int> rowid;
  const LocalMenuCategoriesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.displayOrder = const Value.absent(),
    this.isActive = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalMenuCategoriesCompanion.insert({
    required String id,
    required String name,
    this.displayOrder = const Value.absent(),
    this.isActive = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name);
  static Insertable<LocalMenuCategory> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<int>? displayOrder,
    Expression<bool>? isActive,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (displayOrder != null) 'display_order': displayOrder,
      if (isActive != null) 'is_active': isActive,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalMenuCategoriesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<int>? displayOrder,
    Value<bool>? isActive,
    Value<int>? rowid,
  }) {
    return LocalMenuCategoriesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      displayOrder: displayOrder ?? this.displayOrder,
      isActive: isActive ?? this.isActive,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (displayOrder.present) {
      map['display_order'] = Variable<int>(displayOrder.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalMenuCategoriesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('displayOrder: $displayOrder, ')
          ..write('isActive: $isActive, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalMenuItemsTable extends LocalMenuItems
    with TableInfo<$LocalMenuItemsTable, LocalMenuItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalMenuItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
    'category_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _basePriceMeta = const VerificationMeta(
    'basePrice',
  );
  @override
  late final GeneratedColumn<double> basePrice = GeneratedColumn<double>(
    'base_price',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isAvailableMeta = const VerificationMeta(
    'isAvailable',
  );
  @override
  late final GeneratedColumn<bool> isAvailable = GeneratedColumn<bool>(
    'is_available',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_available" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _isVegMeta = const VerificationMeta('isVeg');
  @override
  late final GeneratedColumn<bool> isVeg = GeneratedColumn<bool>(
    'is_veg',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_veg" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isSpicyMeta = const VerificationMeta(
    'isSpicy',
  );
  @override
  late final GeneratedColumn<bool> isSpicy = GeneratedColumn<bool>(
    'is_spicy',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_spicy" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    categoryId,
    name,
    basePrice,
    isAvailable,
    isVeg,
    isSpicy,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_menu_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalMenuItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('base_price')) {
      context.handle(
        _basePriceMeta,
        basePrice.isAcceptableOrUnknown(data['base_price']!, _basePriceMeta),
      );
    } else if (isInserting) {
      context.missing(_basePriceMeta);
    }
    if (data.containsKey('is_available')) {
      context.handle(
        _isAvailableMeta,
        isAvailable.isAcceptableOrUnknown(
          data['is_available']!,
          _isAvailableMeta,
        ),
      );
    }
    if (data.containsKey('is_veg')) {
      context.handle(
        _isVegMeta,
        isVeg.isAcceptableOrUnknown(data['is_veg']!, _isVegMeta),
      );
    }
    if (data.containsKey('is_spicy')) {
      context.handle(
        _isSpicyMeta,
        isSpicy.isAcceptableOrUnknown(data['is_spicy']!, _isSpicyMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalMenuItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalMenuItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      basePrice: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}base_price'],
      )!,
      isAvailable: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_available'],
      )!,
      isVeg: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_veg'],
      )!,
      isSpicy: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_spicy'],
      )!,
    );
  }

  @override
  $LocalMenuItemsTable createAlias(String alias) {
    return $LocalMenuItemsTable(attachedDatabase, alias);
  }
}

class LocalMenuItem extends DataClass implements Insertable<LocalMenuItem> {
  final String id;
  final String categoryId;
  final String name;
  final double basePrice;
  final bool isAvailable;
  final bool isVeg;
  final bool isSpicy;
  const LocalMenuItem({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.basePrice,
    required this.isAvailable,
    required this.isVeg,
    required this.isSpicy,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['category_id'] = Variable<String>(categoryId);
    map['name'] = Variable<String>(name);
    map['base_price'] = Variable<double>(basePrice);
    map['is_available'] = Variable<bool>(isAvailable);
    map['is_veg'] = Variable<bool>(isVeg);
    map['is_spicy'] = Variable<bool>(isSpicy);
    return map;
  }

  LocalMenuItemsCompanion toCompanion(bool nullToAbsent) {
    return LocalMenuItemsCompanion(
      id: Value(id),
      categoryId: Value(categoryId),
      name: Value(name),
      basePrice: Value(basePrice),
      isAvailable: Value(isAvailable),
      isVeg: Value(isVeg),
      isSpicy: Value(isSpicy),
    );
  }

  factory LocalMenuItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalMenuItem(
      id: serializer.fromJson<String>(json['id']),
      categoryId: serializer.fromJson<String>(json['categoryId']),
      name: serializer.fromJson<String>(json['name']),
      basePrice: serializer.fromJson<double>(json['basePrice']),
      isAvailable: serializer.fromJson<bool>(json['isAvailable']),
      isVeg: serializer.fromJson<bool>(json['isVeg']),
      isSpicy: serializer.fromJson<bool>(json['isSpicy']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'categoryId': serializer.toJson<String>(categoryId),
      'name': serializer.toJson<String>(name),
      'basePrice': serializer.toJson<double>(basePrice),
      'isAvailable': serializer.toJson<bool>(isAvailable),
      'isVeg': serializer.toJson<bool>(isVeg),
      'isSpicy': serializer.toJson<bool>(isSpicy),
    };
  }

  LocalMenuItem copyWith({
    String? id,
    String? categoryId,
    String? name,
    double? basePrice,
    bool? isAvailable,
    bool? isVeg,
    bool? isSpicy,
  }) => LocalMenuItem(
    id: id ?? this.id,
    categoryId: categoryId ?? this.categoryId,
    name: name ?? this.name,
    basePrice: basePrice ?? this.basePrice,
    isAvailable: isAvailable ?? this.isAvailable,
    isVeg: isVeg ?? this.isVeg,
    isSpicy: isSpicy ?? this.isSpicy,
  );
  LocalMenuItem copyWithCompanion(LocalMenuItemsCompanion data) {
    return LocalMenuItem(
      id: data.id.present ? data.id.value : this.id,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      name: data.name.present ? data.name.value : this.name,
      basePrice: data.basePrice.present ? data.basePrice.value : this.basePrice,
      isAvailable: data.isAvailable.present
          ? data.isAvailable.value
          : this.isAvailable,
      isVeg: data.isVeg.present ? data.isVeg.value : this.isVeg,
      isSpicy: data.isSpicy.present ? data.isSpicy.value : this.isSpicy,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalMenuItem(')
          ..write('id: $id, ')
          ..write('categoryId: $categoryId, ')
          ..write('name: $name, ')
          ..write('basePrice: $basePrice, ')
          ..write('isAvailable: $isAvailable, ')
          ..write('isVeg: $isVeg, ')
          ..write('isSpicy: $isSpicy')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, categoryId, name, basePrice, isAvailable, isVeg, isSpicy);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalMenuItem &&
          other.id == this.id &&
          other.categoryId == this.categoryId &&
          other.name == this.name &&
          other.basePrice == this.basePrice &&
          other.isAvailable == this.isAvailable &&
          other.isVeg == this.isVeg &&
          other.isSpicy == this.isSpicy);
}

class LocalMenuItemsCompanion extends UpdateCompanion<LocalMenuItem> {
  final Value<String> id;
  final Value<String> categoryId;
  final Value<String> name;
  final Value<double> basePrice;
  final Value<bool> isAvailable;
  final Value<bool> isVeg;
  final Value<bool> isSpicy;
  final Value<int> rowid;
  const LocalMenuItemsCompanion({
    this.id = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.name = const Value.absent(),
    this.basePrice = const Value.absent(),
    this.isAvailable = const Value.absent(),
    this.isVeg = const Value.absent(),
    this.isSpicy = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalMenuItemsCompanion.insert({
    required String id,
    required String categoryId,
    required String name,
    required double basePrice,
    this.isAvailable = const Value.absent(),
    this.isVeg = const Value.absent(),
    this.isSpicy = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       categoryId = Value(categoryId),
       name = Value(name),
       basePrice = Value(basePrice);
  static Insertable<LocalMenuItem> custom({
    Expression<String>? id,
    Expression<String>? categoryId,
    Expression<String>? name,
    Expression<double>? basePrice,
    Expression<bool>? isAvailable,
    Expression<bool>? isVeg,
    Expression<bool>? isSpicy,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (categoryId != null) 'category_id': categoryId,
      if (name != null) 'name': name,
      if (basePrice != null) 'base_price': basePrice,
      if (isAvailable != null) 'is_available': isAvailable,
      if (isVeg != null) 'is_veg': isVeg,
      if (isSpicy != null) 'is_spicy': isSpicy,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalMenuItemsCompanion copyWith({
    Value<String>? id,
    Value<String>? categoryId,
    Value<String>? name,
    Value<double>? basePrice,
    Value<bool>? isAvailable,
    Value<bool>? isVeg,
    Value<bool>? isSpicy,
    Value<int>? rowid,
  }) {
    return LocalMenuItemsCompanion(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      name: name ?? this.name,
      basePrice: basePrice ?? this.basePrice,
      isAvailable: isAvailable ?? this.isAvailable,
      isVeg: isVeg ?? this.isVeg,
      isSpicy: isSpicy ?? this.isSpicy,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (basePrice.present) {
      map['base_price'] = Variable<double>(basePrice.value);
    }
    if (isAvailable.present) {
      map['is_available'] = Variable<bool>(isAvailable.value);
    }
    if (isVeg.present) {
      map['is_veg'] = Variable<bool>(isVeg.value);
    }
    if (isSpicy.present) {
      map['is_spicy'] = Variable<bool>(isSpicy.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalMenuItemsCompanion(')
          ..write('id: $id, ')
          ..write('categoryId: $categoryId, ')
          ..write('name: $name, ')
          ..write('basePrice: $basePrice, ')
          ..write('isAvailable: $isAvailable, ')
          ..write('isVeg: $isVeg, ')
          ..write('isSpicy: $isSpicy, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalMenuItemSizesTable extends LocalMenuItemSizes
    with TableInfo<$LocalMenuItemSizesTable, LocalMenuItemSize> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalMenuItemSizesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _menuItemIdMeta = const VerificationMeta(
    'menuItemId',
  );
  @override
  late final GeneratedColumn<String> menuItemId = GeneratedColumn<String>(
    'menu_item_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES local_menu_items (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _sizeNameMeta = const VerificationMeta(
    'sizeName',
  );
  @override
  late final GeneratedColumn<String> sizeName = GeneratedColumn<String>(
    'size_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _priceMultiplierMeta = const VerificationMeta(
    'priceMultiplier',
  );
  @override
  late final GeneratedColumn<double> priceMultiplier = GeneratedColumn<double>(
    'price_multiplier',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(1.0),
  );
  static const VerificationMeta _isDefaultMeta = const VerificationMeta(
    'isDefault',
  );
  @override
  late final GeneratedColumn<bool> isDefault = GeneratedColumn<bool>(
    'is_default',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_default" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    menuItemId,
    sizeName,
    priceMultiplier,
    isDefault,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_menu_item_sizes';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalMenuItemSize> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('menu_item_id')) {
      context.handle(
        _menuItemIdMeta,
        menuItemId.isAcceptableOrUnknown(
          data['menu_item_id']!,
          _menuItemIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_menuItemIdMeta);
    }
    if (data.containsKey('size_name')) {
      context.handle(
        _sizeNameMeta,
        sizeName.isAcceptableOrUnknown(data['size_name']!, _sizeNameMeta),
      );
    } else if (isInserting) {
      context.missing(_sizeNameMeta);
    }
    if (data.containsKey('price_multiplier')) {
      context.handle(
        _priceMultiplierMeta,
        priceMultiplier.isAcceptableOrUnknown(
          data['price_multiplier']!,
          _priceMultiplierMeta,
        ),
      );
    }
    if (data.containsKey('is_default')) {
      context.handle(
        _isDefaultMeta,
        isDefault.isAcceptableOrUnknown(data['is_default']!, _isDefaultMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalMenuItemSize map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalMenuItemSize(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      menuItemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}menu_item_id'],
      )!,
      sizeName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}size_name'],
      )!,
      priceMultiplier: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}price_multiplier'],
      )!,
      isDefault: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_default'],
      )!,
    );
  }

  @override
  $LocalMenuItemSizesTable createAlias(String alias) {
    return $LocalMenuItemSizesTable(attachedDatabase, alias);
  }
}

class LocalMenuItemSize extends DataClass
    implements Insertable<LocalMenuItemSize> {
  final String id;
  final String menuItemId;
  final String sizeName;
  final double priceMultiplier;
  final bool isDefault;
  const LocalMenuItemSize({
    required this.id,
    required this.menuItemId,
    required this.sizeName,
    required this.priceMultiplier,
    required this.isDefault,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['menu_item_id'] = Variable<String>(menuItemId);
    map['size_name'] = Variable<String>(sizeName);
    map['price_multiplier'] = Variable<double>(priceMultiplier);
    map['is_default'] = Variable<bool>(isDefault);
    return map;
  }

  LocalMenuItemSizesCompanion toCompanion(bool nullToAbsent) {
    return LocalMenuItemSizesCompanion(
      id: Value(id),
      menuItemId: Value(menuItemId),
      sizeName: Value(sizeName),
      priceMultiplier: Value(priceMultiplier),
      isDefault: Value(isDefault),
    );
  }

  factory LocalMenuItemSize.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalMenuItemSize(
      id: serializer.fromJson<String>(json['id']),
      menuItemId: serializer.fromJson<String>(json['menuItemId']),
      sizeName: serializer.fromJson<String>(json['sizeName']),
      priceMultiplier: serializer.fromJson<double>(json['priceMultiplier']),
      isDefault: serializer.fromJson<bool>(json['isDefault']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'menuItemId': serializer.toJson<String>(menuItemId),
      'sizeName': serializer.toJson<String>(sizeName),
      'priceMultiplier': serializer.toJson<double>(priceMultiplier),
      'isDefault': serializer.toJson<bool>(isDefault),
    };
  }

  LocalMenuItemSize copyWith({
    String? id,
    String? menuItemId,
    String? sizeName,
    double? priceMultiplier,
    bool? isDefault,
  }) => LocalMenuItemSize(
    id: id ?? this.id,
    menuItemId: menuItemId ?? this.menuItemId,
    sizeName: sizeName ?? this.sizeName,
    priceMultiplier: priceMultiplier ?? this.priceMultiplier,
    isDefault: isDefault ?? this.isDefault,
  );
  LocalMenuItemSize copyWithCompanion(LocalMenuItemSizesCompanion data) {
    return LocalMenuItemSize(
      id: data.id.present ? data.id.value : this.id,
      menuItemId: data.menuItemId.present
          ? data.menuItemId.value
          : this.menuItemId,
      sizeName: data.sizeName.present ? data.sizeName.value : this.sizeName,
      priceMultiplier: data.priceMultiplier.present
          ? data.priceMultiplier.value
          : this.priceMultiplier,
      isDefault: data.isDefault.present ? data.isDefault.value : this.isDefault,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalMenuItemSize(')
          ..write('id: $id, ')
          ..write('menuItemId: $menuItemId, ')
          ..write('sizeName: $sizeName, ')
          ..write('priceMultiplier: $priceMultiplier, ')
          ..write('isDefault: $isDefault')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, menuItemId, sizeName, priceMultiplier, isDefault);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalMenuItemSize &&
          other.id == this.id &&
          other.menuItemId == this.menuItemId &&
          other.sizeName == this.sizeName &&
          other.priceMultiplier == this.priceMultiplier &&
          other.isDefault == this.isDefault);
}

class LocalMenuItemSizesCompanion extends UpdateCompanion<LocalMenuItemSize> {
  final Value<String> id;
  final Value<String> menuItemId;
  final Value<String> sizeName;
  final Value<double> priceMultiplier;
  final Value<bool> isDefault;
  final Value<int> rowid;
  const LocalMenuItemSizesCompanion({
    this.id = const Value.absent(),
    this.menuItemId = const Value.absent(),
    this.sizeName = const Value.absent(),
    this.priceMultiplier = const Value.absent(),
    this.isDefault = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalMenuItemSizesCompanion.insert({
    required String id,
    required String menuItemId,
    required String sizeName,
    this.priceMultiplier = const Value.absent(),
    this.isDefault = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       menuItemId = Value(menuItemId),
       sizeName = Value(sizeName);
  static Insertable<LocalMenuItemSize> custom({
    Expression<String>? id,
    Expression<String>? menuItemId,
    Expression<String>? sizeName,
    Expression<double>? priceMultiplier,
    Expression<bool>? isDefault,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (menuItemId != null) 'menu_item_id': menuItemId,
      if (sizeName != null) 'size_name': sizeName,
      if (priceMultiplier != null) 'price_multiplier': priceMultiplier,
      if (isDefault != null) 'is_default': isDefault,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalMenuItemSizesCompanion copyWith({
    Value<String>? id,
    Value<String>? menuItemId,
    Value<String>? sizeName,
    Value<double>? priceMultiplier,
    Value<bool>? isDefault,
    Value<int>? rowid,
  }) {
    return LocalMenuItemSizesCompanion(
      id: id ?? this.id,
      menuItemId: menuItemId ?? this.menuItemId,
      sizeName: sizeName ?? this.sizeName,
      priceMultiplier: priceMultiplier ?? this.priceMultiplier,
      isDefault: isDefault ?? this.isDefault,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (menuItemId.present) {
      map['menu_item_id'] = Variable<String>(menuItemId.value);
    }
    if (sizeName.present) {
      map['size_name'] = Variable<String>(sizeName.value);
    }
    if (priceMultiplier.present) {
      map['price_multiplier'] = Variable<double>(priceMultiplier.value);
    }
    if (isDefault.present) {
      map['is_default'] = Variable<bool>(isDefault.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalMenuItemSizesCompanion(')
          ..write('id: $id, ')
          ..write('menuItemId: $menuItemId, ')
          ..write('sizeName: $sizeName, ')
          ..write('priceMultiplier: $priceMultiplier, ')
          ..write('isDefault: $isDefault, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalMenuItemOptionsTable extends LocalMenuItemOptions
    with TableInfo<$LocalMenuItemOptionsTable, LocalMenuItemOption> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalMenuItemOptionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _menuItemIdMeta = const VerificationMeta(
    'menuItemId',
  );
  @override
  late final GeneratedColumn<String> menuItemId = GeneratedColumn<String>(
    'menu_item_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES local_menu_items (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _groupNameMeta = const VerificationMeta(
    'groupName',
  );
  @override
  late final GeneratedColumn<String> groupName = GeneratedColumn<String>(
    'group_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _optionNameMeta = const VerificationMeta(
    'optionName',
  );
  @override
  late final GeneratedColumn<String> optionName = GeneratedColumn<String>(
    'option_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _additionalPriceMeta = const VerificationMeta(
    'additionalPrice',
  );
  @override
  late final GeneratedColumn<double> additionalPrice = GeneratedColumn<double>(
    'additional_price',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    menuItemId,
    groupName,
    optionName,
    additionalPrice,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_menu_item_options';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalMenuItemOption> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('menu_item_id')) {
      context.handle(
        _menuItemIdMeta,
        menuItemId.isAcceptableOrUnknown(
          data['menu_item_id']!,
          _menuItemIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_menuItemIdMeta);
    }
    if (data.containsKey('group_name')) {
      context.handle(
        _groupNameMeta,
        groupName.isAcceptableOrUnknown(data['group_name']!, _groupNameMeta),
      );
    } else if (isInserting) {
      context.missing(_groupNameMeta);
    }
    if (data.containsKey('option_name')) {
      context.handle(
        _optionNameMeta,
        optionName.isAcceptableOrUnknown(data['option_name']!, _optionNameMeta),
      );
    } else if (isInserting) {
      context.missing(_optionNameMeta);
    }
    if (data.containsKey('additional_price')) {
      context.handle(
        _additionalPriceMeta,
        additionalPrice.isAcceptableOrUnknown(
          data['additional_price']!,
          _additionalPriceMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalMenuItemOption map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalMenuItemOption(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      menuItemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}menu_item_id'],
      )!,
      groupName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_name'],
      )!,
      optionName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}option_name'],
      )!,
      additionalPrice: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}additional_price'],
      )!,
    );
  }

  @override
  $LocalMenuItemOptionsTable createAlias(String alias) {
    return $LocalMenuItemOptionsTable(attachedDatabase, alias);
  }
}

class LocalMenuItemOption extends DataClass
    implements Insertable<LocalMenuItemOption> {
  final String id;
  final String menuItemId;
  final String groupName;
  final String optionName;
  final double additionalPrice;
  const LocalMenuItemOption({
    required this.id,
    required this.menuItemId,
    required this.groupName,
    required this.optionName,
    required this.additionalPrice,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['menu_item_id'] = Variable<String>(menuItemId);
    map['group_name'] = Variable<String>(groupName);
    map['option_name'] = Variable<String>(optionName);
    map['additional_price'] = Variable<double>(additionalPrice);
    return map;
  }

  LocalMenuItemOptionsCompanion toCompanion(bool nullToAbsent) {
    return LocalMenuItemOptionsCompanion(
      id: Value(id),
      menuItemId: Value(menuItemId),
      groupName: Value(groupName),
      optionName: Value(optionName),
      additionalPrice: Value(additionalPrice),
    );
  }

  factory LocalMenuItemOption.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalMenuItemOption(
      id: serializer.fromJson<String>(json['id']),
      menuItemId: serializer.fromJson<String>(json['menuItemId']),
      groupName: serializer.fromJson<String>(json['groupName']),
      optionName: serializer.fromJson<String>(json['optionName']),
      additionalPrice: serializer.fromJson<double>(json['additionalPrice']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'menuItemId': serializer.toJson<String>(menuItemId),
      'groupName': serializer.toJson<String>(groupName),
      'optionName': serializer.toJson<String>(optionName),
      'additionalPrice': serializer.toJson<double>(additionalPrice),
    };
  }

  LocalMenuItemOption copyWith({
    String? id,
    String? menuItemId,
    String? groupName,
    String? optionName,
    double? additionalPrice,
  }) => LocalMenuItemOption(
    id: id ?? this.id,
    menuItemId: menuItemId ?? this.menuItemId,
    groupName: groupName ?? this.groupName,
    optionName: optionName ?? this.optionName,
    additionalPrice: additionalPrice ?? this.additionalPrice,
  );
  LocalMenuItemOption copyWithCompanion(LocalMenuItemOptionsCompanion data) {
    return LocalMenuItemOption(
      id: data.id.present ? data.id.value : this.id,
      menuItemId: data.menuItemId.present
          ? data.menuItemId.value
          : this.menuItemId,
      groupName: data.groupName.present ? data.groupName.value : this.groupName,
      optionName: data.optionName.present
          ? data.optionName.value
          : this.optionName,
      additionalPrice: data.additionalPrice.present
          ? data.additionalPrice.value
          : this.additionalPrice,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalMenuItemOption(')
          ..write('id: $id, ')
          ..write('menuItemId: $menuItemId, ')
          ..write('groupName: $groupName, ')
          ..write('optionName: $optionName, ')
          ..write('additionalPrice: $additionalPrice')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, menuItemId, groupName, optionName, additionalPrice);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalMenuItemOption &&
          other.id == this.id &&
          other.menuItemId == this.menuItemId &&
          other.groupName == this.groupName &&
          other.optionName == this.optionName &&
          other.additionalPrice == this.additionalPrice);
}

class LocalMenuItemOptionsCompanion
    extends UpdateCompanion<LocalMenuItemOption> {
  final Value<String> id;
  final Value<String> menuItemId;
  final Value<String> groupName;
  final Value<String> optionName;
  final Value<double> additionalPrice;
  final Value<int> rowid;
  const LocalMenuItemOptionsCompanion({
    this.id = const Value.absent(),
    this.menuItemId = const Value.absent(),
    this.groupName = const Value.absent(),
    this.optionName = const Value.absent(),
    this.additionalPrice = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalMenuItemOptionsCompanion.insert({
    required String id,
    required String menuItemId,
    required String groupName,
    required String optionName,
    this.additionalPrice = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       menuItemId = Value(menuItemId),
       groupName = Value(groupName),
       optionName = Value(optionName);
  static Insertable<LocalMenuItemOption> custom({
    Expression<String>? id,
    Expression<String>? menuItemId,
    Expression<String>? groupName,
    Expression<String>? optionName,
    Expression<double>? additionalPrice,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (menuItemId != null) 'menu_item_id': menuItemId,
      if (groupName != null) 'group_name': groupName,
      if (optionName != null) 'option_name': optionName,
      if (additionalPrice != null) 'additional_price': additionalPrice,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalMenuItemOptionsCompanion copyWith({
    Value<String>? id,
    Value<String>? menuItemId,
    Value<String>? groupName,
    Value<String>? optionName,
    Value<double>? additionalPrice,
    Value<int>? rowid,
  }) {
    return LocalMenuItemOptionsCompanion(
      id: id ?? this.id,
      menuItemId: menuItemId ?? this.menuItemId,
      groupName: groupName ?? this.groupName,
      optionName: optionName ?? this.optionName,
      additionalPrice: additionalPrice ?? this.additionalPrice,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (menuItemId.present) {
      map['menu_item_id'] = Variable<String>(menuItemId.value);
    }
    if (groupName.present) {
      map['group_name'] = Variable<String>(groupName.value);
    }
    if (optionName.present) {
      map['option_name'] = Variable<String>(optionName.value);
    }
    if (additionalPrice.present) {
      map['additional_price'] = Variable<double>(additionalPrice.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalMenuItemOptionsCompanion(')
          ..write('id: $id, ')
          ..write('menuItemId: $menuItemId, ')
          ..write('groupName: $groupName, ')
          ..write('optionName: $optionName, ')
          ..write('additionalPrice: $additionalPrice, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalDealsTable extends LocalDeals
    with TableInfo<$LocalDealsTable, LocalDeal> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalDealsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dealPriceMeta = const VerificationMeta(
    'dealPrice',
  );
  @override
  late final GeneratedColumn<double> dealPrice = GeneratedColumn<double>(
    'deal_price',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isAvailableMeta = const VerificationMeta(
    'isAvailable',
  );
  @override
  late final GeneratedColumn<bool> isAvailable = GeneratedColumn<bool>(
    'is_available',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_available" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, dealPrice, isAvailable];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_deals';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalDeal> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('deal_price')) {
      context.handle(
        _dealPriceMeta,
        dealPrice.isAcceptableOrUnknown(data['deal_price']!, _dealPriceMeta),
      );
    } else if (isInserting) {
      context.missing(_dealPriceMeta);
    }
    if (data.containsKey('is_available')) {
      context.handle(
        _isAvailableMeta,
        isAvailable.isAcceptableOrUnknown(
          data['is_available']!,
          _isAvailableMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalDeal map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalDeal(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      dealPrice: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}deal_price'],
      )!,
      isAvailable: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_available'],
      )!,
    );
  }

  @override
  $LocalDealsTable createAlias(String alias) {
    return $LocalDealsTable(attachedDatabase, alias);
  }
}

class LocalDeal extends DataClass implements Insertable<LocalDeal> {
  final String id;
  final String name;
  final double dealPrice;
  final bool isAvailable;
  const LocalDeal({
    required this.id,
    required this.name,
    required this.dealPrice,
    required this.isAvailable,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['deal_price'] = Variable<double>(dealPrice);
    map['is_available'] = Variable<bool>(isAvailable);
    return map;
  }

  LocalDealsCompanion toCompanion(bool nullToAbsent) {
    return LocalDealsCompanion(
      id: Value(id),
      name: Value(name),
      dealPrice: Value(dealPrice),
      isAvailable: Value(isAvailable),
    );
  }

  factory LocalDeal.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalDeal(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      dealPrice: serializer.fromJson<double>(json['dealPrice']),
      isAvailable: serializer.fromJson<bool>(json['isAvailable']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'dealPrice': serializer.toJson<double>(dealPrice),
      'isAvailable': serializer.toJson<bool>(isAvailable),
    };
  }

  LocalDeal copyWith({
    String? id,
    String? name,
    double? dealPrice,
    bool? isAvailable,
  }) => LocalDeal(
    id: id ?? this.id,
    name: name ?? this.name,
    dealPrice: dealPrice ?? this.dealPrice,
    isAvailable: isAvailable ?? this.isAvailable,
  );
  LocalDeal copyWithCompanion(LocalDealsCompanion data) {
    return LocalDeal(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      dealPrice: data.dealPrice.present ? data.dealPrice.value : this.dealPrice,
      isAvailable: data.isAvailable.present
          ? data.isAvailable.value
          : this.isAvailable,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalDeal(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('dealPrice: $dealPrice, ')
          ..write('isAvailable: $isAvailable')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, dealPrice, isAvailable);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalDeal &&
          other.id == this.id &&
          other.name == this.name &&
          other.dealPrice == this.dealPrice &&
          other.isAvailable == this.isAvailable);
}

class LocalDealsCompanion extends UpdateCompanion<LocalDeal> {
  final Value<String> id;
  final Value<String> name;
  final Value<double> dealPrice;
  final Value<bool> isAvailable;
  final Value<int> rowid;
  const LocalDealsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.dealPrice = const Value.absent(),
    this.isAvailable = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalDealsCompanion.insert({
    required String id,
    required String name,
    required double dealPrice,
    this.isAvailable = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       dealPrice = Value(dealPrice);
  static Insertable<LocalDeal> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<double>? dealPrice,
    Expression<bool>? isAvailable,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (dealPrice != null) 'deal_price': dealPrice,
      if (isAvailable != null) 'is_available': isAvailable,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalDealsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<double>? dealPrice,
    Value<bool>? isAvailable,
    Value<int>? rowid,
  }) {
    return LocalDealsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      dealPrice: dealPrice ?? this.dealPrice,
      isAvailable: isAvailable ?? this.isAvailable,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (dealPrice.present) {
      map['deal_price'] = Variable<double>(dealPrice.value);
    }
    if (isAvailable.present) {
      map['is_available'] = Variable<bool>(isAvailable.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalDealsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('dealPrice: $dealPrice, ')
          ..write('isAvailable: $isAvailable, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalDealComponentsTable extends LocalDealComponents
    with TableInfo<$LocalDealComponentsTable, LocalDealComponent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalDealComponentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dealIdMeta = const VerificationMeta('dealId');
  @override
  late final GeneratedColumn<String> dealId = GeneratedColumn<String>(
    'deal_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES local_deals (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _menuItemIdMeta = const VerificationMeta(
    'menuItemId',
  );
  @override
  late final GeneratedColumn<String> menuItemId = GeneratedColumn<String>(
    'menu_item_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _quantityMeta = const VerificationMeta(
    'quantity',
  );
  @override
  late final GeneratedColumn<String> quantity = GeneratedColumn<String>(
    'quantity',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('1'),
  );
  @override
  List<GeneratedColumn> get $columns => [id, dealId, menuItemId, quantity];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_deal_components';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalDealComponent> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('deal_id')) {
      context.handle(
        _dealIdMeta,
        dealId.isAcceptableOrUnknown(data['deal_id']!, _dealIdMeta),
      );
    } else if (isInserting) {
      context.missing(_dealIdMeta);
    }
    if (data.containsKey('menu_item_id')) {
      context.handle(
        _menuItemIdMeta,
        menuItemId.isAcceptableOrUnknown(
          data['menu_item_id']!,
          _menuItemIdMeta,
        ),
      );
    }
    if (data.containsKey('quantity')) {
      context.handle(
        _quantityMeta,
        quantity.isAcceptableOrUnknown(data['quantity']!, _quantityMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalDealComponent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalDealComponent(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      dealId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deal_id'],
      )!,
      menuItemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}menu_item_id'],
      ),
      quantity: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}quantity'],
      )!,
    );
  }

  @override
  $LocalDealComponentsTable createAlias(String alias) {
    return $LocalDealComponentsTable(attachedDatabase, alias);
  }
}

class LocalDealComponent extends DataClass
    implements Insertable<LocalDealComponent> {
  final String id;
  final String dealId;
  final String? menuItemId;
  final String quantity;
  const LocalDealComponent({
    required this.id,
    required this.dealId,
    this.menuItemId,
    required this.quantity,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['deal_id'] = Variable<String>(dealId);
    if (!nullToAbsent || menuItemId != null) {
      map['menu_item_id'] = Variable<String>(menuItemId);
    }
    map['quantity'] = Variable<String>(quantity);
    return map;
  }

  LocalDealComponentsCompanion toCompanion(bool nullToAbsent) {
    return LocalDealComponentsCompanion(
      id: Value(id),
      dealId: Value(dealId),
      menuItemId: menuItemId == null && nullToAbsent
          ? const Value.absent()
          : Value(menuItemId),
      quantity: Value(quantity),
    );
  }

  factory LocalDealComponent.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalDealComponent(
      id: serializer.fromJson<String>(json['id']),
      dealId: serializer.fromJson<String>(json['dealId']),
      menuItemId: serializer.fromJson<String?>(json['menuItemId']),
      quantity: serializer.fromJson<String>(json['quantity']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'dealId': serializer.toJson<String>(dealId),
      'menuItemId': serializer.toJson<String?>(menuItemId),
      'quantity': serializer.toJson<String>(quantity),
    };
  }

  LocalDealComponent copyWith({
    String? id,
    String? dealId,
    Value<String?> menuItemId = const Value.absent(),
    String? quantity,
  }) => LocalDealComponent(
    id: id ?? this.id,
    dealId: dealId ?? this.dealId,
    menuItemId: menuItemId.present ? menuItemId.value : this.menuItemId,
    quantity: quantity ?? this.quantity,
  );
  LocalDealComponent copyWithCompanion(LocalDealComponentsCompanion data) {
    return LocalDealComponent(
      id: data.id.present ? data.id.value : this.id,
      dealId: data.dealId.present ? data.dealId.value : this.dealId,
      menuItemId: data.menuItemId.present
          ? data.menuItemId.value
          : this.menuItemId,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalDealComponent(')
          ..write('id: $id, ')
          ..write('dealId: $dealId, ')
          ..write('menuItemId: $menuItemId, ')
          ..write('quantity: $quantity')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, dealId, menuItemId, quantity);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalDealComponent &&
          other.id == this.id &&
          other.dealId == this.dealId &&
          other.menuItemId == this.menuItemId &&
          other.quantity == this.quantity);
}

class LocalDealComponentsCompanion extends UpdateCompanion<LocalDealComponent> {
  final Value<String> id;
  final Value<String> dealId;
  final Value<String?> menuItemId;
  final Value<String> quantity;
  final Value<int> rowid;
  const LocalDealComponentsCompanion({
    this.id = const Value.absent(),
    this.dealId = const Value.absent(),
    this.menuItemId = const Value.absent(),
    this.quantity = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalDealComponentsCompanion.insert({
    required String id,
    required String dealId,
    this.menuItemId = const Value.absent(),
    this.quantity = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       dealId = Value(dealId);
  static Insertable<LocalDealComponent> custom({
    Expression<String>? id,
    Expression<String>? dealId,
    Expression<String>? menuItemId,
    Expression<String>? quantity,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (dealId != null) 'deal_id': dealId,
      if (menuItemId != null) 'menu_item_id': menuItemId,
      if (quantity != null) 'quantity': quantity,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalDealComponentsCompanion copyWith({
    Value<String>? id,
    Value<String>? dealId,
    Value<String?>? menuItemId,
    Value<String>? quantity,
    Value<int>? rowid,
  }) {
    return LocalDealComponentsCompanion(
      id: id ?? this.id,
      dealId: dealId ?? this.dealId,
      menuItemId: menuItemId ?? this.menuItemId,
      quantity: quantity ?? this.quantity,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (dealId.present) {
      map['deal_id'] = Variable<String>(dealId.value);
    }
    if (menuItemId.present) {
      map['menu_item_id'] = Variable<String>(menuItemId.value);
    }
    if (quantity.present) {
      map['quantity'] = Variable<String>(quantity.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalDealComponentsCompanion(')
          ..write('id: $id, ')
          ..write('dealId: $dealId, ')
          ..write('menuItemId: $menuItemId, ')
          ..write('quantity: $quantity, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalRestaurantTablesTable extends LocalRestaurantTables
    with TableInfo<$LocalRestaurantTablesTable, LocalRestaurantTable> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalRestaurantTablesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _zoneIdMeta = const VerificationMeta('zoneId');
  @override
  late final GeneratedColumn<String> zoneId = GeneratedColumn<String>(
    'zone_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tableNumberMeta = const VerificationMeta(
    'tableNumber',
  );
  @override
  late final GeneratedColumn<String> tableNumber = GeneratedColumn<String>(
    'table_number',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _capacityMeta = const VerificationMeta(
    'capacity',
  );
  @override
  late final GeneratedColumn<int> capacity = GeneratedColumn<int>(
    'capacity',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(4),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('available'),
  );
  static const VerificationMeta _activeOrderIdMeta = const VerificationMeta(
    'activeOrderId',
  );
  @override
  late final GeneratedColumn<String> activeOrderId = GeneratedColumn<String>(
    'active_order_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isOverflowMeta = const VerificationMeta(
    'isOverflow',
  );
  @override
  late final GeneratedColumn<bool> isOverflow = GeneratedColumn<bool>(
    'is_overflow',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_overflow" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _parentTableIdMeta = const VerificationMeta(
    'parentTableId',
  );
  @override
  late final GeneratedColumn<String> parentTableId = GeneratedColumn<String>(
    'parent_table_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _overflowSuffixMeta = const VerificationMeta(
    'overflowSuffix',
  );
  @override
  late final GeneratedColumn<String> overflowSuffix = GeneratedColumn<String>(
    'overflow_suffix',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    zoneId,
    tableNumber,
    name,
    capacity,
    status,
    activeOrderId,
    version,
    isDeleted,
    isOverflow,
    parentTableId,
    overflowSuffix,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_restaurant_tables';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalRestaurantTable> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('zone_id')) {
      context.handle(
        _zoneIdMeta,
        zoneId.isAcceptableOrUnknown(data['zone_id']!, _zoneIdMeta),
      );
    }
    if (data.containsKey('table_number')) {
      context.handle(
        _tableNumberMeta,
        tableNumber.isAcceptableOrUnknown(
          data['table_number']!,
          _tableNumberMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_tableNumberMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('capacity')) {
      context.handle(
        _capacityMeta,
        capacity.isAcceptableOrUnknown(data['capacity']!, _capacityMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('active_order_id')) {
      context.handle(
        _activeOrderIdMeta,
        activeOrderId.isAcceptableOrUnknown(
          data['active_order_id']!,
          _activeOrderIdMeta,
        ),
      );
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    if (data.containsKey('is_overflow')) {
      context.handle(
        _isOverflowMeta,
        isOverflow.isAcceptableOrUnknown(data['is_overflow']!, _isOverflowMeta),
      );
    }
    if (data.containsKey('parent_table_id')) {
      context.handle(
        _parentTableIdMeta,
        parentTableId.isAcceptableOrUnknown(
          data['parent_table_id']!,
          _parentTableIdMeta,
        ),
      );
    }
    if (data.containsKey('overflow_suffix')) {
      context.handle(
        _overflowSuffixMeta,
        overflowSuffix.isAcceptableOrUnknown(
          data['overflow_suffix']!,
          _overflowSuffixMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalRestaurantTable map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalRestaurantTable(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      zoneId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}zone_id'],
      ),
      tableNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}table_number'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      capacity: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}capacity'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      activeOrderId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}active_order_id'],
      ),
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
      isOverflow: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_overflow'],
      )!,
      parentTableId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_table_id'],
      ),
      overflowSuffix: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}overflow_suffix'],
      ),
    );
  }

  @override
  $LocalRestaurantTablesTable createAlias(String alias) {
    return $LocalRestaurantTablesTable(attachedDatabase, alias);
  }
}

class LocalRestaurantTable extends DataClass
    implements Insertable<LocalRestaurantTable> {
  final String id;
  final String? zoneId;
  final String tableNumber;
  final String name;
  final int capacity;
  final String status;
  final String? activeOrderId;
  final int version;
  final bool isDeleted;
  final bool isOverflow;
  final String? parentTableId;
  final String? overflowSuffix;
  const LocalRestaurantTable({
    required this.id,
    this.zoneId,
    required this.tableNumber,
    required this.name,
    required this.capacity,
    required this.status,
    this.activeOrderId,
    required this.version,
    required this.isDeleted,
    required this.isOverflow,
    this.parentTableId,
    this.overflowSuffix,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || zoneId != null) {
      map['zone_id'] = Variable<String>(zoneId);
    }
    map['table_number'] = Variable<String>(tableNumber);
    map['name'] = Variable<String>(name);
    map['capacity'] = Variable<int>(capacity);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || activeOrderId != null) {
      map['active_order_id'] = Variable<String>(activeOrderId);
    }
    map['version'] = Variable<int>(version);
    map['is_deleted'] = Variable<bool>(isDeleted);
    map['is_overflow'] = Variable<bool>(isOverflow);
    if (!nullToAbsent || parentTableId != null) {
      map['parent_table_id'] = Variable<String>(parentTableId);
    }
    if (!nullToAbsent || overflowSuffix != null) {
      map['overflow_suffix'] = Variable<String>(overflowSuffix);
    }
    return map;
  }

  LocalRestaurantTablesCompanion toCompanion(bool nullToAbsent) {
    return LocalRestaurantTablesCompanion(
      id: Value(id),
      zoneId: zoneId == null && nullToAbsent
          ? const Value.absent()
          : Value(zoneId),
      tableNumber: Value(tableNumber),
      name: Value(name),
      capacity: Value(capacity),
      status: Value(status),
      activeOrderId: activeOrderId == null && nullToAbsent
          ? const Value.absent()
          : Value(activeOrderId),
      version: Value(version),
      isDeleted: Value(isDeleted),
      isOverflow: Value(isOverflow),
      parentTableId: parentTableId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentTableId),
      overflowSuffix: overflowSuffix == null && nullToAbsent
          ? const Value.absent()
          : Value(overflowSuffix),
    );
  }

  factory LocalRestaurantTable.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalRestaurantTable(
      id: serializer.fromJson<String>(json['id']),
      zoneId: serializer.fromJson<String?>(json['zoneId']),
      tableNumber: serializer.fromJson<String>(json['tableNumber']),
      name: serializer.fromJson<String>(json['name']),
      capacity: serializer.fromJson<int>(json['capacity']),
      status: serializer.fromJson<String>(json['status']),
      activeOrderId: serializer.fromJson<String?>(json['activeOrderId']),
      version: serializer.fromJson<int>(json['version']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      isOverflow: serializer.fromJson<bool>(json['isOverflow']),
      parentTableId: serializer.fromJson<String?>(json['parentTableId']),
      overflowSuffix: serializer.fromJson<String?>(json['overflowSuffix']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'zoneId': serializer.toJson<String?>(zoneId),
      'tableNumber': serializer.toJson<String>(tableNumber),
      'name': serializer.toJson<String>(name),
      'capacity': serializer.toJson<int>(capacity),
      'status': serializer.toJson<String>(status),
      'activeOrderId': serializer.toJson<String?>(activeOrderId),
      'version': serializer.toJson<int>(version),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'isOverflow': serializer.toJson<bool>(isOverflow),
      'parentTableId': serializer.toJson<String?>(parentTableId),
      'overflowSuffix': serializer.toJson<String?>(overflowSuffix),
    };
  }

  LocalRestaurantTable copyWith({
    String? id,
    Value<String?> zoneId = const Value.absent(),
    String? tableNumber,
    String? name,
    int? capacity,
    String? status,
    Value<String?> activeOrderId = const Value.absent(),
    int? version,
    bool? isDeleted,
    bool? isOverflow,
    Value<String?> parentTableId = const Value.absent(),
    Value<String?> overflowSuffix = const Value.absent(),
  }) => LocalRestaurantTable(
    id: id ?? this.id,
    zoneId: zoneId.present ? zoneId.value : this.zoneId,
    tableNumber: tableNumber ?? this.tableNumber,
    name: name ?? this.name,
    capacity: capacity ?? this.capacity,
    status: status ?? this.status,
    activeOrderId: activeOrderId.present
        ? activeOrderId.value
        : this.activeOrderId,
    version: version ?? this.version,
    isDeleted: isDeleted ?? this.isDeleted,
    isOverflow: isOverflow ?? this.isOverflow,
    parentTableId: parentTableId.present
        ? parentTableId.value
        : this.parentTableId,
    overflowSuffix: overflowSuffix.present
        ? overflowSuffix.value
        : this.overflowSuffix,
  );
  LocalRestaurantTable copyWithCompanion(LocalRestaurantTablesCompanion data) {
    return LocalRestaurantTable(
      id: data.id.present ? data.id.value : this.id,
      zoneId: data.zoneId.present ? data.zoneId.value : this.zoneId,
      tableNumber: data.tableNumber.present
          ? data.tableNumber.value
          : this.tableNumber,
      name: data.name.present ? data.name.value : this.name,
      capacity: data.capacity.present ? data.capacity.value : this.capacity,
      status: data.status.present ? data.status.value : this.status,
      activeOrderId: data.activeOrderId.present
          ? data.activeOrderId.value
          : this.activeOrderId,
      version: data.version.present ? data.version.value : this.version,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      isOverflow: data.isOverflow.present
          ? data.isOverflow.value
          : this.isOverflow,
      parentTableId: data.parentTableId.present
          ? data.parentTableId.value
          : this.parentTableId,
      overflowSuffix: data.overflowSuffix.present
          ? data.overflowSuffix.value
          : this.overflowSuffix,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalRestaurantTable(')
          ..write('id: $id, ')
          ..write('zoneId: $zoneId, ')
          ..write('tableNumber: $tableNumber, ')
          ..write('name: $name, ')
          ..write('capacity: $capacity, ')
          ..write('status: $status, ')
          ..write('activeOrderId: $activeOrderId, ')
          ..write('version: $version, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('isOverflow: $isOverflow, ')
          ..write('parentTableId: $parentTableId, ')
          ..write('overflowSuffix: $overflowSuffix')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    zoneId,
    tableNumber,
    name,
    capacity,
    status,
    activeOrderId,
    version,
    isDeleted,
    isOverflow,
    parentTableId,
    overflowSuffix,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalRestaurantTable &&
          other.id == this.id &&
          other.zoneId == this.zoneId &&
          other.tableNumber == this.tableNumber &&
          other.name == this.name &&
          other.capacity == this.capacity &&
          other.status == this.status &&
          other.activeOrderId == this.activeOrderId &&
          other.version == this.version &&
          other.isDeleted == this.isDeleted &&
          other.isOverflow == this.isOverflow &&
          other.parentTableId == this.parentTableId &&
          other.overflowSuffix == this.overflowSuffix);
}

class LocalRestaurantTablesCompanion
    extends UpdateCompanion<LocalRestaurantTable> {
  final Value<String> id;
  final Value<String?> zoneId;
  final Value<String> tableNumber;
  final Value<String> name;
  final Value<int> capacity;
  final Value<String> status;
  final Value<String?> activeOrderId;
  final Value<int> version;
  final Value<bool> isDeleted;
  final Value<bool> isOverflow;
  final Value<String?> parentTableId;
  final Value<String?> overflowSuffix;
  final Value<int> rowid;
  const LocalRestaurantTablesCompanion({
    this.id = const Value.absent(),
    this.zoneId = const Value.absent(),
    this.tableNumber = const Value.absent(),
    this.name = const Value.absent(),
    this.capacity = const Value.absent(),
    this.status = const Value.absent(),
    this.activeOrderId = const Value.absent(),
    this.version = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.isOverflow = const Value.absent(),
    this.parentTableId = const Value.absent(),
    this.overflowSuffix = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalRestaurantTablesCompanion.insert({
    required String id,
    this.zoneId = const Value.absent(),
    required String tableNumber,
    required String name,
    this.capacity = const Value.absent(),
    this.status = const Value.absent(),
    this.activeOrderId = const Value.absent(),
    this.version = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.isOverflow = const Value.absent(),
    this.parentTableId = const Value.absent(),
    this.overflowSuffix = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       tableNumber = Value(tableNumber),
       name = Value(name);
  static Insertable<LocalRestaurantTable> custom({
    Expression<String>? id,
    Expression<String>? zoneId,
    Expression<String>? tableNumber,
    Expression<String>? name,
    Expression<int>? capacity,
    Expression<String>? status,
    Expression<String>? activeOrderId,
    Expression<int>? version,
    Expression<bool>? isDeleted,
    Expression<bool>? isOverflow,
    Expression<String>? parentTableId,
    Expression<String>? overflowSuffix,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (zoneId != null) 'zone_id': zoneId,
      if (tableNumber != null) 'table_number': tableNumber,
      if (name != null) 'name': name,
      if (capacity != null) 'capacity': capacity,
      if (status != null) 'status': status,
      if (activeOrderId != null) 'active_order_id': activeOrderId,
      if (version != null) 'version': version,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (isOverflow != null) 'is_overflow': isOverflow,
      if (parentTableId != null) 'parent_table_id': parentTableId,
      if (overflowSuffix != null) 'overflow_suffix': overflowSuffix,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalRestaurantTablesCompanion copyWith({
    Value<String>? id,
    Value<String?>? zoneId,
    Value<String>? tableNumber,
    Value<String>? name,
    Value<int>? capacity,
    Value<String>? status,
    Value<String?>? activeOrderId,
    Value<int>? version,
    Value<bool>? isDeleted,
    Value<bool>? isOverflow,
    Value<String?>? parentTableId,
    Value<String?>? overflowSuffix,
    Value<int>? rowid,
  }) {
    return LocalRestaurantTablesCompanion(
      id: id ?? this.id,
      zoneId: zoneId ?? this.zoneId,
      tableNumber: tableNumber ?? this.tableNumber,
      name: name ?? this.name,
      capacity: capacity ?? this.capacity,
      status: status ?? this.status,
      activeOrderId: activeOrderId ?? this.activeOrderId,
      version: version ?? this.version,
      isDeleted: isDeleted ?? this.isDeleted,
      isOverflow: isOverflow ?? this.isOverflow,
      parentTableId: parentTableId ?? this.parentTableId,
      overflowSuffix: overflowSuffix ?? this.overflowSuffix,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (zoneId.present) {
      map['zone_id'] = Variable<String>(zoneId.value);
    }
    if (tableNumber.present) {
      map['table_number'] = Variable<String>(tableNumber.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (capacity.present) {
      map['capacity'] = Variable<int>(capacity.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (activeOrderId.present) {
      map['active_order_id'] = Variable<String>(activeOrderId.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (isOverflow.present) {
      map['is_overflow'] = Variable<bool>(isOverflow.value);
    }
    if (parentTableId.present) {
      map['parent_table_id'] = Variable<String>(parentTableId.value);
    }
    if (overflowSuffix.present) {
      map['overflow_suffix'] = Variable<String>(overflowSuffix.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalRestaurantTablesCompanion(')
          ..write('id: $id, ')
          ..write('zoneId: $zoneId, ')
          ..write('tableNumber: $tableNumber, ')
          ..write('name: $name, ')
          ..write('capacity: $capacity, ')
          ..write('status: $status, ')
          ..write('activeOrderId: $activeOrderId, ')
          ..write('version: $version, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('isOverflow: $isOverflow, ')
          ..write('parentTableId: $parentTableId, ')
          ..write('overflowSuffix: $overflowSuffix, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalFloorZonesTable extends LocalFloorZones
    with TableInfo<$LocalFloorZonesTable, LocalFloorZone> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalFloorZonesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _displayOrderMeta = const VerificationMeta(
    'displayOrder',
  );
  @override
  late final GeneratedColumn<int> displayOrder = GeneratedColumn<int>(
    'display_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, displayOrder];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_floor_zones';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalFloorZone> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('display_order')) {
      context.handle(
        _displayOrderMeta,
        displayOrder.isAcceptableOrUnknown(
          data['display_order']!,
          _displayOrderMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalFloorZone map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalFloorZone(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      displayOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}display_order'],
      )!,
    );
  }

  @override
  $LocalFloorZonesTable createAlias(String alias) {
    return $LocalFloorZonesTable(attachedDatabase, alias);
  }
}

class LocalFloorZone extends DataClass implements Insertable<LocalFloorZone> {
  final String id;
  final String name;
  final int displayOrder;
  const LocalFloorZone({
    required this.id,
    required this.name,
    required this.displayOrder,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['display_order'] = Variable<int>(displayOrder);
    return map;
  }

  LocalFloorZonesCompanion toCompanion(bool nullToAbsent) {
    return LocalFloorZonesCompanion(
      id: Value(id),
      name: Value(name),
      displayOrder: Value(displayOrder),
    );
  }

  factory LocalFloorZone.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalFloorZone(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      displayOrder: serializer.fromJson<int>(json['displayOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'displayOrder': serializer.toJson<int>(displayOrder),
    };
  }

  LocalFloorZone copyWith({String? id, String? name, int? displayOrder}) =>
      LocalFloorZone(
        id: id ?? this.id,
        name: name ?? this.name,
        displayOrder: displayOrder ?? this.displayOrder,
      );
  LocalFloorZone copyWithCompanion(LocalFloorZonesCompanion data) {
    return LocalFloorZone(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      displayOrder: data.displayOrder.present
          ? data.displayOrder.value
          : this.displayOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalFloorZone(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('displayOrder: $displayOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, displayOrder);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalFloorZone &&
          other.id == this.id &&
          other.name == this.name &&
          other.displayOrder == this.displayOrder);
}

class LocalFloorZonesCompanion extends UpdateCompanion<LocalFloorZone> {
  final Value<String> id;
  final Value<String> name;
  final Value<int> displayOrder;
  final Value<int> rowid;
  const LocalFloorZonesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.displayOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalFloorZonesCompanion.insert({
    required String id,
    required String name,
    this.displayOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name);
  static Insertable<LocalFloorZone> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<int>? displayOrder,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (displayOrder != null) 'display_order': displayOrder,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalFloorZonesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<int>? displayOrder,
    Value<int>? rowid,
  }) {
    return LocalFloorZonesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      displayOrder: displayOrder ?? this.displayOrder,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (displayOrder.present) {
      map['display_order'] = Variable<int>(displayOrder.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalFloorZonesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('displayOrder: $displayOrder, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalStaffUsersTable extends LocalStaffUsers
    with TableInfo<$LocalStaffUsersTable, LocalStaffUser> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalStaffUsersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _usernameMeta = const VerificationMeta(
    'username',
  );
  @override
  late final GeneratedColumn<String> username = GeneratedColumn<String>(
    'username',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  @override
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
    'role',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pinHashMeta = const VerificationMeta(
    'pinHash',
  );
  @override
  late final GeneratedColumn<String> pinHash = GeneratedColumn<String>(
    'pin_hash',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  @override
  List<GeneratedColumn> get $columns => [id, username, role, pinHash, isActive];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_staff_users';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalStaffUser> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('username')) {
      context.handle(
        _usernameMeta,
        username.isAcceptableOrUnknown(data['username']!, _usernameMeta),
      );
    } else if (isInserting) {
      context.missing(_usernameMeta);
    }
    if (data.containsKey('role')) {
      context.handle(
        _roleMeta,
        role.isAcceptableOrUnknown(data['role']!, _roleMeta),
      );
    } else if (isInserting) {
      context.missing(_roleMeta);
    }
    if (data.containsKey('pin_hash')) {
      context.handle(
        _pinHashMeta,
        pinHash.isAcceptableOrUnknown(data['pin_hash']!, _pinHashMeta),
      );
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalStaffUser map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalStaffUser(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      username: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}username'],
      )!,
      role: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role'],
      )!,
      pinHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pin_hash'],
      ),
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
    );
  }

  @override
  $LocalStaffUsersTable createAlias(String alias) {
    return $LocalStaffUsersTable(attachedDatabase, alias);
  }
}

class LocalStaffUser extends DataClass implements Insertable<LocalStaffUser> {
  final String id;
  final String username;
  final String role;
  final String? pinHash;
  final bool isActive;
  const LocalStaffUser({
    required this.id,
    required this.username,
    required this.role,
    this.pinHash,
    required this.isActive,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['username'] = Variable<String>(username);
    map['role'] = Variable<String>(role);
    if (!nullToAbsent || pinHash != null) {
      map['pin_hash'] = Variable<String>(pinHash);
    }
    map['is_active'] = Variable<bool>(isActive);
    return map;
  }

  LocalStaffUsersCompanion toCompanion(bool nullToAbsent) {
    return LocalStaffUsersCompanion(
      id: Value(id),
      username: Value(username),
      role: Value(role),
      pinHash: pinHash == null && nullToAbsent
          ? const Value.absent()
          : Value(pinHash),
      isActive: Value(isActive),
    );
  }

  factory LocalStaffUser.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalStaffUser(
      id: serializer.fromJson<String>(json['id']),
      username: serializer.fromJson<String>(json['username']),
      role: serializer.fromJson<String>(json['role']),
      pinHash: serializer.fromJson<String?>(json['pinHash']),
      isActive: serializer.fromJson<bool>(json['isActive']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'username': serializer.toJson<String>(username),
      'role': serializer.toJson<String>(role),
      'pinHash': serializer.toJson<String?>(pinHash),
      'isActive': serializer.toJson<bool>(isActive),
    };
  }

  LocalStaffUser copyWith({
    String? id,
    String? username,
    String? role,
    Value<String?> pinHash = const Value.absent(),
    bool? isActive,
  }) => LocalStaffUser(
    id: id ?? this.id,
    username: username ?? this.username,
    role: role ?? this.role,
    pinHash: pinHash.present ? pinHash.value : this.pinHash,
    isActive: isActive ?? this.isActive,
  );
  LocalStaffUser copyWithCompanion(LocalStaffUsersCompanion data) {
    return LocalStaffUser(
      id: data.id.present ? data.id.value : this.id,
      username: data.username.present ? data.username.value : this.username,
      role: data.role.present ? data.role.value : this.role,
      pinHash: data.pinHash.present ? data.pinHash.value : this.pinHash,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalStaffUser(')
          ..write('id: $id, ')
          ..write('username: $username, ')
          ..write('role: $role, ')
          ..write('pinHash: $pinHash, ')
          ..write('isActive: $isActive')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, username, role, pinHash, isActive);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalStaffUser &&
          other.id == this.id &&
          other.username == this.username &&
          other.role == this.role &&
          other.pinHash == this.pinHash &&
          other.isActive == this.isActive);
}

class LocalStaffUsersCompanion extends UpdateCompanion<LocalStaffUser> {
  final Value<String> id;
  final Value<String> username;
  final Value<String> role;
  final Value<String?> pinHash;
  final Value<bool> isActive;
  final Value<int> rowid;
  const LocalStaffUsersCompanion({
    this.id = const Value.absent(),
    this.username = const Value.absent(),
    this.role = const Value.absent(),
    this.pinHash = const Value.absent(),
    this.isActive = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalStaffUsersCompanion.insert({
    required String id,
    required String username,
    required String role,
    this.pinHash = const Value.absent(),
    this.isActive = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       username = Value(username),
       role = Value(role);
  static Insertable<LocalStaffUser> custom({
    Expression<String>? id,
    Expression<String>? username,
    Expression<String>? role,
    Expression<String>? pinHash,
    Expression<bool>? isActive,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (username != null) 'username': username,
      if (role != null) 'role': role,
      if (pinHash != null) 'pin_hash': pinHash,
      if (isActive != null) 'is_active': isActive,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalStaffUsersCompanion copyWith({
    Value<String>? id,
    Value<String>? username,
    Value<String>? role,
    Value<String?>? pinHash,
    Value<bool>? isActive,
    Value<int>? rowid,
  }) {
    return LocalStaffUsersCompanion(
      id: id ?? this.id,
      username: username ?? this.username,
      role: role ?? this.role,
      pinHash: pinHash ?? this.pinHash,
      isActive: isActive ?? this.isActive,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (username.present) {
      map['username'] = Variable<String>(username.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (pinHash.present) {
      map['pin_hash'] = Variable<String>(pinHash.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalStaffUsersCompanion(')
          ..write('id: $id, ')
          ..write('username: $username, ')
          ..write('role: $role, ')
          ..write('pinHash: $pinHash, ')
          ..write('isActive: $isActive, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalRolePermissionsTable extends LocalRolePermissions
    with TableInfo<$LocalRolePermissionsTable, LocalRolePermission> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalRolePermissionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  @override
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
    'role',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _moduleNameMeta = const VerificationMeta(
    'moduleName',
  );
  @override
  late final GeneratedColumn<String> moduleName = GeneratedColumn<String>(
    'module_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _actionNameMeta = const VerificationMeta(
    'actionName',
  );
  @override
  late final GeneratedColumn<String> actionName = GeneratedColumn<String>(
    'action_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isGrantedMeta = const VerificationMeta(
    'isGranted',
  );
  @override
  late final GeneratedColumn<bool> isGranted = GeneratedColumn<bool>(
    'is_granted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_granted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    role,
    moduleName,
    actionName,
    isGranted,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_role_permissions';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalRolePermission> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('role')) {
      context.handle(
        _roleMeta,
        role.isAcceptableOrUnknown(data['role']!, _roleMeta),
      );
    } else if (isInserting) {
      context.missing(_roleMeta);
    }
    if (data.containsKey('module_name')) {
      context.handle(
        _moduleNameMeta,
        moduleName.isAcceptableOrUnknown(data['module_name']!, _moduleNameMeta),
      );
    } else if (isInserting) {
      context.missing(_moduleNameMeta);
    }
    if (data.containsKey('action_name')) {
      context.handle(
        _actionNameMeta,
        actionName.isAcceptableOrUnknown(data['action_name']!, _actionNameMeta),
      );
    } else if (isInserting) {
      context.missing(_actionNameMeta);
    }
    if (data.containsKey('is_granted')) {
      context.handle(
        _isGrantedMeta,
        isGranted.isAcceptableOrUnknown(data['is_granted']!, _isGrantedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalRolePermission map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalRolePermission(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      role: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role'],
      )!,
      moduleName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}module_name'],
      )!,
      actionName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}action_name'],
      )!,
      isGranted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_granted'],
      )!,
    );
  }

  @override
  $LocalRolePermissionsTable createAlias(String alias) {
    return $LocalRolePermissionsTable(attachedDatabase, alias);
  }
}

class LocalRolePermission extends DataClass
    implements Insertable<LocalRolePermission> {
  final String id;
  final String role;
  final String moduleName;
  final String actionName;
  final bool isGranted;
  const LocalRolePermission({
    required this.id,
    required this.role,
    required this.moduleName,
    required this.actionName,
    required this.isGranted,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['role'] = Variable<String>(role);
    map['module_name'] = Variable<String>(moduleName);
    map['action_name'] = Variable<String>(actionName);
    map['is_granted'] = Variable<bool>(isGranted);
    return map;
  }

  LocalRolePermissionsCompanion toCompanion(bool nullToAbsent) {
    return LocalRolePermissionsCompanion(
      id: Value(id),
      role: Value(role),
      moduleName: Value(moduleName),
      actionName: Value(actionName),
      isGranted: Value(isGranted),
    );
  }

  factory LocalRolePermission.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalRolePermission(
      id: serializer.fromJson<String>(json['id']),
      role: serializer.fromJson<String>(json['role']),
      moduleName: serializer.fromJson<String>(json['moduleName']),
      actionName: serializer.fromJson<String>(json['actionName']),
      isGranted: serializer.fromJson<bool>(json['isGranted']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'role': serializer.toJson<String>(role),
      'moduleName': serializer.toJson<String>(moduleName),
      'actionName': serializer.toJson<String>(actionName),
      'isGranted': serializer.toJson<bool>(isGranted),
    };
  }

  LocalRolePermission copyWith({
    String? id,
    String? role,
    String? moduleName,
    String? actionName,
    bool? isGranted,
  }) => LocalRolePermission(
    id: id ?? this.id,
    role: role ?? this.role,
    moduleName: moduleName ?? this.moduleName,
    actionName: actionName ?? this.actionName,
    isGranted: isGranted ?? this.isGranted,
  );
  LocalRolePermission copyWithCompanion(LocalRolePermissionsCompanion data) {
    return LocalRolePermission(
      id: data.id.present ? data.id.value : this.id,
      role: data.role.present ? data.role.value : this.role,
      moduleName: data.moduleName.present
          ? data.moduleName.value
          : this.moduleName,
      actionName: data.actionName.present
          ? data.actionName.value
          : this.actionName,
      isGranted: data.isGranted.present ? data.isGranted.value : this.isGranted,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalRolePermission(')
          ..write('id: $id, ')
          ..write('role: $role, ')
          ..write('moduleName: $moduleName, ')
          ..write('actionName: $actionName, ')
          ..write('isGranted: $isGranted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, role, moduleName, actionName, isGranted);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalRolePermission &&
          other.id == this.id &&
          other.role == this.role &&
          other.moduleName == this.moduleName &&
          other.actionName == this.actionName &&
          other.isGranted == this.isGranted);
}

class LocalRolePermissionsCompanion
    extends UpdateCompanion<LocalRolePermission> {
  final Value<String> id;
  final Value<String> role;
  final Value<String> moduleName;
  final Value<String> actionName;
  final Value<bool> isGranted;
  final Value<int> rowid;
  const LocalRolePermissionsCompanion({
    this.id = const Value.absent(),
    this.role = const Value.absent(),
    this.moduleName = const Value.absent(),
    this.actionName = const Value.absent(),
    this.isGranted = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalRolePermissionsCompanion.insert({
    required String id,
    required String role,
    required String moduleName,
    required String actionName,
    this.isGranted = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       role = Value(role),
       moduleName = Value(moduleName),
       actionName = Value(actionName);
  static Insertable<LocalRolePermission> custom({
    Expression<String>? id,
    Expression<String>? role,
    Expression<String>? moduleName,
    Expression<String>? actionName,
    Expression<bool>? isGranted,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (role != null) 'role': role,
      if (moduleName != null) 'module_name': moduleName,
      if (actionName != null) 'action_name': actionName,
      if (isGranted != null) 'is_granted': isGranted,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalRolePermissionsCompanion copyWith({
    Value<String>? id,
    Value<String>? role,
    Value<String>? moduleName,
    Value<String>? actionName,
    Value<bool>? isGranted,
    Value<int>? rowid,
  }) {
    return LocalRolePermissionsCompanion(
      id: id ?? this.id,
      role: role ?? this.role,
      moduleName: moduleName ?? this.moduleName,
      actionName: actionName ?? this.actionName,
      isGranted: isGranted ?? this.isGranted,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (moduleName.present) {
      map['module_name'] = Variable<String>(moduleName.value);
    }
    if (actionName.present) {
      map['action_name'] = Variable<String>(actionName.value);
    }
    if (isGranted.present) {
      map['is_granted'] = Variable<bool>(isGranted.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalRolePermissionsCompanion(')
          ..write('id: $id, ')
          ..write('role: $role, ')
          ..write('moduleName: $moduleName, ')
          ..write('actionName: $actionName, ')
          ..write('isGranted: $isGranted, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalStoreSettingsTable extends LocalStoreSettings
    with TableInfo<$LocalStoreSettingsTable, LocalStoreSetting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalStoreSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _chainNameMeta = const VerificationMeta(
    'chainName',
  );
  @override
  late final GeneratedColumn<String> chainName = GeneratedColumn<String>(
    'chain_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _branchCodeMeta = const VerificationMeta(
    'branchCode',
  );
  @override
  late final GeneratedColumn<String> branchCode = GeneratedColumn<String>(
    'branch_code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _branchNameMeta = const VerificationMeta(
    'branchName',
  );
  @override
  late final GeneratedColumn<String> branchName = GeneratedColumn<String>(
    'branch_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _storePhoneMeta = const VerificationMeta(
    'storePhone',
  );
  @override
  late final GeneratedColumn<String> storePhone = GeneratedColumn<String>(
    'store_phone',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _taxPercentageMeta = const VerificationMeta(
    'taxPercentage',
  );
  @override
  late final GeneratedColumn<double> taxPercentage = GeneratedColumn<double>(
    'tax_percentage',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    chainName,
    branchCode,
    branchName,
    storePhone,
    taxPercentage,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_store_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalStoreSetting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('chain_name')) {
      context.handle(
        _chainNameMeta,
        chainName.isAcceptableOrUnknown(data['chain_name']!, _chainNameMeta),
      );
    } else if (isInserting) {
      context.missing(_chainNameMeta);
    }
    if (data.containsKey('branch_code')) {
      context.handle(
        _branchCodeMeta,
        branchCode.isAcceptableOrUnknown(data['branch_code']!, _branchCodeMeta),
      );
    } else if (isInserting) {
      context.missing(_branchCodeMeta);
    }
    if (data.containsKey('branch_name')) {
      context.handle(
        _branchNameMeta,
        branchName.isAcceptableOrUnknown(data['branch_name']!, _branchNameMeta),
      );
    } else if (isInserting) {
      context.missing(_branchNameMeta);
    }
    if (data.containsKey('store_phone')) {
      context.handle(
        _storePhoneMeta,
        storePhone.isAcceptableOrUnknown(data['store_phone']!, _storePhoneMeta),
      );
    } else if (isInserting) {
      context.missing(_storePhoneMeta);
    }
    if (data.containsKey('tax_percentage')) {
      context.handle(
        _taxPercentageMeta,
        taxPercentage.isAcceptableOrUnknown(
          data['tax_percentage']!,
          _taxPercentageMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalStoreSetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalStoreSetting(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      chainName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}chain_name'],
      )!,
      branchCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}branch_code'],
      )!,
      branchName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}branch_name'],
      )!,
      storePhone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}store_phone'],
      )!,
      taxPercentage: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}tax_percentage'],
      )!,
    );
  }

  @override
  $LocalStoreSettingsTable createAlias(String alias) {
    return $LocalStoreSettingsTable(attachedDatabase, alias);
  }
}

class LocalStoreSetting extends DataClass
    implements Insertable<LocalStoreSetting> {
  final String id;
  final String chainName;
  final String branchCode;
  final String branchName;
  final String storePhone;
  final double taxPercentage;
  const LocalStoreSetting({
    required this.id,
    required this.chainName,
    required this.branchCode,
    required this.branchName,
    required this.storePhone,
    required this.taxPercentage,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['chain_name'] = Variable<String>(chainName);
    map['branch_code'] = Variable<String>(branchCode);
    map['branch_name'] = Variable<String>(branchName);
    map['store_phone'] = Variable<String>(storePhone);
    map['tax_percentage'] = Variable<double>(taxPercentage);
    return map;
  }

  LocalStoreSettingsCompanion toCompanion(bool nullToAbsent) {
    return LocalStoreSettingsCompanion(
      id: Value(id),
      chainName: Value(chainName),
      branchCode: Value(branchCode),
      branchName: Value(branchName),
      storePhone: Value(storePhone),
      taxPercentage: Value(taxPercentage),
    );
  }

  factory LocalStoreSetting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalStoreSetting(
      id: serializer.fromJson<String>(json['id']),
      chainName: serializer.fromJson<String>(json['chainName']),
      branchCode: serializer.fromJson<String>(json['branchCode']),
      branchName: serializer.fromJson<String>(json['branchName']),
      storePhone: serializer.fromJson<String>(json['storePhone']),
      taxPercentage: serializer.fromJson<double>(json['taxPercentage']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'chainName': serializer.toJson<String>(chainName),
      'branchCode': serializer.toJson<String>(branchCode),
      'branchName': serializer.toJson<String>(branchName),
      'storePhone': serializer.toJson<String>(storePhone),
      'taxPercentage': serializer.toJson<double>(taxPercentage),
    };
  }

  LocalStoreSetting copyWith({
    String? id,
    String? chainName,
    String? branchCode,
    String? branchName,
    String? storePhone,
    double? taxPercentage,
  }) => LocalStoreSetting(
    id: id ?? this.id,
    chainName: chainName ?? this.chainName,
    branchCode: branchCode ?? this.branchCode,
    branchName: branchName ?? this.branchName,
    storePhone: storePhone ?? this.storePhone,
    taxPercentage: taxPercentage ?? this.taxPercentage,
  );
  LocalStoreSetting copyWithCompanion(LocalStoreSettingsCompanion data) {
    return LocalStoreSetting(
      id: data.id.present ? data.id.value : this.id,
      chainName: data.chainName.present ? data.chainName.value : this.chainName,
      branchCode: data.branchCode.present
          ? data.branchCode.value
          : this.branchCode,
      branchName: data.branchName.present
          ? data.branchName.value
          : this.branchName,
      storePhone: data.storePhone.present
          ? data.storePhone.value
          : this.storePhone,
      taxPercentage: data.taxPercentage.present
          ? data.taxPercentage.value
          : this.taxPercentage,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalStoreSetting(')
          ..write('id: $id, ')
          ..write('chainName: $chainName, ')
          ..write('branchCode: $branchCode, ')
          ..write('branchName: $branchName, ')
          ..write('storePhone: $storePhone, ')
          ..write('taxPercentage: $taxPercentage')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    chainName,
    branchCode,
    branchName,
    storePhone,
    taxPercentage,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalStoreSetting &&
          other.id == this.id &&
          other.chainName == this.chainName &&
          other.branchCode == this.branchCode &&
          other.branchName == this.branchName &&
          other.storePhone == this.storePhone &&
          other.taxPercentage == this.taxPercentage);
}

class LocalStoreSettingsCompanion extends UpdateCompanion<LocalStoreSetting> {
  final Value<String> id;
  final Value<String> chainName;
  final Value<String> branchCode;
  final Value<String> branchName;
  final Value<String> storePhone;
  final Value<double> taxPercentage;
  final Value<int> rowid;
  const LocalStoreSettingsCompanion({
    this.id = const Value.absent(),
    this.chainName = const Value.absent(),
    this.branchCode = const Value.absent(),
    this.branchName = const Value.absent(),
    this.storePhone = const Value.absent(),
    this.taxPercentage = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalStoreSettingsCompanion.insert({
    required String id,
    required String chainName,
    required String branchCode,
    required String branchName,
    required String storePhone,
    this.taxPercentage = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       chainName = Value(chainName),
       branchCode = Value(branchCode),
       branchName = Value(branchName),
       storePhone = Value(storePhone);
  static Insertable<LocalStoreSetting> custom({
    Expression<String>? id,
    Expression<String>? chainName,
    Expression<String>? branchCode,
    Expression<String>? branchName,
    Expression<String>? storePhone,
    Expression<double>? taxPercentage,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (chainName != null) 'chain_name': chainName,
      if (branchCode != null) 'branch_code': branchCode,
      if (branchName != null) 'branch_name': branchName,
      if (storePhone != null) 'store_phone': storePhone,
      if (taxPercentage != null) 'tax_percentage': taxPercentage,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalStoreSettingsCompanion copyWith({
    Value<String>? id,
    Value<String>? chainName,
    Value<String>? branchCode,
    Value<String>? branchName,
    Value<String>? storePhone,
    Value<double>? taxPercentage,
    Value<int>? rowid,
  }) {
    return LocalStoreSettingsCompanion(
      id: id ?? this.id,
      chainName: chainName ?? this.chainName,
      branchCode: branchCode ?? this.branchCode,
      branchName: branchName ?? this.branchName,
      storePhone: storePhone ?? this.storePhone,
      taxPercentage: taxPercentage ?? this.taxPercentage,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (chainName.present) {
      map['chain_name'] = Variable<String>(chainName.value);
    }
    if (branchCode.present) {
      map['branch_code'] = Variable<String>(branchCode.value);
    }
    if (branchName.present) {
      map['branch_name'] = Variable<String>(branchName.value);
    }
    if (storePhone.present) {
      map['store_phone'] = Variable<String>(storePhone.value);
    }
    if (taxPercentage.present) {
      map['tax_percentage'] = Variable<double>(taxPercentage.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalStoreSettingsCompanion(')
          ..write('id: $id, ')
          ..write('chainName: $chainName, ')
          ..write('branchCode: $branchCode, ')
          ..write('branchName: $branchName, ')
          ..write('storePhone: $storePhone, ')
          ..write('taxPercentage: $taxPercentage, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $LocalOrdersTable localOrders = $LocalOrdersTable(this);
  late final $LocalOrderItemsTable localOrderItems = $LocalOrderItemsTable(
    this,
  );
  late final $LocalOrderPaymentsTable localOrderPayments =
      $LocalOrderPaymentsTable(this);
  late final $SyncOutboxTable syncOutbox = $SyncOutboxTable(this);
  late final $TerminalSequencesTable terminalSequences =
      $TerminalSequencesTable(this);
  late final $OfflinePrintJobsTable offlinePrintJobs = $OfflinePrintJobsTable(
    this,
  );
  late final $SyncCursorsTable syncCursors = $SyncCursorsTable(this);
  late final $SyncConflictsTable syncConflicts = $SyncConflictsTable(this);
  late final $LocalDailyCalculationsTable localDailyCalculations =
      $LocalDailyCalculationsTable(this);
  late final $LocalMenuCategoriesTable localMenuCategories =
      $LocalMenuCategoriesTable(this);
  late final $LocalMenuItemsTable localMenuItems = $LocalMenuItemsTable(this);
  late final $LocalMenuItemSizesTable localMenuItemSizes =
      $LocalMenuItemSizesTable(this);
  late final $LocalMenuItemOptionsTable localMenuItemOptions =
      $LocalMenuItemOptionsTable(this);
  late final $LocalDealsTable localDeals = $LocalDealsTable(this);
  late final $LocalDealComponentsTable localDealComponents =
      $LocalDealComponentsTable(this);
  late final $LocalRestaurantTablesTable localRestaurantTables =
      $LocalRestaurantTablesTable(this);
  late final $LocalFloorZonesTable localFloorZones = $LocalFloorZonesTable(
    this,
  );
  late final $LocalStaffUsersTable localStaffUsers = $LocalStaffUsersTable(
    this,
  );
  late final $LocalRolePermissionsTable localRolePermissions =
      $LocalRolePermissionsTable(this);
  late final $LocalStoreSettingsTable localStoreSettings =
      $LocalStoreSettingsTable(this);
  late final OrdersDao ordersDao = OrdersDao(this as AppDatabase);
  late final OutboxDao outboxDao = OutboxDao(this as AppDatabase);
  late final CatalogDao catalogDao = CatalogDao(this as AppDatabase);
  late final SyncCursorsDao syncCursorsDao = SyncCursorsDao(
    this as AppDatabase,
  );
  late final DailyCalculationsDao dailyCalculationsDao = DailyCalculationsDao(
    this as AppDatabase,
  );
  late final TerminalSequencesDao terminalSequencesDao = TerminalSequencesDao(
    this as AppDatabase,
  );
  late final PrintJobsDao printJobsDao = PrintJobsDao(this as AppDatabase);
  late final RetentionDao retentionDao = RetentionDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    localOrders,
    localOrderItems,
    localOrderPayments,
    syncOutbox,
    terminalSequences,
    offlinePrintJobs,
    syncCursors,
    syncConflicts,
    localDailyCalculations,
    localMenuCategories,
    localMenuItems,
    localMenuItemSizes,
    localMenuItemOptions,
    localDeals,
    localDealComponents,
    localRestaurantTables,
    localFloorZones,
    localStaffUsers,
    localRolePermissions,
    localStoreSettings,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'local_orders',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('local_order_items', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'local_orders',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('local_order_payments', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'local_menu_items',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('local_menu_item_sizes', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'local_menu_items',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('local_menu_item_options', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'local_deals',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('local_deal_components', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$LocalOrdersTableCreateCompanionBuilder =
    LocalOrdersCompanion Function({
      required String id,
      required String orderNumber,
      required String orderType,
      Value<String?> shiftId,
      Value<String> status,
      required double subtotal,
      Value<double> discountPercentage,
      Value<double> discountAmount,
      Value<double> taxAmount,
      required double grandTotal,
      Value<String> paymentStatus,
      Value<bool> isPaid,
      Value<bool> isHeld,
      Value<bool> kitchenTicketSent,
      Value<String?> rejectionReason,
      required String deviceId,
      Value<DateTime> createdAt,
      Value<String> syncStatus,
      Value<int> serverVersion,
      Value<DateTime> clientUpdatedAt,
      Value<DateTime?> serverUpdatedAt,
      Value<bool> isDeleted,
      Value<int> rowid,
    });
typedef $$LocalOrdersTableUpdateCompanionBuilder =
    LocalOrdersCompanion Function({
      Value<String> id,
      Value<String> orderNumber,
      Value<String> orderType,
      Value<String?> shiftId,
      Value<String> status,
      Value<double> subtotal,
      Value<double> discountPercentage,
      Value<double> discountAmount,
      Value<double> taxAmount,
      Value<double> grandTotal,
      Value<String> paymentStatus,
      Value<bool> isPaid,
      Value<bool> isHeld,
      Value<bool> kitchenTicketSent,
      Value<String?> rejectionReason,
      Value<String> deviceId,
      Value<DateTime> createdAt,
      Value<String> syncStatus,
      Value<int> serverVersion,
      Value<DateTime> clientUpdatedAt,
      Value<DateTime?> serverUpdatedAt,
      Value<bool> isDeleted,
      Value<int> rowid,
    });

final class $$LocalOrdersTableReferences
    extends BaseReferences<_$AppDatabase, $LocalOrdersTable, LocalOrder> {
  $$LocalOrdersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$LocalOrderItemsTable, List<LocalOrderItem>>
  _localOrderItemsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.localOrderItems,
    aliasName: 'local_orders__id__local_order_items__order_id',
  );

  $$LocalOrderItemsTableProcessedTableManager get localOrderItemsRefs {
    final manager = $$LocalOrderItemsTableTableManager(
      $_db,
      $_db.localOrderItems,
    ).filter((f) => f.orderId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _localOrderItemsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$LocalOrderPaymentsTable, List<LocalOrderPayment>>
  _localOrderPaymentsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.localOrderPayments,
        aliasName: 'local_orders__id__local_order_payments__order_id',
      );

  $$LocalOrderPaymentsTableProcessedTableManager get localOrderPaymentsRefs {
    final manager = $$LocalOrderPaymentsTableTableManager(
      $_db,
      $_db.localOrderPayments,
    ).filter((f) => f.orderId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _localOrderPaymentsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$LocalOrdersTableFilterComposer
    extends Composer<_$AppDatabase, $LocalOrdersTable> {
  $$LocalOrdersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get orderNumber => $composableBuilder(
    column: $table.orderNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get orderType => $composableBuilder(
    column: $table.orderType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get shiftId => $composableBuilder(
    column: $table.shiftId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get subtotal => $composableBuilder(
    column: $table.subtotal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get discountPercentage => $composableBuilder(
    column: $table.discountPercentage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get discountAmount => $composableBuilder(
    column: $table.discountAmount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get taxAmount => $composableBuilder(
    column: $table.taxAmount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get grandTotal => $composableBuilder(
    column: $table.grandTotal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get paymentStatus => $composableBuilder(
    column: $table.paymentStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isPaid => $composableBuilder(
    column: $table.isPaid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isHeld => $composableBuilder(
    column: $table.isHeld,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get kitchenTicketSent => $composableBuilder(
    column: $table.kitchenTicketSent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rejectionReason => $composableBuilder(
    column: $table.rejectionReason,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get serverVersion => $composableBuilder(
    column: $table.serverVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get clientUpdatedAt => $composableBuilder(
    column: $table.clientUpdatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get serverUpdatedAt => $composableBuilder(
    column: $table.serverUpdatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> localOrderItemsRefs(
    Expression<bool> Function($$LocalOrderItemsTableFilterComposer f) f,
  ) {
    final $$LocalOrderItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.localOrderItems,
      getReferencedColumn: (t) => t.orderId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalOrderItemsTableFilterComposer(
            $db: $db,
            $table: $db.localOrderItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> localOrderPaymentsRefs(
    Expression<bool> Function($$LocalOrderPaymentsTableFilterComposer f) f,
  ) {
    final $$LocalOrderPaymentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.localOrderPayments,
      getReferencedColumn: (t) => t.orderId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalOrderPaymentsTableFilterComposer(
            $db: $db,
            $table: $db.localOrderPayments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LocalOrdersTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalOrdersTable> {
  $$LocalOrdersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get orderNumber => $composableBuilder(
    column: $table.orderNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get orderType => $composableBuilder(
    column: $table.orderType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get shiftId => $composableBuilder(
    column: $table.shiftId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get subtotal => $composableBuilder(
    column: $table.subtotal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get discountPercentage => $composableBuilder(
    column: $table.discountPercentage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get discountAmount => $composableBuilder(
    column: $table.discountAmount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get taxAmount => $composableBuilder(
    column: $table.taxAmount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get grandTotal => $composableBuilder(
    column: $table.grandTotal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get paymentStatus => $composableBuilder(
    column: $table.paymentStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPaid => $composableBuilder(
    column: $table.isPaid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isHeld => $composableBuilder(
    column: $table.isHeld,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get kitchenTicketSent => $composableBuilder(
    column: $table.kitchenTicketSent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rejectionReason => $composableBuilder(
    column: $table.rejectionReason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get serverVersion => $composableBuilder(
    column: $table.serverVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get clientUpdatedAt => $composableBuilder(
    column: $table.clientUpdatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get serverUpdatedAt => $composableBuilder(
    column: $table.serverUpdatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalOrdersTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalOrdersTable> {
  $$LocalOrdersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get orderNumber => $composableBuilder(
    column: $table.orderNumber,
    builder: (column) => column,
  );

  GeneratedColumn<String> get orderType =>
      $composableBuilder(column: $table.orderType, builder: (column) => column);

  GeneratedColumn<String> get shiftId =>
      $composableBuilder(column: $table.shiftId, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<double> get subtotal =>
      $composableBuilder(column: $table.subtotal, builder: (column) => column);

  GeneratedColumn<double> get discountPercentage => $composableBuilder(
    column: $table.discountPercentage,
    builder: (column) => column,
  );

  GeneratedColumn<double> get discountAmount => $composableBuilder(
    column: $table.discountAmount,
    builder: (column) => column,
  );

  GeneratedColumn<double> get taxAmount =>
      $composableBuilder(column: $table.taxAmount, builder: (column) => column);

  GeneratedColumn<double> get grandTotal => $composableBuilder(
    column: $table.grandTotal,
    builder: (column) => column,
  );

  GeneratedColumn<String> get paymentStatus => $composableBuilder(
    column: $table.paymentStatus,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isPaid =>
      $composableBuilder(column: $table.isPaid, builder: (column) => column);

  GeneratedColumn<bool> get isHeld =>
      $composableBuilder(column: $table.isHeld, builder: (column) => column);

  GeneratedColumn<bool> get kitchenTicketSent => $composableBuilder(
    column: $table.kitchenTicketSent,
    builder: (column) => column,
  );

  GeneratedColumn<String> get rejectionReason => $composableBuilder(
    column: $table.rejectionReason,
    builder: (column) => column,
  );

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );

  GeneratedColumn<int> get serverVersion => $composableBuilder(
    column: $table.serverVersion,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get clientUpdatedAt => $composableBuilder(
    column: $table.clientUpdatedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get serverUpdatedAt => $composableBuilder(
    column: $table.serverUpdatedAt,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  Expression<T> localOrderItemsRefs<T extends Object>(
    Expression<T> Function($$LocalOrderItemsTableAnnotationComposer a) f,
  ) {
    final $$LocalOrderItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.localOrderItems,
      getReferencedColumn: (t) => t.orderId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalOrderItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.localOrderItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> localOrderPaymentsRefs<T extends Object>(
    Expression<T> Function($$LocalOrderPaymentsTableAnnotationComposer a) f,
  ) {
    final $$LocalOrderPaymentsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.localOrderPayments,
          getReferencedColumn: (t) => t.orderId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$LocalOrderPaymentsTableAnnotationComposer(
                $db: $db,
                $table: $db.localOrderPayments,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$LocalOrdersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalOrdersTable,
          LocalOrder,
          $$LocalOrdersTableFilterComposer,
          $$LocalOrdersTableOrderingComposer,
          $$LocalOrdersTableAnnotationComposer,
          $$LocalOrdersTableCreateCompanionBuilder,
          $$LocalOrdersTableUpdateCompanionBuilder,
          (LocalOrder, $$LocalOrdersTableReferences),
          LocalOrder,
          PrefetchHooks Function({
            bool localOrderItemsRefs,
            bool localOrderPaymentsRefs,
          })
        > {
  $$LocalOrdersTableTableManager(_$AppDatabase db, $LocalOrdersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalOrdersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalOrdersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalOrdersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> orderNumber = const Value.absent(),
                Value<String> orderType = const Value.absent(),
                Value<String?> shiftId = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<double> subtotal = const Value.absent(),
                Value<double> discountPercentage = const Value.absent(),
                Value<double> discountAmount = const Value.absent(),
                Value<double> taxAmount = const Value.absent(),
                Value<double> grandTotal = const Value.absent(),
                Value<String> paymentStatus = const Value.absent(),
                Value<bool> isPaid = const Value.absent(),
                Value<bool> isHeld = const Value.absent(),
                Value<bool> kitchenTicketSent = const Value.absent(),
                Value<String?> rejectionReason = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
                Value<int> serverVersion = const Value.absent(),
                Value<DateTime> clientUpdatedAt = const Value.absent(),
                Value<DateTime?> serverUpdatedAt = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalOrdersCompanion(
                id: id,
                orderNumber: orderNumber,
                orderType: orderType,
                shiftId: shiftId,
                status: status,
                subtotal: subtotal,
                discountPercentage: discountPercentage,
                discountAmount: discountAmount,
                taxAmount: taxAmount,
                grandTotal: grandTotal,
                paymentStatus: paymentStatus,
                isPaid: isPaid,
                isHeld: isHeld,
                kitchenTicketSent: kitchenTicketSent,
                rejectionReason: rejectionReason,
                deviceId: deviceId,
                createdAt: createdAt,
                syncStatus: syncStatus,
                serverVersion: serverVersion,
                clientUpdatedAt: clientUpdatedAt,
                serverUpdatedAt: serverUpdatedAt,
                isDeleted: isDeleted,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String orderNumber,
                required String orderType,
                Value<String?> shiftId = const Value.absent(),
                Value<String> status = const Value.absent(),
                required double subtotal,
                Value<double> discountPercentage = const Value.absent(),
                Value<double> discountAmount = const Value.absent(),
                Value<double> taxAmount = const Value.absent(),
                required double grandTotal,
                Value<String> paymentStatus = const Value.absent(),
                Value<bool> isPaid = const Value.absent(),
                Value<bool> isHeld = const Value.absent(),
                Value<bool> kitchenTicketSent = const Value.absent(),
                Value<String?> rejectionReason = const Value.absent(),
                required String deviceId,
                Value<DateTime> createdAt = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
                Value<int> serverVersion = const Value.absent(),
                Value<DateTime> clientUpdatedAt = const Value.absent(),
                Value<DateTime?> serverUpdatedAt = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalOrdersCompanion.insert(
                id: id,
                orderNumber: orderNumber,
                orderType: orderType,
                shiftId: shiftId,
                status: status,
                subtotal: subtotal,
                discountPercentage: discountPercentage,
                discountAmount: discountAmount,
                taxAmount: taxAmount,
                grandTotal: grandTotal,
                paymentStatus: paymentStatus,
                isPaid: isPaid,
                isHeld: isHeld,
                kitchenTicketSent: kitchenTicketSent,
                rejectionReason: rejectionReason,
                deviceId: deviceId,
                createdAt: createdAt,
                syncStatus: syncStatus,
                serverVersion: serverVersion,
                clientUpdatedAt: clientUpdatedAt,
                serverUpdatedAt: serverUpdatedAt,
                isDeleted: isDeleted,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalOrdersTable, LocalOrder>(table),
                  $$LocalOrdersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({localOrderItemsRefs = false, localOrderPaymentsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (localOrderItemsRefs) db.localOrderItems,
                    if (localOrderPaymentsRefs) db.localOrderPayments,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (localOrderItemsRefs)
                        await $_getPrefetchedData<
                          LocalOrder,
                          $LocalOrdersTable,
                          LocalOrderItem
                        >(
                          currentTable: table,
                          referencedTable: $$LocalOrdersTableReferences
                              ._localOrderItemsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$LocalOrdersTableReferences(
                                db,
                                table,
                                p0,
                              ).localOrderItemsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.orderId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (localOrderPaymentsRefs)
                        await $_getPrefetchedData<
                          LocalOrder,
                          $LocalOrdersTable,
                          LocalOrderPayment
                        >(
                          currentTable: table,
                          referencedTable: $$LocalOrdersTableReferences
                              ._localOrderPaymentsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$LocalOrdersTableReferences(
                                db,
                                table,
                                p0,
                              ).localOrderPaymentsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.orderId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$LocalOrdersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalOrdersTable,
      LocalOrder,
      $$LocalOrdersTableFilterComposer,
      $$LocalOrdersTableOrderingComposer,
      $$LocalOrdersTableAnnotationComposer,
      $$LocalOrdersTableCreateCompanionBuilder,
      $$LocalOrdersTableUpdateCompanionBuilder,
      (LocalOrder, $$LocalOrdersTableReferences),
      LocalOrder,
      PrefetchHooks Function({
        bool localOrderItemsRefs,
        bool localOrderPaymentsRefs,
      })
    >;
typedef $$LocalOrderItemsTableCreateCompanionBuilder =
    LocalOrderItemsCompanion Function({
      required String id,
      required String orderId,
      Value<String?> menuItemId,
      required String itemName,
      Value<String?> sizeName,
      required double unitPrice,
      required int quantity,
      required double subtotal,
      Value<String?> notes,
      Value<bool> isCancelled,
      Value<DateTime?> cancelledAt,
      Value<String?> cancelReason,
      Value<DateTime?> voidedAt,
      Value<String?> voidedBy,
      Value<String?> supersedesItemId,
      Value<String?> createdByDeviceId,
      Value<DateTime?> clientCreatedAt,
      Value<String> syncStatus,
      Value<int> serverVersion,
      Value<int> rowid,
    });
typedef $$LocalOrderItemsTableUpdateCompanionBuilder =
    LocalOrderItemsCompanion Function({
      Value<String> id,
      Value<String> orderId,
      Value<String?> menuItemId,
      Value<String> itemName,
      Value<String?> sizeName,
      Value<double> unitPrice,
      Value<int> quantity,
      Value<double> subtotal,
      Value<String?> notes,
      Value<bool> isCancelled,
      Value<DateTime?> cancelledAt,
      Value<String?> cancelReason,
      Value<DateTime?> voidedAt,
      Value<String?> voidedBy,
      Value<String?> supersedesItemId,
      Value<String?> createdByDeviceId,
      Value<DateTime?> clientCreatedAt,
      Value<String> syncStatus,
      Value<int> serverVersion,
      Value<int> rowid,
    });

final class $$LocalOrderItemsTableReferences
    extends
        BaseReferences<_$AppDatabase, $LocalOrderItemsTable, LocalOrderItem> {
  $$LocalOrderItemsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $LocalOrdersTable _orderIdTable(_$AppDatabase db) => db.localOrders
      .createAlias('local_order_items__order_id__local_orders__id');

  $$LocalOrdersTableProcessedTableManager get orderId {
    final $_column = $_itemColumn<String>('order_id')!;

    final manager = $$LocalOrdersTableTableManager(
      $_db,
      $_db.localOrders,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_orderIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$LocalOrderItemsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalOrderItemsTable> {
  $$LocalOrderItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get menuItemId => $composableBuilder(
    column: $table.menuItemId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get itemName => $composableBuilder(
    column: $table.itemName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sizeName => $composableBuilder(
    column: $table.sizeName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get unitPrice => $composableBuilder(
    column: $table.unitPrice,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get subtotal => $composableBuilder(
    column: $table.subtotal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isCancelled => $composableBuilder(
    column: $table.isCancelled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get cancelledAt => $composableBuilder(
    column: $table.cancelledAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cancelReason => $composableBuilder(
    column: $table.cancelReason,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get voidedAt => $composableBuilder(
    column: $table.voidedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get voidedBy => $composableBuilder(
    column: $table.voidedBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get supersedesItemId => $composableBuilder(
    column: $table.supersedesItemId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdByDeviceId => $composableBuilder(
    column: $table.createdByDeviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get clientCreatedAt => $composableBuilder(
    column: $table.clientCreatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get serverVersion => $composableBuilder(
    column: $table.serverVersion,
    builder: (column) => ColumnFilters(column),
  );

  $$LocalOrdersTableFilterComposer get orderId {
    final $$LocalOrdersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.orderId,
      referencedTable: $db.localOrders,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalOrdersTableFilterComposer(
            $db: $db,
            $table: $db.localOrders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LocalOrderItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalOrderItemsTable> {
  $$LocalOrderItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get menuItemId => $composableBuilder(
    column: $table.menuItemId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get itemName => $composableBuilder(
    column: $table.itemName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sizeName => $composableBuilder(
    column: $table.sizeName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get unitPrice => $composableBuilder(
    column: $table.unitPrice,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get subtotal => $composableBuilder(
    column: $table.subtotal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isCancelled => $composableBuilder(
    column: $table.isCancelled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get cancelledAt => $composableBuilder(
    column: $table.cancelledAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cancelReason => $composableBuilder(
    column: $table.cancelReason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get voidedAt => $composableBuilder(
    column: $table.voidedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get voidedBy => $composableBuilder(
    column: $table.voidedBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get supersedesItemId => $composableBuilder(
    column: $table.supersedesItemId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdByDeviceId => $composableBuilder(
    column: $table.createdByDeviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get clientCreatedAt => $composableBuilder(
    column: $table.clientCreatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get serverVersion => $composableBuilder(
    column: $table.serverVersion,
    builder: (column) => ColumnOrderings(column),
  );

  $$LocalOrdersTableOrderingComposer get orderId {
    final $$LocalOrdersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.orderId,
      referencedTable: $db.localOrders,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalOrdersTableOrderingComposer(
            $db: $db,
            $table: $db.localOrders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LocalOrderItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalOrderItemsTable> {
  $$LocalOrderItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get menuItemId => $composableBuilder(
    column: $table.menuItemId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get itemName =>
      $composableBuilder(column: $table.itemName, builder: (column) => column);

  GeneratedColumn<String> get sizeName =>
      $composableBuilder(column: $table.sizeName, builder: (column) => column);

  GeneratedColumn<double> get unitPrice =>
      $composableBuilder(column: $table.unitPrice, builder: (column) => column);

  GeneratedColumn<int> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => column);

  GeneratedColumn<double> get subtotal =>
      $composableBuilder(column: $table.subtotal, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<bool> get isCancelled => $composableBuilder(
    column: $table.isCancelled,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get cancelledAt => $composableBuilder(
    column: $table.cancelledAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get cancelReason => $composableBuilder(
    column: $table.cancelReason,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get voidedAt =>
      $composableBuilder(column: $table.voidedAt, builder: (column) => column);

  GeneratedColumn<String> get voidedBy =>
      $composableBuilder(column: $table.voidedBy, builder: (column) => column);

  GeneratedColumn<String> get supersedesItemId => $composableBuilder(
    column: $table.supersedesItemId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get createdByDeviceId => $composableBuilder(
    column: $table.createdByDeviceId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get clientCreatedAt => $composableBuilder(
    column: $table.clientCreatedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );

  GeneratedColumn<int> get serverVersion => $composableBuilder(
    column: $table.serverVersion,
    builder: (column) => column,
  );

  $$LocalOrdersTableAnnotationComposer get orderId {
    final $$LocalOrdersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.orderId,
      referencedTable: $db.localOrders,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalOrdersTableAnnotationComposer(
            $db: $db,
            $table: $db.localOrders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LocalOrderItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalOrderItemsTable,
          LocalOrderItem,
          $$LocalOrderItemsTableFilterComposer,
          $$LocalOrderItemsTableOrderingComposer,
          $$LocalOrderItemsTableAnnotationComposer,
          $$LocalOrderItemsTableCreateCompanionBuilder,
          $$LocalOrderItemsTableUpdateCompanionBuilder,
          (LocalOrderItem, $$LocalOrderItemsTableReferences),
          LocalOrderItem,
          PrefetchHooks Function({bool orderId})
        > {
  $$LocalOrderItemsTableTableManager(
    _$AppDatabase db,
    $LocalOrderItemsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalOrderItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalOrderItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalOrderItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> orderId = const Value.absent(),
                Value<String?> menuItemId = const Value.absent(),
                Value<String> itemName = const Value.absent(),
                Value<String?> sizeName = const Value.absent(),
                Value<double> unitPrice = const Value.absent(),
                Value<int> quantity = const Value.absent(),
                Value<double> subtotal = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<bool> isCancelled = const Value.absent(),
                Value<DateTime?> cancelledAt = const Value.absent(),
                Value<String?> cancelReason = const Value.absent(),
                Value<DateTime?> voidedAt = const Value.absent(),
                Value<String?> voidedBy = const Value.absent(),
                Value<String?> supersedesItemId = const Value.absent(),
                Value<String?> createdByDeviceId = const Value.absent(),
                Value<DateTime?> clientCreatedAt = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
                Value<int> serverVersion = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalOrderItemsCompanion(
                id: id,
                orderId: orderId,
                menuItemId: menuItemId,
                itemName: itemName,
                sizeName: sizeName,
                unitPrice: unitPrice,
                quantity: quantity,
                subtotal: subtotal,
                notes: notes,
                isCancelled: isCancelled,
                cancelledAt: cancelledAt,
                cancelReason: cancelReason,
                voidedAt: voidedAt,
                voidedBy: voidedBy,
                supersedesItemId: supersedesItemId,
                createdByDeviceId: createdByDeviceId,
                clientCreatedAt: clientCreatedAt,
                syncStatus: syncStatus,
                serverVersion: serverVersion,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String orderId,
                Value<String?> menuItemId = const Value.absent(),
                required String itemName,
                Value<String?> sizeName = const Value.absent(),
                required double unitPrice,
                required int quantity,
                required double subtotal,
                Value<String?> notes = const Value.absent(),
                Value<bool> isCancelled = const Value.absent(),
                Value<DateTime?> cancelledAt = const Value.absent(),
                Value<String?> cancelReason = const Value.absent(),
                Value<DateTime?> voidedAt = const Value.absent(),
                Value<String?> voidedBy = const Value.absent(),
                Value<String?> supersedesItemId = const Value.absent(),
                Value<String?> createdByDeviceId = const Value.absent(),
                Value<DateTime?> clientCreatedAt = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
                Value<int> serverVersion = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalOrderItemsCompanion.insert(
                id: id,
                orderId: orderId,
                menuItemId: menuItemId,
                itemName: itemName,
                sizeName: sizeName,
                unitPrice: unitPrice,
                quantity: quantity,
                subtotal: subtotal,
                notes: notes,
                isCancelled: isCancelled,
                cancelledAt: cancelledAt,
                cancelReason: cancelReason,
                voidedAt: voidedAt,
                voidedBy: voidedBy,
                supersedesItemId: supersedesItemId,
                createdByDeviceId: createdByDeviceId,
                clientCreatedAt: clientCreatedAt,
                syncStatus: syncStatus,
                serverVersion: serverVersion,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalOrderItemsTable, LocalOrderItem>(table),
                  $$LocalOrderItemsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({orderId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (orderId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.orderId,
                                referencedTable:
                                    $$LocalOrderItemsTableReferences
                                        ._orderIdTable(db),
                                referencedColumn:
                                    $$LocalOrderItemsTableReferences
                                        ._orderIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$LocalOrderItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalOrderItemsTable,
      LocalOrderItem,
      $$LocalOrderItemsTableFilterComposer,
      $$LocalOrderItemsTableOrderingComposer,
      $$LocalOrderItemsTableAnnotationComposer,
      $$LocalOrderItemsTableCreateCompanionBuilder,
      $$LocalOrderItemsTableUpdateCompanionBuilder,
      (LocalOrderItem, $$LocalOrderItemsTableReferences),
      LocalOrderItem,
      PrefetchHooks Function({bool orderId})
    >;
typedef $$LocalOrderPaymentsTableCreateCompanionBuilder =
    LocalOrderPaymentsCompanion Function({
      required String id,
      required String orderId,
      required String paymentMethod,
      required double amount,
      Value<double?> tenderedAmount,
      Value<double?> changeReturned,
      Value<String?> transactionReference,
      Value<String?> cardLastFour,
      Value<String?> bankName,
      Value<String> paymentStatus,
      Value<String?> receivedBy,
      Value<DateTime> createdAt,
      Value<String> syncStatus,
      Value<int> rowid,
    });
typedef $$LocalOrderPaymentsTableUpdateCompanionBuilder =
    LocalOrderPaymentsCompanion Function({
      Value<String> id,
      Value<String> orderId,
      Value<String> paymentMethod,
      Value<double> amount,
      Value<double?> tenderedAmount,
      Value<double?> changeReturned,
      Value<String?> transactionReference,
      Value<String?> cardLastFour,
      Value<String?> bankName,
      Value<String> paymentStatus,
      Value<String?> receivedBy,
      Value<DateTime> createdAt,
      Value<String> syncStatus,
      Value<int> rowid,
    });

final class $$LocalOrderPaymentsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $LocalOrderPaymentsTable,
          LocalOrderPayment
        > {
  $$LocalOrderPaymentsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $LocalOrdersTable _orderIdTable(_$AppDatabase db) => db.localOrders
      .createAlias('local_order_payments__order_id__local_orders__id');

  $$LocalOrdersTableProcessedTableManager get orderId {
    final $_column = $_itemColumn<String>('order_id')!;

    final manager = $$LocalOrdersTableTableManager(
      $_db,
      $_db.localOrders,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_orderIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$LocalOrderPaymentsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalOrderPaymentsTable> {
  $$LocalOrderPaymentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get paymentMethod => $composableBuilder(
    column: $table.paymentMethod,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get tenderedAmount => $composableBuilder(
    column: $table.tenderedAmount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get changeReturned => $composableBuilder(
    column: $table.changeReturned,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get transactionReference => $composableBuilder(
    column: $table.transactionReference,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cardLastFour => $composableBuilder(
    column: $table.cardLastFour,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bankName => $composableBuilder(
    column: $table.bankName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get paymentStatus => $composableBuilder(
    column: $table.paymentStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get receivedBy => $composableBuilder(
    column: $table.receivedBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );

  $$LocalOrdersTableFilterComposer get orderId {
    final $$LocalOrdersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.orderId,
      referencedTable: $db.localOrders,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalOrdersTableFilterComposer(
            $db: $db,
            $table: $db.localOrders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LocalOrderPaymentsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalOrderPaymentsTable> {
  $$LocalOrderPaymentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get paymentMethod => $composableBuilder(
    column: $table.paymentMethod,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get tenderedAmount => $composableBuilder(
    column: $table.tenderedAmount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get changeReturned => $composableBuilder(
    column: $table.changeReturned,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get transactionReference => $composableBuilder(
    column: $table.transactionReference,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cardLastFour => $composableBuilder(
    column: $table.cardLastFour,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bankName => $composableBuilder(
    column: $table.bankName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get paymentStatus => $composableBuilder(
    column: $table.paymentStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get receivedBy => $composableBuilder(
    column: $table.receivedBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );

  $$LocalOrdersTableOrderingComposer get orderId {
    final $$LocalOrdersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.orderId,
      referencedTable: $db.localOrders,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalOrdersTableOrderingComposer(
            $db: $db,
            $table: $db.localOrders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LocalOrderPaymentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalOrderPaymentsTable> {
  $$LocalOrderPaymentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get paymentMethod => $composableBuilder(
    column: $table.paymentMethod,
    builder: (column) => column,
  );

  GeneratedColumn<double> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<double> get tenderedAmount => $composableBuilder(
    column: $table.tenderedAmount,
    builder: (column) => column,
  );

  GeneratedColumn<double> get changeReturned => $composableBuilder(
    column: $table.changeReturned,
    builder: (column) => column,
  );

  GeneratedColumn<String> get transactionReference => $composableBuilder(
    column: $table.transactionReference,
    builder: (column) => column,
  );

  GeneratedColumn<String> get cardLastFour => $composableBuilder(
    column: $table.cardLastFour,
    builder: (column) => column,
  );

  GeneratedColumn<String> get bankName =>
      $composableBuilder(column: $table.bankName, builder: (column) => column);

  GeneratedColumn<String> get paymentStatus => $composableBuilder(
    column: $table.paymentStatus,
    builder: (column) => column,
  );

  GeneratedColumn<String> get receivedBy => $composableBuilder(
    column: $table.receivedBy,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );

  $$LocalOrdersTableAnnotationComposer get orderId {
    final $$LocalOrdersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.orderId,
      referencedTable: $db.localOrders,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalOrdersTableAnnotationComposer(
            $db: $db,
            $table: $db.localOrders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LocalOrderPaymentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalOrderPaymentsTable,
          LocalOrderPayment,
          $$LocalOrderPaymentsTableFilterComposer,
          $$LocalOrderPaymentsTableOrderingComposer,
          $$LocalOrderPaymentsTableAnnotationComposer,
          $$LocalOrderPaymentsTableCreateCompanionBuilder,
          $$LocalOrderPaymentsTableUpdateCompanionBuilder,
          (LocalOrderPayment, $$LocalOrderPaymentsTableReferences),
          LocalOrderPayment,
          PrefetchHooks Function({bool orderId})
        > {
  $$LocalOrderPaymentsTableTableManager(
    _$AppDatabase db,
    $LocalOrderPaymentsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalOrderPaymentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalOrderPaymentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalOrderPaymentsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> orderId = const Value.absent(),
                Value<String> paymentMethod = const Value.absent(),
                Value<double> amount = const Value.absent(),
                Value<double?> tenderedAmount = const Value.absent(),
                Value<double?> changeReturned = const Value.absent(),
                Value<String?> transactionReference = const Value.absent(),
                Value<String?> cardLastFour = const Value.absent(),
                Value<String?> bankName = const Value.absent(),
                Value<String> paymentStatus = const Value.absent(),
                Value<String?> receivedBy = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalOrderPaymentsCompanion(
                id: id,
                orderId: orderId,
                paymentMethod: paymentMethod,
                amount: amount,
                tenderedAmount: tenderedAmount,
                changeReturned: changeReturned,
                transactionReference: transactionReference,
                cardLastFour: cardLastFour,
                bankName: bankName,
                paymentStatus: paymentStatus,
                receivedBy: receivedBy,
                createdAt: createdAt,
                syncStatus: syncStatus,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String orderId,
                required String paymentMethod,
                required double amount,
                Value<double?> tenderedAmount = const Value.absent(),
                Value<double?> changeReturned = const Value.absent(),
                Value<String?> transactionReference = const Value.absent(),
                Value<String?> cardLastFour = const Value.absent(),
                Value<String?> bankName = const Value.absent(),
                Value<String> paymentStatus = const Value.absent(),
                Value<String?> receivedBy = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalOrderPaymentsCompanion.insert(
                id: id,
                orderId: orderId,
                paymentMethod: paymentMethod,
                amount: amount,
                tenderedAmount: tenderedAmount,
                changeReturned: changeReturned,
                transactionReference: transactionReference,
                cardLastFour: cardLastFour,
                bankName: bankName,
                paymentStatus: paymentStatus,
                receivedBy: receivedBy,
                createdAt: createdAt,
                syncStatus: syncStatus,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalOrderPaymentsTable, LocalOrderPayment>(
                    table,
                  ),
                  $$LocalOrderPaymentsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({orderId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (orderId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.orderId,
                                referencedTable:
                                    $$LocalOrderPaymentsTableReferences
                                        ._orderIdTable(db),
                                referencedColumn:
                                    $$LocalOrderPaymentsTableReferences
                                        ._orderIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$LocalOrderPaymentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalOrderPaymentsTable,
      LocalOrderPayment,
      $$LocalOrderPaymentsTableFilterComposer,
      $$LocalOrderPaymentsTableOrderingComposer,
      $$LocalOrderPaymentsTableAnnotationComposer,
      $$LocalOrderPaymentsTableCreateCompanionBuilder,
      $$LocalOrderPaymentsTableUpdateCompanionBuilder,
      (LocalOrderPayment, $$LocalOrderPaymentsTableReferences),
      LocalOrderPayment,
      PrefetchHooks Function({bool orderId})
    >;
typedef $$SyncOutboxTableCreateCompanionBuilder =
    SyncOutboxCompanion Function({
      Value<int> id,
      required String operationId,
      required String deviceId,
      required String entityType,
      required String entityId,
      required String operationType,
      Value<int> baseVersion,
      required String payload,
      Value<String?> dependsOnOperationId,
      Value<int> dependencyOrder,
      Value<String> status,
      Value<int> retryCount,
      Value<DateTime?> nextRetryAt,
      Value<DateTime> createdAt,
      Value<DateTime?> sentAt,
      Value<DateTime?> ackedAt,
      Value<String?> lastError,
      Value<String?> conflictDetails,
      Value<int> schemaVersion,
    });
typedef $$SyncOutboxTableUpdateCompanionBuilder =
    SyncOutboxCompanion Function({
      Value<int> id,
      Value<String> operationId,
      Value<String> deviceId,
      Value<String> entityType,
      Value<String> entityId,
      Value<String> operationType,
      Value<int> baseVersion,
      Value<String> payload,
      Value<String?> dependsOnOperationId,
      Value<int> dependencyOrder,
      Value<String> status,
      Value<int> retryCount,
      Value<DateTime?> nextRetryAt,
      Value<DateTime> createdAt,
      Value<DateTime?> sentAt,
      Value<DateTime?> ackedAt,
      Value<String?> lastError,
      Value<String?> conflictDetails,
      Value<int> schemaVersion,
    });

class $$SyncOutboxTableFilterComposer
    extends Composer<_$AppDatabase, $SyncOutboxTable> {
  $$SyncOutboxTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get operationId => $composableBuilder(
    column: $table.operationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get operationType => $composableBuilder(
    column: $table.operationType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get baseVersion => $composableBuilder(
    column: $table.baseVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dependsOnOperationId => $composableBuilder(
    column: $table.dependsOnOperationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dependencyOrder => $composableBuilder(
    column: $table.dependencyOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get nextRetryAt => $composableBuilder(
    column: $table.nextRetryAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get sentAt => $composableBuilder(
    column: $table.sentAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get ackedAt => $composableBuilder(
    column: $table.ackedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get conflictDetails => $composableBuilder(
    column: $table.conflictDetails,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get schemaVersion => $composableBuilder(
    column: $table.schemaVersion,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncOutboxTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncOutboxTable> {
  $$SyncOutboxTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get operationId => $composableBuilder(
    column: $table.operationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get operationType => $composableBuilder(
    column: $table.operationType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get baseVersion => $composableBuilder(
    column: $table.baseVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dependsOnOperationId => $composableBuilder(
    column: $table.dependsOnOperationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dependencyOrder => $composableBuilder(
    column: $table.dependencyOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get nextRetryAt => $composableBuilder(
    column: $table.nextRetryAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get sentAt => $composableBuilder(
    column: $table.sentAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get ackedAt => $composableBuilder(
    column: $table.ackedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get conflictDetails => $composableBuilder(
    column: $table.conflictDetails,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get schemaVersion => $composableBuilder(
    column: $table.schemaVersion,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncOutboxTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncOutboxTable> {
  $$SyncOutboxTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get operationId => $composableBuilder(
    column: $table.operationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get operationType => $composableBuilder(
    column: $table.operationType,
    builder: (column) => column,
  );

  GeneratedColumn<int> get baseVersion => $composableBuilder(
    column: $table.baseVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<String> get dependsOnOperationId => $composableBuilder(
    column: $table.dependsOnOperationId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get dependencyOrder => $composableBuilder(
    column: $table.dependencyOrder,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get nextRetryAt => $composableBuilder(
    column: $table.nextRetryAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get sentAt =>
      $composableBuilder(column: $table.sentAt, builder: (column) => column);

  GeneratedColumn<DateTime> get ackedAt =>
      $composableBuilder(column: $table.ackedAt, builder: (column) => column);

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<String> get conflictDetails => $composableBuilder(
    column: $table.conflictDetails,
    builder: (column) => column,
  );

  GeneratedColumn<int> get schemaVersion => $composableBuilder(
    column: $table.schemaVersion,
    builder: (column) => column,
  );
}

class $$SyncOutboxTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncOutboxTable,
          SyncOutboxEntry,
          $$SyncOutboxTableFilterComposer,
          $$SyncOutboxTableOrderingComposer,
          $$SyncOutboxTableAnnotationComposer,
          $$SyncOutboxTableCreateCompanionBuilder,
          $$SyncOutboxTableUpdateCompanionBuilder,
          (
            SyncOutboxEntry,
            BaseReferences<_$AppDatabase, $SyncOutboxTable, SyncOutboxEntry>,
          ),
          SyncOutboxEntry,
          PrefetchHooks Function()
        > {
  $$SyncOutboxTableTableManager(_$AppDatabase db, $SyncOutboxTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncOutboxTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncOutboxTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncOutboxTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> operationId = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<String> entityType = const Value.absent(),
                Value<String> entityId = const Value.absent(),
                Value<String> operationType = const Value.absent(),
                Value<int> baseVersion = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<String?> dependsOnOperationId = const Value.absent(),
                Value<int> dependencyOrder = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
                Value<DateTime?> nextRetryAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> sentAt = const Value.absent(),
                Value<DateTime?> ackedAt = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<String?> conflictDetails = const Value.absent(),
                Value<int> schemaVersion = const Value.absent(),
              }) => SyncOutboxCompanion(
                id: id,
                operationId: operationId,
                deviceId: deviceId,
                entityType: entityType,
                entityId: entityId,
                operationType: operationType,
                baseVersion: baseVersion,
                payload: payload,
                dependsOnOperationId: dependsOnOperationId,
                dependencyOrder: dependencyOrder,
                status: status,
                retryCount: retryCount,
                nextRetryAt: nextRetryAt,
                createdAt: createdAt,
                sentAt: sentAt,
                ackedAt: ackedAt,
                lastError: lastError,
                conflictDetails: conflictDetails,
                schemaVersion: schemaVersion,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String operationId,
                required String deviceId,
                required String entityType,
                required String entityId,
                required String operationType,
                Value<int> baseVersion = const Value.absent(),
                required String payload,
                Value<String?> dependsOnOperationId = const Value.absent(),
                Value<int> dependencyOrder = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
                Value<DateTime?> nextRetryAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> sentAt = const Value.absent(),
                Value<DateTime?> ackedAt = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<String?> conflictDetails = const Value.absent(),
                Value<int> schemaVersion = const Value.absent(),
              }) => SyncOutboxCompanion.insert(
                id: id,
                operationId: operationId,
                deviceId: deviceId,
                entityType: entityType,
                entityId: entityId,
                operationType: operationType,
                baseVersion: baseVersion,
                payload: payload,
                dependsOnOperationId: dependsOnOperationId,
                dependencyOrder: dependencyOrder,
                status: status,
                retryCount: retryCount,
                nextRetryAt: nextRetryAt,
                createdAt: createdAt,
                sentAt: sentAt,
                ackedAt: ackedAt,
                lastError: lastError,
                conflictDetails: conflictDetails,
                schemaVersion: schemaVersion,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SyncOutboxTable, SyncOutboxEntry>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $SyncOutboxTable,
                    SyncOutboxEntry
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncOutboxTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncOutboxTable,
      SyncOutboxEntry,
      $$SyncOutboxTableFilterComposer,
      $$SyncOutboxTableOrderingComposer,
      $$SyncOutboxTableAnnotationComposer,
      $$SyncOutboxTableCreateCompanionBuilder,
      $$SyncOutboxTableUpdateCompanionBuilder,
      (
        SyncOutboxEntry,
        BaseReferences<_$AppDatabase, $SyncOutboxTable, SyncOutboxEntry>,
      ),
      SyncOutboxEntry,
      PrefetchHooks Function()
    >;
typedef $$TerminalSequencesTableCreateCompanionBuilder =
    TerminalSequencesCompanion Function({
      required String sequenceKey,
      required String businessDate,
      required int currentValue,
      Value<int> rowid,
    });
typedef $$TerminalSequencesTableUpdateCompanionBuilder =
    TerminalSequencesCompanion Function({
      Value<String> sequenceKey,
      Value<String> businessDate,
      Value<int> currentValue,
      Value<int> rowid,
    });

class $$TerminalSequencesTableFilterComposer
    extends Composer<_$AppDatabase, $TerminalSequencesTable> {
  $$TerminalSequencesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get sequenceKey => $composableBuilder(
    column: $table.sequenceKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get businessDate => $composableBuilder(
    column: $table.businessDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get currentValue => $composableBuilder(
    column: $table.currentValue,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TerminalSequencesTableOrderingComposer
    extends Composer<_$AppDatabase, $TerminalSequencesTable> {
  $$TerminalSequencesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get sequenceKey => $composableBuilder(
    column: $table.sequenceKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get businessDate => $composableBuilder(
    column: $table.businessDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get currentValue => $composableBuilder(
    column: $table.currentValue,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TerminalSequencesTableAnnotationComposer
    extends Composer<_$AppDatabase, $TerminalSequencesTable> {
  $$TerminalSequencesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get sequenceKey => $composableBuilder(
    column: $table.sequenceKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get businessDate => $composableBuilder(
    column: $table.businessDate,
    builder: (column) => column,
  );

  GeneratedColumn<int> get currentValue => $composableBuilder(
    column: $table.currentValue,
    builder: (column) => column,
  );
}

class $$TerminalSequencesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TerminalSequencesTable,
          TerminalSequence,
          $$TerminalSequencesTableFilterComposer,
          $$TerminalSequencesTableOrderingComposer,
          $$TerminalSequencesTableAnnotationComposer,
          $$TerminalSequencesTableCreateCompanionBuilder,
          $$TerminalSequencesTableUpdateCompanionBuilder,
          (
            TerminalSequence,
            BaseReferences<
              _$AppDatabase,
              $TerminalSequencesTable,
              TerminalSequence
            >,
          ),
          TerminalSequence,
          PrefetchHooks Function()
        > {
  $$TerminalSequencesTableTableManager(
    _$AppDatabase db,
    $TerminalSequencesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TerminalSequencesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TerminalSequencesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TerminalSequencesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> sequenceKey = const Value.absent(),
                Value<String> businessDate = const Value.absent(),
                Value<int> currentValue = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TerminalSequencesCompanion(
                sequenceKey: sequenceKey,
                businessDate: businessDate,
                currentValue: currentValue,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String sequenceKey,
                required String businessDate,
                required int currentValue,
                Value<int> rowid = const Value.absent(),
              }) => TerminalSequencesCompanion.insert(
                sequenceKey: sequenceKey,
                businessDate: businessDate,
                currentValue: currentValue,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TerminalSequencesTable, TerminalSequence>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $TerminalSequencesTable,
                    TerminalSequence
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TerminalSequencesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TerminalSequencesTable,
      TerminalSequence,
      $$TerminalSequencesTableFilterComposer,
      $$TerminalSequencesTableOrderingComposer,
      $$TerminalSequencesTableAnnotationComposer,
      $$TerminalSequencesTableCreateCompanionBuilder,
      $$TerminalSequencesTableUpdateCompanionBuilder,
      (
        TerminalSequence,
        BaseReferences<
          _$AppDatabase,
          $TerminalSequencesTable,
          TerminalSequence
        >,
      ),
      TerminalSequence,
      PrefetchHooks Function()
    >;
typedef $$OfflinePrintJobsTableCreateCompanionBuilder =
    OfflinePrintJobsCompanion Function({
      Value<int> id,
      required String jobType,
      Value<String?> orderId,
      required String printerTarget,
      required Uint8List rawEscPosData,
      Value<String> status,
      Value<int> retryCount,
      Value<DateTime> createdAt,
    });
typedef $$OfflinePrintJobsTableUpdateCompanionBuilder =
    OfflinePrintJobsCompanion Function({
      Value<int> id,
      Value<String> jobType,
      Value<String?> orderId,
      Value<String> printerTarget,
      Value<Uint8List> rawEscPosData,
      Value<String> status,
      Value<int> retryCount,
      Value<DateTime> createdAt,
    });

class $$OfflinePrintJobsTableFilterComposer
    extends Composer<_$AppDatabase, $OfflinePrintJobsTable> {
  $$OfflinePrintJobsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get jobType => $composableBuilder(
    column: $table.jobType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get orderId => $composableBuilder(
    column: $table.orderId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get printerTarget => $composableBuilder(
    column: $table.printerTarget,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get rawEscPosData => $composableBuilder(
    column: $table.rawEscPosData,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OfflinePrintJobsTableOrderingComposer
    extends Composer<_$AppDatabase, $OfflinePrintJobsTable> {
  $$OfflinePrintJobsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get jobType => $composableBuilder(
    column: $table.jobType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get orderId => $composableBuilder(
    column: $table.orderId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get printerTarget => $composableBuilder(
    column: $table.printerTarget,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get rawEscPosData => $composableBuilder(
    column: $table.rawEscPosData,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OfflinePrintJobsTableAnnotationComposer
    extends Composer<_$AppDatabase, $OfflinePrintJobsTable> {
  $$OfflinePrintJobsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get jobType =>
      $composableBuilder(column: $table.jobType, builder: (column) => column);

  GeneratedColumn<String> get orderId =>
      $composableBuilder(column: $table.orderId, builder: (column) => column);

  GeneratedColumn<String> get printerTarget => $composableBuilder(
    column: $table.printerTarget,
    builder: (column) => column,
  );

  GeneratedColumn<Uint8List> get rawEscPosData => $composableBuilder(
    column: $table.rawEscPosData,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$OfflinePrintJobsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OfflinePrintJobsTable,
          OfflinePrintJob,
          $$OfflinePrintJobsTableFilterComposer,
          $$OfflinePrintJobsTableOrderingComposer,
          $$OfflinePrintJobsTableAnnotationComposer,
          $$OfflinePrintJobsTableCreateCompanionBuilder,
          $$OfflinePrintJobsTableUpdateCompanionBuilder,
          (
            OfflinePrintJob,
            BaseReferences<
              _$AppDatabase,
              $OfflinePrintJobsTable,
              OfflinePrintJob
            >,
          ),
          OfflinePrintJob,
          PrefetchHooks Function()
        > {
  $$OfflinePrintJobsTableTableManager(
    _$AppDatabase db,
    $OfflinePrintJobsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OfflinePrintJobsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OfflinePrintJobsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OfflinePrintJobsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> jobType = const Value.absent(),
                Value<String?> orderId = const Value.absent(),
                Value<String> printerTarget = const Value.absent(),
                Value<Uint8List> rawEscPosData = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => OfflinePrintJobsCompanion(
                id: id,
                jobType: jobType,
                orderId: orderId,
                printerTarget: printerTarget,
                rawEscPosData: rawEscPosData,
                status: status,
                retryCount: retryCount,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String jobType,
                Value<String?> orderId = const Value.absent(),
                required String printerTarget,
                required Uint8List rawEscPosData,
                Value<String> status = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => OfflinePrintJobsCompanion.insert(
                id: id,
                jobType: jobType,
                orderId: orderId,
                printerTarget: printerTarget,
                rawEscPosData: rawEscPosData,
                status: status,
                retryCount: retryCount,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$OfflinePrintJobsTable, OfflinePrintJob>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $OfflinePrintJobsTable,
                    OfflinePrintJob
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OfflinePrintJobsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OfflinePrintJobsTable,
      OfflinePrintJob,
      $$OfflinePrintJobsTableFilterComposer,
      $$OfflinePrintJobsTableOrderingComposer,
      $$OfflinePrintJobsTableAnnotationComposer,
      $$OfflinePrintJobsTableCreateCompanionBuilder,
      $$OfflinePrintJobsTableUpdateCompanionBuilder,
      (
        OfflinePrintJob,
        BaseReferences<_$AppDatabase, $OfflinePrintJobsTable, OfflinePrintJob>,
      ),
      OfflinePrintJob,
      PrefetchHooks Function()
    >;
typedef $$SyncCursorsTableCreateCompanionBuilder =
    SyncCursorsCompanion Function({
      required String feedKey,
      Value<int> lastPulledSequence,
      Value<DateTime?> lastSyncAttempt,
      Value<DateTime?> lastSuccessfulSync,
      Value<int> rowid,
    });
typedef $$SyncCursorsTableUpdateCompanionBuilder =
    SyncCursorsCompanion Function({
      Value<String> feedKey,
      Value<int> lastPulledSequence,
      Value<DateTime?> lastSyncAttempt,
      Value<DateTime?> lastSuccessfulSync,
      Value<int> rowid,
    });

class $$SyncCursorsTableFilterComposer
    extends Composer<_$AppDatabase, $SyncCursorsTable> {
  $$SyncCursorsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get feedKey => $composableBuilder(
    column: $table.feedKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastPulledSequence => $composableBuilder(
    column: $table.lastPulledSequence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSyncAttempt => $composableBuilder(
    column: $table.lastSyncAttempt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSuccessfulSync => $composableBuilder(
    column: $table.lastSuccessfulSync,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncCursorsTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncCursorsTable> {
  $$SyncCursorsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get feedKey => $composableBuilder(
    column: $table.feedKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastPulledSequence => $composableBuilder(
    column: $table.lastPulledSequence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSyncAttempt => $composableBuilder(
    column: $table.lastSyncAttempt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSuccessfulSync => $composableBuilder(
    column: $table.lastSuccessfulSync,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncCursorsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncCursorsTable> {
  $$SyncCursorsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get feedKey =>
      $composableBuilder(column: $table.feedKey, builder: (column) => column);

  GeneratedColumn<int> get lastPulledSequence => $composableBuilder(
    column: $table.lastPulledSequence,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastSyncAttempt => $composableBuilder(
    column: $table.lastSyncAttempt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastSuccessfulSync => $composableBuilder(
    column: $table.lastSuccessfulSync,
    builder: (column) => column,
  );
}

class $$SyncCursorsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncCursorsTable,
          SyncCursor,
          $$SyncCursorsTableFilterComposer,
          $$SyncCursorsTableOrderingComposer,
          $$SyncCursorsTableAnnotationComposer,
          $$SyncCursorsTableCreateCompanionBuilder,
          $$SyncCursorsTableUpdateCompanionBuilder,
          (
            SyncCursor,
            BaseReferences<_$AppDatabase, $SyncCursorsTable, SyncCursor>,
          ),
          SyncCursor,
          PrefetchHooks Function()
        > {
  $$SyncCursorsTableTableManager(_$AppDatabase db, $SyncCursorsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncCursorsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncCursorsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncCursorsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> feedKey = const Value.absent(),
                Value<int> lastPulledSequence = const Value.absent(),
                Value<DateTime?> lastSyncAttempt = const Value.absent(),
                Value<DateTime?> lastSuccessfulSync = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncCursorsCompanion(
                feedKey: feedKey,
                lastPulledSequence: lastPulledSequence,
                lastSyncAttempt: lastSyncAttempt,
                lastSuccessfulSync: lastSuccessfulSync,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String feedKey,
                Value<int> lastPulledSequence = const Value.absent(),
                Value<DateTime?> lastSyncAttempt = const Value.absent(),
                Value<DateTime?> lastSuccessfulSync = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncCursorsCompanion.insert(
                feedKey: feedKey,
                lastPulledSequence: lastPulledSequence,
                lastSyncAttempt: lastSyncAttempt,
                lastSuccessfulSync: lastSuccessfulSync,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SyncCursorsTable, SyncCursor>(table),
                  BaseReferences<_$AppDatabase, $SyncCursorsTable, SyncCursor>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncCursorsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncCursorsTable,
      SyncCursor,
      $$SyncCursorsTableFilterComposer,
      $$SyncCursorsTableOrderingComposer,
      $$SyncCursorsTableAnnotationComposer,
      $$SyncCursorsTableCreateCompanionBuilder,
      $$SyncCursorsTableUpdateCompanionBuilder,
      (
        SyncCursor,
        BaseReferences<_$AppDatabase, $SyncCursorsTable, SyncCursor>,
      ),
      SyncCursor,
      PrefetchHooks Function()
    >;
typedef $$SyncConflictsTableCreateCompanionBuilder =
    SyncConflictsCompanion Function({
      required String id,
      required String operationId,
      required String entityType,
      required String entityId,
      required String conflictType,
      Value<String> resolutionStatus,
      Value<String?> errorMessage,
      required String payload,
      Value<String?> serverState,
      Value<DateTime> createdAt,
      Value<DateTime?> resolvedAt,
      Value<int> rowid,
    });
typedef $$SyncConflictsTableUpdateCompanionBuilder =
    SyncConflictsCompanion Function({
      Value<String> id,
      Value<String> operationId,
      Value<String> entityType,
      Value<String> entityId,
      Value<String> conflictType,
      Value<String> resolutionStatus,
      Value<String?> errorMessage,
      Value<String> payload,
      Value<String?> serverState,
      Value<DateTime> createdAt,
      Value<DateTime?> resolvedAt,
      Value<int> rowid,
    });

class $$SyncConflictsTableFilterComposer
    extends Composer<_$AppDatabase, $SyncConflictsTable> {
  $$SyncConflictsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get operationId => $composableBuilder(
    column: $table.operationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get conflictType => $composableBuilder(
    column: $table.conflictType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get resolutionStatus => $composableBuilder(
    column: $table.resolutionStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get serverState => $composableBuilder(
    column: $table.serverState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get resolvedAt => $composableBuilder(
    column: $table.resolvedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncConflictsTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncConflictsTable> {
  $$SyncConflictsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get operationId => $composableBuilder(
    column: $table.operationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get conflictType => $composableBuilder(
    column: $table.conflictType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get resolutionStatus => $composableBuilder(
    column: $table.resolutionStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get serverState => $composableBuilder(
    column: $table.serverState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get resolvedAt => $composableBuilder(
    column: $table.resolvedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncConflictsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncConflictsTable> {
  $$SyncConflictsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get operationId => $composableBuilder(
    column: $table.operationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get conflictType => $composableBuilder(
    column: $table.conflictType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get resolutionStatus => $composableBuilder(
    column: $table.resolutionStatus,
    builder: (column) => column,
  );

  GeneratedColumn<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<String> get serverState => $composableBuilder(
    column: $table.serverState,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get resolvedAt => $composableBuilder(
    column: $table.resolvedAt,
    builder: (column) => column,
  );
}

class $$SyncConflictsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncConflictsTable,
          SyncConflict,
          $$SyncConflictsTableFilterComposer,
          $$SyncConflictsTableOrderingComposer,
          $$SyncConflictsTableAnnotationComposer,
          $$SyncConflictsTableCreateCompanionBuilder,
          $$SyncConflictsTableUpdateCompanionBuilder,
          (
            SyncConflict,
            BaseReferences<_$AppDatabase, $SyncConflictsTable, SyncConflict>,
          ),
          SyncConflict,
          PrefetchHooks Function()
        > {
  $$SyncConflictsTableTableManager(_$AppDatabase db, $SyncConflictsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncConflictsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncConflictsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncConflictsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> operationId = const Value.absent(),
                Value<String> entityType = const Value.absent(),
                Value<String> entityId = const Value.absent(),
                Value<String> conflictType = const Value.absent(),
                Value<String> resolutionStatus = const Value.absent(),
                Value<String?> errorMessage = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<String?> serverState = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> resolvedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncConflictsCompanion(
                id: id,
                operationId: operationId,
                entityType: entityType,
                entityId: entityId,
                conflictType: conflictType,
                resolutionStatus: resolutionStatus,
                errorMessage: errorMessage,
                payload: payload,
                serverState: serverState,
                createdAt: createdAt,
                resolvedAt: resolvedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String operationId,
                required String entityType,
                required String entityId,
                required String conflictType,
                Value<String> resolutionStatus = const Value.absent(),
                Value<String?> errorMessage = const Value.absent(),
                required String payload,
                Value<String?> serverState = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> resolvedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncConflictsCompanion.insert(
                id: id,
                operationId: operationId,
                entityType: entityType,
                entityId: entityId,
                conflictType: conflictType,
                resolutionStatus: resolutionStatus,
                errorMessage: errorMessage,
                payload: payload,
                serverState: serverState,
                createdAt: createdAt,
                resolvedAt: resolvedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SyncConflictsTable, SyncConflict>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $SyncConflictsTable,
                    SyncConflict
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncConflictsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncConflictsTable,
      SyncConflict,
      $$SyncConflictsTableFilterComposer,
      $$SyncConflictsTableOrderingComposer,
      $$SyncConflictsTableAnnotationComposer,
      $$SyncConflictsTableCreateCompanionBuilder,
      $$SyncConflictsTableUpdateCompanionBuilder,
      (
        SyncConflict,
        BaseReferences<_$AppDatabase, $SyncConflictsTable, SyncConflict>,
      ),
      SyncConflict,
      PrefetchHooks Function()
    >;
typedef $$LocalDailyCalculationsTableCreateCompanionBuilder =
    LocalDailyCalculationsCompanion Function({
      required String id,
      required String cashierId,
      required String cashierName,
      required double startingCash,
      Value<double> expectedCashDrawer,
      Value<double?> actualCashCounted,
      Value<double> cashVariance,
      Value<String> status,
      Value<DateTime> createdAt,
      Value<DateTime?> submittedAt,
      Value<String?> closingNotes,
      Value<String> syncStatus,
      Value<int> serverVersion,
      Value<int> rowid,
    });
typedef $$LocalDailyCalculationsTableUpdateCompanionBuilder =
    LocalDailyCalculationsCompanion Function({
      Value<String> id,
      Value<String> cashierId,
      Value<String> cashierName,
      Value<double> startingCash,
      Value<double> expectedCashDrawer,
      Value<double?> actualCashCounted,
      Value<double> cashVariance,
      Value<String> status,
      Value<DateTime> createdAt,
      Value<DateTime?> submittedAt,
      Value<String?> closingNotes,
      Value<String> syncStatus,
      Value<int> serverVersion,
      Value<int> rowid,
    });

class $$LocalDailyCalculationsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalDailyCalculationsTable> {
  $$LocalDailyCalculationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cashierId => $composableBuilder(
    column: $table.cashierId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cashierName => $composableBuilder(
    column: $table.cashierName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get startingCash => $composableBuilder(
    column: $table.startingCash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get expectedCashDrawer => $composableBuilder(
    column: $table.expectedCashDrawer,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get actualCashCounted => $composableBuilder(
    column: $table.actualCashCounted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get cashVariance => $composableBuilder(
    column: $table.cashVariance,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get submittedAt => $composableBuilder(
    column: $table.submittedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get closingNotes => $composableBuilder(
    column: $table.closingNotes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get serverVersion => $composableBuilder(
    column: $table.serverVersion,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalDailyCalculationsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalDailyCalculationsTable> {
  $$LocalDailyCalculationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cashierId => $composableBuilder(
    column: $table.cashierId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cashierName => $composableBuilder(
    column: $table.cashierName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get startingCash => $composableBuilder(
    column: $table.startingCash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get expectedCashDrawer => $composableBuilder(
    column: $table.expectedCashDrawer,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get actualCashCounted => $composableBuilder(
    column: $table.actualCashCounted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get cashVariance => $composableBuilder(
    column: $table.cashVariance,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get submittedAt => $composableBuilder(
    column: $table.submittedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get closingNotes => $composableBuilder(
    column: $table.closingNotes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get serverVersion => $composableBuilder(
    column: $table.serverVersion,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalDailyCalculationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalDailyCalculationsTable> {
  $$LocalDailyCalculationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get cashierId =>
      $composableBuilder(column: $table.cashierId, builder: (column) => column);

  GeneratedColumn<String> get cashierName => $composableBuilder(
    column: $table.cashierName,
    builder: (column) => column,
  );

  GeneratedColumn<double> get startingCash => $composableBuilder(
    column: $table.startingCash,
    builder: (column) => column,
  );

  GeneratedColumn<double> get expectedCashDrawer => $composableBuilder(
    column: $table.expectedCashDrawer,
    builder: (column) => column,
  );

  GeneratedColumn<double> get actualCashCounted => $composableBuilder(
    column: $table.actualCashCounted,
    builder: (column) => column,
  );

  GeneratedColumn<double> get cashVariance => $composableBuilder(
    column: $table.cashVariance,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get submittedAt => $composableBuilder(
    column: $table.submittedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get closingNotes => $composableBuilder(
    column: $table.closingNotes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );

  GeneratedColumn<int> get serverVersion => $composableBuilder(
    column: $table.serverVersion,
    builder: (column) => column,
  );
}

class $$LocalDailyCalculationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalDailyCalculationsTable,
          LocalDailyCalculation,
          $$LocalDailyCalculationsTableFilterComposer,
          $$LocalDailyCalculationsTableOrderingComposer,
          $$LocalDailyCalculationsTableAnnotationComposer,
          $$LocalDailyCalculationsTableCreateCompanionBuilder,
          $$LocalDailyCalculationsTableUpdateCompanionBuilder,
          (
            LocalDailyCalculation,
            BaseReferences<
              _$AppDatabase,
              $LocalDailyCalculationsTable,
              LocalDailyCalculation
            >,
          ),
          LocalDailyCalculation,
          PrefetchHooks Function()
        > {
  $$LocalDailyCalculationsTableTableManager(
    _$AppDatabase db,
    $LocalDailyCalculationsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalDailyCalculationsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$LocalDailyCalculationsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$LocalDailyCalculationsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> cashierId = const Value.absent(),
                Value<String> cashierName = const Value.absent(),
                Value<double> startingCash = const Value.absent(),
                Value<double> expectedCashDrawer = const Value.absent(),
                Value<double?> actualCashCounted = const Value.absent(),
                Value<double> cashVariance = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> submittedAt = const Value.absent(),
                Value<String?> closingNotes = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
                Value<int> serverVersion = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalDailyCalculationsCompanion(
                id: id,
                cashierId: cashierId,
                cashierName: cashierName,
                startingCash: startingCash,
                expectedCashDrawer: expectedCashDrawer,
                actualCashCounted: actualCashCounted,
                cashVariance: cashVariance,
                status: status,
                createdAt: createdAt,
                submittedAt: submittedAt,
                closingNotes: closingNotes,
                syncStatus: syncStatus,
                serverVersion: serverVersion,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String cashierId,
                required String cashierName,
                required double startingCash,
                Value<double> expectedCashDrawer = const Value.absent(),
                Value<double?> actualCashCounted = const Value.absent(),
                Value<double> cashVariance = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> submittedAt = const Value.absent(),
                Value<String?> closingNotes = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
                Value<int> serverVersion = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalDailyCalculationsCompanion.insert(
                id: id,
                cashierId: cashierId,
                cashierName: cashierName,
                startingCash: startingCash,
                expectedCashDrawer: expectedCashDrawer,
                actualCashCounted: actualCashCounted,
                cashVariance: cashVariance,
                status: status,
                createdAt: createdAt,
                submittedAt: submittedAt,
                closingNotes: closingNotes,
                syncStatus: syncStatus,
                serverVersion: serverVersion,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $LocalDailyCalculationsTable,
                    LocalDailyCalculation
                  >(table),
                  BaseReferences<
                    _$AppDatabase,
                    $LocalDailyCalculationsTable,
                    LocalDailyCalculation
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalDailyCalculationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalDailyCalculationsTable,
      LocalDailyCalculation,
      $$LocalDailyCalculationsTableFilterComposer,
      $$LocalDailyCalculationsTableOrderingComposer,
      $$LocalDailyCalculationsTableAnnotationComposer,
      $$LocalDailyCalculationsTableCreateCompanionBuilder,
      $$LocalDailyCalculationsTableUpdateCompanionBuilder,
      (
        LocalDailyCalculation,
        BaseReferences<
          _$AppDatabase,
          $LocalDailyCalculationsTable,
          LocalDailyCalculation
        >,
      ),
      LocalDailyCalculation,
      PrefetchHooks Function()
    >;
typedef $$LocalMenuCategoriesTableCreateCompanionBuilder =
    LocalMenuCategoriesCompanion Function({
      required String id,
      required String name,
      Value<int> displayOrder,
      Value<bool> isActive,
      Value<int> rowid,
    });
typedef $$LocalMenuCategoriesTableUpdateCompanionBuilder =
    LocalMenuCategoriesCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<int> displayOrder,
      Value<bool> isActive,
      Value<int> rowid,
    });

class $$LocalMenuCategoriesTableFilterComposer
    extends Composer<_$AppDatabase, $LocalMenuCategoriesTable> {
  $$LocalMenuCategoriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get displayOrder => $composableBuilder(
    column: $table.displayOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalMenuCategoriesTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalMenuCategoriesTable> {
  $$LocalMenuCategoriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get displayOrder => $composableBuilder(
    column: $table.displayOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalMenuCategoriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalMenuCategoriesTable> {
  $$LocalMenuCategoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get displayOrder => $composableBuilder(
    column: $table.displayOrder,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);
}

class $$LocalMenuCategoriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalMenuCategoriesTable,
          LocalMenuCategory,
          $$LocalMenuCategoriesTableFilterComposer,
          $$LocalMenuCategoriesTableOrderingComposer,
          $$LocalMenuCategoriesTableAnnotationComposer,
          $$LocalMenuCategoriesTableCreateCompanionBuilder,
          $$LocalMenuCategoriesTableUpdateCompanionBuilder,
          (
            LocalMenuCategory,
            BaseReferences<
              _$AppDatabase,
              $LocalMenuCategoriesTable,
              LocalMenuCategory
            >,
          ),
          LocalMenuCategory,
          PrefetchHooks Function()
        > {
  $$LocalMenuCategoriesTableTableManager(
    _$AppDatabase db,
    $LocalMenuCategoriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalMenuCategoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalMenuCategoriesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$LocalMenuCategoriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> displayOrder = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalMenuCategoriesCompanion(
                id: id,
                name: name,
                displayOrder: displayOrder,
                isActive: isActive,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<int> displayOrder = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalMenuCategoriesCompanion.insert(
                id: id,
                name: name,
                displayOrder: displayOrder,
                isActive: isActive,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalMenuCategoriesTable, LocalMenuCategory>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $LocalMenuCategoriesTable,
                    LocalMenuCategory
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalMenuCategoriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalMenuCategoriesTable,
      LocalMenuCategory,
      $$LocalMenuCategoriesTableFilterComposer,
      $$LocalMenuCategoriesTableOrderingComposer,
      $$LocalMenuCategoriesTableAnnotationComposer,
      $$LocalMenuCategoriesTableCreateCompanionBuilder,
      $$LocalMenuCategoriesTableUpdateCompanionBuilder,
      (
        LocalMenuCategory,
        BaseReferences<
          _$AppDatabase,
          $LocalMenuCategoriesTable,
          LocalMenuCategory
        >,
      ),
      LocalMenuCategory,
      PrefetchHooks Function()
    >;
typedef $$LocalMenuItemsTableCreateCompanionBuilder =
    LocalMenuItemsCompanion Function({
      required String id,
      required String categoryId,
      required String name,
      required double basePrice,
      Value<bool> isAvailable,
      Value<bool> isVeg,
      Value<bool> isSpicy,
      Value<int> rowid,
    });
typedef $$LocalMenuItemsTableUpdateCompanionBuilder =
    LocalMenuItemsCompanion Function({
      Value<String> id,
      Value<String> categoryId,
      Value<String> name,
      Value<double> basePrice,
      Value<bool> isAvailable,
      Value<bool> isVeg,
      Value<bool> isSpicy,
      Value<int> rowid,
    });

final class $$LocalMenuItemsTableReferences
    extends BaseReferences<_$AppDatabase, $LocalMenuItemsTable, LocalMenuItem> {
  $$LocalMenuItemsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$LocalMenuItemSizesTable, List<LocalMenuItemSize>>
  _localMenuItemSizesRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.localMenuItemSizes,
        aliasName: 'local_menu_items__id__local_menu_item_sizes__menu_item_id',
      );

  $$LocalMenuItemSizesTableProcessedTableManager get localMenuItemSizesRefs {
    final manager = $$LocalMenuItemSizesTableTableManager(
      $_db,
      $_db.localMenuItemSizes,
    ).filter((f) => f.menuItemId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _localMenuItemSizesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $LocalMenuItemOptionsTable,
    List<LocalMenuItemOption>
  >
  _localMenuItemOptionsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.localMenuItemOptions,
        aliasName:
            'local_menu_items__id__local_menu_item_options__menu_item_id',
      );

  $$LocalMenuItemOptionsTableProcessedTableManager
  get localMenuItemOptionsRefs {
    final manager = $$LocalMenuItemOptionsTableTableManager(
      $_db,
      $_db.localMenuItemOptions,
    ).filter((f) => f.menuItemId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _localMenuItemOptionsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$LocalMenuItemsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalMenuItemsTable> {
  $$LocalMenuItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get basePrice => $composableBuilder(
    column: $table.basePrice,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isAvailable => $composableBuilder(
    column: $table.isAvailable,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isVeg => $composableBuilder(
    column: $table.isVeg,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isSpicy => $composableBuilder(
    column: $table.isSpicy,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> localMenuItemSizesRefs(
    Expression<bool> Function($$LocalMenuItemSizesTableFilterComposer f) f,
  ) {
    final $$LocalMenuItemSizesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.localMenuItemSizes,
      getReferencedColumn: (t) => t.menuItemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalMenuItemSizesTableFilterComposer(
            $db: $db,
            $table: $db.localMenuItemSizes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> localMenuItemOptionsRefs(
    Expression<bool> Function($$LocalMenuItemOptionsTableFilterComposer f) f,
  ) {
    final $$LocalMenuItemOptionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.localMenuItemOptions,
      getReferencedColumn: (t) => t.menuItemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalMenuItemOptionsTableFilterComposer(
            $db: $db,
            $table: $db.localMenuItemOptions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LocalMenuItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalMenuItemsTable> {
  $$LocalMenuItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get basePrice => $composableBuilder(
    column: $table.basePrice,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isAvailable => $composableBuilder(
    column: $table.isAvailable,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isVeg => $composableBuilder(
    column: $table.isVeg,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isSpicy => $composableBuilder(
    column: $table.isSpicy,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalMenuItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalMenuItemsTable> {
  $$LocalMenuItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<double> get basePrice =>
      $composableBuilder(column: $table.basePrice, builder: (column) => column);

  GeneratedColumn<bool> get isAvailable => $composableBuilder(
    column: $table.isAvailable,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isVeg =>
      $composableBuilder(column: $table.isVeg, builder: (column) => column);

  GeneratedColumn<bool> get isSpicy =>
      $composableBuilder(column: $table.isSpicy, builder: (column) => column);

  Expression<T> localMenuItemSizesRefs<T extends Object>(
    Expression<T> Function($$LocalMenuItemSizesTableAnnotationComposer a) f,
  ) {
    final $$LocalMenuItemSizesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.localMenuItemSizes,
          getReferencedColumn: (t) => t.menuItemId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$LocalMenuItemSizesTableAnnotationComposer(
                $db: $db,
                $table: $db.localMenuItemSizes,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> localMenuItemOptionsRefs<T extends Object>(
    Expression<T> Function($$LocalMenuItemOptionsTableAnnotationComposer a) f,
  ) {
    final $$LocalMenuItemOptionsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.localMenuItemOptions,
          getReferencedColumn: (t) => t.menuItemId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$LocalMenuItemOptionsTableAnnotationComposer(
                $db: $db,
                $table: $db.localMenuItemOptions,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$LocalMenuItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalMenuItemsTable,
          LocalMenuItem,
          $$LocalMenuItemsTableFilterComposer,
          $$LocalMenuItemsTableOrderingComposer,
          $$LocalMenuItemsTableAnnotationComposer,
          $$LocalMenuItemsTableCreateCompanionBuilder,
          $$LocalMenuItemsTableUpdateCompanionBuilder,
          (LocalMenuItem, $$LocalMenuItemsTableReferences),
          LocalMenuItem,
          PrefetchHooks Function({
            bool localMenuItemSizesRefs,
            bool localMenuItemOptionsRefs,
          })
        > {
  $$LocalMenuItemsTableTableManager(
    _$AppDatabase db,
    $LocalMenuItemsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalMenuItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalMenuItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalMenuItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> categoryId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<double> basePrice = const Value.absent(),
                Value<bool> isAvailable = const Value.absent(),
                Value<bool> isVeg = const Value.absent(),
                Value<bool> isSpicy = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalMenuItemsCompanion(
                id: id,
                categoryId: categoryId,
                name: name,
                basePrice: basePrice,
                isAvailable: isAvailable,
                isVeg: isVeg,
                isSpicy: isSpicy,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String categoryId,
                required String name,
                required double basePrice,
                Value<bool> isAvailable = const Value.absent(),
                Value<bool> isVeg = const Value.absent(),
                Value<bool> isSpicy = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalMenuItemsCompanion.insert(
                id: id,
                categoryId: categoryId,
                name: name,
                basePrice: basePrice,
                isAvailable: isAvailable,
                isVeg: isVeg,
                isSpicy: isSpicy,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalMenuItemsTable, LocalMenuItem>(table),
                  $$LocalMenuItemsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                localMenuItemSizesRefs = false,
                localMenuItemOptionsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (localMenuItemSizesRefs) db.localMenuItemSizes,
                    if (localMenuItemOptionsRefs) db.localMenuItemOptions,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (localMenuItemSizesRefs)
                        await $_getPrefetchedData<
                          LocalMenuItem,
                          $LocalMenuItemsTable,
                          LocalMenuItemSize
                        >(
                          currentTable: table,
                          referencedTable: $$LocalMenuItemsTableReferences
                              ._localMenuItemSizesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$LocalMenuItemsTableReferences(
                                db,
                                table,
                                p0,
                              ).localMenuItemSizesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.menuItemId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (localMenuItemOptionsRefs)
                        await $_getPrefetchedData<
                          LocalMenuItem,
                          $LocalMenuItemsTable,
                          LocalMenuItemOption
                        >(
                          currentTable: table,
                          referencedTable: $$LocalMenuItemsTableReferences
                              ._localMenuItemOptionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$LocalMenuItemsTableReferences(
                                db,
                                table,
                                p0,
                              ).localMenuItemOptionsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.menuItemId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$LocalMenuItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalMenuItemsTable,
      LocalMenuItem,
      $$LocalMenuItemsTableFilterComposer,
      $$LocalMenuItemsTableOrderingComposer,
      $$LocalMenuItemsTableAnnotationComposer,
      $$LocalMenuItemsTableCreateCompanionBuilder,
      $$LocalMenuItemsTableUpdateCompanionBuilder,
      (LocalMenuItem, $$LocalMenuItemsTableReferences),
      LocalMenuItem,
      PrefetchHooks Function({
        bool localMenuItemSizesRefs,
        bool localMenuItemOptionsRefs,
      })
    >;
typedef $$LocalMenuItemSizesTableCreateCompanionBuilder =
    LocalMenuItemSizesCompanion Function({
      required String id,
      required String menuItemId,
      required String sizeName,
      Value<double> priceMultiplier,
      Value<bool> isDefault,
      Value<int> rowid,
    });
typedef $$LocalMenuItemSizesTableUpdateCompanionBuilder =
    LocalMenuItemSizesCompanion Function({
      Value<String> id,
      Value<String> menuItemId,
      Value<String> sizeName,
      Value<double> priceMultiplier,
      Value<bool> isDefault,
      Value<int> rowid,
    });

final class $$LocalMenuItemSizesTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $LocalMenuItemSizesTable,
          LocalMenuItemSize
        > {
  $$LocalMenuItemSizesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $LocalMenuItemsTable _menuItemIdTable(_$AppDatabase db) => db
      .localMenuItems
      .createAlias('local_menu_item_sizes__menu_item_id__local_menu_items__id');

  $$LocalMenuItemsTableProcessedTableManager get menuItemId {
    final $_column = $_itemColumn<String>('menu_item_id')!;

    final manager = $$LocalMenuItemsTableTableManager(
      $_db,
      $_db.localMenuItems,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_menuItemIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$LocalMenuItemSizesTableFilterComposer
    extends Composer<_$AppDatabase, $LocalMenuItemSizesTable> {
  $$LocalMenuItemSizesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sizeName => $composableBuilder(
    column: $table.sizeName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get priceMultiplier => $composableBuilder(
    column: $table.priceMultiplier,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDefault => $composableBuilder(
    column: $table.isDefault,
    builder: (column) => ColumnFilters(column),
  );

  $$LocalMenuItemsTableFilterComposer get menuItemId {
    final $$LocalMenuItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.menuItemId,
      referencedTable: $db.localMenuItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalMenuItemsTableFilterComposer(
            $db: $db,
            $table: $db.localMenuItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LocalMenuItemSizesTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalMenuItemSizesTable> {
  $$LocalMenuItemSizesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sizeName => $composableBuilder(
    column: $table.sizeName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get priceMultiplier => $composableBuilder(
    column: $table.priceMultiplier,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDefault => $composableBuilder(
    column: $table.isDefault,
    builder: (column) => ColumnOrderings(column),
  );

  $$LocalMenuItemsTableOrderingComposer get menuItemId {
    final $$LocalMenuItemsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.menuItemId,
      referencedTable: $db.localMenuItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalMenuItemsTableOrderingComposer(
            $db: $db,
            $table: $db.localMenuItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LocalMenuItemSizesTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalMenuItemSizesTable> {
  $$LocalMenuItemSizesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get sizeName =>
      $composableBuilder(column: $table.sizeName, builder: (column) => column);

  GeneratedColumn<double> get priceMultiplier => $composableBuilder(
    column: $table.priceMultiplier,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isDefault =>
      $composableBuilder(column: $table.isDefault, builder: (column) => column);

  $$LocalMenuItemsTableAnnotationComposer get menuItemId {
    final $$LocalMenuItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.menuItemId,
      referencedTable: $db.localMenuItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalMenuItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.localMenuItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LocalMenuItemSizesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalMenuItemSizesTable,
          LocalMenuItemSize,
          $$LocalMenuItemSizesTableFilterComposer,
          $$LocalMenuItemSizesTableOrderingComposer,
          $$LocalMenuItemSizesTableAnnotationComposer,
          $$LocalMenuItemSizesTableCreateCompanionBuilder,
          $$LocalMenuItemSizesTableUpdateCompanionBuilder,
          (LocalMenuItemSize, $$LocalMenuItemSizesTableReferences),
          LocalMenuItemSize,
          PrefetchHooks Function({bool menuItemId})
        > {
  $$LocalMenuItemSizesTableTableManager(
    _$AppDatabase db,
    $LocalMenuItemSizesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalMenuItemSizesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalMenuItemSizesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalMenuItemSizesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> menuItemId = const Value.absent(),
                Value<String> sizeName = const Value.absent(),
                Value<double> priceMultiplier = const Value.absent(),
                Value<bool> isDefault = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalMenuItemSizesCompanion(
                id: id,
                menuItemId: menuItemId,
                sizeName: sizeName,
                priceMultiplier: priceMultiplier,
                isDefault: isDefault,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String menuItemId,
                required String sizeName,
                Value<double> priceMultiplier = const Value.absent(),
                Value<bool> isDefault = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalMenuItemSizesCompanion.insert(
                id: id,
                menuItemId: menuItemId,
                sizeName: sizeName,
                priceMultiplier: priceMultiplier,
                isDefault: isDefault,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalMenuItemSizesTable, LocalMenuItemSize>(
                    table,
                  ),
                  $$LocalMenuItemSizesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({menuItemId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (menuItemId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.menuItemId,
                                referencedTable:
                                    $$LocalMenuItemSizesTableReferences
                                        ._menuItemIdTable(db),
                                referencedColumn:
                                    $$LocalMenuItemSizesTableReferences
                                        ._menuItemIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$LocalMenuItemSizesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalMenuItemSizesTable,
      LocalMenuItemSize,
      $$LocalMenuItemSizesTableFilterComposer,
      $$LocalMenuItemSizesTableOrderingComposer,
      $$LocalMenuItemSizesTableAnnotationComposer,
      $$LocalMenuItemSizesTableCreateCompanionBuilder,
      $$LocalMenuItemSizesTableUpdateCompanionBuilder,
      (LocalMenuItemSize, $$LocalMenuItemSizesTableReferences),
      LocalMenuItemSize,
      PrefetchHooks Function({bool menuItemId})
    >;
typedef $$LocalMenuItemOptionsTableCreateCompanionBuilder =
    LocalMenuItemOptionsCompanion Function({
      required String id,
      required String menuItemId,
      required String groupName,
      required String optionName,
      Value<double> additionalPrice,
      Value<int> rowid,
    });
typedef $$LocalMenuItemOptionsTableUpdateCompanionBuilder =
    LocalMenuItemOptionsCompanion Function({
      Value<String> id,
      Value<String> menuItemId,
      Value<String> groupName,
      Value<String> optionName,
      Value<double> additionalPrice,
      Value<int> rowid,
    });

final class $$LocalMenuItemOptionsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $LocalMenuItemOptionsTable,
          LocalMenuItemOption
        > {
  $$LocalMenuItemOptionsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $LocalMenuItemsTable _menuItemIdTable(_$AppDatabase db) =>
      db.localMenuItems.createAlias(
        'local_menu_item_options__menu_item_id__local_menu_items__id',
      );

  $$LocalMenuItemsTableProcessedTableManager get menuItemId {
    final $_column = $_itemColumn<String>('menu_item_id')!;

    final manager = $$LocalMenuItemsTableTableManager(
      $_db,
      $_db.localMenuItems,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_menuItemIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$LocalMenuItemOptionsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalMenuItemOptionsTable> {
  $$LocalMenuItemOptionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get groupName => $composableBuilder(
    column: $table.groupName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get optionName => $composableBuilder(
    column: $table.optionName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get additionalPrice => $composableBuilder(
    column: $table.additionalPrice,
    builder: (column) => ColumnFilters(column),
  );

  $$LocalMenuItemsTableFilterComposer get menuItemId {
    final $$LocalMenuItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.menuItemId,
      referencedTable: $db.localMenuItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalMenuItemsTableFilterComposer(
            $db: $db,
            $table: $db.localMenuItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LocalMenuItemOptionsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalMenuItemOptionsTable> {
  $$LocalMenuItemOptionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get groupName => $composableBuilder(
    column: $table.groupName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get optionName => $composableBuilder(
    column: $table.optionName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get additionalPrice => $composableBuilder(
    column: $table.additionalPrice,
    builder: (column) => ColumnOrderings(column),
  );

  $$LocalMenuItemsTableOrderingComposer get menuItemId {
    final $$LocalMenuItemsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.menuItemId,
      referencedTable: $db.localMenuItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalMenuItemsTableOrderingComposer(
            $db: $db,
            $table: $db.localMenuItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LocalMenuItemOptionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalMenuItemOptionsTable> {
  $$LocalMenuItemOptionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get groupName =>
      $composableBuilder(column: $table.groupName, builder: (column) => column);

  GeneratedColumn<String> get optionName => $composableBuilder(
    column: $table.optionName,
    builder: (column) => column,
  );

  GeneratedColumn<double> get additionalPrice => $composableBuilder(
    column: $table.additionalPrice,
    builder: (column) => column,
  );

  $$LocalMenuItemsTableAnnotationComposer get menuItemId {
    final $$LocalMenuItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.menuItemId,
      referencedTable: $db.localMenuItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalMenuItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.localMenuItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LocalMenuItemOptionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalMenuItemOptionsTable,
          LocalMenuItemOption,
          $$LocalMenuItemOptionsTableFilterComposer,
          $$LocalMenuItemOptionsTableOrderingComposer,
          $$LocalMenuItemOptionsTableAnnotationComposer,
          $$LocalMenuItemOptionsTableCreateCompanionBuilder,
          $$LocalMenuItemOptionsTableUpdateCompanionBuilder,
          (LocalMenuItemOption, $$LocalMenuItemOptionsTableReferences),
          LocalMenuItemOption,
          PrefetchHooks Function({bool menuItemId})
        > {
  $$LocalMenuItemOptionsTableTableManager(
    _$AppDatabase db,
    $LocalMenuItemOptionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalMenuItemOptionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalMenuItemOptionsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$LocalMenuItemOptionsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> menuItemId = const Value.absent(),
                Value<String> groupName = const Value.absent(),
                Value<String> optionName = const Value.absent(),
                Value<double> additionalPrice = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalMenuItemOptionsCompanion(
                id: id,
                menuItemId: menuItemId,
                groupName: groupName,
                optionName: optionName,
                additionalPrice: additionalPrice,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String menuItemId,
                required String groupName,
                required String optionName,
                Value<double> additionalPrice = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalMenuItemOptionsCompanion.insert(
                id: id,
                menuItemId: menuItemId,
                groupName: groupName,
                optionName: optionName,
                additionalPrice: additionalPrice,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalMenuItemOptionsTable, LocalMenuItemOption>(
                    table,
                  ),
                  $$LocalMenuItemOptionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({menuItemId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (menuItemId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.menuItemId,
                                referencedTable:
                                    $$LocalMenuItemOptionsTableReferences
                                        ._menuItemIdTable(db),
                                referencedColumn:
                                    $$LocalMenuItemOptionsTableReferences
                                        ._menuItemIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$LocalMenuItemOptionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalMenuItemOptionsTable,
      LocalMenuItemOption,
      $$LocalMenuItemOptionsTableFilterComposer,
      $$LocalMenuItemOptionsTableOrderingComposer,
      $$LocalMenuItemOptionsTableAnnotationComposer,
      $$LocalMenuItemOptionsTableCreateCompanionBuilder,
      $$LocalMenuItemOptionsTableUpdateCompanionBuilder,
      (LocalMenuItemOption, $$LocalMenuItemOptionsTableReferences),
      LocalMenuItemOption,
      PrefetchHooks Function({bool menuItemId})
    >;
typedef $$LocalDealsTableCreateCompanionBuilder =
    LocalDealsCompanion Function({
      required String id,
      required String name,
      required double dealPrice,
      Value<bool> isAvailable,
      Value<int> rowid,
    });
typedef $$LocalDealsTableUpdateCompanionBuilder =
    LocalDealsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<double> dealPrice,
      Value<bool> isAvailable,
      Value<int> rowid,
    });

final class $$LocalDealsTableReferences
    extends BaseReferences<_$AppDatabase, $LocalDealsTable, LocalDeal> {
  $$LocalDealsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<
    $LocalDealComponentsTable,
    List<LocalDealComponent>
  >
  _localDealComponentsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.localDealComponents,
        aliasName: 'local_deals__id__local_deal_components__deal_id',
      );

  $$LocalDealComponentsTableProcessedTableManager get localDealComponentsRefs {
    final manager = $$LocalDealComponentsTableTableManager(
      $_db,
      $_db.localDealComponents,
    ).filter((f) => f.dealId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _localDealComponentsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$LocalDealsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalDealsTable> {
  $$LocalDealsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get dealPrice => $composableBuilder(
    column: $table.dealPrice,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isAvailable => $composableBuilder(
    column: $table.isAvailable,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> localDealComponentsRefs(
    Expression<bool> Function($$LocalDealComponentsTableFilterComposer f) f,
  ) {
    final $$LocalDealComponentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.localDealComponents,
      getReferencedColumn: (t) => t.dealId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalDealComponentsTableFilterComposer(
            $db: $db,
            $table: $db.localDealComponents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LocalDealsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalDealsTable> {
  $$LocalDealsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get dealPrice => $composableBuilder(
    column: $table.dealPrice,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isAvailable => $composableBuilder(
    column: $table.isAvailable,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalDealsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalDealsTable> {
  $$LocalDealsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<double> get dealPrice =>
      $composableBuilder(column: $table.dealPrice, builder: (column) => column);

  GeneratedColumn<bool> get isAvailable => $composableBuilder(
    column: $table.isAvailable,
    builder: (column) => column,
  );

  Expression<T> localDealComponentsRefs<T extends Object>(
    Expression<T> Function($$LocalDealComponentsTableAnnotationComposer a) f,
  ) {
    final $$LocalDealComponentsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.localDealComponents,
          getReferencedColumn: (t) => t.dealId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$LocalDealComponentsTableAnnotationComposer(
                $db: $db,
                $table: $db.localDealComponents,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$LocalDealsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalDealsTable,
          LocalDeal,
          $$LocalDealsTableFilterComposer,
          $$LocalDealsTableOrderingComposer,
          $$LocalDealsTableAnnotationComposer,
          $$LocalDealsTableCreateCompanionBuilder,
          $$LocalDealsTableUpdateCompanionBuilder,
          (LocalDeal, $$LocalDealsTableReferences),
          LocalDeal,
          PrefetchHooks Function({bool localDealComponentsRefs})
        > {
  $$LocalDealsTableTableManager(_$AppDatabase db, $LocalDealsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalDealsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalDealsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalDealsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<double> dealPrice = const Value.absent(),
                Value<bool> isAvailable = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalDealsCompanion(
                id: id,
                name: name,
                dealPrice: dealPrice,
                isAvailable: isAvailable,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required double dealPrice,
                Value<bool> isAvailable = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalDealsCompanion.insert(
                id: id,
                name: name,
                dealPrice: dealPrice,
                isAvailable: isAvailable,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalDealsTable, LocalDeal>(table),
                  $$LocalDealsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({localDealComponentsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (localDealComponentsRefs) db.localDealComponents,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (localDealComponentsRefs)
                    await $_getPrefetchedData<
                      LocalDeal,
                      $LocalDealsTable,
                      LocalDealComponent
                    >(
                      currentTable: table,
                      referencedTable: $$LocalDealsTableReferences
                          ._localDealComponentsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$LocalDealsTableReferences(
                            db,
                            table,
                            p0,
                          ).localDealComponentsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.dealId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$LocalDealsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalDealsTable,
      LocalDeal,
      $$LocalDealsTableFilterComposer,
      $$LocalDealsTableOrderingComposer,
      $$LocalDealsTableAnnotationComposer,
      $$LocalDealsTableCreateCompanionBuilder,
      $$LocalDealsTableUpdateCompanionBuilder,
      (LocalDeal, $$LocalDealsTableReferences),
      LocalDeal,
      PrefetchHooks Function({bool localDealComponentsRefs})
    >;
typedef $$LocalDealComponentsTableCreateCompanionBuilder =
    LocalDealComponentsCompanion Function({
      required String id,
      required String dealId,
      Value<String?> menuItemId,
      Value<String> quantity,
      Value<int> rowid,
    });
typedef $$LocalDealComponentsTableUpdateCompanionBuilder =
    LocalDealComponentsCompanion Function({
      Value<String> id,
      Value<String> dealId,
      Value<String?> menuItemId,
      Value<String> quantity,
      Value<int> rowid,
    });

final class $$LocalDealComponentsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $LocalDealComponentsTable,
          LocalDealComponent
        > {
  $$LocalDealComponentsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $LocalDealsTable _dealIdTable(_$AppDatabase db) => db.localDeals
      .createAlias('local_deal_components__deal_id__local_deals__id');

  $$LocalDealsTableProcessedTableManager get dealId {
    final $_column = $_itemColumn<String>('deal_id')!;

    final manager = $$LocalDealsTableTableManager(
      $_db,
      $_db.localDeals,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_dealIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$LocalDealComponentsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalDealComponentsTable> {
  $$LocalDealComponentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get menuItemId => $composableBuilder(
    column: $table.menuItemId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnFilters(column),
  );

  $$LocalDealsTableFilterComposer get dealId {
    final $$LocalDealsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.dealId,
      referencedTable: $db.localDeals,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalDealsTableFilterComposer(
            $db: $db,
            $table: $db.localDeals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LocalDealComponentsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalDealComponentsTable> {
  $$LocalDealComponentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get menuItemId => $composableBuilder(
    column: $table.menuItemId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnOrderings(column),
  );

  $$LocalDealsTableOrderingComposer get dealId {
    final $$LocalDealsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.dealId,
      referencedTable: $db.localDeals,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalDealsTableOrderingComposer(
            $db: $db,
            $table: $db.localDeals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LocalDealComponentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalDealComponentsTable> {
  $$LocalDealComponentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get menuItemId => $composableBuilder(
    column: $table.menuItemId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => column);

  $$LocalDealsTableAnnotationComposer get dealId {
    final $$LocalDealsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.dealId,
      referencedTable: $db.localDeals,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalDealsTableAnnotationComposer(
            $db: $db,
            $table: $db.localDeals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LocalDealComponentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalDealComponentsTable,
          LocalDealComponent,
          $$LocalDealComponentsTableFilterComposer,
          $$LocalDealComponentsTableOrderingComposer,
          $$LocalDealComponentsTableAnnotationComposer,
          $$LocalDealComponentsTableCreateCompanionBuilder,
          $$LocalDealComponentsTableUpdateCompanionBuilder,
          (LocalDealComponent, $$LocalDealComponentsTableReferences),
          LocalDealComponent,
          PrefetchHooks Function({bool dealId})
        > {
  $$LocalDealComponentsTableTableManager(
    _$AppDatabase db,
    $LocalDealComponentsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalDealComponentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalDealComponentsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$LocalDealComponentsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> dealId = const Value.absent(),
                Value<String?> menuItemId = const Value.absent(),
                Value<String> quantity = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalDealComponentsCompanion(
                id: id,
                dealId: dealId,
                menuItemId: menuItemId,
                quantity: quantity,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String dealId,
                Value<String?> menuItemId = const Value.absent(),
                Value<String> quantity = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalDealComponentsCompanion.insert(
                id: id,
                dealId: dealId,
                menuItemId: menuItemId,
                quantity: quantity,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalDealComponentsTable, LocalDealComponent>(
                    table,
                  ),
                  $$LocalDealComponentsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({dealId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (dealId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.dealId,
                                referencedTable:
                                    $$LocalDealComponentsTableReferences
                                        ._dealIdTable(db),
                                referencedColumn:
                                    $$LocalDealComponentsTableReferences
                                        ._dealIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$LocalDealComponentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalDealComponentsTable,
      LocalDealComponent,
      $$LocalDealComponentsTableFilterComposer,
      $$LocalDealComponentsTableOrderingComposer,
      $$LocalDealComponentsTableAnnotationComposer,
      $$LocalDealComponentsTableCreateCompanionBuilder,
      $$LocalDealComponentsTableUpdateCompanionBuilder,
      (LocalDealComponent, $$LocalDealComponentsTableReferences),
      LocalDealComponent,
      PrefetchHooks Function({bool dealId})
    >;
typedef $$LocalRestaurantTablesTableCreateCompanionBuilder =
    LocalRestaurantTablesCompanion Function({
      required String id,
      Value<String?> zoneId,
      required String tableNumber,
      required String name,
      Value<int> capacity,
      Value<String> status,
      Value<String?> activeOrderId,
      Value<int> version,
      Value<bool> isDeleted,
      Value<bool> isOverflow,
      Value<String?> parentTableId,
      Value<String?> overflowSuffix,
      Value<int> rowid,
    });
typedef $$LocalRestaurantTablesTableUpdateCompanionBuilder =
    LocalRestaurantTablesCompanion Function({
      Value<String> id,
      Value<String?> zoneId,
      Value<String> tableNumber,
      Value<String> name,
      Value<int> capacity,
      Value<String> status,
      Value<String?> activeOrderId,
      Value<int> version,
      Value<bool> isDeleted,
      Value<bool> isOverflow,
      Value<String?> parentTableId,
      Value<String?> overflowSuffix,
      Value<int> rowid,
    });

class $$LocalRestaurantTablesTableFilterComposer
    extends Composer<_$AppDatabase, $LocalRestaurantTablesTable> {
  $$LocalRestaurantTablesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get zoneId => $composableBuilder(
    column: $table.zoneId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tableNumber => $composableBuilder(
    column: $table.tableNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get capacity => $composableBuilder(
    column: $table.capacity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get activeOrderId => $composableBuilder(
    column: $table.activeOrderId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isOverflow => $composableBuilder(
    column: $table.isOverflow,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parentTableId => $composableBuilder(
    column: $table.parentTableId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get overflowSuffix => $composableBuilder(
    column: $table.overflowSuffix,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalRestaurantTablesTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalRestaurantTablesTable> {
  $$LocalRestaurantTablesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get zoneId => $composableBuilder(
    column: $table.zoneId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tableNumber => $composableBuilder(
    column: $table.tableNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get capacity => $composableBuilder(
    column: $table.capacity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get activeOrderId => $composableBuilder(
    column: $table.activeOrderId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isOverflow => $composableBuilder(
    column: $table.isOverflow,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parentTableId => $composableBuilder(
    column: $table.parentTableId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get overflowSuffix => $composableBuilder(
    column: $table.overflowSuffix,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalRestaurantTablesTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalRestaurantTablesTable> {
  $$LocalRestaurantTablesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get zoneId =>
      $composableBuilder(column: $table.zoneId, builder: (column) => column);

  GeneratedColumn<String> get tableNumber => $composableBuilder(
    column: $table.tableNumber,
    builder: (column) => column,
  );

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get capacity =>
      $composableBuilder(column: $table.capacity, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get activeOrderId => $composableBuilder(
    column: $table.activeOrderId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<bool> get isOverflow => $composableBuilder(
    column: $table.isOverflow,
    builder: (column) => column,
  );

  GeneratedColumn<String> get parentTableId => $composableBuilder(
    column: $table.parentTableId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get overflowSuffix => $composableBuilder(
    column: $table.overflowSuffix,
    builder: (column) => column,
  );
}

class $$LocalRestaurantTablesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalRestaurantTablesTable,
          LocalRestaurantTable,
          $$LocalRestaurantTablesTableFilterComposer,
          $$LocalRestaurantTablesTableOrderingComposer,
          $$LocalRestaurantTablesTableAnnotationComposer,
          $$LocalRestaurantTablesTableCreateCompanionBuilder,
          $$LocalRestaurantTablesTableUpdateCompanionBuilder,
          (
            LocalRestaurantTable,
            BaseReferences<
              _$AppDatabase,
              $LocalRestaurantTablesTable,
              LocalRestaurantTable
            >,
          ),
          LocalRestaurantTable,
          PrefetchHooks Function()
        > {
  $$LocalRestaurantTablesTableTableManager(
    _$AppDatabase db,
    $LocalRestaurantTablesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalRestaurantTablesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$LocalRestaurantTablesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$LocalRestaurantTablesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> zoneId = const Value.absent(),
                Value<String> tableNumber = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> capacity = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> activeOrderId = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<bool> isOverflow = const Value.absent(),
                Value<String?> parentTableId = const Value.absent(),
                Value<String?> overflowSuffix = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalRestaurantTablesCompanion(
                id: id,
                zoneId: zoneId,
                tableNumber: tableNumber,
                name: name,
                capacity: capacity,
                status: status,
                activeOrderId: activeOrderId,
                version: version,
                isDeleted: isDeleted,
                isOverflow: isOverflow,
                parentTableId: parentTableId,
                overflowSuffix: overflowSuffix,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> zoneId = const Value.absent(),
                required String tableNumber,
                required String name,
                Value<int> capacity = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> activeOrderId = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<bool> isOverflow = const Value.absent(),
                Value<String?> parentTableId = const Value.absent(),
                Value<String?> overflowSuffix = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalRestaurantTablesCompanion.insert(
                id: id,
                zoneId: zoneId,
                tableNumber: tableNumber,
                name: name,
                capacity: capacity,
                status: status,
                activeOrderId: activeOrderId,
                version: version,
                isDeleted: isDeleted,
                isOverflow: isOverflow,
                parentTableId: parentTableId,
                overflowSuffix: overflowSuffix,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $LocalRestaurantTablesTable,
                    LocalRestaurantTable
                  >(table),
                  BaseReferences<
                    _$AppDatabase,
                    $LocalRestaurantTablesTable,
                    LocalRestaurantTable
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalRestaurantTablesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalRestaurantTablesTable,
      LocalRestaurantTable,
      $$LocalRestaurantTablesTableFilterComposer,
      $$LocalRestaurantTablesTableOrderingComposer,
      $$LocalRestaurantTablesTableAnnotationComposer,
      $$LocalRestaurantTablesTableCreateCompanionBuilder,
      $$LocalRestaurantTablesTableUpdateCompanionBuilder,
      (
        LocalRestaurantTable,
        BaseReferences<
          _$AppDatabase,
          $LocalRestaurantTablesTable,
          LocalRestaurantTable
        >,
      ),
      LocalRestaurantTable,
      PrefetchHooks Function()
    >;
typedef $$LocalFloorZonesTableCreateCompanionBuilder =
    LocalFloorZonesCompanion Function({
      required String id,
      required String name,
      Value<int> displayOrder,
      Value<int> rowid,
    });
typedef $$LocalFloorZonesTableUpdateCompanionBuilder =
    LocalFloorZonesCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<int> displayOrder,
      Value<int> rowid,
    });

class $$LocalFloorZonesTableFilterComposer
    extends Composer<_$AppDatabase, $LocalFloorZonesTable> {
  $$LocalFloorZonesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get displayOrder => $composableBuilder(
    column: $table.displayOrder,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalFloorZonesTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalFloorZonesTable> {
  $$LocalFloorZonesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get displayOrder => $composableBuilder(
    column: $table.displayOrder,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalFloorZonesTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalFloorZonesTable> {
  $$LocalFloorZonesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get displayOrder => $composableBuilder(
    column: $table.displayOrder,
    builder: (column) => column,
  );
}

class $$LocalFloorZonesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalFloorZonesTable,
          LocalFloorZone,
          $$LocalFloorZonesTableFilterComposer,
          $$LocalFloorZonesTableOrderingComposer,
          $$LocalFloorZonesTableAnnotationComposer,
          $$LocalFloorZonesTableCreateCompanionBuilder,
          $$LocalFloorZonesTableUpdateCompanionBuilder,
          (
            LocalFloorZone,
            BaseReferences<
              _$AppDatabase,
              $LocalFloorZonesTable,
              LocalFloorZone
            >,
          ),
          LocalFloorZone,
          PrefetchHooks Function()
        > {
  $$LocalFloorZonesTableTableManager(
    _$AppDatabase db,
    $LocalFloorZonesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalFloorZonesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalFloorZonesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalFloorZonesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> displayOrder = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalFloorZonesCompanion(
                id: id,
                name: name,
                displayOrder: displayOrder,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<int> displayOrder = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalFloorZonesCompanion.insert(
                id: id,
                name: name,
                displayOrder: displayOrder,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalFloorZonesTable, LocalFloorZone>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $LocalFloorZonesTable,
                    LocalFloorZone
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalFloorZonesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalFloorZonesTable,
      LocalFloorZone,
      $$LocalFloorZonesTableFilterComposer,
      $$LocalFloorZonesTableOrderingComposer,
      $$LocalFloorZonesTableAnnotationComposer,
      $$LocalFloorZonesTableCreateCompanionBuilder,
      $$LocalFloorZonesTableUpdateCompanionBuilder,
      (
        LocalFloorZone,
        BaseReferences<_$AppDatabase, $LocalFloorZonesTable, LocalFloorZone>,
      ),
      LocalFloorZone,
      PrefetchHooks Function()
    >;
typedef $$LocalStaffUsersTableCreateCompanionBuilder =
    LocalStaffUsersCompanion Function({
      required String id,
      required String username,
      required String role,
      Value<String?> pinHash,
      Value<bool> isActive,
      Value<int> rowid,
    });
typedef $$LocalStaffUsersTableUpdateCompanionBuilder =
    LocalStaffUsersCompanion Function({
      Value<String> id,
      Value<String> username,
      Value<String> role,
      Value<String?> pinHash,
      Value<bool> isActive,
      Value<int> rowid,
    });

class $$LocalStaffUsersTableFilterComposer
    extends Composer<_$AppDatabase, $LocalStaffUsersTable> {
  $$LocalStaffUsersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get username => $composableBuilder(
    column: $table.username,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pinHash => $composableBuilder(
    column: $table.pinHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalStaffUsersTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalStaffUsersTable> {
  $$LocalStaffUsersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get username => $composableBuilder(
    column: $table.username,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pinHash => $composableBuilder(
    column: $table.pinHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalStaffUsersTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalStaffUsersTable> {
  $$LocalStaffUsersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get username =>
      $composableBuilder(column: $table.username, builder: (column) => column);

  GeneratedColumn<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<String> get pinHash =>
      $composableBuilder(column: $table.pinHash, builder: (column) => column);

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);
}

class $$LocalStaffUsersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalStaffUsersTable,
          LocalStaffUser,
          $$LocalStaffUsersTableFilterComposer,
          $$LocalStaffUsersTableOrderingComposer,
          $$LocalStaffUsersTableAnnotationComposer,
          $$LocalStaffUsersTableCreateCompanionBuilder,
          $$LocalStaffUsersTableUpdateCompanionBuilder,
          (
            LocalStaffUser,
            BaseReferences<
              _$AppDatabase,
              $LocalStaffUsersTable,
              LocalStaffUser
            >,
          ),
          LocalStaffUser,
          PrefetchHooks Function()
        > {
  $$LocalStaffUsersTableTableManager(
    _$AppDatabase db,
    $LocalStaffUsersTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalStaffUsersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalStaffUsersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalStaffUsersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> username = const Value.absent(),
                Value<String> role = const Value.absent(),
                Value<String?> pinHash = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalStaffUsersCompanion(
                id: id,
                username: username,
                role: role,
                pinHash: pinHash,
                isActive: isActive,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String username,
                required String role,
                Value<String?> pinHash = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalStaffUsersCompanion.insert(
                id: id,
                username: username,
                role: role,
                pinHash: pinHash,
                isActive: isActive,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalStaffUsersTable, LocalStaffUser>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $LocalStaffUsersTable,
                    LocalStaffUser
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalStaffUsersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalStaffUsersTable,
      LocalStaffUser,
      $$LocalStaffUsersTableFilterComposer,
      $$LocalStaffUsersTableOrderingComposer,
      $$LocalStaffUsersTableAnnotationComposer,
      $$LocalStaffUsersTableCreateCompanionBuilder,
      $$LocalStaffUsersTableUpdateCompanionBuilder,
      (
        LocalStaffUser,
        BaseReferences<_$AppDatabase, $LocalStaffUsersTable, LocalStaffUser>,
      ),
      LocalStaffUser,
      PrefetchHooks Function()
    >;
typedef $$LocalRolePermissionsTableCreateCompanionBuilder =
    LocalRolePermissionsCompanion Function({
      required String id,
      required String role,
      required String moduleName,
      required String actionName,
      Value<bool> isGranted,
      Value<int> rowid,
    });
typedef $$LocalRolePermissionsTableUpdateCompanionBuilder =
    LocalRolePermissionsCompanion Function({
      Value<String> id,
      Value<String> role,
      Value<String> moduleName,
      Value<String> actionName,
      Value<bool> isGranted,
      Value<int> rowid,
    });

class $$LocalRolePermissionsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalRolePermissionsTable> {
  $$LocalRolePermissionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get moduleName => $composableBuilder(
    column: $table.moduleName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get actionName => $composableBuilder(
    column: $table.actionName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isGranted => $composableBuilder(
    column: $table.isGranted,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalRolePermissionsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalRolePermissionsTable> {
  $$LocalRolePermissionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get moduleName => $composableBuilder(
    column: $table.moduleName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get actionName => $composableBuilder(
    column: $table.actionName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isGranted => $composableBuilder(
    column: $table.isGranted,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalRolePermissionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalRolePermissionsTable> {
  $$LocalRolePermissionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<String> get moduleName => $composableBuilder(
    column: $table.moduleName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get actionName => $composableBuilder(
    column: $table.actionName,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isGranted =>
      $composableBuilder(column: $table.isGranted, builder: (column) => column);
}

class $$LocalRolePermissionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalRolePermissionsTable,
          LocalRolePermission,
          $$LocalRolePermissionsTableFilterComposer,
          $$LocalRolePermissionsTableOrderingComposer,
          $$LocalRolePermissionsTableAnnotationComposer,
          $$LocalRolePermissionsTableCreateCompanionBuilder,
          $$LocalRolePermissionsTableUpdateCompanionBuilder,
          (
            LocalRolePermission,
            BaseReferences<
              _$AppDatabase,
              $LocalRolePermissionsTable,
              LocalRolePermission
            >,
          ),
          LocalRolePermission,
          PrefetchHooks Function()
        > {
  $$LocalRolePermissionsTableTableManager(
    _$AppDatabase db,
    $LocalRolePermissionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalRolePermissionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalRolePermissionsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$LocalRolePermissionsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> role = const Value.absent(),
                Value<String> moduleName = const Value.absent(),
                Value<String> actionName = const Value.absent(),
                Value<bool> isGranted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalRolePermissionsCompanion(
                id: id,
                role: role,
                moduleName: moduleName,
                actionName: actionName,
                isGranted: isGranted,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String role,
                required String moduleName,
                required String actionName,
                Value<bool> isGranted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalRolePermissionsCompanion.insert(
                id: id,
                role: role,
                moduleName: moduleName,
                actionName: actionName,
                isGranted: isGranted,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalRolePermissionsTable, LocalRolePermission>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $LocalRolePermissionsTable,
                    LocalRolePermission
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalRolePermissionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalRolePermissionsTable,
      LocalRolePermission,
      $$LocalRolePermissionsTableFilterComposer,
      $$LocalRolePermissionsTableOrderingComposer,
      $$LocalRolePermissionsTableAnnotationComposer,
      $$LocalRolePermissionsTableCreateCompanionBuilder,
      $$LocalRolePermissionsTableUpdateCompanionBuilder,
      (
        LocalRolePermission,
        BaseReferences<
          _$AppDatabase,
          $LocalRolePermissionsTable,
          LocalRolePermission
        >,
      ),
      LocalRolePermission,
      PrefetchHooks Function()
    >;
typedef $$LocalStoreSettingsTableCreateCompanionBuilder =
    LocalStoreSettingsCompanion Function({
      required String id,
      required String chainName,
      required String branchCode,
      required String branchName,
      required String storePhone,
      Value<double> taxPercentage,
      Value<int> rowid,
    });
typedef $$LocalStoreSettingsTableUpdateCompanionBuilder =
    LocalStoreSettingsCompanion Function({
      Value<String> id,
      Value<String> chainName,
      Value<String> branchCode,
      Value<String> branchName,
      Value<String> storePhone,
      Value<double> taxPercentage,
      Value<int> rowid,
    });

class $$LocalStoreSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalStoreSettingsTable> {
  $$LocalStoreSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get chainName => $composableBuilder(
    column: $table.chainName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get branchCode => $composableBuilder(
    column: $table.branchCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get branchName => $composableBuilder(
    column: $table.branchName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get storePhone => $composableBuilder(
    column: $table.storePhone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get taxPercentage => $composableBuilder(
    column: $table.taxPercentage,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalStoreSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalStoreSettingsTable> {
  $$LocalStoreSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get chainName => $composableBuilder(
    column: $table.chainName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get branchCode => $composableBuilder(
    column: $table.branchCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get branchName => $composableBuilder(
    column: $table.branchName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get storePhone => $composableBuilder(
    column: $table.storePhone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get taxPercentage => $composableBuilder(
    column: $table.taxPercentage,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalStoreSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalStoreSettingsTable> {
  $$LocalStoreSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get chainName =>
      $composableBuilder(column: $table.chainName, builder: (column) => column);

  GeneratedColumn<String> get branchCode => $composableBuilder(
    column: $table.branchCode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get branchName => $composableBuilder(
    column: $table.branchName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get storePhone => $composableBuilder(
    column: $table.storePhone,
    builder: (column) => column,
  );

  GeneratedColumn<double> get taxPercentage => $composableBuilder(
    column: $table.taxPercentage,
    builder: (column) => column,
  );
}

class $$LocalStoreSettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalStoreSettingsTable,
          LocalStoreSetting,
          $$LocalStoreSettingsTableFilterComposer,
          $$LocalStoreSettingsTableOrderingComposer,
          $$LocalStoreSettingsTableAnnotationComposer,
          $$LocalStoreSettingsTableCreateCompanionBuilder,
          $$LocalStoreSettingsTableUpdateCompanionBuilder,
          (
            LocalStoreSetting,
            BaseReferences<
              _$AppDatabase,
              $LocalStoreSettingsTable,
              LocalStoreSetting
            >,
          ),
          LocalStoreSetting,
          PrefetchHooks Function()
        > {
  $$LocalStoreSettingsTableTableManager(
    _$AppDatabase db,
    $LocalStoreSettingsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalStoreSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalStoreSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalStoreSettingsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> chainName = const Value.absent(),
                Value<String> branchCode = const Value.absent(),
                Value<String> branchName = const Value.absent(),
                Value<String> storePhone = const Value.absent(),
                Value<double> taxPercentage = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalStoreSettingsCompanion(
                id: id,
                chainName: chainName,
                branchCode: branchCode,
                branchName: branchName,
                storePhone: storePhone,
                taxPercentage: taxPercentage,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String chainName,
                required String branchCode,
                required String branchName,
                required String storePhone,
                Value<double> taxPercentage = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalStoreSettingsCompanion.insert(
                id: id,
                chainName: chainName,
                branchCode: branchCode,
                branchName: branchName,
                storePhone: storePhone,
                taxPercentage: taxPercentage,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalStoreSettingsTable, LocalStoreSetting>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $LocalStoreSettingsTable,
                    LocalStoreSetting
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalStoreSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalStoreSettingsTable,
      LocalStoreSetting,
      $$LocalStoreSettingsTableFilterComposer,
      $$LocalStoreSettingsTableOrderingComposer,
      $$LocalStoreSettingsTableAnnotationComposer,
      $$LocalStoreSettingsTableCreateCompanionBuilder,
      $$LocalStoreSettingsTableUpdateCompanionBuilder,
      (
        LocalStoreSetting,
        BaseReferences<
          _$AppDatabase,
          $LocalStoreSettingsTable,
          LocalStoreSetting
        >,
      ),
      LocalStoreSetting,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$LocalOrdersTableTableManager get localOrders =>
      $$LocalOrdersTableTableManager(_db, _db.localOrders);
  $$LocalOrderItemsTableTableManager get localOrderItems =>
      $$LocalOrderItemsTableTableManager(_db, _db.localOrderItems);
  $$LocalOrderPaymentsTableTableManager get localOrderPayments =>
      $$LocalOrderPaymentsTableTableManager(_db, _db.localOrderPayments);
  $$SyncOutboxTableTableManager get syncOutbox =>
      $$SyncOutboxTableTableManager(_db, _db.syncOutbox);
  $$TerminalSequencesTableTableManager get terminalSequences =>
      $$TerminalSequencesTableTableManager(_db, _db.terminalSequences);
  $$OfflinePrintJobsTableTableManager get offlinePrintJobs =>
      $$OfflinePrintJobsTableTableManager(_db, _db.offlinePrintJobs);
  $$SyncCursorsTableTableManager get syncCursors =>
      $$SyncCursorsTableTableManager(_db, _db.syncCursors);
  $$SyncConflictsTableTableManager get syncConflicts =>
      $$SyncConflictsTableTableManager(_db, _db.syncConflicts);
  $$LocalDailyCalculationsTableTableManager get localDailyCalculations =>
      $$LocalDailyCalculationsTableTableManager(
        _db,
        _db.localDailyCalculations,
      );
  $$LocalMenuCategoriesTableTableManager get localMenuCategories =>
      $$LocalMenuCategoriesTableTableManager(_db, _db.localMenuCategories);
  $$LocalMenuItemsTableTableManager get localMenuItems =>
      $$LocalMenuItemsTableTableManager(_db, _db.localMenuItems);
  $$LocalMenuItemSizesTableTableManager get localMenuItemSizes =>
      $$LocalMenuItemSizesTableTableManager(_db, _db.localMenuItemSizes);
  $$LocalMenuItemOptionsTableTableManager get localMenuItemOptions =>
      $$LocalMenuItemOptionsTableTableManager(_db, _db.localMenuItemOptions);
  $$LocalDealsTableTableManager get localDeals =>
      $$LocalDealsTableTableManager(_db, _db.localDeals);
  $$LocalDealComponentsTableTableManager get localDealComponents =>
      $$LocalDealComponentsTableTableManager(_db, _db.localDealComponents);
  $$LocalRestaurantTablesTableTableManager get localRestaurantTables =>
      $$LocalRestaurantTablesTableTableManager(_db, _db.localRestaurantTables);
  $$LocalFloorZonesTableTableManager get localFloorZones =>
      $$LocalFloorZonesTableTableManager(_db, _db.localFloorZones);
  $$LocalStaffUsersTableTableManager get localStaffUsers =>
      $$LocalStaffUsersTableTableManager(_db, _db.localStaffUsers);
  $$LocalRolePermissionsTableTableManager get localRolePermissions =>
      $$LocalRolePermissionsTableTableManager(_db, _db.localRolePermissions);
  $$LocalStoreSettingsTableTableManager get localStoreSettings =>
      $$LocalStoreSettingsTableTableManager(_db, _db.localStoreSettings);
}
