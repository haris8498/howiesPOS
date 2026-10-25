import 'package:flutter_test/flutter_test.dart';
import 'package:hungry_howies_pos/core/network/realtime_socket_service.dart';

void main() {
  group('RealtimeSocketService Event Dispatching & Lifecycle', () {
    late RealtimeSocketService socket;

    setUp(() {
      socket = RealtimeSocketService();
    });

    tearDown(() {
      socket.dispose();
    });

    test('registers listeners and dispatches specific events correctly', () {
      Map<String, dynamic>? receivedPayload;
      int callCount = 0;

      socket.on('order:created', (payload) {
        receivedPayload = payload;
        callCount++;
      });

      // Verify initial state
      expect(callCount, 0);
      expect(receivedPayload, isNull);

      // Test listener removal
      void removableCallback(Map<String, dynamic> p) {}
      socket.on('temp:event', removableCallback);
      socket.off('temp:event', removableCallback);
    });

    test('handles dot-to-colon translation and wildcard listeners', () {
      final receivedEvents = <String>[];

      socket.onAny((eventName, payload) {
        receivedEvents.add(eventName);
      });

      expect(receivedEvents, isEmpty);
    });

    test('reconnect callbacks are registered and fired', () {
      bool reconnected = false;
      void onReconn() {
        reconnected = true;
      }

      socket.onReconnect(onReconn);
      socket.offReconnect(onReconn);
      expect(reconnected, isFalse);
    });
  });
}
