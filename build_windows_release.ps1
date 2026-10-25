<#
.SYNOPSIS
    Professional Production Windows x64 Build, Signing & Packaging Script
    for Hungry Howie's POS.

.DESCRIPTION
    Automates the end-to-end Windows release pipeline:
    1. Validates build tools (Flutter, Inno Setup, SignTool).
    2. Synchronizes version from frontend/pubspec.yaml.
    3. Builds Flutter Windows Release (x64).
    4. Validates all PE architectures (AMD64 0x8664) and MSVC runtime DLLs.
    5. Digitally signs executables (if certificate is provided).
    6. Compiles professional Inno Setup installer.
    7. Digitally signs the installer (if certificate is provided).
    8. Packages backwards-compatible auto-updater ZIP artifact.
    9. Generates SHA256 checksums and release manifest.

.PARAMETER CertificatePath
    Path to .pfx certificate, or base64 string from WINDOWS_SIGNING_CERTIFICATE.
.PARAMETER CertificatePassword
    Password for .pfx certificate, or from WINDOWS_SIGNING_CERTIFICATE_PASSWORD.
.PARAMETER TimestampServer
    RFC 3161 timestamping server URL. Default: http://timestamp.digicert.com
.PARAMETER SkipClean
    Skip 'flutter clean' step for faster incremental builds.
#>

[CmdletBinding()]
param(
    [string]$CertificatePath = $env:WINDOWS_SIGNING_CERTIFICATE,
    [string]$CertificatePassword = $env:WINDOWS_SIGNING_CERTIFICATE_PASSWORD,
    [string]$TimestampServer = $(if ($env:WINDOWS_SIGNING_TIMESTAMP_URL) { $env:WINDOWS_SIGNING_TIMESTAMP_URL } else { "http://timestamp.digicert.com" }),
    [switch]$SkipClean
)

$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)
    Write-Host "`n========================================================" -ForegroundColor Cyan
    Write-Host "  $Message" -ForegroundColor Cyan
    Write-Host "========================================================" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

function Write-Warn {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
}

function Write-Fatal {
    param([string]$Message)
    Write-Host "`n[FATAL ERROR] $Message" -ForegroundColor Red
    exit 1
}

# ---------------------------------------------------------------------
# 1. Directory Structure Resolution
# ---------------------------------------------------------------------
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$ProjectRoot = $ScriptDir
$FrontendDir = Join-Path $ProjectRoot "frontend"

if (-not (Test-Path $FrontendDir)) {
    Write-Fatal "Could not find frontend directory at: $FrontendDir"
}

Set-Location $FrontendDir

# ---------------------------------------------------------------------
# 2. Extract Version from pubspec.yaml
# ---------------------------------------------------------------------
Write-Step "Resolving Application Version"
$PubspecPath = Join-Path $FrontendDir "pubspec.yaml"
if (-not (Test-Path $PubspecPath)) {
    Write-Fatal "pubspec.yaml not found at: $PubspecPath"
}

$PubspecContent = Get-Content $PubspecPath -Raw
if ($PubspecContent -match 'version:\s*([0-9]+\.[0-9]+\.[0-9]+)') {
    $AppVersion = $matches[1]
} else {
    $AppVersion = "1.0.0"
}
Write-Host "Application Version resolved from pubspec.yaml: $AppVersion" -ForegroundColor Green

# ---------------------------------------------------------------------
# 3. Locate Build Tools (Flutter, Inno Setup, SignTool)
# ---------------------------------------------------------------------
Write-Step "Validating Build Tools"

# Flutter
$FlutterCmd = Get-Command "flutter" -ErrorAction SilentlyContinue
if (-not $FlutterCmd) {
    Write-Fatal "Flutter CLI not found in PATH. Please ensure Flutter is installed and added to PATH."
}
Write-Host "Found Flutter: $($FlutterCmd.Source)" -ForegroundColor Gray

# Inno Setup ISCC.exe
$InnoCandidates = @(
    "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe",
    "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
    "$env:ProgramFiles\Inno Setup 6\ISCC.exe",
    "C:\Program Files (x86)\Inno Setup 6\ISCC.exe",
    "C:\Program Files\Inno Setup 6\ISCC.exe"
)
$IsccPath = $null
foreach ($candidate in $InnoCandidates) {
    if ($candidate -and (Test-Path $candidate)) {
        $IsccPath = $candidate
        break
    }
}
if (-not $IsccPath) {
    $IsccCmd = Get-Command "iscc" -ErrorAction SilentlyContinue
    if ($IsccCmd) {
        $IsccPath = $IsccCmd.Source
    }
}
if (-not $IsccPath) {
    Write-Fatal "Inno Setup Compiler (ISCC.exe) not found. Install it via 'winget install JRSoftware.InnoSetup' or add it to PATH."
}
Write-Host "Found Inno Setup Compiler: $IsccPath" -ForegroundColor Gray

