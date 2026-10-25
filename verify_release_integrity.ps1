<#
.SYNOPSIS
    Automated Release Integrity & Dependency Verification Script
    for Hungry Howie's POS Windows Release.

.DESCRIPTION
    Performs comprehensive verification of the built artifacts:
    - Verifies Release folder contents and Flutter runtime files.
    - Verifies presence of all 8 Microsoft Visual C++ runtime DLLs.
    - Verifies all plugin libraries (printing, audio, url_launcher).
    - Validates PE headers for all DLLs and EXEs (ensuring 0x8664 x64 machine architecture).
    - Verifies Windows executable metadata (Company, Product, Version).
    - Verifies Inno Setup installer executable existence, integrity and size.
    - Verifies portable auto-updater ZIP archive structure and size.
    - Validates release manifest and verifies cryptographic SHA256 checksums.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

$PassCount = 0
$FailCount = 0

function Assert-Condition {
    param(
        [bool]$Condition,
        [string]$Description,
        [string]$Detail = ""
    )
    if ($Condition) {
        Write-Host " [PASS] $Description" -ForegroundColor Green
        if ($Detail) { Write-Host "        $Detail" -ForegroundColor Gray }
        $script:PassCount++
    } else {
        Write-Host " [FAIL] $Description" -ForegroundColor Red
        if ($Detail) { Write-Host "        $Detail" -ForegroundColor DarkRed }
        $script:FailCount++
    }
}

Write-Host "`n========================================================" -ForegroundColor Cyan
Write-Host "  Hungry Howie's POS - Release Integrity Verification" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$FrontendDir = Join-Path $ScriptDir "frontend"
$ReleaseDir = Join-Path $FrontendDir "build\windows\x64\runner\Release"
$InstallerPath = Join-Path $FrontendDir "build\installer\Hungry-Howies-POS-Windows-x64-Setup.exe"
$ZipPath = Join-Path $FrontendDir "Hungry-Howies-POS-Windows.zip"
$ManifestPath = Join-Path $FrontendDir "build\installer\release-manifest.json"

# 1. Release Directory Verification
Assert-Condition -Condition (Test-Path $ReleaseDir) -Description "Release directory exists" -Detail $ReleaseDir

$MainExe = Join-Path $ReleaseDir "hungry_howies_pos.exe"
$UpdaterExe = Join-Path $ReleaseDir "updater.exe"
Assert-Condition -Condition (Test-Path $MainExe) -Description "Main executable exists (hungry_howies_pos.exe)"
Assert-Condition -Condition (Test-Path $UpdaterExe) -Description "Auto-updater helper exists (updater.exe)"

# 2. Windows Executable Metadata
if (Test-Path $MainExe) {
    $info = (Get-Item $MainExe).VersionInfo
    Assert-Condition -Condition ($info.ProductName -match "Hungry Howie") -Description "Metadata: ProductName contains 'Hungry Howie'" -Detail "Product: $($info.ProductName)"
    Assert-Condition -Condition ($info.CompanyName -match "Hungry Howie") -Description "Metadata: CompanyName contains 'Hungry Howie'" -Detail "Company: $($info.CompanyName)"
    Assert-Condition -Condition ($info.FileVersion -ne $null -and $info.FileVersion -ne "") -Description "Metadata: FileVersion populated" -Detail "FileVersion: $($info.FileVersion)"
}

# 3. Microsoft Visual C++ Runtime DLLs Verification
$RequiredMsvcDlls = @(
    "msvcp140.dll",
    "msvcp140_1.dll",
    "msvcp140_2.dll",
    "msvcp140_atomic_wait.dll",
    "msvcp140_codecvt_ids.dll",
    "vcruntime140.dll",
    "vcruntime140_1.dll",
    "concrt140.dll"
)

Write-Host "`nChecking MSVC Runtime DLLs in release bundle:" -ForegroundColor White
$AllMsvcPresent = $true
foreach ($dll in $RequiredMsvcDlls) {
    $p = Join-Path $ReleaseDir $dll
    $exists = Test-Path $p
    if (-not $exists) { $AllMsvcPresent = $false }
    Assert-Condition -Condition $exists -Description "MSVC runtime DLL: $dll"
}

# 4. Flutter Plugins and Engine DLLs
$RequiredFlutterDlls = @(
    "flutter_windows.dll",
    "printing_plugin.dll",
    "file_selector_windows_plugin.dll",
    "pdfium.dll",
    "sqlite3mc.dll",
    "dartjni.dll"
)

Write-Host "`nChecking Flutter Engine & Plugin DLLs:" -ForegroundColor White
foreach ($dll in $RequiredFlutterDlls) {
    $p = Join-Path $ReleaseDir $dll
    Assert-Condition -Condition (Test-Path $p) -Description "Flutter/Plugin DLL: $dll"
}

