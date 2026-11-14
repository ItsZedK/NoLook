; The Windows installer. Built by tools/build_installer.sh from the Windows build folder.
; It installs for the current user only, so NoLook can update itself without asking for admin.
; Run: ISCC /DAppVersion=0.1.0 /DSourceDir=<build folder> /DOutputDir=<where> nolook.iss

#ifndef AppVersion
  #define AppVersion "0.1.0"
#endif
#ifndef SourceDir
  #define SourceDir "..\..\app\build\windows\x64\runner\Release"
#endif
#ifndef OutputDir
  #define OutputDir "..\..\build\installer"
#endif

[Setup]
; Never change the AppId, Windows uses it to know an install is the same app.
AppId={{7E3C9B52-4A1D-4F6B-9C0E-5B2F8A41D6C3}
AppName=NoLook
AppVersion={#AppVersion}
AppVerName=NoLook {#AppVersion}
AppPublisher=ItsZedK
AppPublisherURL=https://nolook.itszedk.com
AppSupportURL=https://github.com/ItsZedK/NoLook/issues
DefaultDirName={localappdata}\Programs\NoLook
DefaultGroupName=NoLook
DisableProgramGroupPage=yes
DisableDirPage=yes
PrivilegesRequired=lowest
OutputDir={#OutputDir}
OutputBaseFilename=NoLook-setup
SetupIconFile=..\..\app\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\nolook.exe
UninstallDisplayName=NoLook
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
CloseApplications=force
RestartApplications=no

[Languages]
Name: "en"; MessagesFile: "compiler:Default.isl"
Name: "hu"; MessagesFile: "compiler:Languages\Hungarian.isl"

[CustomMessages]
en.DesktopIcon=Add a desktop shortcut
hu.DesktopIcon=Parancsikon az asztalra
en.RemoveData=Delete your blocks and settings too?%n%nChoose No to keep them in case you install NoLook again.
hu.RemoveData=A tiltásaidat és a beállításaidat is törlöd?%n%nVálaszd a Nemet, ha megtartanád őket egy újratelepítéshez.

[Tasks]
Name: "desktopicon"; Description: "{cm:DesktopIcon}"; Flags: unchecked

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Excludes: "nolook_host.old*.exe"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
; Straight in Programs, the same shortcut NoLook makes for its notifications.
Name: "{userprograms}\NoLook"; Filename: "{app}\nolook.exe"
Name: "{userdesktop}\NoLook"; Filename: "{app}\nolook.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\nolook.exe"; Description: "{cm:LaunchProgram,NoLook}"; Flags: nowait postinstall skipifsilent

[UninstallRun]
; NoLook keeps running in the tray, and a connected browser keeps the helper running.
Filename: "{sys}\taskkill.exe"; Parameters: "/im nolook.exe /f"; Flags: runhidden; RunOnceId: "StopNoLook"
Filename: "{sys}\taskkill.exe"; Parameters: "/im nolook_host.exe /f"; Flags: runhidden; RunOnceId: "StopHelper"

[Registry]
; NoLook adds these itself when it runs. Listed here so uninstalling removes them.
Root: HKCU; Subkey: "Software\Google\Chrome\NativeMessagingHosts\com.itszedk.nolook"; Flags: uninsdeletekey dontcreatekey
Root: HKCU; Subkey: "Software\Microsoft\Edge\NativeMessagingHosts\com.itszedk.nolook"; Flags: uninsdeletekey dontcreatekey
Root: HKCU; Subkey: "Software\BraveSoftware\Brave-Browser\NativeMessagingHosts\com.itszedk.nolook"; Flags: uninsdeletekey dontcreatekey
Root: HKCU; Subkey: "Software\Chromium\NativeMessagingHosts\com.itszedk.nolook"; Flags: uninsdeletekey dontcreatekey
Root: HKCU; Subkey: "Software\Vivaldi\NativeMessagingHosts\com.itszedk.nolook"; Flags: uninsdeletekey dontcreatekey
Root: HKCU; Subkey: "Software\Mozilla\NativeMessagingHosts\com.itszedk.nolook"; Flags: uninsdeletekey dontcreatekey
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: none; ValueName: "NoLook"; Flags: uninsdeletevalue dontcreatekey

[UninstallDelete]
; Old helpers moved aside by updates.
Type: files; Name: "{app}\nolook_host.old*.exe"

[Code]
procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if (CurUninstallStep = usPostUninstall) and not UninstallSilent then
    if MsgBox(CustomMessage('RemoveData'), mbConfirmation, MB_YESNO or MB_DEFBUTTON2) = IDYES then
      DelTree(ExpandConstant('{userappdata}\NoLook'), True, True, True);
end;
