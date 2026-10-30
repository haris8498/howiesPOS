import 'dart:convert';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../core/database/app_database.dart';
import '../core/database/tables/offline_print_jobs_table.dart';
import '../domain/models/order_model.dart';
import '../domain/models/restaurant_table.dart';
import '../domain/models/takeaway_model.dart';
import '../domain/models/delivery_model.dart';
import '../domain/models/online_order_model.dart';

import 'printer/escpos_builder.dart';
import 'printer/native_win32_printer.dart';
import 'printer/network_printer.dart';

enum ReceiptType {
  customerReceipt, // Final Paid Bill / Tax Invoice
  kitchenKot,      // Kitchen Order Ticket
  preBill,         // Table / Customer Check before payment
  deliveryDispatch,// Delivery Dispatch slip with customer address & COD
}

enum PaperWidth {
  roll80mm, // 80mm thermal roll (Standard POS, 48 cols)
  roll58mm, // 58mm thermal roll (Mini POS, 32 cols)
}

enum PrinterConnectionType {
  windowsSpooler, // Direct Win32 Spooler RAW printing
  usbPort,        // Direct USB/COM Port (e.g. USB001, COM1)
  networkTcp,     // Network LAN/Wi-Fi TCP IP:Port 9100
  systemDefault,  // Auto-detect attached thermal printer
}

class ReceiptItemData {
  final String? id;
  final String name;
  final int quantity;
  final double unitPrice;
  final double totalPrice;
  final String? size;
  final String? crust;
  final List<String> toppings;
  final String? notes;
  final bool isCancelled;
  final String? cancelReason;

  const ReceiptItemData({
    this.id,
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    this.size,
    this.crust,
    this.toppings = const [],
    this.notes,
    this.isCancelled = false,
    this.cancelReason,
  });
}

class ReceiptData {
  final ReceiptType type;
  final String storeName;
  final String branchName;
  final String branchCode;
  final String storePhone;
  final String? storeTaxId;
  final String orderNumber;
  final String? tokenNumber;
  final String? tableNumber;
  final String? tableName;
  final String? tableSection; // e.g. "Hall", "Main Hall", "Outdoor"
  final String? orderType; // DINE-IN, TAKEAWAY, DELIVERY, ONLINE
  final String? customerName;
  final String? customerPhone;
  final String? customerAddress;
  final String? riderName;
  final String? cashierOrServer;
  final DateTime dateTime;
  final List<ReceiptItemData> items;
  final double subtotal;
  final double discountAmount;
  final double taxAmount;
  final double taxRate;
  final double serviceChargeAmount;
  final double deliveryFee;
  final double grandTotal;
  final String paymentMethod;
  final double tenderedAmount;
  final double changeReturned;
  final String? transactionRef;
  final String? notes;
  final bool isReprint;
  final bool isModified;

  String get itemsSignature {
    final active = items
        .where((i) => !i.isCancelled)
        .map((i) => '${i.quantity}x${i.name}|${i.size ?? ""}|${i.crust ?? ""}|${i.notes ?? ""}')
        .toList()
      ..sort();
    final cancelled = items
        .where((i) => i.isCancelled)
        .map((i) => '${i.quantity}x${i.name}|${i.size ?? ""}|${i.crust ?? ""}|${i.notes ?? ""}')
        .toList()
      ..sort();
    return 'act:[${active.join(",")}]_cnc:[${cancelled.join(",")}]_sub:${subtotal.toStringAsFixed(0)}';
  }

  const ReceiptData({
    required this.type,
    this.storeName = "HUNGRY HOWIES",
    this.branchName = 'Near UOG GATE # 2 Nawaz Sharif Medical College Gujrat',
    this.branchCode = '',
    this.storePhone = '',
    this.storeTaxId,
    required this.orderNumber,
    this.tokenNumber,
    this.tableNumber,
    this.tableName,
    this.tableSection,
    this.orderType = 'DINE-IN',
    this.customerName,
    this.customerPhone,
    this.customerAddress,
    this.riderName,
    this.cashierOrServer,
    required this.dateTime,
    required this.items,
    required this.subtotal,
    this.discountAmount = 0.0,
    this.taxAmount = 0.0,
    this.taxRate = 0.0,
    this.serviceChargeAmount = 0.0,
    this.deliveryFee = 0.0,
    required this.grandTotal,
    this.paymentMethod = 'CASH',
    this.tenderedAmount = 0.0,
    this.changeReturned = 0.0,
    this.transactionRef,
    this.notes,
    this.isReprint = false,
    this.isModified = false,
  });

  ReceiptData copyWith({
    ReceiptType? type,
    String? storeName,
    String? branchName,
    String? branchCode,
    String? storePhone,
    String? storeTaxId,
    String? orderNumber,
    String? tokenNumber,
    String? tableNumber,
    String? tableName,
    String? tableSection,
    String? orderType,
    String? customerName,
    String? customerPhone,
    String? customerAddress,
    String? riderName,
    String? cashierOrServer,
    DateTime? dateTime,
    List<ReceiptItemData>? items,
    double? subtotal,
    double? discountAmount,
    double? taxAmount,
    double? taxRate,
    double? serviceChargeAmount,
    double? deliveryFee,
    double? grandTotal,
    String? paymentMethod,
    double? tenderedAmount,
    double? changeReturned,
    String? transactionRef,
    String? notes,
    bool? isReprint,
    bool? isModified,
  }) {
    return ReceiptData(
      type: type ?? this.type,
      storeName: storeName ?? this.storeName,
      branchName: branchName ?? this.branchName,
      branchCode: branchCode ?? this.branchCode,
      storePhone: storePhone ?? this.storePhone,
      storeTaxId: storeTaxId ?? this.storeTaxId,
      orderNumber: orderNumber ?? this.orderNumber,
      tokenNumber: tokenNumber ?? this.tokenNumber,
      tableNumber: tableNumber ?? this.tableNumber,
      tableName: tableName ?? this.tableName,
      tableSection: tableSection ?? this.tableSection,
      orderType: orderType ?? this.orderType,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      customerAddress: customerAddress ?? this.customerAddress,
      riderName: riderName ?? this.riderName,
      cashierOrServer: cashierOrServer ?? this.cashierOrServer,
      dateTime: dateTime ?? this.dateTime,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      discountAmount: discountAmount ?? this.discountAmount,
      taxAmount: taxAmount ?? this.taxAmount,
      taxRate: taxRate ?? this.taxRate,
      serviceChargeAmount: serviceChargeAmount ?? this.serviceChargeAmount,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      grandTotal: grandTotal ?? this.grandTotal,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      tenderedAmount: tenderedAmount ?? this.tenderedAmount,
      changeReturned: changeReturned ?? this.changeReturned,
      transactionRef: transactionRef ?? this.transactionRef,
      notes: notes ?? this.notes,
      isReprint: isReprint ?? this.isReprint,
      isModified: isModified ?? this.isModified,
    );
  }

  /// Factory helper for Restaurant Table Final Paid Receipt
  factory ReceiptData.fromTablePaid({
    required RestaurantTable table,
    required String orderId,
    required double subtotal,
    required double taxAmount,
    required double taxRate,
    required double grandTotal,
    required double tenderedAmount,
    required double changeReturned,
    double discountAmount = 0.0,
    String paymentMethod = 'CASH',
    String? cashierName,
    String storeName = "HUNGRY HOWIES",
    String branchName = 'Near UOG Gate # 2 Nawaz Sharif Medical College Gujrat.',
    String storePhone = '+1 (800) 555-HOWIE',
  }) {
    final items = <ReceiptItemData>[];
    for (final item in table.currentOrderItems) {
      final isCancelled = item['is_cancelled'] == true || item['is_cancelled'] == 1;
      if (isCancelled) continue; // Do NOT include cancelled items in final customer bill
      final name = item['name']?.toString() ?? 'Item';
      final qty = (item['quantity'] as num?)?.toInt() ?? 1;
      final unitPrice = double.tryParse(item['price']?.toString() ?? '0') ?? 0.0;
      final size = item['selected_size']?.toString();
      final crust = item['selected_crust']?.toString();
      items.add(
        ReceiptItemData(
          id: item['id']?.toString(),
          name: name,
          quantity: qty,
          unitPrice: unitPrice,
          totalPrice: unitPrice * qty,
          size: size,
          crust: crust,
          isCancelled: false,
        ),
      );
    }

    final effectiveOrderNo = orderId.isNotEmpty
        ? orderId
        : (table.activeOrderNumber ?? (table.activeOrderId ?? 'TBL-${table.tableNumber}'));

    final activeSubtotal = items.fold<double>(0.0, (s, i) => s + i.totalPrice);
    final effSubtotal = activeSubtotal > 0 ? activeSubtotal : subtotal;
    final effDiscount = discountAmount > 0 ? discountAmount : table.discountAmount;
    final effTax = taxRate > 0 ? (effSubtotal * taxRate / 100) : (table.currentOrderItems.any((i) => i['is_cancelled'] == true || i['is_cancelled'] == 1) ? (effSubtotal * 0.05) : taxAmount);
    final effGrandTotal = (effSubtotal - effDiscount + effTax).clamp(0.0, double.infinity);

    return ReceiptData(
      type: ReceiptType.customerReceipt,
      storeName: storeName,
      branchName: branchName,
      storePhone: storePhone,
      orderNumber: effectiveOrderNo,
      tokenNumber: table.tableNumber,
      tableNumber: table.tableNumber,
      tableName: table.name,
      orderType: 'DINE-IN (${table.name})',
      cashierOrServer: cashierName ?? 'Cashier',
      dateTime: DateTime.now(),
      items: items,
      subtotal: effSubtotal,
      discountAmount: effDiscount,
      taxAmount: effTax,
      taxRate: taxRate,
      grandTotal: effGrandTotal,
      paymentMethod: paymentMethod,
      tenderedAmount: tenderedAmount > 0 ? tenderedAmount : effGrandTotal,
      changeReturned: changeReturned,
    );
  }

  /// Factory helper for Restaurant Table Pre-Bill (Estimate)
  factory ReceiptData.fromTablePreBill({
    required RestaurantTable table,
    required double subtotal,
    required double taxAmount,
    required double grandTotal,
    required double taxRate,
    double discountAmount = 0.0,
    String storeName = "HUNGRY HOWIES",
    String branchName = 'Near UOG Gate # 2 Nawaz Sharif Medical College Gujrat.',
    String storePhone = '+1 (800) 555-HOWIE',
  }) {
    final items = <ReceiptItemData>[];
    for (final item in table.currentOrderItems) {
      final isCancelled = item['is_cancelled'] == true || item['is_cancelled'] == 1;
      if (isCancelled) continue; // Do NOT include cancelled items in customer pre-bill
      final name = item['name']?.toString() ?? 'Item';
      final qty = (item['quantity'] as num?)?.toInt() ?? 1;
      final unitPrice = double.tryParse(item['price']?.toString() ?? '0') ?? 0.0;
      final size = item['selected_size']?.toString();
      final crust = item['selected_crust']?.toString();
      items.add(
        ReceiptItemData(
          id: item['id']?.toString(),
          name: name,
          quantity: qty,
          unitPrice: unitPrice,
          totalPrice: unitPrice * qty,
          size: size,
          crust: crust,
          isCancelled: false,
        ),
      );
    }

    final effectiveOrderNo = table.activeOrderNumber ?? (table.activeOrderId ?? 'TBL-${table.tableNumber}');
    final activeSubtotal = items.fold<double>(0.0, (s, i) => s + i.totalPrice);
    final effSubtotal = activeSubtotal > 0 ? activeSubtotal : subtotal;
    final effDiscount = discountAmount > 0 ? discountAmount : table.discountAmount;
    final effTax = taxRate > 0 ? (effSubtotal * taxRate / 100) : (table.currentOrderItems.any((i) => i['is_cancelled'] == true || i['is_cancelled'] == 1) ? (effSubtotal * 0.05) : taxAmount);
    final effGrandTotal = (effSubtotal - effDiscount + effTax).clamp(0.0, double.infinity);

    return ReceiptData(
      type: ReceiptType.preBill,
      storeName: storeName,
      branchName: branchName,
      storePhone: storePhone,
      orderNumber: effectiveOrderNo,
      tokenNumber: table.tableNumber,
      tableNumber: table.tableNumber,
      tableName: table.name,
      orderType: 'DINE-IN PRE-BILL',
      dateTime: DateTime.now(),
      items: items,
      subtotal: effSubtotal,
      discountAmount: effDiscount,
      taxAmount: effTax,
      taxRate: taxRate,
      grandTotal: effGrandTotal,
    );
  }

