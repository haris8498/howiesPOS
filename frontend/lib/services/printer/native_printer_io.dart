import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Desktop & IO Native Windows Spooler Direct Printing Engine
/// Bypasses all print dialogs, PDF renderers, and OneNote.
/// Transmits raw ESC/POS binary directly to the hardware thermal printer queue via winspool.drv.
class NativeWin32Printer {
  static const String _psRawPrinterDefinition = r'''
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public class RawSpoolerHelper {
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public class DOCINFOW {
        [MarshalAs(UnmanagedType.LPWStr)] public string pDocName;
        [MarshalAs(UnmanagedType.LPWStr)] public string pOutputFile;
        [MarshalAs(UnmanagedType.LPWStr)] public string pDataType;
    }

    [DllImport("winspool.Drv", EntryPoint = "OpenPrinterW", SetLastError = true, ExactSpelling = true, CallingConvention = CallingConvention.StdCall)]
    public static extern bool OpenPrinter([MarshalAs(UnmanagedType.LPWStr)] string szPrinter, out IntPtr hPrinter, IntPtr pd);

    [DllImport("winspool.Drv", EntryPoint = "ClosePrinter", SetLastError = true, ExactSpelling = true, CallingConvention = CallingConvention.StdCall)]
    public static extern bool ClosePrinter(IntPtr hPrinter);

    [DllImport("winspool.Drv", EntryPoint = "StartDocPrinterW", SetLastError = true, ExactSpelling = true, CallingConvention = CallingConvention.StdCall)]
    public static extern bool StartDocPrinter(IntPtr hPrinter, int level, [In, MarshalAs(UnmanagedType.LPStruct)] DOCINFOW di);

    [DllImport("winspool.Drv", EntryPoint = "EndDocPrinter", SetLastError = true, ExactSpelling = true, CallingConvention = CallingConvention.StdCall)]
    public static extern bool EndDocPrinter(IntPtr hPrinter);

    [DllImport("winspool.Drv", EntryPoint = "StartPagePrinter", SetLastError = true, ExactSpelling = true, CallingConvention = CallingConvention.StdCall)]
    public static extern bool StartPagePrinter(IntPtr hPrinter);

    [DllImport("winspool.Drv", EntryPoint = "EndPagePrinter", SetLastError = true, ExactSpelling = true, CallingConvention = CallingConvention.StdCall)]
    public static extern bool EndPagePrinter(IntPtr hPrinter);

    [DllImport("winspool.Drv", EntryPoint = "WritePrinter", SetLastError = true, ExactSpelling = true, CallingConvention = CallingConvention.StdCall)]
    public static extern bool WritePrinter(IntPtr hPrinter, IntPtr pBytes, int dwCount, out int dwWritten);

    public static bool SendRawBytes(string szPrinterName, byte[] bytes, string docName) {
        IntPtr hPrinter = IntPtr.Zero;
        DOCINFOW di = new DOCINFOW();
        di.pDocName = docName;
        di.pDataType = "RAW";
        bool success = false;

        if (OpenPrinter(szPrinterName, out hPrinter, IntPtr.Zero)) {
            if (StartDocPrinter(hPrinter, 1, di)) {
                if (StartPagePrinter(hPrinter)) {
                    IntPtr pUnmanagedBytes = Marshal.AllocCoTaskMem(bytes.Length);
                    Marshal.Copy(bytes, 0, pUnmanagedBytes, bytes.Length);
                    int dwWritten = 0;
                    success = WritePrinter(hPrinter, pUnmanagedBytes, bytes.Length, out dwWritten);
                    Marshal.FreeCoTaskMem(pUnmanagedBytes);
                    EndPagePrinter(hPrinter);
                }
                EndDocPrinter(hPrinter);
            }
            ClosePrinter(hPrinter);
        }
        return success;
    }
}
"@ -ErrorAction SilentlyContinue
''';

