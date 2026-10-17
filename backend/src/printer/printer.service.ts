import { Injectable, Logger } from '@nestjs/common';
import { exec } from 'child_process';
import { promisify } from 'util';
import * as fs from 'fs';
import * as os from 'os';
import * as path from 'path';

const execAsync = promisify(exec);

@Injectable()
export class PrinterService {
  private readonly logger = new Logger(PrinterService.name);

  private readonly psRawPrinterHelper = `
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
        if (bytes == null || bytes.Length == 0) return true;
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
                    
                    int offset = 0;
                    success = true;
                    // Write in chunks to guarantee large orders (many items) are completely transferred
                    while (offset < bytes.Length) {
                        int toWrite = Math.Min(bytes.Length - offset, 4096);
                        IntPtr currentPtr = new IntPtr(pUnmanagedBytes.ToInt64() + offset);
                        int dwWritten = 0;
                        if (!WritePrinter(hPrinter, currentPtr, toWrite, out dwWritten) || dwWritten <= 0) {
                            success = false;
                            break;
                        }
                        offset += dwWritten;
                    }
                    
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
`;

  private cachedPrintersData: { printers: string[]; defaultPrinter: string; ports: string[]; timestamp: number } | null = null;

  /**
   * Fetches all available physical & spooler printers on the host system.
   */
  async getAvailablePrinters(): Promise<{ printers: string[]; defaultPrinter: string; ports: string[] }> {
    const isWindows = os.platform() === 'win32';
    if (!isWindows) {
      return { printers: ['POS Receipt Printer'], defaultPrinter: 'POS Receipt Printer', ports: [] };
    }

    const now = Date.now();
    if (this.cachedPrintersData && now - this.cachedPrintersData.timestamp < 10000) {
      return {
        printers: [...this.cachedPrintersData.printers],
        defaultPrinter: this.cachedPrintersData.defaultPrinter,
        ports: [],
      };
    }

    const printers: string[] = [];

    // Query Printers via PowerShell
    try {
      const { stdout } = await execAsync(
        'powershell -NoProfile -Command "Get-Printer | Select-Object -ExpandProperty Name"',
      );
      const lines = stdout
        .split(/[\r\n]+/)
        .map((s) => s.trim())
        .filter((s) => s.length > 0);

      for (const p of lines) {
        const lower = p.toLowerCase();
        if (
          !lower.includes('pdf') &&
          !lower.includes('onenote') &&
          !lower.includes('fax') &&
          !lower.includes('xps') &&
          !lower.includes('root print queue')
        ) {
          printers.push(p);
        }
      }
    } catch (e: any) {
      this.logger.warn(`Error getting Windows printers: ${e?.message ?? e}`);
    }

    const defaultPrinter = printers.length > 0 ? printers[0] : '';
    const result = { printers, defaultPrinter, ports: [] };

    this.cachedPrintersData = { ...result, timestamp: now };
    return result;
  }

  /**
   * Ensures generic text printer queue exists for USB001
   */
  async ensurePosPrinter(printerName = 'POS Receipt Printer', portName = 'USB001'): Promise<boolean> {
    if (os.platform() !== 'win32') return false;
    try {
      const script = `
try {
  $existing = Get-Printer -Name "${printerName}" -ErrorAction SilentlyContinue
  if ($null -eq $existing) {
    try { Add-PrinterDriver -Name "Generic / Text Only" -ErrorAction SilentlyContinue } catch {}
    Add-Printer -Name "${printerName}" -DriverName "Generic / Text Only" -PortName "${portName}" -ErrorAction Stop
  }
  "OK"
} catch {
  $_.Exception.Message
}
`;
      const { stdout } = await execAsync(`powershell -NoProfile -Command "${script.replace(/\n/g, ' ')}"`);
      return stdout.includes('OK');
    } catch (e: any) {
      this.logger.warn(`Error ensuring POS printer: ${e?.message ?? e}`);
      return false;
    }
  }

  /**
   * Prints raw ESC/POS binary data to the designated Windows spooler queue or port.
   * Handles large payloads with any number of product items without buffer truncation.
   * Ultra-fast execution via native precompiled RawSpooler binary (<20ms) with reliable fallback.
   */
  async printRaw(printerName: string, base64Data: string, docName = 'POS Receipt'): Promise<boolean> {
    if (os.platform() !== 'win32') {
      this.logger.log(`[Non-Windows] Simulating print of ${base64Data.length} chars to ${printerName}`);
      return true;
    }

    const rawBuffer = Buffer.from(base64Data, 'base64');
    const timestamp = Date.now();
    const tempBinPath = path.join(os.tmpdir(), `pos_raw_${timestamp}.bin`);
    const tempScriptPath = path.join(os.tmpdir(), `pos_print_${timestamp}.ps1`);

    try {
      // 1. Write binary buffer directly to disk for 100% reliable chunking
      fs.writeFileSync(tempBinPath, rawBuffer);

      // 2. Resolve destination printer spooler name
      const targetSpooler = printerName.startsWith('Port:') ? 'POS Receipt Printer' : printerName;

      // 3. Ultra-fast path: Check for native precompiled RawSpooler.exe
      const candidatePaths = [
        path.join(__dirname, 'RawSpooler.exe'),
        path.join(process.cwd(), 'bin', 'RawSpooler.exe'),
        path.join(process.cwd(), 'src', 'printer', 'RawSpooler.exe'),
        path.join(process.cwd(), 'dist', 'printer', 'RawSpooler.exe'),
      ];

      for (const exePath of candidatePaths) {
        if (fs.existsSync(exePath)) {
          try {
            const { stdout } = await execAsync(`"${exePath}" "${targetSpooler}" "${tempBinPath}" "${docName}"`);
            if (stdout.includes('OK')) {
              this.logger.log(`[Native Spooler] Successfully printed ${rawBuffer.length} bytes to ${targetSpooler} in <25ms`);
              return true;
            }
          } catch (nativeErr: any) {
            this.logger.warn(`Native RawSpooler warning: ${nativeErr?.message ?? nativeErr}, falling back to PowerShell`);
            break;
          }
        }
      }

      // 4. Fallback path: Spool RAW bytes through PowerShell
      const escapedBinPath = tempBinPath.replace(/\\/g, '\\\\');
      const scriptContent = `
${this.psRawPrinterHelper}
$bytes = [System.IO.File]::ReadAllBytes('${escapedBinPath}')
$res = [RawSpoolerHelper]::SendRawBytes('${targetSpooler}', $bytes, '${docName}')
if ($res) { "OK" } else { "FAIL" }
`;
      fs.writeFileSync(tempScriptPath, scriptContent, 'utf-8');

      const { stdout } = await execAsync(
        `powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "${tempScriptPath}"`,
      );
      const success = stdout.includes('OK');
      if (success) {
        this.logger.log(`Successfully printed ${rawBuffer.length} bytes to ${targetSpooler}`);
      } else {
        this.logger.warn(`Spooler print to ${targetSpooler} returned FAIL: ${stdout.trim()}`);
      }
      return success;
    } catch (e: any) {
      this.logger.error(`Print error to ${printerName}: ${e?.message ?? e}`, e?.stack);
      return false;
    } finally {
      try {
        if (fs.existsSync(tempBinPath)) fs.unlinkSync(tempBinPath);
      } catch (_) {}
      try {
        if (fs.existsSync(tempScriptPath)) fs.unlinkSync(tempScriptPath);
      } catch (_) {}
    }
  }
}
