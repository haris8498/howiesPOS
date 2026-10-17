# Stage 1: Client Foundation Report

> **Branch:** `offline/main`  
> **Stage:** `client-foundation` (Stage 1)  
> **Date:** October 17, 2026  
> **Architecture Spec:** `docs/offline-analysis/99-FINAL-ARCHITECTURE.md` (§4.1, §4.5, §5.1, §16.1, §17.1)  
> **Baseline Reference:** `docs/offline-implementation/00-baseline.md`

---

## 1. Executive Summary

Stage 1 successfully establishes the local storage foundation, Windows cryptographic security layer, and runtime feature flag gating for the offline-first POS architecture without altering existing production screens or workflows.

1. **Dependency Modernization:** Pinned and integrated `drift: 2.35.2`, `sqlite3: 3.5.2`, `sqlcipher_flutter_libs: 0.7.0+eol`, `sqlite3_flutter_libs: 0.6.0+eol`, `ffi: ^2.2.0`, and `path_provider: ^2.1.5` under Dart 3.12.2 and Flutter 3.44.8, along with `drift_dev: 2.35.1` and `build_runner: 2.15.1`. Configured build hooks to bundle `sqlite3mc` (SQLite3MultipleCiphers) for transparent AES-256 database encryption.
2. **Feature Flag Gating:** Implemented `FeatureFlags.offlineFirstEnabled` defaulting to `false` (per Approved Deviation #3), ensuring zero behavioral change until pilot activation.
3. **Windows DPAPI FFI Bridge:** Implemented user-scope Win32 DPAPI (`CryptProtectData` and `CryptUnprotectData`) via `dart:ffi` calling `Crypt32.dll` and `kernel32.dll`. Provides automatic 256-bit secure key generation on first boot stored at `%LOCALAPPDATA%\HungryHowies\db.key`, DPAPI encryption/decryption, 64-char hex key derivation for SQLCipher, and in-memory zeroing of sensitive buffers.
4. **Encrypted Drift Connection Factory:** Created the connection factory supporting lazy/synchronous `QueryExecutor` with SQLCipher encryption pragmas (§5.1: WAL mode, synchronous NORMAL, busy_timeout 5000ms, foreign_keys ON). Proved on throwaway databases that wrong or missing keys fail with `SqliteException(26): file is not a database`.
5. **Windows Desktop Native Verification:** Ran `flutter build windows`, which compiled and linked cleanly in 159.5 seconds, packaging `sqlite3mc.dll` (2.13 MB) into the release runner folder.
6. **RFC 9562 UUID v7 Verification:** Verified that `uuid: ^4.4.0` generates monotonic, collision-free RFC 9562 UUID v7 identifiers with version nibble 7.

---

## 2. Files Created and Modified

### Created Files
- `frontend/lib/config/feature_flags.dart`: Global compile-time and runtime flag `FeatureFlags.offlineFirstEnabled` (default `false`).
- `frontend/lib/core/security/windows_dpapi.dart`: User-scope Windows DPAPI bridge via `dart:ffi` (`CryptProtectData` / `CryptUnprotectData`), key generation/persistence at `%LOCALAPPDATA%\HungryHowies\db.key`, hex derivation, and memory zeroing (`zeroOut`).
- `frontend/lib/core/database/encrypted_connection.dart`: Encrypted Drift `QueryExecutor` / `LazyDatabase` factory enforcing Spec §5.1 SQLite pragmas.
- `frontend/test/core/windows_dpapi_test.dart`: Unit tests for DPAPI raw byte roundtrip, string roundtrip, empty input handling, master key generation & retrieval, and in-memory zeroing.
- `frontend/test/core/encrypted_connection_test.dart`: Unit tests for Spec §5.1 pragmas, table creation & data retrieval with valid key, rejection of invalid keys (`SqliteException` code 26), rejection of unauthenticated access, and `LazyDatabase` lifecycle.
- `frontend/test/core/uuid_v7_test.dart`: Unit tests verifying RFC 9562 UUID v7 format compliance, monotonic lexicographical ordering, and collision resistance across rapid generation loops.

### Modified Files
- `frontend/pubspec.yaml`: Added `drift`, `sqlite3`, `sqlcipher_flutter_libs`, `sqlite3_flutter_libs`, `ffi`, `path_provider`, `drift_dev`, `build_runner`, and `hooks` (`sqlite3mc`).
- `frontend/pubspec.lock`: Locked pinned dependency tree.

---

## 3. Test Suites & Verification Results

### Test Execution (`flutter test`)
- **Total Tests:** 28 passed, 0 failed (baseline was 15 passed, +13 new tests added).
  - `CompleteOrderUseCase` Coordinated Transaction Tests (2/2 passed)
  - `PasswordHasher` Security Tests (3/3 passed)
  - `PermissionChecker` Authorization Tests (4/4 passed)
  - `PricingEngine` Domain Tests (5/5 passed)
  - `App smoke test` (1/1 passed)
  - `WindowsDpapi Tests` (5/5 passed):
    - Raw byte protect/unprotect roundtrip
    - Base64 string protectString/unprotectString roundtrip
    - Empty input handling
    - Key generation on first run & persistence verification
    - In-memory `zeroOut` zeroing
  - `Encrypted Connection & Pragmas Tests (§5.1)` (5/5 passed):
    - SQLite PRAGMAs verification (WAL, synchronous NORMAL = 1, busy_timeout = 5000, foreign_keys = 1)
    - Successful read/write with valid 256-bit hex key
    - Access rejection with invalid key (`SqliteException(26): file is not a database`)
    - Access rejection with null key on encrypted database
    - `LazyDatabase` connection factory verification
  - `UUID v7 Verification Tests (§4.2)` (3/3 passed):
    - RFC 9562 UUID v7 format matching version 7 nibble and variant bits
    - Strict monotonic lexicographical sorting over time
    - 1,000 rapid iterations zero collision check

### Code Generation (`dart run build_runner build`)
- Executed `dart run build_runner build --delete-conflicting-outputs`.
- Completed in 83s with 283 outputs written and 0 compilation errors.

### Static Analysis (`dart analyze`)
- Analyzed `frontend/`: 0 errors.
- Found 1 pre-existing warning (`test_mapping.dart:5:8` unused import) and 40 pre-existing hints, identical to baseline.
- Zero errors, warnings, or hints introduced by Stage 1 files.

### Windows Desktop Native Compilation (`flutter build windows`)
- Command: `flutter build windows`
- Result: Code 0 (Success in 159.5s).
- Artifact: `frontend/build/windows/x64/runner/Release/hungry_howies_pos.exe`
- Verified `sqlite3mc.dll` (2,136,576 bytes) bundled and linked in release output directory.

---

## 4. Commands Run

```powershell
# Dependencies & Analysis
flutter pub get
dart analyze
dart run build_runner build --delete-conflicting-outputs

# Testing
flutter test test/core/windows_dpapi_test.dart
flutter test test/core/encrypted_connection_test.dart
flutter test test/core/uuid_v7_test.dart
flutter test

# Native Windows Release Verification
flutter build windows
```

---

## 5. Deviations & Blockers

- **Approved Deviation #3 Applied:** `FeatureFlags.offlineFirstEnabled` is set to `defaultValue: false` (spec originally specified `true`). It remains dormant until activated by the developer in the final pilot step.
- **Blockers:** None. All tools, compilers, FFI bridges, and native dependencies resolved cleanly without blockers.

---

## 6. How to Verify Manually

1. **Check Feature Flag Default:**
   Run:
   ```powershell
   dart -e "import 'package:hungry_howies_pos/config/feature_flags.dart'; void main() { print('Offline flag: ${FeatureFlags.offlineFirstEnabled}'); }"
   ```
   Confirm output is `Offline flag: false`.

2. **Verify DPAPI & Database Encryption Unit Tests:**
   ```powershell
   cd frontend
   flutter test test/core/windows_dpapi_test.dart
   flutter test test/core/encrypted_connection_test.dart
   flutter test test/core/uuid_v7_test.dart
   ```
   All 13 foundation unit tests will pass.

3. **Verify Windows Native Linkage:**
   Inspect `frontend/build/windows/x64/runner/Release/sqlite3mc.dll` to confirm the presence of the encrypted SQLite library alongside the application executable.