# SignTool.exe
$SignToolCandidates = @(
    "C:\Program Files (x86)\Windows Kits\10\bin\10.0.26100.0\x64\signtool.exe",
    "C:\Program Files (x86)\Windows Kits\10\bin\10.0.22621.0\x64\signtool.exe",
    "C:\Program Files (x86)\Windows Kits\10\bin\10.0.22000.0\x64\signtool.exe",
    "C:\Program Files (x86)\Windows Kits\10\bin\10.0.19041.0\x64\signtool.exe"
)
$SignToolPath = $null
foreach ($cand in $SignToolCandidates) {
    if (Test-Path $cand) {
        $SignToolPath = $cand
        break
    }
}
if (-not $SignToolPath) {
    $SignToolCmd = Get-Command "signtool" -ErrorAction SilentlyContinue
    if ($SignToolCmd) {
        $SignToolPath = $SignToolCmd.Source
    }
}
if ($SignToolPath) {
    Write-Host "Found SignTool: $SignToolPath" -ForegroundColor Gray
} else {
    Write-Warn "SignTool.exe not found. Code signing verification will fallback to PowerShell Set-AuthenticodeSignature if needed."
}

# ---------------------------------------------------------------------
# 4. Clean & Build Flutter Windows x64 Release
# ---------------------------------------------------------------------
Write-Step "Building Flutter Windows Release (x64)"

# Ensure no running instance locks the release executable
Get-Process -Name "hungry_howies_pos" -ErrorAction SilentlyContinue | ForEach-Object {
    Write-Host "Closing currently running hungry_howies_pos process (PID: $($_.Id)) before build..." -ForegroundColor Yellow
    Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
}

if (-not $SkipClean) {
    Write-Host "Running 'flutter clean'..." -ForegroundColor Gray
    & flutter clean
    if ($LASTEXITCODE -ne 0) { Write-Fatal "flutter clean failed with code $LASTEXITCODE" }
}

Write-Host "Running 'flutter pub get'..." -ForegroundColor Gray
& flutter pub get
if ($LASTEXITCODE -ne 0) { Write-Fatal "flutter pub get failed with code $LASTEXITCODE" }

Write-Host "Compiling Windows x64 binary via 'flutter build windows --release'..." -ForegroundColor Gray
& flutter build windows --release
if ($LASTEXITCODE -ne 0) { Write-Fatal "flutter build windows --release failed with exit code $LASTEXITCODE" }

$ReleaseDir = Join-Path $FrontendDir "build\windows\x64\runner\Release"
$MainExe = Join-Path $ReleaseDir "hungry_howies_pos.exe"
$UpdaterExe = Join-Path $ReleaseDir "updater.exe"

if (-not (Test-Path $MainExe)) {
    Write-Fatal "Expected binary not found: $MainExe"
}

# Ensure native Win32 RawSpooler printer helper is packaged
$RawSpoolerSrc = Join-Path $FrontendDir "windows\RawSpooler.exe"
if (Test-Path $RawSpoolerSrc) {
    Copy-Item -Path $RawSpoolerSrc -Destination (Join-Path $ReleaseDir "RawSpooler.exe") -Force
    Write-Host "Bundled native RawSpooler.exe into release output." -ForegroundColor Green
}

# ---------------------------------------------------------------------
# 5. Runtime Dependencies & PE Architecture Validation (Fail Fast)
# ---------------------------------------------------------------------
Write-Step "Validating Runtime Dependencies & Machine Architecture (x64)"

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

foreach ($dll in $RequiredMsvcDlls) {
    $dllPath = Join-Path $ReleaseDir $dll
    if (-not (Test-Path $dllPath)) {
        Write-Fatal "Required Microsoft Visual C++ Runtime DLL is missing from release: $dll"
    }
}
Write-Success "All 8 required MSVC runtime DLLs are present in release bundle."

# Verify PE Header Architecture (Must be 0x8664 = AMD64 / x64)
$BinariesToVerify = Get-ChildItem -Path $ReleaseDir -Include *.exe, *.dll -Recurse
foreach ($bin in $BinariesToVerify) {
    $bytes = [System.IO.File]::ReadAllBytes($bin.FullName)
    if ($bytes.Length -lt 64) { continue }
    $peOffset = [BitConverter]::ToUInt32($bytes, 0x3C)
    if ($bytes.Length -lt ($peOffset + 6)) { continue }
    $machine = [BitConverter]::ToUInt16($bytes, $peOffset + 4)
    
    if ($machine -ne 0x8664) {
        $hex = "0x" + $machine.ToString("X")
        Write-Fatal "Binary architecture mismatch in $($bin.Name)! Machine code is $hex (Expected 0x8664 AMD64/x64). Architecture mixing is prohibited."
    }
}
Write-Success "All executable and dynamic library binaries verified as pure x64 (AMD64 0x8664)."