  /// Sends raw byte payload (ESC/POS) directly to a Windows Spooler printer queue.
  /// Zero print dialogs. Zero OneNote dependencies. Returns true on success.
  static Future<bool> printRawBytesToSpooler(
    String printerName,
    Uint8List rawBytes, {
    String docName = 'POS Thermal Receipt',
  }) async {
    if (!Platform.isWindows) return false;

    // 1. Ultra-fast direct native spooler executable check (<20ms)
    final tempBin = File('${Directory.systemTemp.path}\\pos_raw_${DateTime.now().millisecondsSinceEpoch}.bin');
    try {
      await tempBin.writeAsBytes(rawBytes, flush: true);

      final candidatePaths = [
        '${Directory.current.path}\\windows\\RawSpooler.exe',
        '${Directory.current.path}\\RawSpooler.exe',
        '${Directory.current.path}\\..\\backend\\bin\\RawSpooler.exe',
        'c:\\flutter\\Howies POS\\backend\\bin\\RawSpooler.exe',
      ];

      for (final exePath in candidatePaths) {
        if (File(exePath).existsSync()) {
          final res = await Process.run(exePath, [printerName, tempBin.path, docName]);
          if ((res.stdout as String).contains('OK')) {
            return true;
          }
        }
      }
    } catch (e) {
      debugPrint('Native spooler direct exe check: $e');
    } finally {
      if (tempBin.existsSync()) {
        try {
          tempBin.deleteSync();
        } catch (_) {}
      }
    }

    // 2. Reliable PowerShell Fallback
    try {
      final b64 = base64Encode(rawBytes);
      final script = '''
$_psRawPrinterDefinition
\$bytes = [System.Convert]::FromBase64String('$b64')
\$res = [RawSpoolerHelper]::SendRawBytes('$printerName', \$bytes, '$docName')
if (\$res) { "OK" } else { "FAIL" }
''';

      final result = await Process.run(
        'powershell',
        ['-NoProfile', '-NonInteractive', '-Command', script],
        runInShell: true,
      );

      final output = (result.stdout as String).trim();
      return output.contains('OK');
    } catch (e) {
      debugPrint('NativeWin32Printer spooler error: $e');
      return false;
    }
  }

  /// Sends raw byte payload directly to a local USB / Serial / Parallel port.
  /// (e.g. "\\\\.\\USB001", "\\\\.\\COM1", "LPT1")
  static Future<bool> printRawBytesToPort(String portName, Uint8List rawBytes) async {
    if (!Platform.isWindows) return false;
    try {
      final formattedPort = portName.startsWith(r'\\.\') ? portName : r'\\.\' + portName;
      final file = File(formattedPort);
      final raf = await file.open(mode: FileMode.writeOnly);
      await raf.writeFrom(rawBytes);
      await raf.flush();
      await raf.close();
      return true;
    } catch (e) {
      debugPrint('Direct port print error on $portName: $e');
      return false;
    }
  }

  /// Discovers all Windows printer queue names via PowerShell without triggering UI.
  static Future<List<String>> getInstalledWindowsPrinters() async {
    if (!Platform.isWindows) return [];
    try {
      final result = await Process.run(
        'powershell',
        ['-NoProfile', '-Command', "Get-Printer | Select-Object -ExpandProperty Name"],
        runInShell: true,
      );
      if (result.exitCode == 0) {
        final lines = (result.stdout as String)
            .split(RegExp(r'[\r\n]+'))
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
        return lines;
      }
    } catch (e) {
      debugPrint('Error getting Windows printers: $e');
    }
    return [];
  }

  /// Discovers available USB and COM ports (e.g., USB001, COM1, etc.)
  static Future<List<String>> getAvailablePrinterPorts() async {
    if (!Platform.isWindows) return [];
    try {
      final result = await Process.run(
        'powershell',
        [
          '-NoProfile',
          '-Command',
          "Get-PrinterPort | Where-Object { \$_.Name -match 'USB|COM|LPT' } | Select-Object -ExpandProperty Name"
        ],
        runInShell: true,
      );
      if (result.exitCode == 0) {
        final lines = (result.stdout as String)
            .split(RegExp(r'[\r\n]+'))
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
        return lines;
      }
    } catch (e) {
      debugPrint('Error getting printer ports: $e');
    }
    return ['USB001', 'COM1', 'COM2', 'COM3'];
  }

  /// Ensures a Windows spooler Generic/Text Only printer queue is registered for the USB thermal printer
  static Future<bool> ensurePosPrinterInstalled({
    String printerName = 'POS Receipt Printer',
    String portName = 'USB001',
  }) async {
    if (!Platform.isWindows) return false;
    try {
      final script = '''
try {
  \$existing = Get-Printer -Name "$printerName" -ErrorAction SilentlyContinue
  if (\$null -eq \$existing) {
    try { Add-PrinterDriver -Name "Generic / Text Only" -ErrorAction SilentlyContinue } catch {}
    Add-Printer -Name "$printerName" -DriverName "Generic / Text Only" -PortName "$portName" -ErrorAction Stop
  }
  "OK"
} catch {
  \$_.Exception.Message
}
''';
      final result = await Process.run(
        'powershell',
        ['-NoProfile', '-Command', script],
        runInShell: true,
      );
      final output = (result.stdout as String).trim();
      return output.contains('OK');
    } catch (e) {
      debugPrint('Error ensuring POS printer installed: $e');
      return false;
    }
  }
}
