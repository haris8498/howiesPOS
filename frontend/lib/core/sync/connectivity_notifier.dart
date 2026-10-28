import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../config/api_config.dart';
import '../network/api_client.dart';

/// Network connectivity states for hungry Howie's POS.
enum ConnectivityStatus {
  online,
  offline,
  probing,
}

/// State object representing real-time server health and connectivity status.
class ConnectivityState {
  final ConnectivityStatus status;
  final DateTime? lastProbeAt;
  final int? latencyMs;
  final int consecutiveFailures;
  final String? errorMessage;

  const ConnectivityState({
    this.status = ConnectivityStatus.offline,
    this.lastProbeAt,
    this.latencyMs,
    this.consecutiveFailures = 0,
    this.errorMessage,
  });

  bool get isOnline => status == ConnectivityStatus.online;
  bool get isOffline => status == ConnectivityStatus.offline;
  bool get isProbing => status == ConnectivityStatus.probing;

  ConnectivityState copyWith({
    ConnectivityStatus? status,
    DateTime? lastProbeAt,
    int? latencyMs,
    int? consecutiveFailures,
    String? errorMessage,
  }) {
    return ConnectivityState(
      status: status ?? this.status,
      lastProbeAt: lastProbeAt ?? this.lastProbeAt,
      latencyMs: latencyMs ?? this.latencyMs,
      consecutiveFailures: consecutiveFailures ?? this.consecutiveFailures,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConnectivityState &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          lastProbeAt == other.lastProbeAt &&
          latencyMs == other.latencyMs &&
          consecutiveFailures == other.consecutiveFailures &&
          errorMessage == other.errorMessage;

  @override
  int get hashCode =>
      status.hashCode ^
      lastProbeAt.hashCode ^
      latencyMs.hashCode ^
      consecutiveFailures.hashCode ^
      errorMessage.hashCode;

  @override
  String toString() =>
      'ConnectivityState(status: $status, isOnline: $isOnline, latency: ${latencyMs}ms, failures: $consecutiveFailures)';
}

/// Active connectivity monitor probing `/api/health` per Spec §6.4 & §13.
///
/// Does NOT rely solely on OS-level network interfaces. Directly verifies
/// end-to-end HTTP reachability against the central backend API.
class ConnectivityNotifier extends StateNotifier<ConnectivityState> {
  final ApiClient? apiClient;
  final http.Client? httpClient;
  final String? healthEndpointOverride;
  final Duration probeTimeout;

  Timer? _monitorTimer;
  bool _isDisposed = false;

  ConnectivityNotifier({
    this.apiClient,
    this.httpClient,
    this.healthEndpointOverride,
    this.probeTimeout = const Duration(seconds: 5),
    ConnectivityState? initialState,
  }) : super(initialState ?? const ConnectivityState());

  ConnectivityState get currentState => (!mounted || _isDisposed) ? const ConnectivityState() : state;
  bool get isOnline => (!mounted || _isDisposed) ? false : state.isOnline;

  /// URL used for the health probe.
  String get healthUrl {
    if (healthEndpointOverride != null && healthEndpointOverride!.isNotEmpty) {
      return healthEndpointOverride!;
    }
    final base = apiClient?.baseUrl ?? ApiConfig.baseUrl;
    final cleanBase = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    return '$cleanBase/health';
  }

  /// Actively probes the `/api/health` endpoint.
  /// Returns `true` if backend responds with HTTP 200, otherwise `false`.
  Future<bool> probeHealth() async {
    if (_isDisposed) return false;

    state = state.copyWith(status: ConnectivityStatus.probing);
    final stopwatch = Stopwatch()..start();

    try {
      final client = httpClient ?? http.Client();
      final uri = Uri.parse(healthUrl);

      final response = await client
          .get(uri, headers: const {
            'Accept': 'application/json',
          })
          .timeout(probeTimeout);

      stopwatch.stop();
      final latency = stopwatch.elapsedMilliseconds;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        // SYNC-035: Captive portals return HTTP 200 with HTML login pages.
        // Health probe requires valid JSON body to avoid false-online loops.
        bool serviceHealthy = false;
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic>) {
            if (decoded.containsKey('success')) {
              serviceHealthy = decoded['success'] == true;
            } else if (decoded.containsKey('status')) {
              serviceHealthy = decoded['status'] == 'ok' || decoded['status'] == 200;
            } else {
              serviceHealthy = true;
            }
          }
        } catch (_) {
          serviceHealthy = false;
        }

        if (serviceHealthy) {
          state = state.copyWith(
            status: ConnectivityStatus.online,
            lastProbeAt: DateTime.now(),
            latencyMs: latency,
            consecutiveFailures: 0,
            errorMessage: null,
          );
          return true;
        }
      }

      final errorMsg = 'Health probe returned HTTP ${response.statusCode}';
      _handleProbeFailure(errorMsg);
      return false;
    } catch (e) {
      stopwatch.stop();
      final errorMsg = 'Health probe failed: $e';
      _handleProbeFailure(errorMsg);
      return false;
    }
  }

  void _handleProbeFailure(String error) {
    if (_isDisposed) return;
    final nextFailures = state.consecutiveFailures + 1;
    state = state.copyWith(
      status: ConnectivityStatus.offline,
      lastProbeAt: DateTime.now(),
      latencyMs: null,
      consecutiveFailures: nextFailures,
      errorMessage: error,
    );
  }

  /// Starts background periodic probing.
  void startMonitoring({Duration interval = const Duration(seconds: 15)}) {
    _monitorTimer?.cancel();
    probeHealth(); // Immediate first probe
    _monitorTimer = Timer.periodic(interval, (_) {
      if (!_isDisposed) {
        probeHealth();
      }
    });
  }

  /// Stops background periodic probing.
  void stopMonitoring() {
    _monitorTimer?.cancel();
    _monitorTimer = null;
  }

  /// Whether background periodic monitoring is currently active.
  bool get isMonitoring => _monitorTimer != null;

  /// Manual transition for offline testing or manual override.
  void setOnlineManually({int latencyMs = 15}) {
    state = state.copyWith(
      status: ConnectivityStatus.online,
      lastProbeAt: DateTime.now(),
      latencyMs: latencyMs,
      consecutiveFailures: 0,
      errorMessage: null,
    );
  }

  /// Manual transition to offline for testing or disconnection events.
  void setOfflineManually({String? reason}) {
    state = state.copyWith(
      status: ConnectivityStatus.offline,
      lastProbeAt: DateTime.now(),
      latencyMs: null,
      consecutiveFailures: state.consecutiveFailures + 1,
      errorMessage: reason ?? 'Manually disconnected',
    );
  }

  @override
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _monitorTimer?.cancel();
    _monitorTimer = null;
    super.dispose();
  }
}
