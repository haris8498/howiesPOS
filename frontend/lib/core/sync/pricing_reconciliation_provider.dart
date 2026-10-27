import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Represents a server authoritative pricing reconciliation event per D-03 / SYNC-016.
class PricingReconciliationNotification {
  final String orderId;
  final String orderNumber;
  final double clientTotal;
  final double serverTotal;
  final String pricingStatus; // 'VERIFIED' | 'MISMATCH' | 'UNAUTHORIZED_DISCOUNT'
  final double difference;
  final String message;

  const PricingReconciliationNotification({
    required this.orderId,
    required this.orderNumber,
    required this.clientTotal,
    required this.serverTotal,
    required this.pricingStatus,
    required this.difference,
    required this.message,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PricingReconciliationNotification &&
          runtimeType == other.runtimeType &&
          orderId == other.orderId &&
          serverTotal == other.serverTotal;

  @override
  int get hashCode => orderId.hashCode ^ serverTotal.hashCode;
}

class PricingReconciliationNotifier extends StateNotifier<List<PricingReconciliationNotification>> {
  PricingReconciliationNotifier() : super(const []);

  void notify({
    required String orderId,
    required String orderNumber,
    required double clientTotal,
    required double serverTotal,
    required String pricingStatus,
    required double difference,
    String? message,
  }) {
    final msg = message ??
        (pricingStatus == 'UNAUTHORIZED_DISCOUNT'
            ? 'Order #$orderNumber discount was unapproved and removed by server: PKR ${clientTotal.toStringAsFixed(0)} -> PKR ${serverTotal.toStringAsFixed(0)}'
            : 'Order #$orderNumber total was reconciled by server: PKR ${clientTotal.toStringAsFixed(0)} -> PKR ${serverTotal.toStringAsFixed(0)}');

    final notif = PricingReconciliationNotification(
      orderId: orderId,
      orderNumber: orderNumber,
      clientTotal: clientTotal,
      serverTotal: serverTotal,
      pricingStatus: pricingStatus,
      difference: difference,
      message: msg,
    );

    if (state.any((n) => n.orderId == orderId && n.serverTotal == serverTotal)) {
      return;
    }
    state = [...state, notif];
  }

  void dismiss(PricingReconciliationNotification notification) {
    state = state.where((n) => n != notification).toList();
  }

  void clear() {
    state = const [];
  }
}

final pricingReconciliationNotificationProvider =
    StateNotifierProvider<PricingReconciliationNotifier, List<PricingReconciliationNotification>>((ref) {
  final notifier = PricingReconciliationNotifier();
  final sub = PricingReconciliationEventBus.stream.listen((notif) {
    notifier.notify(
      orderId: notif.orderId,
      orderNumber: notif.orderNumber,
      clientTotal: notif.clientTotal,
      serverTotal: notif.serverTotal,
      pricingStatus: notif.pricingStatus,
      difference: notif.difference,
      message: notif.message,
    );
  });
  ref.onDispose(() {
    sub.cancel();
  });
  return notifier;
});

class PricingReconciliationEventBus {
  static final StreamController<PricingReconciliationNotification> _controller =
      StreamController<PricingReconciliationNotification>.broadcast();

  static Stream<PricingReconciliationNotification> get stream => _controller.stream;

  static void emit(PricingReconciliationNotification notif) {
    if (!_controller.isClosed) {
      _controller.add(notif);
    }
  }
}
