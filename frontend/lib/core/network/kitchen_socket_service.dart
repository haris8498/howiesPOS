import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../config/api_config.dart';
import '../security/token_storage.dart';

typedef SocketEventCallback = void Function(Map<String, dynamic> payload);

/// Real-Time WebSocket / Socket.IO v4 Client for Kitchen / KDS Order Events (Cross-Platform)
class KitchenSocketService {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  bool _isDisposed = false;
  bool _isConnected = false;

  final Map<String, List<SocketEventCallback>> _listeners = {};

  bool get isConnected => _isConnected;

  /// Connect to the NestJS Kitchen Gateway
  Future<void> connect({String? socketUrl}) async {
    if (_isConnected || _isDisposed) return;

    final baseUrl = socketUrl ?? ApiConfig.socketUrl;
    final token = await TokenStorage.getToken();

    try {
      // Build Socket.IO v4 WebSocket URI
      final uri = Uri.parse(baseUrl).replace(
        scheme: Uri.parse(baseUrl).scheme == 'https' ? 'wss' : 'ws',
        path: '/socket.io/',
        queryParameters: {
          'EIO': '4',
          'transport': 'websocket',
          if (token != null && token.isNotEmpty) 'token': token,
        },
      );

      _channel = WebSocketChannel.connect(uri);
      await _channel?.ready.timeout(const Duration(seconds: 5));

      _isConnected = true;

      // Send Socket.IO connect packet with auth token
      final authPayload = token != null ? jsonEncode({'token': token}) : '{}';
      _channel?.sink.add('40$authPayload');

      // Subscribe to messages
      _subscription?.cancel();
      _subscription = _channel?.stream.listen(
        _handleMessage,
        onDone: _handleDisconnect,
        onError: (err) => _handleDisconnect(),
        cancelOnError: true,
      );

      // Setup Heartbeat / Keepalive
      _pingTimer?.cancel();
      _pingTimer = Timer.periodic(const Duration(seconds: 20), (timer) {
        if (_isConnected && _channel != null) {
          _channel?.sink.add('2'); // Engine.IO ping
        }
      });
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _handleMessage(dynamic data) {
    if (data is! String) return;

    // Engine.IO ping -> respond pong
    if (data == '2') {
      _channel?.sink.add('3'); // Engine.IO pong
      return;
    }

    // Engine.IO pong
    if (data == '3') return;

    // Socket.IO event: 42["event_name", {payload}]
    if (data.startsWith('42')) {
      try {
        final jsonStr = data.substring(2);
        final list = jsonDecode(jsonStr);
        if (list is List && list.isNotEmpty) {
          final eventName = list[0].toString();
          final payload = list.length > 1 && list[1] is Map<String, dynamic>
              ? list[1] as Map<String, dynamic>
              : <String, dynamic>{};

          _notifyListeners(eventName, payload);
        }
      } catch (_) {}
    }
  }

  void _notifyListeners(String eventName, Map<String, dynamic> payload) {
    final callbacks = _listeners[eventName];
    if (callbacks != null) {
      for (final callback in List<SocketEventCallback>.from(callbacks)) {
        try {
          callback(payload);
        } catch (_) {}
      }
    }

    // Also notify wildcard listeners
    final wildcardCallbacks = _listeners['*'];
    if (wildcardCallbacks != null) {
      for (final callback in List<SocketEventCallback>.from(wildcardCallbacks)) {
        try {
          callback({'event': eventName, 'data': payload});
        } catch (_) {}
      }
    }
  }

  void _handleDisconnect() {
    _isConnected = false;
    _pingTimer?.cancel();
    if (!_isDisposed) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _isConnected = false;
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (!_isDisposed) {
        connect();
      }
    });
  }

  /// Add a listener for a specific event (e.g. 'order.created', 'order.status_changed', 'order.ready')
  void on(String eventName, SocketEventCallback callback) {
    _listeners.putIfAbsent(eventName, () => []);
    if (!_listeners[eventName]!.contains(callback)) {
      _listeners[eventName]!.add(callback);
    }
  }

  /// Remove a listener
  void off(String eventName, [SocketEventCallback? callback]) {
    if (callback != null) {
      _listeners[eventName]?.remove(callback);
    } else {
      _listeners.remove(eventName);
    }
  }

  /// Join kitchen room
  void joinKitchen() {
    if (_isConnected && _channel != null) {
      _channel?.sink.add('42["join_kitchen",{}]');
    }
  }

  /// Leave kitchen room
  void leaveKitchen() {
    if (_isConnected && _channel != null) {
      _channel?.sink.add('42["leave_kitchen",{}]');
    }
  }

  /// Clean up and disconnect
  void dispose() {
    _isDisposed = true;
    _isConnected = false;
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _listeners.clear();
    _channel?.sink.close();
    _channel = null;
  }
}
