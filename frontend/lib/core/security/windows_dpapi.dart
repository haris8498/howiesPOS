import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as p;

/// Exception thrown when a Windows DPAPI cryptographic operation fails.
class DpapiException implements Exception {
  final String message;
  final int? errorCode;

  const DpapiException(this.message, [this.errorCode]);

  @override
  String toString() {
    if (errorCode != null) {
      return 'DpapiException: $message (Windows Error Code: $errorCode)';
    }
    return 'DpapiException: $message';
  }
}

/// Win32 DATA_BLOB struct for DPAPI.
final class DataBlob extends Struct {
  @Uint32()
  external int cbData;

  external Pointer<Uint8> pbData;
}

typedef _CryptProtectDataNative = Int32 Function(
  Pointer<DataBlob> pDataIn,
  Pointer<Utf16> szDataDescr,
  Pointer<DataBlob> pOptionalEntropy,
  Pointer<Void> pvReserved,
  Pointer<Void> pPromptStruct,
  Uint32 dwFlags,
  Pointer<DataBlob> pDataOut,
);

typedef _CryptProtectDataDart = int Function(
  Pointer<DataBlob> pDataIn,
  Pointer<Utf16> szDataDescr,
  Pointer<DataBlob> pOptionalEntropy,
  Pointer<Void> pvReserved,
  Pointer<Void> pPromptStruct,
  int dwFlags,
  Pointer<DataBlob> pDataOut,
);

typedef _CryptUnprotectDataNative = Int32 Function(
  Pointer<DataBlob> pDataIn,
  Pointer<Pointer<Utf16>> ppszDataDescr,
  Pointer<DataBlob> pOptionalEntropy,
  Pointer<Void> pvReserved,
  Pointer<Void> pPromptStruct,
  Uint32 dwFlags,
  Pointer<DataBlob> pDataOut,
);

typedef _CryptUnprotectDataDart = int Function(
  Pointer<DataBlob> pDataIn,
  Pointer<Pointer<Utf16>> ppszDataDescr,
  Pointer<DataBlob> pOptionalEntropy,
  Pointer<Void> pvReserved,
  Pointer<Void> pPromptStruct,
  int dwFlags,
  Pointer<DataBlob> pDataOut,
);

typedef _LocalFreeNative = Pointer<Void> Function(Pointer<Void> hMem);
typedef _LocalFreeDart = Pointer<Void> Function(Pointer<Void> hMem);

typedef _GetLastErrorNative = Uint32 Function();
typedef _GetLastErrorDart = int Function();

/// Windows Data Protection API (DPAPI) bridge.
///
/// Encrypts and decrypts secrets using user-scope Win32 DPAPI (`CryptProtectData`
/// and `CryptUnprotectData`), ensuring only the current Windows OS user account
/// can decrypt the stored data.
class WindowsDpapi {
  static const int _cryptprotectUiForbidden = 0x01;

  static DynamicLibrary? _crypt32;
  static DynamicLibrary? _kernel32;
  static _CryptProtectDataDart? _cryptProtectData;
  static _CryptUnprotectDataDart? _cryptUnprotectData;
  static _LocalFreeDart? _localFree;
  static _GetLastErrorDart? _getLastError;

  static void _ensureInitialized() {
    if (!Platform.isWindows) {
      throw UnsupportedError('DPAPI is only supported on Windows platforms.');
    }
    if (_crypt32 != null) return;

    _crypt32 = DynamicLibrary.open('Crypt32.dll');
    _kernel32 = DynamicLibrary.open('kernel32.dll');

    _cryptProtectData = _crypt32!.lookupFunction<
        _CryptProtectDataNative, _CryptProtectDataDart>('CryptProtectData');

    _cryptUnprotectData = _crypt32!.lookupFunction<
        _CryptUnprotectDataNative, _CryptUnprotectDataDart>('CryptUnprotectData');

    _localFree = _kernel32!.lookupFunction<
        _LocalFreeNative, _LocalFreeDart>('LocalFree');

    _getLastError = _kernel32!.lookupFunction<
        _GetLastErrorNative, _GetLastErrorDart>('GetLastError');
  }

  /// Protects (encrypts) [data] using user-scope DPAPI.
  static Uint8List protect(Uint8List data, {String? description}) {
    _ensureInitialized();
    if (data.isEmpty) {
      return Uint8List(0);
    }

    return using((arena) {
      final pDataIn = arena<DataBlob>();
      final pBuffer = arena<Uint8>(data.length);
      final pDataOut = arena<DataBlob>();

      final nativeBytes = pBuffer.asTypedList(data.length);
      nativeBytes.setAll(0, data);

      pDataIn.ref.cbData = data.length;
      pDataIn.ref.pbData = pBuffer;

      final pDescription = description != null
          ? description.toNativeUtf16(allocator: arena)
          : nullptr;

      final success = _cryptProtectData!(
        pDataIn,
        pDescription,
        nullptr,
        nullptr,
        nullptr,
        _cryptprotectUiForbidden,
        pDataOut,
      );

      // Zero out input copy in arena before returning
      nativeBytes.fillRange(0, nativeBytes.length, 0);

      if (success == 0) {
        final err = _getLastError!();
        throw DpapiException('CryptProtectData failed', err);
      }

      try {
        final outBytes = pDataOut.ref.pbData.asTypedList(pDataOut.ref.cbData);
        return Uint8List.fromList(outBytes);
      } finally {
        if (pDataOut.ref.pbData != nullptr) {
          _localFree!(pDataOut.ref.pbData.cast());
        }
      }
    });
  }