  /// Factory helper for Kitchen Order Ticket (KOT) from Table
  factory ReceiptData.fromTableKot({
    required RestaurantTable table,
    required String ticketId,
    String storeName = "HUNGRY HOWIES",
    String? cashierOrServer,
    bool isReprint = false,
    bool isModified = false,
  }) {
    final items = <ReceiptItemData>[];
    for (final item in table.currentOrderItems) {
      final name = item['name']?.toString() ?? 'Item';
      final qty = (item['quantity'] as num?)?.toInt() ?? 1;
      final unitPrice = double.tryParse(item['price']?.toString() ?? '0') ?? 0.0;
      final size = item['selected_size']?.toString();
      final crust = item['selected_crust']?.toString();
      final notes = item['notes']?.toString();
      final isCancelled = item['is_cancelled'] == true ||
          item['is_cancelled'] == 1 ||
          item['is_cancelled'] == 'true' ||
          item['is_cancelled'] == '1';
      final cancelReason = item['cancel_reason']?.toString();
      items.add(
        ReceiptItemData(
          id: item['id']?.toString(),
          name: name,
          quantity: qty,
          unitPrice: unitPrice,
          totalPrice: unitPrice * qty,
          size: size,
          crust: crust,
          notes: notes,
          isCancelled: isCancelled,
          cancelReason: cancelReason,
        ),
      );
    }

    String section = table.section;
    if (section.startsWith('Main ')) {
      section = section.substring(5);
    }

    return ReceiptData(
      type: ReceiptType.kitchenKot,
      storeName: storeName,
      orderNumber: ticketId,
      tokenNumber: ticketId,
      tableNumber: table.tableNumber,
      tableName: table.name.toUpperCase(),
      tableSection: section.isNotEmpty ? section : 'Hall',
      orderType: 'DINE IN',
      cashierOrServer: cashierOrServer ?? 'SRV',
      dateTime: DateTime.now(),
      items: items,
      subtotal: table.currentBillAmount,
      grandTotal: table.currentBillAmount,
      isReprint: isReprint,
      isModified: isModified,
    );
  }

  /// Factory helper for generic OrderModel (POS)
  factory ReceiptData.fromOrderModel({
    required OrderModel order,
    ReceiptType type = ReceiptType.customerReceipt,
    double tenderedAmount = 0.0,
    double changeReturned = 0.0,
    String paymentMethod = 'CASH',
    String storeName = "HUNGRY HOWIES",
    String branchName = 'Near UOG Gate # 2 Nawaz Sharif Medical College Gujrat.',
    String storePhone = '+1 (800) 555-HOWIE',
    bool isReprint = false,
    bool isModified = false,
  }) {
    final items = order.items
        .where((i) => type == ReceiptType.kitchenKot || !i.isCancelled)
        .map((i) {
      return ReceiptItemData(
        id: i.id,
        name: i.item.name,
        quantity: i.quantity,
        unitPrice: i.unitPrice,
        totalPrice: i.totalPrice,
        size: i.selectedSize,
        crust: i.selectedCrust,
        toppings: i.extraToppings,
        notes: i.notes,
        isCancelled: i.isCancelled,
        cancelReason: i.cancelReason,
      );
    }).toList();

    String orderTypeStr = 'POS QUICK ORDER';
    if (order.type == OrderType.takeaway || order.type == OrderType.takeAway) {
      orderTypeStr = 'TAKEAWAY';
    } else if (order.type == OrderType.online || order.type == OrderType.delivery) {
      orderTypeStr = 'DELIVERY';
    } else if (order.type == OrderType.dineIn || order.type == OrderType.quickOrder) {
      orderTypeStr = 'DINE-IN';
    }

    return ReceiptData(
      type: type,
      storeName: storeName,
      branchName: branchName,
      storePhone: storePhone,
      orderNumber: order.orderNumber,
      tokenNumber: order.tokenNumber ?? order.orderNumber,
      tableNumber: order.tableId,
      orderType: orderTypeStr,
      customerName: order.customerName,
      customerPhone: order.customerPhone,
      customerAddress: order.deliveryAddress,
      dateTime: order.createdAt,
      items: items,
      subtotal: items.where((i) => !i.isCancelled).fold<double>(0.0, (s, i) => s + i.totalPrice),
      taxAmount: order.taxAmount > 0 ? order.taxAmount : order.dineInTax,
      taxRate: order.subtotal > 0 && (order.taxAmount > 0 || order.dineInTax > 0)
          ? ((order.taxAmount > 0 ? order.taxAmount : order.dineInTax) / order.subtotal * 100)
          : 0.0,
      deliveryFee: order.deliveryFee,
      grandTotal: (items.where((i) => !i.isCancelled).fold<double>(0.0, (s, i) => s + i.totalPrice) -
              order.discountAmount +
              (order.taxAmount > 0 ? order.taxAmount : order.dineInTax) +
              order.deliveryFee)
          .clamp(0.0, double.infinity),
      paymentMethod: paymentMethod,
      tenderedAmount: tenderedAmount > 0 ? tenderedAmount : order.grandTotal,
      changeReturned: changeReturned,
      isReprint: isReprint,
      isModified: isModified,
    );
  }

  /// Factory helper for TakeawayOrder
  factory ReceiptData.fromTakeawayOrder({
    required TakeawayOrder order,
    ReceiptType type = ReceiptType.customerReceipt,
    double tenderedAmount = 0.0,
    double changeReturned = 0.0,
    String paymentMethod = 'CASH',
    String storeName = "HUNGRY HOWIES",
    String branchName = 'Near UOG Gate # 2 Nawaz Sharif Medical College Gujrat.',
    String storePhone = '+1 (800) 555-HOWIE',
    bool isReprint = false,
    bool isModified = false,
  }) {
    final items = <ReceiptItemData>[];

    if (order.items.isNotEmpty) {
      for (final i in order.items) {
        if (type != ReceiptType.kitchenKot && i.isCancelled) continue;
        items.add(
          ReceiptItemData(
            id: i.id,
            name: i.item.name,
            quantity: i.quantity,
            unitPrice: i.unitPrice,
            totalPrice: i.totalPrice,
            size: i.selectedSize,
            crust: i.selectedCrust,
            toppings: i.extraToppings,
            notes: i.notes,
            isCancelled: i.isCancelled,
            cancelReason: i.cancelReason,
          ),
        );
      }
    } else {
      final rawParts = order.itemsSummary.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      for (final part in rawParts) {
        final regex = RegExp(r'^(\d+)x\s+(.+)$');
        final match = regex.firstMatch(part);
        final qty = match != null ? int.tryParse(match.group(1)!) ?? 1 : 1;
        final name = match != null ? match.group(2)! : part;
        final unitPrice = rawParts.length == 1 && order.subtotal > 0
            ? order.subtotal / qty
            : (order.subtotal / (rawParts.length * qty));

        items.add(
          ReceiptItemData(
            name: name,
            quantity: qty,
            unitPrice: unitPrice,
            totalPrice: unitPrice * qty,
          ),
        );
      }
    }

    if (items.isEmpty) {
      items.add(
        ReceiptItemData(
          name: order.itemsSummary.isNotEmpty ? order.itemsSummary : 'Takeaway Order Items',
          quantity: 1,
          unitPrice: order.subtotal,
          totalPrice: order.subtotal,
        ),
      );
    }

    final activeSubtotal = items.where((i) => !i.isCancelled).fold<double>(0.0, (s, i) => s + i.totalPrice);
    final effSubtotal = activeSubtotal > 0 ? activeSubtotal : order.subtotal;
    final effTax = order.subtotal > 0 && order.taxAmount > 0 ? (order.taxAmount / order.subtotal * effSubtotal) : 0.0;
    final effGrandTotal = (effSubtotal - order.discountAmount + effTax).clamp(0.0, double.infinity);

    return ReceiptData(
      type: type,
      storeName: storeName,
      branchName: branchName,
      storePhone: storePhone,
      orderNumber: order.id.isNotEmpty ? order.id : order.tokenNumber,
      tokenNumber: order.tokenNumber,
      orderType: 'TAKEAWAY',
      customerName: order.customerName,
      customerPhone: order.customerPhone,
      dateTime: order.createdAt,
      items: items,
      subtotal: effSubtotal,
      discountAmount: order.discountAmount,
      taxAmount: effTax,
      taxRate: effSubtotal > 0 && effTax > 0 ? (effTax / effSubtotal * 100) : 0.0,
      grandTotal: effGrandTotal,
      paymentMethod: paymentMethod,
      tenderedAmount: tenderedAmount > 0 ? tenderedAmount : effGrandTotal,
      changeReturned: changeReturned,
      isReprint: isReprint,
      isModified: isModified,
    );
  }

  /// Factory helper for DeliveryOrder
  factory ReceiptData.fromDeliveryOrder({
    required DeliveryOrder order,
    ReceiptType type = ReceiptType.customerReceipt,
    double tenderedAmount = 0.0,
    double changeReturned = 0.0,
    String? paymentMethod,
    String storeName = "HUNGRY HOWIES",
    String branchName = 'Near UOG Gate # 2 Nawaz Sharif Medical College Gujrat.',
    String storePhone = '+1 (800) 555-HOWIE',
    bool isReprint = false,
    bool isModified = false,
  }) {
    final items = <ReceiptItemData>[];
    final subtotal = (order.totalAmount - order.deliveryCharge).clamp(0.0, double.infinity);

    if (order.items.isNotEmpty) {
      for (final i in order.items) {
        if (type != ReceiptType.kitchenKot && i.isCancelled) continue;
        items.add(
          ReceiptItemData(
            id: i.id,
            name: i.item.name,
            quantity: i.quantity,
            unitPrice: i.unitPrice,
            totalPrice: i.totalPrice,
            size: i.selectedSize,
            crust: i.selectedCrust,
            toppings: i.extraToppings,
            notes: i.notes,
            isCancelled: i.isCancelled,
            cancelReason: i.cancelReason,
          ),
        );
      }
    } else {
      final rawParts = order.itemsSummary.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      for (final part in rawParts) {
        final regex = RegExp(r'^(\d+)x\s+(.+)$');
        final match = regex.firstMatch(part);
        final qty = match != null ? int.tryParse(match.group(1)!) ?? 1 : 1;
        final name = match != null ? match.group(2)! : part;
        final unitPrice = rawParts.length == 1 && subtotal > 0
            ? subtotal / qty
            : (subtotal / (rawParts.length * qty));

        items.add(
          ReceiptItemData(
            name: name,
            quantity: qty,
            unitPrice: unitPrice,
            totalPrice: unitPrice * qty,
          ),
        );
      }
    }

    if (items.isEmpty) {
      items.add(
        ReceiptItemData(
          name: order.itemsSummary.isNotEmpty ? order.itemsSummary : 'Delivery Order Items',
          quantity: 1,
          unitPrice: subtotal,
          totalPrice: subtotal,
        ),
      );
    }

    final payMethod = paymentMethod ?? order.paymentMethod;
    final activeSubtotal = items.where((i) => !i.isCancelled).fold<double>(0.0, (s, i) => s + i.totalPrice);
    final effSubtotal = activeSubtotal > 0 ? activeSubtotal : subtotal;
    final effGrandTotal = (effSubtotal + order.deliveryCharge).clamp(0.0, double.infinity);

    return ReceiptData(
      type: type,
      storeName: storeName,
      branchName: branchName,
      storePhone: storePhone,
      orderNumber: order.orderNumber,
      tokenNumber: order.orderNumber,
      orderType: 'DELIVERY (${order.orderSource})',
      customerName: order.customerName,
      customerPhone: order.customerPhone,
      customerAddress: order.deliveryAddress,
      riderName: order.riderName,
      dateTime: order.createdAt,
      items: items,
      subtotal: effSubtotal,
      deliveryFee: order.deliveryCharge,
      grandTotal: effGrandTotal,
      paymentMethod: payMethod.toUpperCase(),
      tenderedAmount: tenderedAmount > 0 ? tenderedAmount : effGrandTotal,
      changeReturned: changeReturned,
      isReprint: isReprint,
      isModified: isModified,
    );
  }

  /// Factory helper for OnlineOrderModel
  factory ReceiptData.fromOnlineOrder({
    required OnlineOrderModel order,
    ReceiptType type = ReceiptType.customerReceipt,
    double tenderedAmount = 0.0,
    double changeReturned = 0.0,
    String? paymentMethod,
    String storeName = "HUNGRY HOWIES",
    String branchName = 'Near UOG Gate # 2 Nawaz Sharif Medical College Gujrat.',
    String storePhone = '+1 (800) 555-HOWIE',
  }) {
    final items = order.items.map((i) {
      return ReceiptItemData(
        name: i.itemName,
        quantity: i.quantity,
        unitPrice: i.unitPrice,
        totalPrice: i.totalPrice,
        size: i.size,
        toppings: i.toppings,
        notes: i.specialInstructions,
      );
    }).toList();

    final payMethod = paymentMethod ?? order.paymentMethod.name.toUpperCase();
    final activeSubtotal = items.where((i) => !i.isCancelled).fold<double>(0.0, (s, i) => s + i.totalPrice);
    final effSubtotal = activeSubtotal > 0 ? activeSubtotal : order.subtotal;
    final effTax = order.subtotal > 0 && order.taxAmount > 0 ? (order.taxAmount / order.subtotal * effSubtotal) : 0.0;
    final effGrandTotal = (effSubtotal - order.discountAmount + effTax + order.deliveryFee).clamp(0.0, double.infinity);

    return ReceiptData(
      type: type,
      storeName: storeName,
      branchName: branchName,
      storePhone: storePhone,
      orderNumber: order.orderNumber,
      tokenNumber: order.orderNumber,
      orderType: 'ONLINE ORDER (${order.orderSource ?? "WEB"})',
      customerName: order.customerName,
      customerPhone: order.customerPhone,
      customerAddress: order.customerAddress,
      riderName: order.riderName,
      dateTime: order.createdAt,
      items: items,
      subtotal: effSubtotal,
      discountAmount: order.discountAmount,
      taxAmount: effTax,
      taxRate: effSubtotal > 0 && effTax > 0 ? (effTax / effSubtotal * 100) : 5.0,
      deliveryFee: order.deliveryFee,
      grandTotal: effGrandTotal,
      paymentMethod: payMethod,
      tenderedAmount: tenderedAmount > 0 ? tenderedAmount : effGrandTotal,
      changeReturned: changeReturned,
      notes: order.notes,
    );
  }
}

