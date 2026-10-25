import 'dart:async';
import 'realtime_socket_service.dart';

export 'realtime_socket_service.dart' show SocketEventCallback;

/// Real-Time WebSocket / Socket.IO v4 Client for Kitchen / KDS Order Events (Cross-Platform)
/// Backed by the centralized application-wide [RealtimeSocketService].
class KitchenSocketService {
  final RealtimeSocketService _realtime = RealtimeSocketService.instance;

  bool get isConnected => _realtime.isConnected;

  /// Connect to the NestJS Gateway
  Future<void> connect({String? socketUrl}) => _realtime.connect(socketUrl: socketUrl);

  /// Add a listener for a specific event
  void on(String eventName, SocketEventCallback callback) => _realtime.on(eventName, callback);

  /// Remove a listener
  void off(String eventName, [SocketEventCallback? callback]) => _realtime.off(eventName, callback);

  /// Join kitchen room
  void joinKitchen() => _realtime.joinKitchen();

  /// Leave kitchen room
  void leaveKitchen() => _realtime.leaveKitchen();

  /// Clean up
  void dispose() {
    // Delegated to centralized lifecycle
  }
}