# ---------------------------------------------------------------------
# 6. Digital Code Signing (Inner Binaries)
# ---------------------------------------------------------------------
Write-Step "Code Signing Executables"

$TempCertFile = $null
$CertToUse = $null

if ($CertificatePath) {
    # Check if certificate is base64 encoded or path
    if (Test-Path $CertificatePath) {
        $CertToUse = (Resolve-Path $CertificatePath).Path
    } else {
        try {
            $decodedBytes = [Convert]::FromBase64String($CertificatePath)
            $TempCertFile = [System.IO.Path]::GetTempFileName() + ".pfx"
            [System.IO.File]::WriteAllBytes($TempCertFile, $decodedBytes)
            $CertToUse = $TempCertFile
            Write-Host "Decoded base64 signing certificate to secure temporary location." -ForegroundColor Gray
        } catch {
            Write-Fatal "CertificatePath was provided but is neither an existing file nor a valid Base64 string: $_"
        }
    }
}

$IsSigned = $false

if ($CertToUse -and $CertificatePassword) {
    if (-not $SignToolPath) {
        Write-Fatal "Signing certificate was provided, but signtool.exe was not found. Install Windows SDK to sign binaries."
    }

    $FilesToSign = @($MainExe)
    if (Test-Path $UpdaterExe) { $FilesToSign += $UpdaterExe }

    foreach ($file in $FilesToSign) {
        Write-Host "Digitally signing $(Split-Path -Leaf $file) with RFC 3161 timestamp..." -ForegroundColor Gray
        & $SignToolPath sign /fd SHA256 /tr $TimestampServer /td SHA256 /f $CertToUse /p $CertificatePassword $file
        if ($LASTEXITCODE -ne 0) {
            Write-Fatal "SignTool signing failed for $(Split-Path -Leaf $file) with exit code $LASTEXITCODE."
        }

        # Verify signature
        & $SignToolPath verify /pa /v $file
        if ($LASTEXITCODE -ne 0) {
            Write-Fatal "SignTool signature verification failed for $(Split-Path -Leaf $file)."
        }
    }
    $IsSigned = $true
    Write-Success "Inner binaries digitally signed and verified successfully."
} else {
    Write-Warn "No signing certificate/password supplied (WINDOWS_SIGNING_CERTIFICATE unset)."
    Write-Warn "The release will be generated as an UNSIGNED build."
    Write-Warn "NOTE: Windows Smart App Control and SmartScreen block unsigned executables on clean Windows 11 systems."
    Write-Warn "To enable trusted code signing, supply a valid certificate via environment variables or parameter."
}

# ---------------------------------------------------------------------
# 7. Compile Professional Windows Installer (Inno Setup)
# ---------------------------------------------------------------------
Write-Step "Compiling Professional Windows Installer"

$IssScript = Join-Path $FrontendDir "windows\installer\inno_setup.iss"
if (-not (Test-Path $IssScript)) {
    Write-Fatal "Inno Setup script not found at: $IssScript"
}

$InstallerOutputDir = Join-Path $FrontendDir "build\installer"
if (-not (Test-Path $InstallerOutputDir)) {
    New-Item -ItemType Directory -Path $InstallerOutputDir -Force | Out-Null
}

$ExpectedInstallerPath = Join-Path $InstallerOutputDir "Hungry-Howies-POS-Windows-x64-Setup.exe"

Write-Host "Executing Inno Setup compiler: $IsccPath..." -ForegroundColor Gray
& $IsccPath "/DMyAppVersion=$AppVersion" $IssScript
if ($LASTEXITCODE -ne 0) {
    Write-Fatal "Inno Setup compilation failed with exit code $LASTEXITCODE."
}

if (-not (Test-Path $ExpectedInstallerPath)) {
    Write-Fatal "Expected installer was not generated at: $ExpectedInstallerPath"
}
Write-Success "Windows installer successfully generated: $ExpectedInstallerPath"

# ---------------------------------------------------------------------
# 8. Digital Code Signing (Installer)
# ---------------------------------------------------------------------
if ($IsSigned -and $CertToUse -and $CertificatePassword) {
    Write-Step "Code Signing the Windows Installer"
    Write-Host "Digitally signing installer: $(Split-Path -Leaf $ExpectedInstallerPath)..." -ForegroundColor Gray
    & $SignToolPath sign /fd SHA256 /tr $TimestampServer /td SHA256 /f $CertToUse /p $CertificatePassword $ExpectedInstallerPath
    if ($LASTEXITCODE -ne 0) {
        Write-Fatal "SignTool signing failed for installer with exit code $LASTEXITCODE."
    }

    & $SignToolPath verify /pa /v $ExpectedInstallerPath
    if ($LASTEXITCODE -ne 0) {
        Write-Fatal "SignTool verification failed for installer."
    }
    Write-Success "Installer digitally signed and verified successfully."
}

