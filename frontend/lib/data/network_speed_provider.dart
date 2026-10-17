import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

enum NetworkSpeedLevel {
  fast,    // Green
  medium,  // Orange
  slow,    // Red (low speed)
  offline, // Red (disconnected)
}

class NetworkSpeedState {
  final NetworkSpeedLevel level;
  final int latencyMs;
  final bool isChecking;
  final DateTime lastChecked;
  final String statusMessage;

  const NetworkSpeedState({
    required this.level,
    required this.latencyMs,
    required this.isChecking,
    required this.lastChecked,
    required this.statusMessage,
  });

  NetworkSpeedState copyWith({
    NetworkSpeedLevel? level,
    int? latencyMs,
    bool? isChecking,
    DateTime? lastChecked,
    String? statusMessage,
  }) {
    return NetworkSpeedState(
      level: level ?? this.level,
      latencyMs: latencyMs ?? this.latencyMs,
      isChecking: isChecking ?? this.isChecking,
      lastChecked: lastChecked ?? this.lastChecked,
      statusMessage: statusMessage ?? this.statusMessage,
    );
  }
}

class NetworkSpeedNotifier extends StateNotifier<NetworkSpeedState> {
  Timer? _pollingTimer;

  NetworkSpeedNotifier()
      : super(
          NetworkSpeedState(
            level: NetworkSpeedLevel.fast,
            latencyMs: 38,
            isChecking: false,
            lastChecked: DateTime.now(),
            statusMessage: 'Fast Internet Connection (38 ms)',
          ),
        ) {
    _startPeriodicCheck();
    checkSpeed();
  }

  void _startPeriodicCheck() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      checkSpeed();
    });
  }

  Future<void> checkSpeed() async {
    if (state.isChecking) return;
    state = state.copyWith(isChecking: true);

    try {
      final stopwatch = Stopwatch()..start();
      bool connected = false;

      try {
        final uri = Uri.parse('${ApiConfig.baseUrl}/health');
        final resp = await http.get(uri).timeout(const Duration(seconds: 3));
        stopwatch.stop();
        if (resp.statusCode >= 200 && resp.statusCode < 500) {
          connected = true;
        }
      } catch (_) {
        try {
          final uri = Uri.parse('https://httpbin.org/status/200');
          final resp = await http.get(uri).timeout(const Duration(seconds: 3));
          stopwatch.stop();
          if (resp.statusCode == 200) {
            connected = true;
          }
        } catch (_) {
          connected = false;
        }
      }

      if (!connected) {
        state = state.copyWith(
          level: NetworkSpeedLevel.offline,
          latencyMs: 9999,
          isChecking: false,
          lastChecked: DateTime.now(),
          statusMessage: 'Offline / Disconnected',
        );
        return;
      }

      final latency = stopwatch.elapsedMilliseconds;
      NetworkSpeedLevel level;
      String message;

      if (latency < 120) {
        level = NetworkSpeedLevel.fast;
        message = 'Fast Internet Connection ($latency ms)';
      } else if (latency < 350) {
        level = NetworkSpeedLevel.medium;
        message = 'Moderate Internet Speed ($latency ms)';
      } else {
        level = NetworkSpeedLevel.slow;
        message = 'Slow Internet Connection ($latency ms)';
      }

      state = state.copyWith(
        level: level,
        latencyMs: latency,
        isChecking: false,
        lastChecked: DateTime.now(),
        statusMessage: message,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error measuring network speed: $e');
      }
      state = state.copyWith(
        level: NetworkSpeedLevel.slow,
        latencyMs: 500,
        isChecking: false,
        lastChecked: DateTime.now(),
        statusMessage: 'Poor Connectivity',
      );
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }
}

final networkSpeedProvider =
    StateNotifierProvider<NetworkSpeedNotifier, NetworkSpeedState>((ref) {
  return NetworkSpeedNotifier();
});