  /// Unprotects (decrypts) [encryptedData] using user-scope DPAPI.
  static Uint8List unprotect(Uint8List encryptedData) {
    _ensureInitialized();
    if (encryptedData.isEmpty) {
      return Uint8List(0);
    }

    return using((arena) {
      final pDataIn = arena<DataBlob>();
      final pBuffer = arena<Uint8>(encryptedData.length);
      final pDataOut = arena<DataBlob>();

      final nativeBytes = pBuffer.asTypedList(encryptedData.length);
      nativeBytes.setAll(0, encryptedData);

      pDataIn.ref.cbData = encryptedData.length;
      pDataIn.ref.pbData = pBuffer;

      final success = _cryptUnprotectData!(
        pDataIn,
        nullptr,
        nullptr,
        nullptr,
        nullptr,
        _cryptprotectUiForbidden,
        pDataOut,
      );

      if (success == 0) {
        final err = _getLastError!();
        throw DpapiException('CryptUnprotectData failed', err);
      }

      try {
        final outBytes = pDataOut.ref.pbData.asTypedList(pDataOut.ref.cbData);
        return Uint8List.fromList(outBytes);
      } finally {
        if (pDataOut.ref.pbData != nullptr) {
          // Zero out decrypted bytes in Win32 memory before releasing
          pDataOut.ref.pbData
              .asTypedList(pDataOut.ref.cbData)
              .fillRange(0, pDataOut.ref.cbData, 0);
          _localFree!(pDataOut.ref.pbData.cast());
        }
      }
    });
  }

  /// Protects a UTF-8 plaintext string and returns base64-encoded ciphertext.
  static String protectString(String plaintext, {String? description}) {
    final rawBytes = Uint8List.fromList(utf8.encode(plaintext));
    try {
      final encryptedBytes = protect(rawBytes, description: description);
      return base64.encode(encryptedBytes);
    } finally {
      zeroOut(rawBytes);
    }
  }

  /// Decrypts a base64-encoded ciphertext and returns the UTF-8 plaintext string.
  static String unprotectString(String base64Ciphertext) {
    final encryptedBytes = base64.decode(base64Ciphertext);
    final decryptedBytes = unprotect(Uint8List.fromList(encryptedBytes));
    try {
      return utf8.decode(decryptedBytes);
    } finally {
      zeroOut(decryptedBytes);
    }
  }

  /// Returns the default path for the DPAPI-encrypted SQLCipher master key file.
  /// Follows Spec §16.1: %LOCALAPPDATA%\HungryHowies\db.key
  static String getDefaultKeyPath() {
    if (Platform.isWindows) {
      final localAppData = Platform.environment['LOCALAPPDATA'];
      if (localAppData != null && localAppData.isNotEmpty) {
        return p.join(localAppData, 'HungryHowies', 'db.key');
      }
    }
    return p.join(Directory.systemTemp.path, 'HungryHowies', 'db.key');
  }

  /// Retrieves the existing 256-bit (32-byte) key or generates a new one on first run.
  ///
  /// The key is stored DPAPI-wrapped at [customKeyPath] (or [getDefaultKeyPath]).
  /// Caller is responsible for zeroing out the returned key bytes with [zeroOut]
  /// once passed to SQLCipher.
  static Uint8List getOrCreateMasterKey({String? customKeyPath}) {
    final keyPath = customKeyPath ?? getDefaultKeyPath();
    final keyFile = File(keyPath);

    if (keyFile.existsSync()) {
      final encryptedBytes = keyFile.readAsBytesSync();
      if (encryptedBytes.isEmpty) {
        throw const DpapiException('Master key file is empty');
      }
      return unprotect(encryptedBytes);
    }

    // Generate cryptographically secure 256-bit (32-byte) random key
    final random = Random.secure();
    final rawKey = Uint8List(32);
    for (int i = 0; i < 32; i++) {
      rawKey[i] = random.nextInt(256);
    }

    try {
      final encryptedBytes = protect(
        rawKey,
        description: 'HungryHowies SQLite Master Key',
      );

      final parentDir = keyFile.parent;
      if (!parentDir.existsSync()) {
        parentDir.createSync(recursive: true);
      }

      keyFile.writeAsBytesSync(encryptedBytes, flush: true);
      return Uint8List.fromList(rawKey);
    } finally {
      zeroOut(rawKey);
    }
  }

  /// Returns the 64-character lowercase hexadecimal representation of the master key
  /// suitable for SQLCipher raw hex key PRAGMA:
  /// `PRAGMA key = "x'<64-char-hex>'";`
  static String getOrCreateSqlCipherKeyHex({String? customKeyPath}) {
    final masterKey = getOrCreateMasterKey(customKeyPath: customKeyPath);
    try {
      return bytesToHex(masterKey);
    } finally {
      zeroOut(masterKey);
    }
  }

  /// Converts a byte array to a lowercase hexadecimal string.
  static String bytesToHex(Uint8List bytes) {
    final buffer = StringBuffer();
    for (final b in bytes) {
      buffer.write(b.toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  /// Converts a hexadecimal string back to bytes.
  static Uint8List hexToBytes(String hex) {
    final clean = hex.trim();
    if (clean.length % 2 != 0) {
      throw ArgumentError('Hex string must have an even length');
    }
    final bytes = Uint8List(clean.length ~/ 2);
    for (int i = 0; i < clean.length; i += 2) {
      bytes[i ~/ 2] = int.parse(clean.substring(i, i + 2), radix: 16);
    }
    return bytes;
  }

  /// Overwrites [bytes] in memory with zeros to prevent sensitive data lingering in RAM.
  static void zeroOut(List<int> bytes) {
    bytes.fillRange(0, bytes.length, 0);
  }
}
