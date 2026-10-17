using System;
using System.IO;
using System.Runtime.InteropServices;

namespace HowiesPOS {
    public class RawSpooler {
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

        public static int Main(string[] args) {
            if (args.Length < 2) {
                Console.WriteLine("Usage: RawSpooler.exe <printerName> <binaryFilePath> [docName]");
                return 1;
            }

            string szPrinterName = args[0];
            string filePath = args[1];
            string docName = args.Length > 2 ? args[2] : "POS Receipt";

            if (!File.Exists(filePath)) {
                Console.WriteLine("FILE_NOT_FOUND");
                return 2;
            }

            byte[] bytes = File.ReadAllBytes(filePath);
            if (bytes == null || bytes.Length == 0) {
                Console.WriteLine("OK");
                return 0;
            }

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

            if (success) {
                Console.WriteLine("OK");
                return 0;
            } else {
                Console.WriteLine("FAIL");
                return 3;
            }
        }
    }
}
