import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Represents a table seating overflow notification (§10.2, D-01/SYNC-011).
class TableReassignmentNotification {
  final String orderId;
  final String fromTableId;
  final String toTableId;
  final String toLabel;
  final String message;

  const TableReassignmentNotification({
    required this.orderId,
    required this.fromTableId,
    required this.toTableId,
    required this.toLabel,
    required this.message,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TableReassignmentNotification &&
          runtimeType == other.runtimeType &&
          orderId == other.orderId &&
          toTableId == other.toTableId;

  @override
  int get hashCode => orderId.hashCode ^ toTableId.hashCode;
}

class TableReassignmentNotifier extends StateNotifier<List<TableReassignmentNotification>> {
  TableReassignmentNotifier() : super(const []);

  void notify({
    required String orderId,
    required String fromTableId,
    required String toTableId,
    required String toLabel,
    String? message,
  }) {
    final msg = message ?? 'Table was split due to concurrent seating; order moved to $toLabel';
    final notif = TableReassignmentNotification(
      orderId: orderId,
      fromTableId: fromTableId,
      toTableId: toTableId,
      toLabel: toLabel,
      message: msg,
    );
    if (state.any((n) => n.orderId == orderId && n.toTableId == toTableId)) {
      return;
    }
    state = [...state, notif];
  }

  void dismiss(TableReassignmentNotification notification) {
    state = state.where((n) => n != notification).toList();
  }

  void clear() {
    state = const [];
  }
}

final tableReassignmentNotificationProvider =
    StateNotifierProvider<TableReassignmentNotifier, List<TableReassignmentNotification>>((ref) {
  final notifier = TableReassignmentNotifier();
  final sub = TableReassignmentEventBus.stream.listen((notif) {
    notifier.notify(
      orderId: notif.orderId,
      fromTableId: notif.fromTableId,
      toTableId: notif.toTableId,
      toLabel: notif.toLabel,
      message: notif.message,
    );
  });
  ref.onDispose(() {
    sub.cancel();
  });
  return notifier;
});

class TableReassignmentEventBus {
  static final StreamController<TableReassignmentNotification> _controller =
      StreamController<TableReassignmentNotification>.broadcast();

  static Stream<TableReassignmentNotification> get stream => _controller.stream;

  static void emit(TableReassignmentNotification notif) {
    if (!_controller.isClosed) {
      _controller.add(notif);
    }
  }
}
