import 'package:flutter/foundation.dart';

/// Web fallback stub for native Windows printer
class NativeWin32Printer {
  static Future<bool> printRawBytesToSpooler(
    String printerName,
    Uint8List rawBytes, {
    String docName = 'POS Thermal Receipt',
  }) async {
    return false;
  }

  static Future<bool> printRawBytesToPort(
    String portName,
    Uint8List rawBytes,
  ) async {
    return false;
  }

  static Future<List<String>> getInstalledWindowsPrinters() async {
    return [];
  }

  static Future<List<String>> getAvailablePrinterPorts() async {
    return [];
  }

  static Future<bool> ensurePosPrinterInstalled({
    String printerName = 'POS Receipt Printer',
    String portName = 'USB001',
  }) async {
    return false;
  }
}
