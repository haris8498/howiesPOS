import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../config/api_config.dart';
import '../security/token_storage.dart';

typedef SocketEventCallback = void Function(Map<String, dynamic> payload);
typedef SocketAnyEventCallback = void Function(String eventName, Map<String, dynamic> payload);
typedef SocketReconnectCallback = FutureOr<void> Function();

/// Centralized Real-Time Socket.IO v4 Client for Hungry Howie's POS.
/// Maintains a single authenticated WebSocket connection across the application lifecycle.
class RealtimeSocketService {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  bool _isDisposed = false;
  bool _isConnected = false;
  bool _isConnecting = false;
  bool _hasEverConnected = false;
  int _reconnectAttempts = 0;

  final Map<String, Set<SocketEventCallback>> _listeners = {};
  final Set<SocketAnyEventCallback> _anyListeners = {};
  final Set<SocketReconnectCallback> _reconnectListeners = {};

  final StreamController<bool> _connectionStateController =
      StreamController<bool>.broadcast();

  bool get isConnected => _isConnected;
  Stream<bool> get connectionStream => _connectionStateController.stream;

  static RealtimeSocketService? _instance;
  static RealtimeSocketService get instance {
    _instance ??= RealtimeSocketService();
    return _instance!;
  }

  /// Connect to the NestJS Realtime Gateway
  Future<void> connect({String? socketUrl, String? explicitToken}) async {
    if (_isDisposed || _isConnected || _isConnecting) return;
    _isConnecting = true;

    final baseUrl = socketUrl ?? ApiConfig.socketUrl;
    final token = explicitToken ?? await TokenStorage.getToken();

    if (token == null || token.isEmpty) {
      debugPrint('[RealtimeSocket] No auth token available. Awaiting user login.');
      _isConnecting = false;
      return;
    }

    try {
      final parsedUri = Uri.parse(baseUrl);
      final wsScheme = parsedUri.scheme == 'https' ? 'wss' : 'ws';

      // Build Socket.IO v4 WebSocket URI with query parameters
      final uri = parsedUri.replace(
        scheme: wsScheme,
        path: '/socket.io/',
        queryParameters: {
          'EIO': '4',
          'transport': 'websocket',
          'token': token,
        },
      );

      debugPrint('[RealtimeSocket] Connecting to ${uri.scheme}://${uri.host}:${uri.port}${uri.path}...');

      _channel = WebSocketChannel.connect(uri);
      await _channel?.ready.timeout(const Duration(seconds: 6));

      _isConnecting = false;

      // Send Socket.IO connect packet with auth token for root namespace '/'
      final authPayload = jsonEncode({'token': token});
      _channel?.sink.add('40$authPayload');

      // Join standard rooms
      joinPos();
      joinKitchen();

      debugPrint('[RealtimeSocket] WebSocket transport opened. Awaiting Socket.IO namespace handshake...');

      // Listen to incoming messages
      _subscription?.cancel();
      _subscription = _channel?.stream.listen(
        _handleMessage,
        onDone: () {
          debugPrint('[RealtimeSocket] Connection closed by server.');
          _handleDisconnect();
        },
        onError: (err) {
          debugPrint('[RealtimeSocket] Socket connection error: $err');
          _handleDisconnect();
        },
        cancelOnError: true,
      );

      // Heartbeat / Keepalive (Engine.IO PING every 20 seconds)
      _pingTimer?.cancel();
      _pingTimer = Timer.periodic(const Duration(seconds: 20), (timer) {
        if (_isConnected && _channel != null) {
          try {
            _channel?.sink.add('2'); // Engine.IO ping
          } catch (_) {
            _handleDisconnect();
          }
        }
      });
    } catch (e) {
      debugPrint('[RealtimeSocket] Connection failed: $e');
      _isConnecting = false;
      _handleDisconnect();
    }
  }

  void _handleMessage(dynamic data) {
    if (data is! String) return;

    // Engine.IO ping from server -> respond with pong
    if (data == '2') {
      try {
        _channel?.sink.add('3'); // Engine.IO pong
      } catch (_) {}
      return;
    }

    // Engine.IO pong from server
    if (data == '3') return;

    // Engine.IO open handshake packet: 0{"sid":...}
    if (data.startsWith('0{')) {
      debugPrint('[RealtimeSocket] Engine.IO handshake open received.');
      return;
    }

    // Socket.IO connect acknowledgment: 40 or 40{"sid":...}
    if (data.startsWith('40')) {
      debugPrint('[RealtimeSocket] Socket.IO namespace handshake established & authenticated.');
      final wasAlreadyConnected = _isConnected;
      _isConnected = true;
      _reconnectAttempts = 0;
      _connectionStateController.add(true);

      if (!wasAlreadyConnected && _hasEverConnected) {
        debugPrint('[RealtimeSocket] Restored connection to server. Notifying reconnect listeners.');
        _notifyReconnectListeners();
      }
      _hasEverConnected = true;
      return;
    }

    // Socket.IO custom event: 42["event_name", {payload}]
    if (data.startsWith('42')) {
      try {
        final jsonStr = data.substring(2);
        final list = jsonDecode(jsonStr);
        if (list is List && list.isNotEmpty) {
          final eventName = list[0].toString();
          final payload = list.length > 1 && list[1] is Map<String, dynamic>
              ? list[1] as Map<String, dynamic>
              : (list.length > 1 ? {'data': list[1]} : <String, dynamic>{});

          debugPrint('[RealtimeSocket] Received event: $eventName');
          _notifyListeners(eventName, payload);
        }
      } catch (err) {
        debugPrint('[RealtimeSocket] Failed to parse event packet: $err');
      }
    }
  }

