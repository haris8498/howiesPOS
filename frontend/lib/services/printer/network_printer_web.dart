import 'package:flutter/foundation.dart';

/// Web stub for NetworkPrinter
class NetworkPrinter {
  static Future<bool> sendRawBytesToNetworkPrinter(
    String host,
    int port,
    Uint8List rawBytes, {
    Duration timeout = const Duration(seconds: 4),
  }) async {
    return false;
  }

  static Future<bool> pingPrinter(
    String host,
    int port, {
    Duration timeout = const Duration(seconds: 2),
  }) async {
    return false;
  }
}
