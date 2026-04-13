; Texas Hold'em Gym — Windows installer (Inno Setup 6).
; Prerequisites: run build-release.ps1 first so dist\windows contains Poker.exe + deployed Qt + DLLs.
; Build: .\build-installer.ps1 from this directory, or ISCC with /D defines (see build-installer.ps1).

#define MyAppName "Texas Hold'em Gym"
#define MyAppPublisher "Texas Hold'em Gym"
#define MyAppURL "https://www.texasholdemgym.com"
#define MyAppExeName "Poker.exe"

#ifndef MyAppVersion
#define MyAppVersion "0.1.0"
#endif

#ifndef MyGitHash
#define MyGitHash "local"
#endif

#ifndef StagingAbs
#define StagingAbs "."
#endif

[Setup]
AppId={{E7B3D2A1-4C5F-6E8D-9A0B-1C2D3E4F5A6B}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
AllowNoIcons=yes
OutputDir=..\..\..\dist
OutputBaseFilename=TexasHoldemGym-Setup-{#MyAppVersion}-{#MyGitHash}
UninstallDisplayIcon={app}\{#MyAppExeName}
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=admin
MinVersion=10.0
CloseApplications=yes
RestartApplications=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#StagingAbs}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[InstallDelete]
; Avoid stale Qt plugin trees if the layout changed between releases
Type: filesandordirs; Name: "{app}\qml"
Type: filesandordirs; Name: "{app}\plugins"
