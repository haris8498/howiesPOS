# Riverpod Lifecycle Safety Grep Guide

## Objective
Prevent `Unhandled Exception: Tried to modify a provider while the widget tree was building` errors.
This occurs whenever a StateNotifier, Notifier, or Provider state is mutated synchronously inside:
- `initState`
- `didUpdateWidget`
- `didChangeDependencies`
- `build`
- `dispose`

## Safe Pattern
All provider mutations or side-effects triggered in lifecycle hooks must be deferred using `WidgetsBinding.instance.addPostFrameCallback`:
```dart
@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) {
      ref.read(myProvider.notifier).loadData();
    }
  });
}
```

## Repeatable Inspection Commands

### 1. PowerShell Sweep for `ref.read` in Lifecycle Methods
```powershell
Get-ChildItem -Path frontend\lib -Recurse -Filter *.dart | ForEach-Object {
    $content = Get-Content $_.FullName -Raw
    if ($content -match 'void\s+(initState|didUpdateWidget|didChangeDependencies|dispose)\s*\(') {
        $matches = [regex]::Matches($content, 'void\s+(initState|didUpdateWidget|didChangeDependencies|dispose)\s*\([^)]*\)\s*\{[^}]*\}')
        foreach ($m in $matches) {
            if ($m.Value -match 'ref\.read\(' -and $m.Value -notmatch 'addPostFrameCallback') {
                Write-Output "VIOLATION in $($_.FullName):"
                Write-Output $m.Value
            }
        }
    }
}
```

### 2. Standalone Dart Scanner Script
Run:
```bash
dart run scripts/find_lifecycle.dart
```

### 3. Build-Time Mutation Check
Check that no `ref.read(...notifier).mutation()` is executed in the root of any `build()` function:
```bash
dart run scripts/find_build_mutations.dart
```

## Verification Status
- Swept 100% of files in `frontend/lib/`.
- `_PortalShellWrapperState` in `frontend/lib/config/router.dart` uses post-frame callbacks guarded by `if (mounted)` in both `initState` and `didUpdateWidget`.
- `RoleRightsNotifier.loadPermissions()` in `frontend/lib/data/role_rights_repository.dart` guards against concurrent/re-entrant triggers using `if (!mounted || state.isLoading) return;`.