  void _notifyListeners(String eventName, Map<String, dynamic> payload) {
    // Notify specific event listeners
    final callbacks = _listeners[eventName];
    if (callbacks != null && callbacks.isNotEmpty) {
      for (final callback in List<SocketEventCallback>.from(callbacks)) {
        try {
          callback(payload);
        } catch (err) {
          debugPrint('[RealtimeSocket] Error in listener for $eventName: $err');
        }
      }
    }

    // Also support dot / colon translation (e.g. if order.created was emitted, notify order:created too)
    String? alternateName;
    if (eventName.contains(':')) {
      alternateName = eventName.replaceAll(':', '.');
    } else if (eventName.contains('.')) {
      alternateName = eventName.replaceAll('.', ':');
    }

    if (alternateName != null) {
      final altCallbacks = _listeners[alternateName];
      if (altCallbacks != null && altCallbacks.isNotEmpty) {
        for (final callback in List<SocketEventCallback>.from(altCallbacks)) {
          try {
            callback(payload);
          } catch (err) {
            debugPrint('[RealtimeSocket] Error in alt listener for $alternateName: $err');
          }
        }
      }
    }

    // Notify any/wildcard listeners
    if (_anyListeners.isNotEmpty) {
      for (final callback in List<SocketAnyEventCallback>.from(_anyListeners)) {
        try {
          callback(eventName, payload);
        } catch (err) {
          debugPrint('[RealtimeSocket] Error in anyListener: $err');
        }
      }
    }
  }

  void _handleDisconnect() {
    final wasConnected = _isConnected;
    _isConnected = false;
    _isConnecting = false;
    _pingTimer?.cancel();

    if (wasConnected) {
      _connectionStateController.add(false);
    }

    if (!_isDisposed) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();

    // Exponential backoff: 5s, 10s, 15s, up to 30s max
    _reconnectAttempts++;
    final delaySeconds = (_reconnectAttempts * 5).clamp(5, 30);

    debugPrint('[RealtimeSocket] Scheduling reconnect attempt #$_reconnectAttempts in ${delaySeconds}s...');

    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () async {
      if (!_isDisposed && !_isConnected && !_isConnecting) {
        await connect();
      }
    });
  }

  void _notifyReconnectListeners() {
    for (final callback in List<SocketReconnectCallback>.from(_reconnectListeners)) {
      try {
        callback();
      } catch (err) {
        debugPrint('[RealtimeSocket] Error in reconnect callback: $err');
      }
    }
  }

  /// Register a listener for a specific event
  void on(String eventName, SocketEventCallback callback) {
    _listeners.putIfAbsent(eventName, () => <SocketEventCallback>{});
    _listeners[eventName]!.add(callback);
  }

  /// Remove a listener
  void off(String eventName, [SocketEventCallback? callback]) {
    if (callback != null) {
      _listeners[eventName]?.remove(callback);
      if (_listeners[eventName]?.isEmpty ?? false) {
        _listeners.remove(eventName);
      }
    } else {
      _listeners.remove(eventName);
    }
  }

  /// Register a wildcard listener for all events
  void onAny(SocketAnyEventCallback callback) {
    _anyListeners.add(callback);
  }

  /// Remove a wildcard listener
  void offAny(SocketAnyEventCallback callback) {
    _anyListeners.remove(callback);
  }

  /// Register a callback to be fired whenever reconnection succeeds
  void onReconnect(SocketReconnectCallback callback) {
    _reconnectListeners.add(callback);
  }

  /// Remove a reconnect callback
  void offReconnect(SocketReconnectCallback callback) {
    _reconnectListeners.remove(callback);
  }

  /// Remove all event listeners to prevent duplicate listener accumulation
  void clearAllListeners() {
    _listeners.clear();
    _anyListeners.clear();
  }

  /// Clear all reconnect listeners
  void clearReconnectListeners() {
    _reconnectListeners.clear();
  }

  /// Join POS room
  void joinPos() {
    if (_isConnected && _channel != null) {
      try {
        _channel?.sink.add('42["join_pos",{}]');
      } catch (_) {}
    }
  }

  /// Join Kitchen room
  void joinKitchen() {
    if (_isConnected && _channel != null) {
      try {
        _channel?.sink.add('42["join_kitchen",{}]');
      } catch (_) {}
    }
  }

  /// Leave Kitchen room
  void leaveKitchen() {
    if (_isConnected && _channel != null) {
      try {
        _channel?.sink.add('42["leave_kitchen",{}]');
      } catch (_) {}
    }
  }

  /// Disconnect explicitly (e.g. on user logout)
  void disconnect() {
    debugPrint('[RealtimeSocket] Disconnecting socket...');
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    _isConnected = false;
    _isConnecting = false;
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
    _channel = null;
    _connectionStateController.add(false);
  }

  /// Clean up and dispose all resources
  void dispose() {
    _isDisposed = true;
    disconnect();
    _listeners.clear();
    _anyListeners.clear();
    _reconnectListeners.clear();
    _connectionStateController.close();
  }
}

/// Riverpod provider for RealtimeSocketService
final realtimeSocketServiceProvider = Provider<RealtimeSocketService>((ref) {
  final service = RealtimeSocketService.instance;
  ref.onDispose(() {
    // Keep connection alive across standard widget life cycles
  });
  return service;
});