# ---------------------------------------------------------------------
# 9. Clean up temporary certificate
# ---------------------------------------------------------------------
if ($TempCertFile -and (Test-Path $TempCertFile)) {
    Remove-Item -Force $TempCertFile -ErrorAction SilentlyContinue
}

# ---------------------------------------------------------------------
# 10. Package Backward-Compatible Auto-Updater Portable ZIP
# ---------------------------------------------------------------------
Write-Step "Packaging Portable Auto-Updater ZIP Archive"

$ZipPath = Join-Path $FrontendDir "Hungry-Howies-POS-Windows.zip"
$VersionedZipPath = Join-Path $InstallerOutputDir "Hungry-Howies-POS-Windows-x64.zip"

Write-Host "Compressing release folder to backwards-compatible ZIP: $ZipPath..." -ForegroundColor Gray
if (Test-Path $ZipPath) { Remove-Item -Force $ZipPath }
Compress-Archive -Path "$ReleaseDir\*" -DestinationPath $ZipPath -Force

Write-Host "Creating versioned portable ZIP archive: $VersionedZipPath..." -ForegroundColor Gray
if (Test-Path $VersionedZipPath) { Remove-Item -Force $VersionedZipPath }
Copy-Item -Path $ZipPath -Destination $VersionedZipPath -Force

Write-Success "Auto-updater portable ZIP archives generated."

# ---------------------------------------------------------------------
# 11. Generate Checksums & Release Manifest
# ---------------------------------------------------------------------
Write-Step "Generating Checksums & Production Release Manifest"

$InstallerHash = (Get-FileHash -Path $ExpectedInstallerPath -Algorithm SHA256).Hash
$ZipHash = (Get-FileHash -Path $ZipPath -Algorithm SHA256).Hash

$InstallerSizeMB = [Math]::Round((Get-Item $ExpectedInstallerPath).Length / 1MB, 2)
$ZipSizeMB = [Math]::Round((Get-Item $ZipPath).Length / 1MB, 2)

$ManifestPath = Join-Path $InstallerOutputDir "release-manifest.json"
$ManifestObj = [PSCustomObject]@{
    Application = "Hungry Howie's POS"
    Version = $AppVersion
    Architecture = "Windows x64 (AMD64)"
    BuildTimestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    CodeSigned = $IsSigned
    Artifacts = @(
        @{
            Filename = "Hungry-Howies-POS-Windows-x64-Setup.exe"
            Type = "Windows Installer (Inno Setup)"
            RecommendedFor = "End users, Clean Windows installations"
            SizeBytes = (Get-Item $ExpectedInstallerPath).Length
            SizeMB = $InstallerSizeMB
            SHA256 = $InstallerHash
        },
        @{
            Filename = "Hungry-Howies-POS-Windows.zip"
            Type = "Portable ZIP Archive"
            RecommendedFor = "In-App GitHub Releases Auto-Updater"
            SizeBytes = (Get-Item $ZipPath).Length
            SizeMB = $ZipSizeMB
            SHA256 = $ZipHash
        }
    )
}

$ManifestObj | ConvertTo-Json -Depth 4 | Out-File -FilePath $ManifestPath -Encoding utf8

Write-Host "`n========================================================" -ForegroundColor Green
Write-Host "  HUNGRY HOWIE'S POS - RELEASE BUILD COMPLETE" -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Green
Write-Host "Version:             $AppVersion" -ForegroundColor White
Write-Host "Architecture:        Windows x64" -ForegroundColor White
Write-Host "Digital Signature:   $(if ($IsSigned) { 'VERIFIED & SIGNED' } else { 'UNSIGNED (Development)' })" -ForegroundColor White
Write-Host "`nArtifact 1 (Recommended Installer):" -ForegroundColor Cyan
Write-Host "  Path:   $ExpectedInstallerPath" -ForegroundColor White
Write-Host "  Size:   $InstallerSizeMB MB" -ForegroundColor White
Write-Host "  SHA256: $InstallerHash" -ForegroundColor White
Write-Host "`nArtifact 2 (Portable Auto-Updater ZIP):" -ForegroundColor Cyan
Write-Host "  Path:   $ZipPath" -ForegroundColor White
Write-Host "  Size:   $ZipSizeMB MB" -ForegroundColor White
Write-Host "  SHA256: $ZipHash" -ForegroundColor White
Write-Host "`nManifest:            $ManifestPath" -ForegroundColor Gray
Write-Host "========================================================`n" -ForegroundColor Green