/// Robust, Production-Grade POS Receipt & KOT Printing Engine
/// Supports direct native Win32 Spooler raw ESC/POS, Direct USB Port, and Network TCP.
/// Bypasses all browser dialogues, Windows preview dialogs, and OneNote.
class ReceiptPrinterService {
  // Preference Keys - Customer Printer
  static const String _prefKeyPrinterName = 'pos_saved_printer_name';
  static const String _prefKeyPrinterUrl = 'pos_saved_printer_url';
  static const String _prefKeyPaperWidth = 'pos_paper_width'; // '80mm' or '58mm'
  static const String _prefKeyDirectPrint = 'pos_direct_silent_print'; // bool
  static const String _prefKeyAutoCut = 'pos_auto_cut_enabled'; // bool
  static const String _prefKeyDrawerKick = 'pos_drawer_kick_enabled'; // bool

  // Preference Keys - Kitchen / KOT Printer
  static const String _prefKeyKitchenPrinterName = 'pos_kitchen_printer_name';
  static const String _prefKeyKitchenSameAsCustomer = 'pos_kitchen_same_as_customer';
  static const String _prefKeyKitchenPaperWidth = 'pos_kitchen_paper_width';
  static const String _prefKeyKitchenAutoCut = 'pos_kitchen_auto_cut';

  /// Active database instance backing the OfflinePrintJobs spooler
  static AppDatabase? _database;

  /// Sets the database instance for OfflinePrintJobs durable spooling
  static void setDatabase(AppDatabase? db) {
    _database = db;
  }

  /// Gets the currently configured database
  static AppDatabase? get database => _database;

  /// Test hook to simulate physical thermal printer hardware in unit tests.
  /// If set, calls to physical printing route through this callback instead
  /// of native winspool / P-Invoke.
  @visibleForTesting
  static Future<bool> Function(String targetPrinter, Uint8List rawBytes, {String docName})? testPrinterFn;

  /// Test hook to capture duplicate blocked notices in tests
  @visibleForTesting
  static void Function(String notice)? testDuplicateNoticeFn;

  /// In-flight job locks to prevent concurrent duplicate spooling for the same ticket
  static final Set<String> _inFlightJobLocks = <String>{};

  // Rapid debounce map to prevent accidental double-click duplicate prints
  static final Map<String, DateTime> _recentPrintLocks = {};

  // Preference Key & Cache for strictly One-Time Kitchen (KOT) Printed Ticket IDs
  static const String _prefKeyPrintedKotList = 'pos_printed_kitchen_kot_set';
  static const String _prefKeyPrintedKotSignatures = 'pos_printed_kot_signatures_map';
  static const String _prefKeyEverPrintedKotList = 'pos_ever_printed_kitchen_kot_set';
  static final Set<String> _printedKitchenTickets = <String>{};
  static final Set<String> _everPrintedKotTickets = <String>{};
  static final Map<String, String> _printedKitchenSignatures = <String, String>{};
  static bool _hasLoadedPrintedKotSet = false;
  static bool _hasLoadedPrintedKotSignatures = false;
  static bool _hasLoadedEverPrintedKotSet = false;

  /// Loads printed kitchen tickets from local persistent storage
  static Future<Set<String>> _loadPrintedKitchenTickets() async {
    if (!_hasLoadedPrintedKotSet) {
      final prefs = await SharedPreferences.getInstance();
      final savedList = prefs.getStringList(_prefKeyPrintedKotList) ?? [];
      _printedKitchenTickets.addAll(savedList.map((e) => e.trim().toLowerCase()));
      _hasLoadedPrintedKotSet = true;
    }
    return _printedKitchenTickets;
  }

  /// Loads tickets that have ever been sent to kitchen
  static Future<Set<String>> _loadEverPrintedKotTickets() async {
    if (!_hasLoadedEverPrintedKotSet) {
      final prefs = await SharedPreferences.getInstance();
      final savedList = prefs.getStringList(_prefKeyEverPrintedKotList) ?? [];
      _everPrintedKotTickets.addAll(savedList.map((e) => e.trim().toLowerCase()));
      _hasLoadedEverPrintedKotSet = true;
    }
    return _everPrintedKotTickets;
  }

  /// Checks if an order was EVER printed to the kitchen at least once
  static Future<bool> hasOrderEverPrintedKot(
    String? idOrOrderNumber, {
    String? tokenNumber,
    AppDatabase? db,
  }) async {
    final candidateIds = expandOrderCandidates([idOrOrderNumber, tokenNumber]);
    if (candidateIds.isEmpty) return false;

    // 1. Check in-memory & persistent ever-printed set
    final everSet = await _loadEverPrintedKotTickets();
    for (final raw in candidateIds) {
      if (everSet.contains(raw.toLowerCase())) return true;
    }

    // 2. Check SQLite print jobs
    final targetDb = db ?? _database;
    if (targetDb != null) {
      for (final raw in candidateIds) {
        final jobs = await targetDb.printJobsDao.getJobsForOrder(raw);
        if (jobs.any((j) => j.jobType == PrintJobType.kitchenTicket)) {
          return true;
        }
      }
    }

    // 3. Check SharedPreferences / in-memory set as fallback
    final set = await _loadPrintedKitchenTickets();
    for (final raw in candidateIds) {
      if (set.contains(raw.toLowerCase())) return true;
    }

    return false;
  }

