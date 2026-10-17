import 'dart:io';
import 'package:flutter/foundation.dart';

/// Direct TCP Socket Printer Engine for LAN / Ethernet / Wi-Fi Thermal Printers
/// Standard ESC/POS raw TCP port is 9100.
class NetworkPrinter {
  static Future<bool> sendRawBytesToNetworkPrinter(
    String host,
    int port,
    Uint8List rawBytes, {
    Duration timeout = const Duration(seconds: 4),
  }) async {
    Socket? socket;
    try {
      socket = await Socket.connect(host, port, timeout: timeout);
      socket.add(rawBytes);
      await socket.flush();
      await socket.close();
      return true;
    } catch (e) {
      debugPrint('Network printer communication error ($host:$port): $e');
      socket?.destroy();
      return false;
    }
  }

  /// Tests connectivity to a network thermal printer
  static Future<bool> pingPrinter(
    String host,
    int port, {
    Duration timeout = const Duration(seconds: 2),
  }) async {
    try {
      final socket = await Socket.connect(host, port, timeout: timeout);
      await socket.close();
      return true;
    } catch (_) {
      return false;
    }
  }
}
