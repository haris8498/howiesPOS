import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Manages the state of active in-memory order carts across POS screens (e.g. Takeaway and Dine-In).
///
/// Prevents the updater from initiating application restarts while cashiers have
/// unsaved or open carts in memory.
class OpenOrderGuardNotifier extends StateNotifier<bool> {
  OpenOrderGuardNotifier() : super(false);

  final Set<String> _openSources = {};

  void _safelyUpdateState(bool newValue) {
    if (state == newValue) return;
    final binding = WidgetsBinding.instance;
    if (binding.schedulerPhase != SchedulerPhase.idle) {
      binding.addPostFrameCallback((_) {
        if (mounted) {
          state = newValue;
        }
      });
    } else {
      state = newValue;
    }
  }

  /// Registers an active order cart from a given [sourceId].
  void setOrderOpen(String sourceId) {
    if (_openSources.add(sourceId)) {
      _safelyUpdateState(true);
    }
  }

  /// Clears an active order cart registration for [sourceId].
  void clearOrderOpen(String sourceId) {
    if (!mounted) return;
    if (_openSources.remove(sourceId)) {
      _safelyUpdateState(_openSources.isNotEmpty);
    }
  }

  /// Sets or clears the open order status for [sourceId].
  void updateOrderOpen(String sourceId, bool isOpen) {
    if (isOpen) {
      setOrderOpen(sourceId);
    } else {
      clearOrderOpen(sourceId);
    }
  }

  /// Returns true if at least one order cart is currently open.
  bool get hasOpenOrder => state;

  /// Returns the set of all active source IDs.
  Set<String> get openSources => Set.unmodifiable(_openSources);
}

/// Global provider for checking if any order cart is currently open.
final openOrderGuardProvider =
    StateNotifierProvider<OpenOrderGuardNotifier, bool>((ref) {
  return OpenOrderGuardNotifier();
});

/// Convenience boolean provider alias for [openOrderGuardProvider].
final hasOpenOrderProvider = Provider<bool>((ref) {
  return ref.watch(openOrderGuardProvider);
});
