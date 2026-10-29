; =====================================================================
; Hungry Howie's POS - Professional Windows x64 Inno Setup Installer Script
; =====================================================================

#define MyAppName "Hungry Howie's POS"
#ifndef MyAppVersion
  #define MyAppVersion "1.0.0"
#endif
#define MyAppPublisher "Hungry Howie's Pizza & Subs"
#define MyAppURL "https://github.com/haris8498/howiesPOS"
#define MyAppExeName "hungry_howies_pos.exe"
; NEVER change this AppId after go-live
#define AppId "{{B37B2E79-9B9D-4F15-B62C-09B92451C6A1}}"

[Setup]
AppId={#AppId}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
OutputDir=..\..\build\installer
OutputBaseFilename=Hungry-Howies-POS-Windows-x64-Setup
SetupIconFile=..\runner\resources\app_icon.ico
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=admin
CloseApplications=yes
RestartApplications=no
UninstallDisplayIcon={app}\{#MyAppExeName}
UninstallDisplayName={#MyAppName}
VersionInfoVersion={#MyAppVersion}
VersionInfoCompany={#MyAppPublisher}
VersionInfoDescription=Hungry Howie's Point of Sale Setup
VersionInfoProductName={#MyAppName}
VersionInfoCopyright=Copyright (C) 2026 Hungry Howie's. All rights reserved.

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
; Clean up runtime logs and temporary caches while preserving user database in AppData
Type: filesandordirs; Name: "{app}\data"