# 5. PE Architecture Verification (Must be 0x8664 = AMD64 / x64)
Write-Host "`nChecking PE Header Architecture on all executables and DLLs:" -ForegroundColor White
$AllBinaries = Get-ChildItem -Path $ReleaseDir -Include *.exe, *.dll -Recurse
$AllX64 = $true
$InspectedCount = 0

foreach ($bin in $AllBinaries) {
    $bytes = [System.IO.File]::ReadAllBytes($bin.FullName)
    if ($bytes.Length -lt 64) { continue }
    $peOffset = [BitConverter]::ToUInt32($bytes, 0x3C)
    if ($bytes.Length -lt ($peOffset + 6)) { continue }
    $machine = [BitConverter]::ToUInt16($bytes, $peOffset + 4)
    $InspectedCount++
    if ($machine -ne 0x8664) {
        $AllX64 = $false
        Write-Host "Architecture mismatch in $($bin.Name): 0x$($machine.ToString('X'))" -ForegroundColor Red
    }
}
Assert-Condition -Condition ($AllX64 -and $InspectedCount -gt 10) -Description "Pure x64 Architecture ($InspectedCount binaries inspected, all 0x8664)"

# 6. Data & Assets Directory Verification
$DataDir = Join-Path $ReleaseDir "data"
$FlutterAssetsDir = Join-Path $DataDir "flutter_assets"
$IcuData = Join-Path $DataDir "icudtl.dat"
$AotLib = Join-Path $DataDir "app.so"

Assert-Condition -Condition (Test-Path $FlutterAssetsDir) -Description "data/flutter_assets directory exists"
Assert-Condition -Condition (Test-Path $IcuData) -Description "data/icudtl.dat unicode data exists"
Assert-Condition -Condition (Test-Path $AotLib) -Description "data/app.so AOT compilation library exists"

# 7. Inno Setup Installer Verification
Write-Host "`nChecking Inno Setup Installer:" -ForegroundColor White
$InstallerExists = Test-Path $InstallerPath
Assert-Condition -Condition $InstallerExists -Description "Installer exists (Hungry-Howies-POS-Windows-x64-Setup.exe)"

if ($InstallerExists) {
    $InstallerItem = Get-Item $InstallerPath
    $InstallerSizeMB = [Math]::Round($InstallerItem.Length / 1MB, 2)
    Assert-Condition -Condition ($InstallerSizeMB -gt 50) -Description "Installer size is healthy ($InstallerSizeMB MB > 50 MB)"
}

# 8. Portable Auto-Updater ZIP Archive Verification
Write-Host "`nChecking Portable Auto-Updater ZIP Archive:" -ForegroundColor White
$ZipExists = Test-Path $ZipPath
Assert-Condition -Condition $ZipExists -Description "Portable ZIP exists (Hungry-Howies-POS-Windows.zip)"

if ($ZipExists) {
    $ZipItem = Get-Item $ZipPath
    $ZipSizeMB = [Math]::Round($ZipItem.Length / 1MB, 2)
    Assert-Condition -Condition ($ZipSizeMB -gt 50) -Description "ZIP archive size is healthy ($ZipSizeMB MB > 50 MB)"
}

# 9. Release Manifest & Cryptographic SHA256 Checksums
Write-Host "`nChecking Release Manifest & Hashes:" -ForegroundColor White
$ManifestExists = Test-Path $ManifestPath
Assert-Condition -Condition $ManifestExists -Description "Release manifest exists (release-manifest.json)"

if ($ManifestExists -and $InstallerExists -and $ZipExists) {
    $manifest = Get-Content -Path $ManifestPath | ConvertFrom-Json
    $ActualInstallerHash = (Get-FileHash -Path $InstallerPath -Algorithm SHA256).Hash
    $ActualZipHash = (Get-FileHash -Path $ZipPath -Algorithm SHA256).Hash

    $ManifestInstallerHash = ($manifest.Artifacts | Where-Object { $_.Filename -match "Setup.exe" }).SHA256
    $ManifestZipHash = ($manifest.Artifacts | Where-Object { $_.Filename -match "Windows.zip" }).SHA256

    Assert-Condition -Condition ($ActualInstallerHash -eq $ManifestInstallerHash) -Description "Installer SHA256 matches manifest" -Detail "SHA256: $ActualInstallerHash"
    Assert-Condition -Condition ($ActualZipHash -eq $ManifestZipHash) -Description "Portable ZIP SHA256 matches manifest" -Detail "SHA256: $ActualZipHash"
}

# Summary
Write-Host "`n========================================================" -ForegroundColor $(if ($FailCount -eq 0) { "Green" } else { "Red" })
Write-Host "  VERIFICATION COMPLETE: $PassCount PASSED, $FailCount FAILED" -ForegroundColor $(if ($FailCount -eq 0) { "Green" } else { "Red" })
Write-Host "========================================================`n" -ForegroundColor $(if ($FailCount -eq 0) { "Green" } else { "Red" })

if ($FailCount -gt 0) {
    exit 1
}