  /// Loads printed kitchen item signatures from local storage
  static Future<Map<String, String>> _loadPrintedKitchenSignatures() async {
    if (!_hasLoadedPrintedKotSignatures) {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_prefKeyPrintedKotSignatures);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        try {
          final decoded = jsonDecode(jsonStr);
          if (decoded is Map) {
            decoded.forEach((k, v) => _printedKitchenSignatures[k.toString().toLowerCase()] = v.toString());
          }
        } catch (_) {}
      }
      _hasLoadedPrintedKotSignatures = true;
    }
    return _printedKitchenSignatures;
  }

  /// Records an items signature when KOT is printed
  static Future<void> recordPrintedKitchenSignature(String? idOrOrderNumber, String signature) async {
    if (idOrOrderNumber == null || idOrOrderNumber.trim().isEmpty) return;
    await _loadPrintedKitchenSignatures();
    final clean = idOrOrderNumber.trim().toLowerCase();
    _printedKitchenSignatures[clean] = signature;

    // Also record under extracted numbers
    for (final m in RegExp(r'\d+').allMatches(clean)) {
      final s = m.group(0)!;
      final n = int.tryParse(s);
      if (n != null) {
        _printedKitchenSignatures[n.toString()] = signature;
        _printedKitchenSignatures[n.toString().padLeft(3, '0')] = signature;
      }
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      if (_printedKitchenSignatures.length > 3000) {
        final keysToRemove = _printedKitchenSignatures.keys.take(_printedKitchenSignatures.length - 3000).toList();
        for (final k in keysToRemove) {
          _printedKitchenSignatures.remove(k);
        }
      }
      await prefs.setString(_prefKeyPrintedKotSignatures, jsonEncode(_printedKitchenSignatures));
    } catch (e) {
      debugPrint('Error saving printed KOT signatures: $e');
    }
  }

  /// Expands an order identifier into all its permutations (exact, lowercase, 3-digit padded, extracted numbers)
  static Set<String> expandOrderCandidates(Iterable<String?> inputs) {
    final result = <String>{};
    for (final raw in inputs) {
      if (raw == null || raw.trim().isEmpty) continue;
      final c = raw.trim();
      result.add(c);
      result.add(c.toLowerCase());
      final fmt3 = EscPosBuilder.format3DigitOrderNumber(c);
      if (fmt3.isNotEmpty) {
        result.add(fmt3);
        result.add(fmt3.toLowerCase());
      }
      for (final m in RegExp(r'\d+').allMatches(c)) {
        final s = m.group(0)!;
        final n = int.tryParse(s);
        if (n != null) {
          result.add(n.toString());
          result.add(n.toString().padLeft(3, '0'));
        }
      }
    }
    return result;
  }

  /// Checks if a kitchen ticket / order has already been printed once for the exact current items.
  /// If [currentItemsSignature] is provided and does not match the recorded signature,
  /// returns false because the order was modified and must be allowed to print!
  static Future<bool> isKitchenReceiptPrinted(
    String? idOrOrderNumber, {
    String? tokenNumber,
    String? currentItemsSignature,
    AppDatabase? db,
  }) async {
    final candidateIds = expandOrderCandidates([idOrOrderNumber, tokenNumber]);
    if (candidateIds.isEmpty) return false;

    // Test receipts are never blocked
    for (final raw in candidateIds) {
      final clean = raw.toLowerCase();
      if (clean == 'kot-101' || clean == 'kot-test' || clean == 'test' || clean == 'kitchen test') {
        return false;
      }
    }

    // 1. Tier 5 Durable Winspool KOT Deduplication: Check OfflinePrintJobs in Drift SQLite
    final targetDb = db ?? _database;
    bool isInPrintedSet = false;
    String matchedKey = candidateIds.first.toLowerCase();

    if (targetDb != null) {
      for (final raw in candidateIds) {
        final job = await targetDb.printJobsDao.getPrintedJobForOrder(raw, PrintJobType.kitchenTicket);
        if (job != null) {
          isInPrintedSet = true;
          matchedKey = raw.toLowerCase();
          break;
        }
      }
    }

    // 2. Check SharedPreferences / in-memory set as fallback
    if (!isInPrintedSet) {
      final set = await _loadPrintedKitchenTickets();
      for (final raw in candidateIds) {
        final clean = raw.toLowerCase();
        if (set.contains(clean)) {
          isInPrintedSet = true;
          matchedKey = clean;
          break;
        }
      }
    }

    // If it is not in the printed set (e.g. unmarketed when modified or cancelled), it can print
    if (!isInPrintedSet) {
      return false;
    }

    // 3. If it was printed, check if current items signature differs from the printed signature.
    // If the items were modified or cancelled, signature differs -> return false so updated KOT can print!
    if (currentItemsSignature != null && currentItemsSignature.isNotEmpty) {
      final sigMap = await _loadPrintedKitchenSignatures();
      String? recordedSig;
      for (final raw in candidateIds) {
        final clean = raw.toLowerCase();
        recordedSig = sigMap[clean] ??
            sigMap[clean.replaceAll('_cancel', '')] ??
            sigMap[clean.replaceAll(RegExp(r'[^0-9]'), '')];
        if (recordedSig != null) break;
      }

      // If recordedSig is null (signature was cleared/un-marked when order was modified),
      // order is unlocked and updated KOT can print!
      if (recordedSig == null) {
        debugPrint('🔔 KOT No signature found for [$matchedKey]: Order was unlocked/modified. Updated print unlocked.');
        return false;
      }

      if (recordedSig != currentItemsSignature) {
        debugPrint('🔔 KOT Signature mismatch for [$matchedKey]: Order was modified ($recordedSig != $currentItemsSignature). Updated print unlocked.');
        return false;
      }
    }

    // If it was already printed and items have NOT been modified/cancelled -> return true (BLOCKED!)
    return true;
  }

  /// Marks a kitchen receipt as printed (persisted across app reloads via Drift OfflinePrintJobs)
  static Future<void> markKitchenReceiptPrinted(
    String? idOrOrderNumber, {
    String? signature,
    AppDatabase? db,
  }) async {
    if (idOrOrderNumber == null || idOrOrderNumber.trim().isEmpty) return;
    final cleanId = idOrOrderNumber.trim().toLowerCase();

    if (cleanId == 'kot-101' || cleanId == 'kot-test' || cleanId == 'test' || cleanId == 'kitchen test') {
      return;
    }

    // 1. Mark in Drift SQLite OfflinePrintJobs table for persistent durability across app restarts
    final targetDb = db ?? _database;
    if (targetDb != null) {
      try {
        final jobs = await targetDb.printJobsDao.getJobsForOrder(idOrOrderNumber.trim());
        bool updated = false;
        for (final job in jobs) {
          if (job.jobType == PrintJobType.kitchenTicket && job.status != PrintJobStatus.printed) {
            await targetDb.printJobsDao.markJobStatus(job.id, PrintJobStatus.printed);
            updated = true;
          }
        }
        if (!updated && jobs.isEmpty) {
          await targetDb.printJobsDao.insertJob(
            OfflinePrintJobsCompanion(
              jobType: const Value(PrintJobType.kitchenTicket),
              orderId: Value(idOrOrderNumber.trim()),
              printerTarget: const Value('KITCHEN_WIN_SPOOLER'),
              rawEscPosData: Value(Uint8List.fromList(utf8.encode('KOT_$cleanId'))),
              status: const Value(PrintJobStatus.printed),
              retryCount: const Value(0),
              createdAt: Value(DateTime.now()),
            ),
          );
        }
      } catch (e) {
        debugPrint('Error marking kitchen receipt printed in SQLite: $e');
      }
    }

    // 2. Mark in-memory and SharedPreferences cache
    await _loadPrintedKitchenTickets();
    await _loadEverPrintedKotTickets();
    final candidates = expandOrderCandidates([idOrOrderNumber]);
    for (final c in candidates) {
      _printedKitchenTickets.add(c.toLowerCase());
      _everPrintedKotTickets.add(c.toLowerCase());
      if (signature != null && signature.isNotEmpty) {
        await recordPrintedKitchenSignature(c.toLowerCase(), signature);
      }
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final listToSave = _printedKitchenTickets.toList();
      if (listToSave.length > 3000) {
        listToSave.removeRange(0, listToSave.length - 3000);
      }
      await prefs.setStringList(_prefKeyPrintedKotList, listToSave);

      final everListToSave = _everPrintedKotTickets.toList();
      if (everListToSave.length > 3000) {
        everListToSave.removeRange(0, everListToSave.length - 3000);
      }
      await prefs.setStringList(_prefKeyEverPrintedKotList, everListToSave);
    } catch (e) {
      debugPrint('Error saving printed KOT set: $e');
    }
  }

  /// Comprehensive reset of KOT print lock and signatures for all permutations of an order
  static Future<void> unmarkOrderKitchenReceiptPrinted({
    String? orderId,
    String? orderNumber,
    String? tokenNumber,
    String? tableNumber,
    bool clearHistory = false,
    AppDatabase? db,
  }) async {
    final idsToUnmark = expandOrderCandidates([orderId, orderNumber, tokenNumber, tableNumber]);
    final cancelVariations = <String>{};
    for (final id in idsToUnmark) {
      cancelVariations.add('${id}_cancel');
      if (id.endsWith('_cancel')) {
        cancelVariations.add(id.replaceAll('_cancel', ''));
      }
    }
    idsToUnmark.addAll(cancelVariations);

    final targetDb = db ?? _database;
    if (targetDb != null) {
      for (final id in idsToUnmark) {
        try {
          await targetDb.printJobsDao.deleteJobsForOrder(id);
        } catch (e) {
          debugPrint('Error deleting print jobs in SQLite for $id: $e');
        }
      }
    }

    await _loadPrintedKitchenTickets();
    await _loadPrintedKitchenSignatures();
    await _loadEverPrintedKotTickets();

    for (final id in idsToUnmark) {
      _printedKitchenTickets.remove(id.toLowerCase());
      _printedKitchenSignatures.remove(id.toLowerCase());
      if (clearHistory) {
        _everPrintedKotTickets.remove(id.toLowerCase());
      }
      _recentPrintLocks.remove('kitchenKot_$id');
      _recentPrintLocks.remove('kitchenKot_${id.toLowerCase()}');
      _inFlightJobLocks.remove('kitchenKot_$id');
      _inFlightJobLocks.remove('kitchenKot_${id.toLowerCase()}');
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_prefKeyPrintedKotList, _printedKitchenTickets.toList());
      await prefs.setString(_prefKeyPrintedKotSignatures, jsonEncode(_printedKitchenSignatures));
      if (clearHistory) {
        await prefs.setStringList(_prefKeyEverPrintedKotList, _everPrintedKotTickets.toList());
      }
      debugPrint('🔄 KOT print lock and signatures reset for order keys: $idsToUnmark');
    } catch (e) {
      debugPrint('Error unmarking printed KOT: $e');
    }
  }

  /// Unmarks a kitchen receipt as printed (called when an order is modified/items added/cancelled)
  /// so that the kitchen ticket can be printed one more time for the updated order.
  static Future<void> unmarkKitchenReceiptPrinted(String? idOrOrderNumber) async {
    if (idOrOrderNumber == null || idOrOrderNumber.trim().isEmpty) return;
    await unmarkOrderKitchenReceiptPrinted(orderNumber: idOrOrderNumber);
  }

  /// Clears printed kitchen receipts history (e.g., daily reset)
  static Future<void> clearPrintedKitchenHistory() async {
    _printedKitchenTickets.clear();
    _everPrintedKotTickets.clear();
    _hasLoadedPrintedKotSet = true;
    _hasLoadedEverPrintedKotSet = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefKeyPrintedKotList);
      await prefs.remove(_prefKeyEverPrintedKotList);
    } catch (e) {
      debugPrint('Error clearing printed KOT history: $e');
    }
  }

  /// Reset all internal caches and test hooks for unit testing
  @visibleForTesting
  static void resetForTesting() {
    _printedKitchenTickets.clear();
    _printedKitchenSignatures.clear();
    _everPrintedKotTickets.clear();
    _hasLoadedPrintedKotSet = false;
    _hasLoadedPrintedKotSignatures = false;
    _hasLoadedEverPrintedKotSet = false;
    _inFlightJobLocks.clear();
    _recentPrintLocks.clear();
    testPrinterFn = null;
    testDuplicateNoticeFn = null;
    _database = null;
    _cachedPrinterName = null;
    _cachedPrinterUrl = null;
    _cachedPaperWidth = null;
    _cachedDirectPrint = null;
    _cachedAutoCut = null;
    _cachedDrawerKick = null;
    _cachedKitchenPrinterName = null;
    _cachedKitchenSameAsCustomer = null;
    _cachedKitchenPaperWidth = null;
    _cachedKitchenAutoCut = null;
    _hasLoadedSettings = false;
  }

  /// Clears in-flight debounce locks for testing
  @visibleForTesting
  static void clearRecentPrintLocks() {
    _recentPrintLocks.clear();
    _inFlightJobLocks.clear();
  }

  // In-memory high-speed cache for printer settings to eliminate async disk I/O per print
  static String? _cachedPrinterName;
  static String? _cachedPrinterUrl;
  static PaperWidth? _cachedPaperWidth;
  static bool? _cachedDirectPrint;
  static bool? _cachedAutoCut;
  static bool? _cachedDrawerKick;
  static String? _cachedKitchenPrinterName;
  static bool? _cachedKitchenSameAsCustomer;
  static PaperWidth? _cachedKitchenPaperWidth;
  static bool? _cachedKitchenAutoCut;
  static bool _hasLoadedSettings = false;

  static Future<void> _ensureSettingsLoaded() async {
    if (_hasLoadedSettings) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _cachedPrinterName = prefs.getString(_prefKeyPrinterName);
      _cachedPrinterUrl = prefs.getString(_prefKeyPrinterUrl);
      final widthStr = prefs.getString(_prefKeyPaperWidth) ?? '80mm';
      _cachedPaperWidth = widthStr == '58mm' ? PaperWidth.roll58mm : PaperWidth.roll80mm;
      _cachedDirectPrint = prefs.getBool(_prefKeyDirectPrint) ?? true;
      _cachedAutoCut = prefs.getBool(_prefKeyAutoCut) ?? true;
      _cachedDrawerKick = prefs.getBool(_prefKeyDrawerKick) ?? false;
      _cachedKitchenPrinterName = prefs.getString(_prefKeyKitchenPrinterName);
      _cachedKitchenSameAsCustomer = prefs.getBool(_prefKeyKitchenSameAsCustomer) ?? true;
      final kWidthStr = prefs.getString(_prefKeyKitchenPaperWidth) ?? '80mm';
      _cachedKitchenPaperWidth = kWidthStr == '58mm' ? PaperWidth.roll58mm : PaperWidth.roll80mm;
      _cachedKitchenAutoCut = prefs.getBool(_prefKeyKitchenAutoCut) ?? true;
      _hasLoadedSettings = true;
    } catch (_) {
      _hasLoadedSettings = true;
    }
  }

  // ---------------------------------------------------------------------------
  // Preferences Management
  // ---------------------------------------------------------------------------
  static Future<String?> getSavedPrinterName() async {
    await _ensureSettingsLoaded();
    if (_cachedPrinterName != null && _cachedPrinterName!.toLowerCase().startsWith('port:')) {
      return null;
    }
    return _cachedPrinterName;
  }

  static Future<String?> getSavedPrinterUrl() async {
    await _ensureSettingsLoaded();
    return _cachedPrinterUrl;
  }

  static Future<PaperWidth> getSavedPaperWidth() async {
    await _ensureSettingsLoaded();
    return _cachedPaperWidth ?? PaperWidth.roll80mm;
  }

  static Future<bool> isDirectPrintEnabled() async {
    await _ensureSettingsLoaded();
    return _cachedDirectPrint ?? true;
  }

  static Future<bool> isAutoCutEnabled() async {
    await _ensureSettingsLoaded();
    return _cachedAutoCut ?? true;
  }

  static Future<bool> isDrawerKickEnabled() async {
    await _ensureSettingsLoaded();
    return _cachedDrawerKick ?? false;
  }

  // Check if a printer is configured and not None/empty
  static bool isPrinterConfigured(String? printerName) {
    if (printerName == null) return false;
    final trimmed = printerName.trim();
    if (trimmed.isEmpty ||
        trimmed.toLowerCase() == 'none' ||
        trimmed.toLowerCase() == 'none (disabled)' ||
        trimmed.toLowerCase().startsWith('none') ||
        trimmed.toLowerCase().startsWith('port:')) {
      return false;
    }
    return true;
  }

  // Kitchen Printer Preferences
  static Future<String?> getKitchenPrinterName() async {
    await _ensureSettingsLoaded();
    if (_cachedKitchenPrinterName != null && _cachedKitchenPrinterName!.toLowerCase().startsWith('port:')) {
      return null;
    }
    return _cachedKitchenPrinterName;
  }

  static Future<bool> isKitchenSameAsCustomer() async {
    await _ensureSettingsLoaded();
    return _cachedKitchenSameAsCustomer ?? false;
  }

  static Future<PaperWidth> getKitchenPaperWidth() async {
    await _ensureSettingsLoaded();
    return _cachedKitchenPaperWidth ?? PaperWidth.roll80mm;
  }

  static Future<bool> isKitchenAutoCutEnabled() async {
    await _ensureSettingsLoaded();
    return _cachedKitchenAutoCut ?? true;
  }

  static Future<void> savePrinterSettings({
    String? printerName,
    String? printerUrl,
    PaperWidth? paperWidth,
    bool? directPrint,
    bool? autoCut,
    bool? drawerKick,
    String? kitchenPrinterName,
    bool? kitchenSameAsCustomer,
    PaperWidth? kitchenPaperWidth,
    bool? kitchenAutoCut,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (printerName != null) {
      await prefs.setString(_prefKeyPrinterName, printerName);
      _cachedPrinterName = printerName;
    }
    if (printerUrl != null) {
      await prefs.setString(_prefKeyPrinterUrl, printerUrl);
      _cachedPrinterUrl = printerUrl;
    }
    if (paperWidth != null) {
      await prefs.setString(_prefKeyPaperWidth, paperWidth == PaperWidth.roll58mm ? '58mm' : '80mm');
      _cachedPaperWidth = paperWidth;
    }
    if (directPrint != null) {
      await prefs.setBool(_prefKeyDirectPrint, directPrint);
      _cachedDirectPrint = directPrint;
    }
    if (autoCut != null) {
      await prefs.setBool(_prefKeyAutoCut, autoCut);
      _cachedAutoCut = autoCut;
    }
    if (drawerKick != null) {
      await prefs.setBool(_prefKeyDrawerKick, drawerKick);
      _cachedDrawerKick = drawerKick;
    }

    if (kitchenPrinterName != null) {
      await prefs.setString(_prefKeyKitchenPrinterName, kitchenPrinterName);
      _cachedKitchenPrinterName = kitchenPrinterName;
    }
    if (kitchenSameAsCustomer != null) {
      await prefs.setBool(_prefKeyKitchenSameAsCustomer, kitchenSameAsCustomer);
      _cachedKitchenSameAsCustomer = kitchenSameAsCustomer;
    }
    if (kitchenPaperWidth != null) {
      await prefs.setString(_prefKeyKitchenPaperWidth, kitchenPaperWidth == PaperWidth.roll58mm ? '58mm' : '80mm');
      _cachedKitchenPaperWidth = kitchenPaperWidth;
    }
    if (kitchenAutoCut != null) {
      await prefs.setBool(_prefKeyKitchenAutoCut, kitchenAutoCut);
      _cachedKitchenAutoCut = kitchenAutoCut;
    }
    _hasLoadedSettings = true;
  }

  // ---------------------------------------------------------------------------
  // Discover Attached Printers & Ports
  // ---------------------------------------------------------------------------
  static Future<List<Printer>> getAvailablePrinters() async {
    if (kIsWeb) return [];
    try {
      final spoolerPrinters = await Printing.listPrinters();
      return spoolerPrinters;
    } catch (e) {
      debugPrint('Printer discovery notice: $e');
      return [];
    }
  }

  static Future<List<String>> getAllPrinterOptions() async {
    final Set<String> options = {};

    // 1. Query Windows Desktop spooler if running natively (instant, <50ms)
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      try {
        final winPrinters = await NativeWin32Printer.getInstalledWindowsPrinters();
        for (final p in winPrinters) {
          final lower = p.toLowerCase();
          if (!lower.contains('pdf') &&
              !lower.contains('onenote') &&
              !lower.contains('fax') &&
              !lower.contains('xps') &&
              !lower.contains('root print queue')) {
            options.add(p);
          }
        }
      } catch (e) {
        debugPrint('Native Win32 printer query notice: $e');
      }
    }

    // 2. Query local backend printer API (required for Web and multi-device access, actual printers only)
    try {
      final res = await http.get(Uri.parse('${ApiConfig.baseUrl}/printer/list')).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded['success'] == true && decoded['data'] != null) {
          final pList = (decoded['data']['printers'] as List?)?.map((e) => e.toString()) ?? [];
          for (final p in pList) {
            final lower = p.toLowerCase();
            if (!lower.contains('pdf') &&
                !lower.contains('onenote') &&
                !lower.contains('fax') &&
                !lower.contains('xps') &&
                !lower.contains('root print queue')) {
              options.add(p);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Backend printer list discovery notice: $e');
    }

    return options.toList();
  }

  // ---------------------------------------------------------------------------
  // Direct Silent Print Execution (Kitchen Dual Print + POS Single Print)
  // ---------------------------------------------------------------------------
  /// Directly prints the receipt to the configured physical thermal printer(s).
  /// - Kitchen KOT: Prints to BOTH Kitchen Printer AND POS Printer.
  /// - All Other Receipts (Customer bill, Pre-bill, Takeaway, Delivery): Prints ONLY to POS Printer.
  static Future<bool> printReceipt({
    BuildContext? context,
    required ReceiptData receipt,
    bool forceDialog = false,
    bool forcePrint = false,
    AppDatabase? db,
  }) async {
    final targetDb = db ?? _database;

    // Debounce protection: Prevent duplicate rapid clicks within 1.5 seconds (bypassed if forcePrint)
    final lockKey = '${receipt.type.name}_${receipt.orderNumber}';
    final now = DateTime.now();
    if (!forcePrint && _recentPrintLocks.containsKey(lockKey)) {
      final lastPrint = _recentPrintLocks[lockKey]!;
      if (now.difference(lastPrint).inMilliseconds < 1500) {
        debugPrint('Debounce: Print request ignored for $lockKey (already processing)');
        return true;
      }
    }
    _recentPrintLocks[lockKey] = now;

    // Concurrency lock (job id lock)
    if (_inFlightJobLocks.contains(lockKey)) {
      debugPrint('Concurrency lock: Print request in-flight for $lockKey');
      return true;
    }
    _inFlightJobLocks.add(lockKey);

    try {
      final isKot = receipt.type == ReceiptType.kitchenKot;

      // -----------------------------------------------------------------------
      // CANCELLED-ITEM HANDLING (cancelled-item tickets only for items already printed)
      // -----------------------------------------------------------------------
      if (isKot) {
        final hasCancelled = receipt.items.any((i) => i.isCancelled);
        if (hasCancelled) {
          final hasEverPrinted = await hasOrderEverPrintedKot(
            receipt.orderNumber,
            tokenNumber: receipt.tokenNumber,
            db: targetDb,
          );

          if (!hasEverPrinted && !receipt.isModified && !forcePrint) {
            // If all items are cancelled and ticket was never printed, skip printing
            if (receipt.items.every((i) => i.isCancelled)) {
              debugPrint('Skipping KOT print: All items are cancelled and order was never printed to kitchen.');
              return true;
            }
            // If some items are active and some cancelled, only print active items on initial unprinted KOT
            final activeOnly = receipt.items.where((i) => !i.isCancelled).toList();
            receipt = receipt.copyWith(items: activeOnly);
          }
          // If the order WAS previously printed to the kitchen (hasEverPrinted == true)
          // or is modified/forcePrint: KEEP all cancelled items so they are printed with strikethrough!
        }
      }

      // -----------------------------------------------------------------------
      // STRICT ONE-TIME KITCHEN PRINT ENFORCEMENT (Tier 5 of §15.2)
      // If an unmodified kitchen ticket has already been printed once, reject duplicate prints.
      // If the order has been modified, or if forcePrint/isReprint is set, allow printing!
      // -----------------------------------------------------------------------
      if (isKot && !forcePrint && !receipt.isReprint) {
        final isTestTicket = (receipt.cashierOrServer?.toUpperCase() == 'KITCHEN TEST') ||
            receipt.orderNumber == 'KOT-101' ||
            receipt.orderNumber == 'KOT-TEST';

        if (!isTestTicket) {
          final isAlreadyPrinted = await isKitchenReceiptPrinted(
            receipt.orderNumber,
            tokenNumber: receipt.tokenNumber,
            currentItemsSignature: receipt.itemsSignature,
            db: targetDb,
          );

          if (isAlreadyPrinted) {
            final displayNum = EscPosBuilder.format3DigitOrderNumber(receipt.orderNumber);
            debugPrint('⛔ KITCHEN PRINT BLOCKED: Order #$displayNum has already been printed once.');

            const duplicateNotice = 'Already sent to the kitchen';
            testDuplicateNoticeFn?.call(duplicateNotice);

            if (context != null && context.mounted) {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.block_rounded, color: Colors.white, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          duplicateNotice,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: const Color(0xFFDC2626),
                  duration: const Duration(seconds: 3),
                ),
              );
            }
            return false;
          }
        }
      }

      // 1. Resolve POS Counter Printer
      final rawPos = await getSavedPrinterName();
      String? posPrinter;
      if (isPrinterConfigured(rawPos)) {
        posPrinter = rawPos;
      } else {
        final autoResolved = await _resolveBestThermalPrinter();
        if (isPrinterConfigured(autoResolved)) {
          posPrinter = autoResolved;
        }
      }

      final posWidth = await getSavedPaperWidth();
      final posCut = await isAutoCutEnabled();
      final posDrawer = !isKot && await isDrawerKickEnabled();

      if (isKot) {
        // =========================================================================
        // KITCHEN ORDER TICKET (KOT) PRINTING
        // =========================================================================
        final rawKitchen = await getKitchenPrinterName();
        final String? kitchenPrinter = isPrinterConfigured(rawKitchen) ? rawKitchen : null;
        final kitchenWidth = await getKitchenPaperWidth();
        final kitchenCut = await isKitchenAutoCutEnabled();

        if (kitchenPrinter == null && posPrinter == null) {
          debugPrint('No printer configured for Kitchen KOT (Kitchen: None, POS: None). Skipping print.');
          return true;
        }

        final hasCancelled = receipt.items.any((i) => i.isCancelled);

        // Case 1: Both configured and set to the SAME printer
        if (kitchenPrinter != null && posPrinter != null && kitchenPrinter == posPrinter) {
          final prebuiltBytes = hasCancelled
              ? ((await generateRasterEscPosBytes(receipt, kitchenWidth, autoCut: kitchenCut, openCashDrawer: false, isKitchenPrinter: true)) ??
                  EscPosBuilder.buildReceiptBytes(receipt: receipt, paperWidth: kitchenWidth, autoCut: kitchenCut, openCashDrawer: false, isKitchenPrinter: true))
              : EscPosBuilder.buildReceiptBytes(receipt: receipt, paperWidth: kitchenWidth, autoCut: kitchenCut, openCashDrawer: false, isKitchenPrinter: true);

          final printResult = await _printSingleJob(
            receipt: receipt,
            targetPrinter: kitchenPrinter,
            paperWidth: kitchenWidth,
            autoCut: kitchenCut,
            drawerKick: false,
            prebuiltBytes: prebuiltBytes,
            isKitchenPrinter: true,
            db: targetDb,
          );

          final success = printResult.success;
          final isTestTicket = (receipt.cashierOrServer?.toUpperCase() == 'KITCHEN TEST') ||
              receipt.orderNumber == 'KOT-101' ||
              receipt.orderNumber == 'KOT-TEST';
          if (success && !isTestTicket) {
            await markKitchenReceiptPrinted(receipt.orderNumber, signature: receipt.itemsSignature, db: targetDb);
            if (receipt.tokenNumber != null && receipt.tokenNumber!.isNotEmpty) {
              await markKitchenReceiptPrinted(receipt.tokenNumber!, signature: receipt.itemsSignature, db: targetDb);
            }
            if (receipt.tableNumber != null && receipt.tableNumber!.isNotEmpty) {
              await markKitchenReceiptPrinted(receipt.tableNumber!, signature: receipt.itemsSignature, db: targetDb);
            }
          }

          if (success && context != null && context.mounted) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Kitchen KOT printed to [$kitchenPrinter]',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ],
                ),
                backgroundColor: const Color(0xFF16A34A),
                duration: const Duration(seconds: 2),
              ),
            );
          } else if (!success && context != null && context.mounted) {
            _showPrinterFailureSnackBar(context, printResult.jobId, targetDb);
          }
          return success;
        }

        // Case 2: One or both distinct printers configured
        final List<Future<_JobPrintResult>> printJobs = [];
        bool printingKitchen = false;
        bool printingPos = false;

        if (kitchenPrinter != null) {
          printingKitchen = true;
          final prebuiltKitchenBytes = hasCancelled
              ? ((await generateRasterEscPosBytes(receipt, kitchenWidth, autoCut: kitchenCut, openCashDrawer: false, isKitchenPrinter: true)) ??
                  EscPosBuilder.buildReceiptBytes(receipt: receipt, paperWidth: kitchenWidth, autoCut: kitchenCut, openCashDrawer: false, isKitchenPrinter: true))
              : EscPosBuilder.buildReceiptBytes(receipt: receipt, paperWidth: kitchenWidth, autoCut: kitchenCut, openCashDrawer: false, isKitchenPrinter: true);

          printJobs.add(
            _printSingleJob(
              receipt: receipt,
              targetPrinter: kitchenPrinter,
              paperWidth: kitchenWidth,
              autoCut: kitchenCut,
              drawerKick: false,
              prebuiltBytes: prebuiltKitchenBytes,
              isKitchenPrinter: true,
              db: targetDb,
            ),
          );
        }

        if (posPrinter != null) {
          printingPos = true;
          final prebuiltPosBytes = hasCancelled
              ? ((await generateRasterEscPosBytes(receipt, posWidth, autoCut: posCut, openCashDrawer: false, isKitchenPrinter: false)) ??
                  EscPosBuilder.buildReceiptBytes(receipt: receipt, paperWidth: posWidth, autoCut: posCut, openCashDrawer: false, isKitchenPrinter: false))
              : EscPosBuilder.buildReceiptBytes(receipt: receipt, paperWidth: posWidth, autoCut: posCut, openCashDrawer: false, isKitchenPrinter: false);

          printJobs.add(
            _printSingleJob(
              receipt: receipt,
              targetPrinter: posPrinter,
              paperWidth: posWidth,
              autoCut: posCut,
              drawerKick: false,
              prebuiltBytes: prebuiltPosBytes,
              isKitchenPrinter: false,
              db: targetDb,
            ),
          );
        }

        final printResults = await Future.wait<_JobPrintResult>(printJobs);
        final bool overallSuccess = printResults.any((s) => s.success);
        final int? failedJobId = printResults.where((r) => !r.success && r.jobId != null).map((r) => r.jobId!).firstOrNull;

        final isTestTicket = (receipt.cashierOrServer?.toUpperCase() == 'KITCHEN TEST') ||
            receipt.orderNumber == 'KOT-101' ||
            receipt.orderNumber == 'KOT-TEST';
        if (overallSuccess && !isTestTicket) {
          await markKitchenReceiptPrinted(receipt.orderNumber, signature: receipt.itemsSignature, db: targetDb);
          if (receipt.tokenNumber != null && receipt.tokenNumber!.isNotEmpty) {
            await markKitchenReceiptPrinted(receipt.tokenNumber!, signature: receipt.itemsSignature, db: targetDb);
          }
          if (receipt.tableNumber != null && receipt.tableNumber!.isNotEmpty) {
            await markKitchenReceiptPrinted(receipt.tableNumber!, signature: receipt.itemsSignature, db: targetDb);
          }
        }

        if (overallSuccess && context != null && context.mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          String successMsg;
          if (printingKitchen && printingPos) {
            successMsg = 'Kitchen KOT printed to Kitchen [$kitchenPrinter] + POS [$posPrinter]';
          } else if (printingKitchen) {
            successMsg = 'Kitchen KOT printed to Kitchen [$kitchenPrinter]';
          } else {
            successMsg = 'Kitchen KOT printed to POS [$posPrinter]';
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      successMsg,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF16A34A),
              duration: const Duration(seconds: 2),
            ),
          );
        } else if (!overallSuccess && context != null && context.mounted) {
          _showPrinterFailureSnackBar(context, failedJobId, targetDb);
        }
        return overallSuccess;
      } else {
        // =========================================================================
        // ALL OTHER RECEIPTS (Customer Bills, Pre-Bills, Takeaway, Delivery)
        // =========================================================================
        if (posPrinter == null) {
          debugPrint('POS Printer is not selected (None). Skipping customer receipt print.');
          if (context != null && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('POS printer is not configured (None). Please select a printer in Printer Setup.'),
                backgroundColor: Color(0xFFD97706),
                duration: Duration(seconds: 2),
              ),
            );
          }
          return false;
        }

        final printResult = await _printSingleJob(
          receipt: receipt,
          targetPrinter: posPrinter,
          paperWidth: posWidth,
          autoCut: posCut,
          drawerKick: posDrawer,
          db: targetDb,
        );

        final success = printResult.success;
        if (success && context != null && context.mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Customer Receipt printed to POS Printer [$posPrinter]',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF16A34A),
              duration: const Duration(seconds: 2),
            ),
          );
        } else if (!success && context != null && context.mounted) {
          _showPrinterFailureSnackBar(context, printResult.jobId, targetDb);
        }
        return success;
      }
    } catch (e, stack) {
      debugPrint('Printing error: $e\n$stack');
      if (context != null && context.mounted) {
        _showPrinterFailureSnackBar(context, null, targetDb);
      }
      return false;
    } finally {
      _inFlightJobLocks.remove(lockKey);
    }
  }

  /// Displays non-blocking warning snackbar with 'Retry Print' action per Spec §15.4 & §21 (Decision 1)
  static void _showPrinterFailureSnackBar(BuildContext context, int? jobId, AppDatabase? db) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Printer out of paper / Printer unavailable',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFDC2626),
        duration: const Duration(seconds: 8),
        action: jobId != null
            ? SnackBarAction(
                label: 'Retry Print',
                textColor: Colors.white,
                onPressed: () {
                  retryPrintJob(jobId, context: context, db: db);
                },
              )
            : null,
      ),
    );
  }

  /// Internal helper to send a single print job to a specific physical printer
  static Future<_JobPrintResult> _printSingleJob({
    required ReceiptData receipt,
    required String targetPrinter,
    required PaperWidth paperWidth,
    required bool autoCut,
    required bool drawerKick,
    Uint8List? prebuiltBytes,
    bool isKitchenPrinter = false,
    AppDatabase? db,
  }) async {
    final targetDb = db ?? _database;
    final String jobType = (isKitchenPrinter || receipt.type == ReceiptType.kitchenKot)
        ? PrintJobType.kitchenTicket
        : PrintJobType.customerReceipt;

    int? jobId;

    try {
      final hasCancelledItems = receipt.items.any((i) => i.isCancelled);

      // 1. GENERATE ESC/POS BINARY (or reuse pre-rendered byte buffer)
      Uint8List? escposBytes = prebuiltBytes;
      if (escposBytes == null) {
        if (hasCancelledItems) {
          escposBytes = await generateRasterEscPosBytes(
            receipt,
            paperWidth,
            autoCut: autoCut,
            openCashDrawer: drawerKick,
            isKitchenPrinter: isKitchenPrinter,
          );
        }

        escposBytes ??= EscPosBuilder.buildReceiptBytes(
          receipt: receipt,
          paperWidth: paperWidth,
          autoCut: autoCut,
          openCashDrawer: drawerKick,
          isKitchenPrinter: isKitchenPrinter,
        );
      }

      // 2. ENQUEUE IN OFFLINEPRINTJOBS TABLE (§5.4.3: Durable Hardware Print Spooler Queue)
      if (targetDb != null) {
        try {
          final existingQueued = (jobType == PrintJobType.customerReceipt)
              ? await targetDb.printJobsDao.getQueuedJobForOrder(
                  receipt.orderNumber,
                  jobType,
                )
              : null;
          if (existingQueued != null) {
            jobId = existingQueued.id;
            await targetDb.printJobsDao.updateJobPayloadAndTarget(
              jobId,
              escposBytes,
              targetPrinter,
            );
          } else {
            jobId = await targetDb.printJobsDao.insertJob(
              OfflinePrintJobsCompanion(
                jobType: Value(jobType),
                orderId: Value(receipt.orderNumber),
                printerTarget: Value(targetPrinter),
                rawEscPosData: Value(escposBytes),
                status: const Value(PrintJobStatus.queued),
                retryCount: const Value(0),
                createdAt: Value(DateTime.now()),
              ),
            );
          }
        } catch (e) {
          debugPrint('Notice enqueueing OfflinePrintJob: $e');
        }
      }

      // 3. HARDWARE THERMAL PRINT EXECUTION VIA NATIVE WIN32 / TEST HOOK
      bool printSuccess = false;
      try {
        printSuccess = await _sendRawBytesToPrinter(
          targetPrinter: targetPrinter,
          escposBytes: escposBytes,
          docName: '${receipt.type.name}_${receipt.orderNumber}',
          receipt: receipt,
          paperWidth: paperWidth,
          isKitchenPrinter: isKitchenPrinter,
        );
      } catch (e) {
        debugPrint('Hardware printing threw exception: $e');
        printSuccess = false;
      }

      // 4. UPDATE STATUS IN OFFLINEPRINTJOBS: QUEUED -> PRINTED / FAILED
      if (targetDb != null && jobId != null) {
        try {
          await targetDb.printJobsDao.markJobStatus(
            jobId,
            printSuccess ? PrintJobStatus.printed : PrintJobStatus.failed,
          );
        } catch (e) {
          debugPrint('Notice updating OfflinePrintJob status: $e');
        }
      }

      return _JobPrintResult(success: printSuccess, jobId: jobId);
    } catch (e) {
      debugPrint('Single print job error for $targetPrinter: $e');
      if (targetDb != null && jobId != null) {
        try {
          await targetDb.printJobsDao.markJobStatus(jobId, PrintJobStatus.failed);
        } catch (_) {}
      }
      return _JobPrintResult(success: false, jobId: jobId);
    }
  }

  /// Direct hardware byte transmission to Win32 spooler / test fake printer
  static Future<bool> _sendRawBytesToPrinter({
    required String targetPrinter,
    required Uint8List escposBytes,
    String docName = 'POS Thermal Receipt',
    ReceiptData? receipt,
    PaperWidth paperWidth = PaperWidth.roll80mm,
    bool isKitchenPrinter = false,
  }) async {
    // Priority 0: Fake physical printer hook for unit tests
    if (testPrinterFn != null) {
      return await testPrinterFn!(targetPrinter, escposBytes, docName: docName);
    }

    bool printSuccess = false;

    // 1. PRIORITY 1: DIRECT NATIVE WIN32 DESKTOP PRINTING (Windows Desktop Native Spooler / Port)
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      if (targetPrinter.startsWith('Port: ')) {
        final port = targetPrinter.replaceFirst('Port: ', '').trim();
        printSuccess = await NativeWin32Printer.printRawBytesToPort(port, escposBytes);
        if (!printSuccess) {
          await NativeWin32Printer.ensurePosPrinterInstalled(
            printerName: 'POS Receipt Printer',
            portName: port,
          );
          printSuccess = await NativeWin32Printer.printRawBytesToSpooler(
            'POS Receipt Printer',
            escposBytes,
            docName: docName,
          );
        }
      } else if (targetPrinter.contains(':') && RegExp(r'^\d+\.\d+\.\d+\.\d+:\d+$').hasMatch(targetPrinter)) {
        final parts = targetPrinter.split(':');
        final host = parts[0];
        final port = int.tryParse(parts[1]) ?? 9100;
        printSuccess = await NetworkPrinter.sendRawBytesToNetworkPrinter(host, port, escposBytes);
      } else {
        printSuccess = await NativeWin32Printer.printRawBytesToSpooler(
          targetPrinter,
          escposBytes,
          docName: docName,
        );

        if (!printSuccess && targetPrinter != 'POS Receipt Printer') {
          printSuccess = await NativeWin32Printer.printRawBytesToSpooler(
            'POS Receipt Printer',
            escposBytes,
            docName: docName,
          );
        }
      }
    }

    // 2. PRIORITY 2: LOCAL BACKEND PRINT API (Only when running on Web or local print server)
    if (!printSuccess && (kIsWeb || ApiConfig.baseUrl.contains('localhost') || ApiConfig.baseUrl.contains('127.0.0.1'))) {
      try {
        final b64 = base64Encode(escposBytes);
        final res = await http.post(
          Uri.parse('${ApiConfig.baseUrl}/printer/print'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'printerName': targetPrinter,
            'base64Data': b64,
            'docName': docName,
          }),
        ).timeout(const Duration(seconds: 4));

        if (res.statusCode == 200) {
          final decoded = jsonDecode(res.body);
          if (decoded['success'] == true) {
            printSuccess = true;
          }
        }
      } catch (e) {
        debugPrint('Backend direct print attempt: $e');
      }
    }

    // 3. PRIORITY 3: PDF SPOOLER DIRECT PRINTING FALLBACK
    if (!printSuccess && !kIsWeb && receipt != null) {
      try {
        final printers = await Printing.listPrinters();
        final matchingPrinter = printers.cast<Printer?>().firstWhere(
              (p) => p?.name == targetPrinter || p?.name == 'POS Receipt Printer',
              orElse: () => printers.isNotEmpty
                  ? printers.firstWhere(
                      (p) => !p.name.toLowerCase().contains('pdf') && !p.name.toLowerCase().contains('onenote'),
                      orElse: () => printers.first,
                    )
                  : null,
            );

        if (matchingPrinter != null) {
          final pageFormat = paperWidth == PaperWidth.roll58mm
              ? const PdfPageFormat(58 * PdfPageFormat.mm, double.infinity, marginAll: 2 * PdfPageFormat.mm)
              : const PdfPageFormat(80 * PdfPageFormat.mm, double.infinity, marginAll: 3.5 * PdfPageFormat.mm);

          final doc = await _generateReceiptPdf(
            receipt,
            paperWidth,
            isKitchenPrinter: isKitchenPrinter,
          );
          final pdfBytes = await doc.save();

          printSuccess = await Printing.directPrintPdf(
            printer: matchingPrinter,
            onLayout: (PdfPageFormat format) async => pdfBytes,
            format: pageFormat,
            name: docName,
          );
        }
      } catch (e) {
        debugPrint('Spooler fallback error: $e');
      }
    }

    return printSuccess;
  }

  /// Retries printing a failed or queued print job from OfflinePrintJobs.
  /// Per Architecture Spec §15.4 and §21 (Decision 1): Simple retry without recovery daemons.
  static Future<bool> retryPrintJob(
    int jobId, {
    BuildContext? context,
    AppDatabase? db,
  }) async {
    final targetDb = db ?? _database;
    if (targetDb == null) {
      debugPrint('Cannot retry print: no database configured.');
      return false;
    }

    final job = await targetDb.printJobsDao.getJobById(jobId);
    if (job == null) {
      debugPrint('Retry print: job #$jobId not found in OfflinePrintJobs.');
      return false;
    }

    if (job.status == PrintJobStatus.printed) {
      debugPrint('Retry print: job #$jobId has already been printed. Skipping duplicate print.');
      return true;
    }

    final nextRetry = job.retryCount + 1;
    bool printSuccess = false;
    try {
      printSuccess = await _sendRawBytesToPrinter(
        targetPrinter: job.printerTarget,
        escposBytes: job.rawEscPosData,
        docName: '${job.jobType}_${job.orderId ?? jobId}',
      );
    } catch (e) {
      debugPrint('Retry print threw exception: $e');
      printSuccess = false;
    }

    await targetDb.printJobsDao.markJobStatus(
      jobId,
      printSuccess ? PrintJobStatus.printed : PrintJobStatus.failed,
      retryCount: nextRetry,
    );

    if (printSuccess) {
      if (job.jobType == PrintJobType.kitchenTicket && job.orderId != null) {
        await markKitchenReceiptPrinted(job.orderId, db: targetDb);
      }
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Print succeeded on retry!',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
            backgroundColor: Color(0xFF16A34A),
            duration: Duration(seconds: 3),
          ),
        );
      }
      return true;
    } else {
      if (context != null && context.mounted) {
        _showPrinterFailureSnackBar(context, jobId, targetDb);
      }
      return false;
    }
  }

  /// Prints and enqueues a Daily Shift Z-Report in OfflinePrintJobs per Spec §5.4.3 & §15.4.
  static Future<bool> printShiftZReport({
    BuildContext? context,
    required String shiftId,
    required DateTime date,
    required String cashierName,
    required double startingCash,
    required double totalCashSales,
    required double totalCardSales,
    required double totalOnlineSales,
    required double totalGrossSales,
    required double totalExpenses,
    required double expectedCash,
    required double actualCash,
    required double variance,
    int dineInCount = 0,
    int takeawayCount = 0,
    int deliveryCount = 0,
    int totalOrders = 0,
    String storeName = "HUNGRY HOWIES",
    String branchName = "Near UOG Gate # 2 Gujrat",
    String? printerName,
    bool isReprint = false,
    AppDatabase? db,
  }) async {
    final targetDb = db ?? _database;
    final rawPos = printerName ?? await getSavedPrinterName();
    final targetPrinter = (rawPos != null && isPrinterConfigured(rawPos))
        ? rawPos
        : 'POS Receipt Printer';
    final paperWidth = await getSavedPaperWidth();
    final autoCut = await isAutoCutEnabled();

    final escposBytes = EscPosBuilder.buildShiftZReportBytes(
      shiftId: shiftId,
      date: date,
      cashierName: cashierName,
      startingCash: startingCash,
      totalCashSales: totalCashSales,
      totalCardSales: totalCardSales,
      totalOnlineSales: totalOnlineSales,
      totalGrossSales: totalGrossSales,
      totalExpenses: totalExpenses,
      expectedCash: expectedCash,
      actualCash: actualCash,
      variance: variance,
      dineInCount: dineInCount,
      takeawayCount: takeawayCount,
      deliveryCount: deliveryCount,
      totalOrders: totalOrders,
      storeName: storeName,
      branchName: branchName,
      paperWidth: paperWidth,
      autoCut: autoCut,
      isReprint: isReprint,
    );

    int? jobId;
    if (targetDb != null) {
      try {
        jobId = await targetDb.printJobsDao.insertJob(
          OfflinePrintJobsCompanion(
            jobType: const Value(PrintJobType.shiftZReport),
            orderId: Value(shiftId),
            printerTarget: Value(targetPrinter),
            rawEscPosData: Value(escposBytes),
            status: const Value(PrintJobStatus.queued),
            retryCount: const Value(0),
            createdAt: Value(DateTime.now()),
          ),
        );
      } catch (e) {
        debugPrint('Notice inserting shift Z-report job: $e');
      }
    }

    bool success = false;
    try {
      success = await _sendRawBytesToPrinter(
        targetPrinter: targetPrinter,
        escposBytes: escposBytes,
        docName: 'SHIFT_Z_REPORT_$shiftId',
        paperWidth: paperWidth,
      );
    } catch (e) {
      debugPrint('Shift Z-report print threw exception: $e');
      success = false;
    }

    if (targetDb != null && jobId != null) {
      try {
        await targetDb.printJobsDao.markJobStatus(
          jobId,
          success ? PrintJobStatus.printed : PrintJobStatus.failed,
        );
      } catch (_) {}
    }

    if (success) {
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Shift Z-Report printed to [$targetPrinter]',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF16A34A),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return true;
    } else {
      if (context != null && context.mounted) {
        _showPrinterFailureSnackBar(context, jobId, targetDb);
      }
      return false;
    }
  }

  /// Renders the PDF receipt into a monochrome thermal bitmap and generates standard ESC/POS GS v 0 bit image bytes.
  /// This physically burns the exact continuous horizontal line through cancelled text on standard thermal printers.
  static Future<Uint8List?> generateRasterEscPosBytes(
    ReceiptData receipt,
    PaperWidth paperWidth, {
    bool autoCut = true,
    bool openCashDrawer = false,
    bool isKitchenPrinter = false,
  }) async {
    if (testPrinterFn != null) return null;
    try {
      final doc = await _generateReceiptPdf(
        receipt,
        paperWidth,
        isKitchenPrinter: isKitchenPrinter,
      );
      final pdfBytes = await doc.save();
      final dpi = 203.0; // Standard 203 DPI (8 dots/mm) for POS thermal printers
      final pages = Printing.raster(pdfBytes, pages: [0], dpi: dpi);
      await for (final page in pages) {
        final pixels = page.pixels;
        return EscPosBuilder.rasterToEscPosBytes(
          rgbaPixels: pixels,
          width: page.width,
          height: page.height,
          autoCut: autoCut,
          openCashDrawer: openCashDrawer,
        );
      }
    } catch (e) {
      debugPrint('Raster ESC/POS generation error: $e');
    }
    return null;
  }

  /// Automatically resolves the most appropriate physical thermal printer
  static Future<String?> _resolveBestThermalPrinter() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.windows) return null;

    final winPrinters = await NativeWin32Printer.getInstalledWindowsPrinters();
    const thermalKeywords = [
      'pos', 'thermal', 'receipt', 'xp-', 'xp', 'tm-', 'rp-', 'zj-', 'zj',
      '80', '58', 'xprinter', 'epson', 'rongta', 'gprinter', 'bixolon', 'sunmi', 'star', 'printer'
    ];

    // 1. Look for POS / Thermal in Windows printers
    for (final p in winPrinters) {
      final lower = p.toLowerCase();
      if (lower.contains('pdf') || lower.contains('onenote') || lower.contains('fax') || lower.contains('xps')) {
        continue;
      }
      if (thermalKeywords.any((kw) => lower.contains(kw))) {
        await savePrinterSettings(printerName: p);
        return p;
      }
    }

    // 2. Check if POS Receipt Printer is installed
    if (winPrinters.contains('POS Receipt Printer')) {
      await savePrinterSettings(printerName: 'POS Receipt Printer');
      return 'POS Receipt Printer';
    }

    // 3. Ensure POS Receipt Printer on USB001
    final ensured = await NativeWin32Printer.ensurePosPrinterInstalled(
      printerName: 'POS Receipt Printer',
      portName: 'USB001',
    );
    if (ensured) {
      await savePrinterSettings(printerName: 'POS Receipt Printer');
      return 'POS Receipt Printer';
    }

    return winPrinters.isNotEmpty ? winPrinters.first : 'POS Receipt Printer';
  }

  // ---------------------------------------------------------------------------
  // PDF Document Generator (for digital exports & raster printing)
  // ---------------------------------------------------------------------------
  static pw.Font? _cachedRobotoRegular;
  static pw.Font? _cachedRobotoBold;
  static pw.Font? _cachedRobotoItalic;
  static bool _fontsLoaded = false;

  static Future<void> _ensureFontsLoaded() async {
    if (_fontsLoaded) return;
    try {
      _cachedRobotoRegular = await PdfGoogleFonts.robotoRegular().timeout(const Duration(milliseconds: 600));
      _cachedRobotoBold = await PdfGoogleFonts.robotoBold().timeout(const Duration(milliseconds: 600));
      _cachedRobotoItalic = await PdfGoogleFonts.robotoItalic().timeout(const Duration(milliseconds: 600));
      _fontsLoaded = true;
    } catch (_) {
      _fontsLoaded = true;
    }
  }

  static Future<pw.Document> _generateReceiptPdf(
    ReceiptData receipt,
    PaperWidth paperWidth, {
    bool isKitchenPrinter = false,
  }) async {
    if (!_fontsLoaded) {
      await _ensureFontsLoaded();
    }

    pw.ThemeData themeData;
    if (_cachedRobotoRegular != null && _cachedRobotoBold != null) {
      themeData = pw.ThemeData.withFont(
        base: _cachedRobotoRegular!,
        bold: _cachedRobotoBold!,
        italic: _cachedRobotoItalic,
      );
    } else {
      themeData = pw.ThemeData.base();
    }

    final pdf = pw.Document(theme: themeData);

    final is58 = paperWidth == PaperWidth.roll58mm;
    final contentWidth = is58 ? 46.0 * PdfPageFormat.mm : 68.0 * PdfPageFormat.mm;
    final fontSizeBase = is58 ? 7.5 : 9.0;
    final fontSizeTitle = is58 ? 10.0 : 13.0;
    final fontSizeLarge = is58 ? 12.0 : 15.0;

    // Calculate finite page height to allow PDF rasterization engine (pdfium/canvas) to render bitmap graphics
    // 72mm matches the exact physical 576-dot printhead of 80mm thermal printers (widthBytes = 72)
    // 48mm matches the exact physical 384-dot printhead of 58mm thermal printers (widthBytes = 48)
    final double calculatedHeightMm = (receipt.type == ReceiptType.kitchenKot ? 90.0 : 125.0) + (receipt.items.length * 20.0);
    final pageFormat = is58
        ? PdfPageFormat(48 * PdfPageFormat.mm, calculatedHeightMm * PdfPageFormat.mm, marginAll: 1.0 * PdfPageFormat.mm)
        : PdfPageFormat(72 * PdfPageFormat.mm, calculatedHeightMm * PdfPageFormat.mm, marginAll: 2.0 * PdfPageFormat.mm);

    final dateStr = DateFormat('dd-MMM-yyyy  hh:mm a').format(receipt.dateTime);

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        build: (pw.Context context) {
          if (receipt.type == ReceiptType.kitchenKot) {
            String orderTypeTitle = 'Dine In';
            if (receipt.orderType != null) {
              final ot = receipt.orderType!.toUpperCase();
              if (ot.contains('TAKEAWAY') || ot.contains('TAKE AWAY')) {
                orderTypeTitle = 'Takeaway';
              } else if (ot.contains('DELIVERY')) {
                orderTypeTitle = 'Delivery';
              } else if (ot.contains('ONLINE')) {
                orderTypeTitle = 'Online';
              } else {
                orderTypeTitle = 'Dine In';
              }
            }

            final displayOrderNum = EscPosBuilder.format3DigitOrderNumber(receipt.orderNumber);
            String subHeader = '';
            if (orderTypeTitle == 'Dine In') {
              final section = receipt.tableSection ?? 'Hall';
              final table = receipt.tableName ?? 'TABLE ${receipt.tableNumber ?? "1"}';
              subHeader = '$section - $table';
            } else if (orderTypeTitle == 'Takeaway') {
              subHeader = 'Takeaway - Token #$displayOrderNum';
            } else if (orderTypeTitle == 'Delivery') {
              subHeader = 'Delivery - #$displayOrderNum';
            } else {
              subHeader = 'Online - #$displayOrderNum';
            }

            final dateFormatted = DateFormat('MMM d yyyy').format(receipt.dateTime);
            final timeFormatted = DateFormat('HH:mm').format(receipt.dateTime);
            final totalQty = receipt.items.where((i) => !i.isCancelled).fold<double>(0.0, (sum, i) => sum + i.quantity);

            return pw.Container(
              width: contentWidth,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  pw.Center(
                    child: pw.Text(
                      isKitchenPrinter ? 'Kitchen Receipt' : 'Food Picker - $orderTypeTitle',
                      style: pw.TextStyle(fontSize: fontSizeTitle, fontWeight: pw.FontWeight.normal),
                    ),
                  ),
                  pw.SizedBox(height: 1),
                  pw.Center(
                    child: pw.Text(
                      subHeader,
                      style: pw.TextStyle(fontSize: fontSizeLarge, fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                  pw.SizedBox(height: 3),

                  // Metadata: Date, Time
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Date: $dateFormatted', style: pw.TextStyle(fontSize: fontSizeBase)),
                      pw.Text('Time: $timeFormatted', style: pw.TextStyle(fontSize: fontSizeBase)),
                    ],
                  ),
                  pw.SizedBox(height: 3),

                  // Table Header
                  _divider(thickness: 0.8),
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 2),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Product Name', style: pw.TextStyle(fontSize: fontSizeBase + 1, fontWeight: pw.FontWeight.bold)),
                        pw.Text('Quantity', style: pw.TextStyle(fontSize: fontSizeBase + 1, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  ),
                  _divider(thickness: 0.8),

                  // Items
                  ...receipt.items.map((item) {
                    final qtyStr = item.isCancelled
                        ? '-${item.quantity}'
                        : '${item.quantity}';
                    final modifiers = <String>[];
                    if (item.size != null && item.size!.isNotEmpty && item.size != 'Regular') {
                      modifiers.add('(${item.size})');
                    }
                    if (item.crust != null && item.crust!.isNotEmpty && item.crust != 'Original') {
                      modifiers.add('(${item.crust})');
                    }
                    if (item.toppings.isNotEmpty) {
                      modifiers.add('(${item.toppings.join(", ")})');
                    }
                    if (item.notes != null && item.notes!.isNotEmpty) {
                      modifiers.add('(${item.notes})');
                    }

                    return pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 3),
                          child: pw.Row(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Expanded(
                                child: pw.Column(
                                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                                  children: [
                                    pw.Text(
                                      item.isCancelled ? '[CANCELLED] ${item.name}' : item.name,
                                      style: pw.TextStyle(
                                        fontSize: fontSizeBase + 0.5,
                                        fontWeight: item.isCancelled ? pw.FontWeight.bold : pw.FontWeight.normal,
                                        decoration: item.isCancelled ? pw.TextDecoration.lineThrough : null,
                                        decorationThickness: item.isCancelled ? 2.5 : null,
                                        decorationColor: item.isCancelled ? PdfColors.black : null,
                                        color: item.isCancelled ? PdfColors.black : null,
                                      ),
                                    ),
                                    ...modifiers.map((m) => pw.Text(
                                          m,
                                          style: pw.TextStyle(
                                            fontSize: fontSizeBase - 0.5,
                                            fontStyle: _cachedRobotoItalic != null ? pw.FontStyle.italic : pw.FontStyle.normal,
                                            decoration: item.isCancelled ? pw.TextDecoration.lineThrough : null,
                                            decorationThickness: item.isCancelled ? 2.0 : null,
                                            decorationColor: item.isCancelled ? PdfColors.black : null,
                                            color: item.isCancelled ? PdfColors.black : null,
                                          ),
                                        )),
                                    if (item.isCancelled && item.cancelReason != null && item.cancelReason!.isNotEmpty)
                                      pw.Text(
                                        'Reason: ${item.cancelReason}',
                                        style: pw.TextStyle(fontSize: fontSizeBase - 0.5, fontStyle: _cachedRobotoItalic != null ? pw.FontStyle.italic : pw.FontStyle.normal, color: PdfColors.black),
                                      ),
                                  ],
                                ),
                              ),
                              pw.Text(
                                qtyStr,
                                style: pw.TextStyle(
                                  fontSize: fontSizeBase + 1,
                                  fontWeight: pw.FontWeight.bold,
                                  decoration: item.isCancelled ? pw.TextDecoration.lineThrough : null,
                                  decorationThickness: item.isCancelled ? 2.5 : null,
                                  decorationColor: item.isCancelled ? PdfColors.black : null,
                                  color: item.isCancelled ? PdfColors.black : null,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _divider(thickness: 0.5),
                      ],
                    );
                  }),

                  // Total Row
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 3),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Total:', style: pw.TextStyle(fontSize: fontSizeBase + 1, fontWeight: pw.FontWeight.bold)),
                        pw.Text(
                          totalQty.round().toString(),
                          style: pw.TextStyle(fontSize: fontSizeBase + 1.5, fontWeight: pw.FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  _divider(thickness: 0.8),

                  if (receipt.notes != null && receipt.notes!.isNotEmpty) ...[
                    pw.SizedBox(height: 4),
                    pw.Text('Note: ${receipt.notes}', style: pw.TextStyle(fontSize: fontSizeBase, fontStyle: pw.FontStyle.italic)),
                    pw.SizedBox(height: 4),
                    _divider(thickness: 0.5),
                  ],
                  pw.SizedBox(height: 20),
                ],
              ),
            );
          }

          final activeItems = (receipt.type == ReceiptType.kitchenKot)
              ? receipt.items
              : receipt.items.where((i) => !i.isCancelled).toList();

          final grossAmt = activeItems.fold<double>(0.0, (s, i) => s + i.totalPrice);
          final totalQty = activeItems.fold<double>(0.0, (s, i) => s + i.quantity);
          final double calcTax = receipt.taxRate > 0
              ? (grossAmt * receipt.taxRate / 100)
              : (activeItems.isEmpty ? 0.0 : receipt.taxAmount);
          final double netTotal = (grossAmt - receipt.discountAmount + calcTax + receipt.serviceChargeAmount + receipt.deliveryFee).clamp(0.0, double.infinity);

          final address = receipt.branchName.isNotEmpty
              ? receipt.branchName
              : 'Near UOG Gate # 2 Nawaz Sharif Medical College Gujrat.';

          final displayOrderNum = EscPosBuilder.format3DigitOrderNumber(receipt.orderNumber);

          return pw.Container(
            width: contentWidth,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                // 1. BRAND HEADER
                pw.Center(
                  child: pw.Text(
                    'INVOICE',
                    style: pw.TextStyle(fontSize: fontSizeBase + 1, fontWeight: pw.FontWeight.normal),
                  ),
                ),
                pw.SizedBox(height: 1),
                pw.Center(
                  child: pw.Text(
                    receipt.storeName.toUpperCase(),
                    style: pw.TextStyle(fontSize: fontSizeLarge, fontWeight: pw.FontWeight.bold),
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Center(
                  child: pw.Text(
                    address,
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(fontSize: fontSizeBase - 0.5),
                  ),
                ),
                if (receipt.storePhone.isNotEmpty && receipt.storePhone != '+1 (800) 555-HOWIE') ...[
                  pw.Center(
                    child: pw.Text(
                      'Tel: ${receipt.storePhone}',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(fontSize: fontSizeBase - 0.5),
                    ),
                  ),
                ],

                pw.SizedBox(height: 4),

                // 2. METADATA
                pw.Text('Receipt #: $displayOrderNum', style: pw.TextStyle(fontSize: fontSizeBase)),
                pw.Text('Date: $dateStr', style: pw.TextStyle(fontSize: fontSizeBase)),
                if (receipt.tableNumber != null && receipt.tableNumber!.isNotEmpty)
                  pw.Text('Table: ${receipt.tableName ?? receipt.tableNumber}', style: pw.TextStyle(fontSize: fontSizeBase)),

                pw.SizedBox(height: 4),
                _divider(),

                // 3. ITEMS TABLE HEADER: Sr.  Product  Price  Qty  Total
                pw.Row(
                  children: [
                    pw.Container(
                      width: 14,
                      child: pw.Text('Sr.', style: pw.TextStyle(fontSize: fontSizeBase - 0.5, fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Expanded(
                      flex: 5,
                      child: pw.Text('Product', style: pw.TextStyle(fontSize: fontSizeBase - 0.5, fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Container(
                      width: 32,
                      alignment: pw.Alignment.centerRight,
                      child: pw.Text('Price', style: pw.TextStyle(fontSize: fontSizeBase - 0.5, fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Container(
                      width: 26,
                      alignment: pw.Alignment.centerRight,
                      child: pw.Text('Qty', style: pw.TextStyle(fontSize: fontSizeBase - 0.5, fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Container(
                      width: 38,
                      alignment: pw.Alignment.centerRight,
                      child: pw.Text('Total', style: pw.TextStyle(fontSize: fontSizeBase - 0.5, fontWeight: pw.FontWeight.bold)),
                    ),
                  ],
                ),
                _divider(dashed: true),

                // 4. ITEM ROWS
                ...activeItems.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final item = entry.value;
                  final isCancelled = item.isCancelled;
                  final displayName = item.name;
                  final modifiers = <String>[];
                  if (item.size != null && item.size!.isNotEmpty && item.size != 'Regular') {
                    modifiers.add('(${item.size})');
                  }
                  if (item.crust != null && item.crust!.isNotEmpty && item.crust != 'Original') {
                    modifiers.add('(${item.crust})');
                  }
                  if (item.toppings.isNotEmpty) {
                    modifiers.add('(${item.toppings.join(", ")})');
                  }
                  if (item.notes != null && item.notes!.isNotEmpty) {
                    modifiers.add('(${item.notes})');
                  }

                  final priceStr = isCancelled ? '-${item.unitPrice.round()}' : '${item.unitPrice.round()}';
                  final qtyStr = isCancelled ? '-${item.quantity}' : '${item.quantity}';
                  final totalStr = isCancelled ? '-${item.totalPrice.round()}' : '${item.totalPrice.round()}';

                  return pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 2),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Container(
                              width: 14,
                              child: pw.Text(
                                '${idx + 1}',
                                style: pw.TextStyle(
                                  fontSize: fontSizeBase,
                                  decoration: isCancelled ? pw.TextDecoration.lineThrough : null,
                                  decorationThickness: isCancelled ? 1.5 : null,
                                  decorationColor: isCancelled ? PdfColors.black : null,
                                  color: isCancelled ? PdfColors.black : null,
                                ),
                              ),
                            ),
                            pw.Expanded(
                              flex: 5,
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text(
                                    displayName,
                                    style: pw.TextStyle(
                                      fontSize: fontSizeBase,
                                      decoration: isCancelled ? pw.TextDecoration.lineThrough : null,
                                      decorationThickness: isCancelled ? 1.5 : null,
                                      decorationColor: isCancelled ? PdfColors.black : null,
                                      color: isCancelled ? PdfColors.black : null,
                                      fontWeight: isCancelled ? pw.FontWeight.bold : pw.FontWeight.normal,
                                    ),
                                  ),
                                  ...modifiers.map((m) => pw.Text(
                                        m,
                                        style: pw.TextStyle(
                                          fontSize: fontSizeBase - 1,
                                          fontStyle: _cachedRobotoItalic != null ? pw.FontStyle.italic : pw.FontStyle.normal,
                                          decoration: isCancelled ? pw.TextDecoration.lineThrough : null,
                                          decorationThickness: isCancelled ? 1.5 : null,
                                          decorationColor: isCancelled ? PdfColors.black : null,
                                          color: isCancelled ? PdfColors.black : null,
                                        ),
                                      )),
                                  if (isCancelled && item.cancelReason != null && item.cancelReason!.isNotEmpty)
                                    pw.Text(
                                      'Reason: ${item.cancelReason}',
                                      style: pw.TextStyle(fontSize: fontSizeBase - 1, fontStyle: _cachedRobotoItalic != null ? pw.FontStyle.italic : pw.FontStyle.normal, color: PdfColors.black),
                                    ),
                                ],
                              ),
                            ),
                            pw.Container(
                              width: 32,
                              alignment: pw.Alignment.centerRight,
                              child: pw.Text(
                                priceStr,
                                style: pw.TextStyle(
                                  fontSize: fontSizeBase,
                                  decoration: isCancelled ? pw.TextDecoration.lineThrough : null,
                                  decorationThickness: isCancelled ? 1.5 : null,
                                  decorationColor: isCancelled ? PdfColors.black : null,
                                  color: isCancelled ? PdfColors.black : null,
                                ),
                              ),
                            ),
                            pw.Container(
                              width: 26,
                              alignment: pw.Alignment.centerRight,
                              child: pw.Text(
                                qtyStr,
                                style: pw.TextStyle(
                                  fontSize: fontSizeBase,
                                  decoration: isCancelled ? pw.TextDecoration.lineThrough : null,
                                  decorationThickness: isCancelled ? 1.5 : null,
                                  decorationColor: isCancelled ? PdfColors.black : null,
                                  color: isCancelled ? PdfColors.black : null,
                                ),
                              ),
                            ),
                            pw.Container(
                              width: 38,
                              alignment: pw.Alignment.centerRight,
                              child: pw.Text(
                                totalStr,
                                style: pw.TextStyle(
                                  fontSize: fontSizeBase,
                                  decoration: isCancelled ? pw.TextDecoration.lineThrough : null,
                                  decorationThickness: isCancelled ? 1.5 : null,
                                  decorationColor: isCancelled ? PdfColors.black : null,
                                  color: isCancelled ? PdfColors.black : null,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),

                _divider(),

                // 5. TOTALS SECTION
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 2),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.end,
                    children: [
                      pw.Text('Gross Total:', style: pw.TextStyle(fontSize: fontSizeBase, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(width: 8),
                      pw.Text(totalQty.round().toString(), style: pw.TextStyle(fontSize: fontSizeBase, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(width: 12),
                      pw.Text(grossAmt.round().toString(), style: pw.TextStyle(fontSize: fontSizeBase, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ),

                if (receipt.discountAmount > 0)
                  _rowCalculation('Discount:', '- ${receipt.discountAmount.round()}', fontSizeBase),
                if (calcTax > 0)
                  _rowCalculation(
                    'GST / Tax (${receipt.taxRate > 0 ? (receipt.taxRate == receipt.taxRate.roundToDouble() ? "${receipt.taxRate.toInt()}%" : "${receipt.taxRate.toStringAsFixed(1)}%") : ""}):',
                    '+ ${calcTax.round()}',
                    fontSizeBase,
                  ),
                if (receipt.serviceChargeAmount > 0)
                  _rowCalculation('Service Charge:', '+ ${receipt.serviceChargeAmount.round()}', fontSizeBase),
                if (receipt.deliveryFee > 0)
                  _rowCalculation('Delivery Fee:', '+ ${receipt.deliveryFee.round()}', fontSizeBase),

                _divider(thickness: 0.8),

                // NET TOTAL
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 2),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'Net Total:',
                        style: pw.TextStyle(fontSize: fontSizeTitle, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text(
                        netTotal.round().toString(),
                        style: pw.TextStyle(fontSize: fontSizeTitle, fontWeight: pw.FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                _divider(thickness: 0.8),

                pw.SizedBox(height: 6),

                // 6. FOOTER
                pw.Center(
                  child: pw.Text(
                    'Thank you for your visit',
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(fontSize: fontSizeBase),
                  ),
                ),
                pw.SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );

    return pdf;
  }

  static pw.Widget _divider({bool dashed = false, double thickness = 0.6}) {
    return pw.Container(
      margin: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Divider(
        thickness: thickness,
        borderStyle: dashed ? pw.BorderStyle.dashed : pw.BorderStyle.solid,
      ),
    );
  }

  static pw.Widget _rowCalculation(String label, String value, double fontSize, {bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: fontSize, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

class _JobPrintResult {
  final bool success;
  final int? jobId;
  const _JobPrintResult({required this.success, this.jobId});
}
