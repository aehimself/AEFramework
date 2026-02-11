{
  AE Framework © 2022 by Akos Eigler is licensed under CC BY 4.0.
  To view a copy of this license, visit http://creativecommons.org/licenses/by/4.0/

  This license requires that reusers give credit to the creator. It allows reusers to distribute, remix, adapt,
  and build upon the material in any medium or format, even for commercial purposes.
}

Unit AE.IDE.DelphiVersions;

Interface

Uses System.SysUtils,  AE.DDEManager, AE.IDE.Versions, System.Win.Registry, System.Classes;

Type
  TAEDelphiInstance = Class(TAEIDEInstance)
  strict protected
    Procedure InternalFindIDEWindow; Override;
    Procedure InternalOpenFile(Const inFileName: String; Const inTimeOutInMs: Cardinal = 5000); Override;
  End;

  TAEBorlandDelphiVersion = Class(TAEIDEVersion)
  strict private
    _ddeansimode: Boolean;
    _ddediscoverytimeout: Cardinal;
    _ddeservice: String;
    _ddetopic: String;
    Procedure SetDDEDiscoveryTimeout(Const inDDEDiscoveryTimeout: Cardinal);
  strict protected
    Procedure InternalRefreshInstances; Override;
    Function InternalGetEdition: String; Override;
    Function InternalGetName: String; Override;
    Property InternalDDEANSIMode: Boolean Read _ddeansimode Write _ddeansimode;
    Property InternalDDEService: String Read _ddeservice Write _ddeservice;
    Property InternalDDETopic: String Read _ddetopic Write _ddetopic;
  public
    Class Function BDSRoot: String; Virtual;
    Constructor Create(inOwner: TComponent; Const inExecutablePath: String; Const inVersionNumber: Integer; Const inDDEDiscoveryTimeout: Cardinal); ReIntroduce; Virtual;
    Property DDEANSIMode: Boolean Read _ddeansimode;
    Property DDEDiscoveryTimeout: Cardinal Read _ddediscoverytimeout Write SetDDEDiscoveryTimeout;
    Property DDEService: String Read _ddeservice;
    Property DDETopic: String Read _ddetopic;
  End;

  TAEDelphiVersionClass = Class Of TAEBorlandDelphiVersion;

  TAEBorland2DelphiVersion = Class(TAEBorlandDelphiVersion)
  strict protected
    Function InternalGetName: String; Override;
  public
    Class Function BDSRoot: String; Override;
  End;

  TAECodegearDelphiVersion = Class(TAEBorlandDelphiVersion)
  strict protected
    Function InternalGetName: String; Override;
  public
    Class Function BDSRoot: String; Override;
    Constructor Create(inOwner: TComponent; Const inExecutablePath: String; Const inVersionNumber: Integer; Const inDiscoveryTimeout: Cardinal); Override;
  End;

  TAEEmbarcaderoDelphiVersion = Class(TAECodegearDelphiVersion)
  strict protected
    Function InternalGetName: String; Override;
  public
    Class Function BDSRoot: String; Override;
  End;

  TAEDelphiVersions = Class(TAEIDEVersions)
  strict private
    _ddediscoverytimeout: Cardinal;
    Procedure DiscoverVersions(Const inRegistry: TRegistry; Const inDelphiVersionClass: TAEDelphiVersionClass);
    Procedure SetDDEDiscoveryTimeout(Const inDDEDiscoveryTimeout: Cardinal);
  strict protected
    Procedure InternalRefreshInstalledVersions; Override;
  public
    Constructor Create(inOwner: TComponent); Override;
    Property DDEDiscoveryTimeout: Cardinal Read _ddediscoverytimeout Write SetDDEDiscoveryTimeout;
  End;

  EAEDelphiVersionException = Class(Exception);

Implementation

Uses WinApi.Windows, AE.IDE.Versions.Consts, AE.Misc.FileUtils;

Const
 MINDELPHIVERSION = 3;
 MAXDELPHIVERSION = 23;

Function FindDelphiWindow(inHWND: HWND; inParam: LParam): Boolean; StdCall;
Var
  ppid: Cardinal;
  title, classname: Array[0..255] Of Char;
Begin
  // https://docs.microsoft.com/en-us/previous-versions/windows/desktop/legacy/ms633498(v=vs.85)
  // Result := True   ->   Continue evaluation
  // Result := False  ->   Do not continue evaluation

  GetWindowThreadProcessID(inHWND, ppid);
  GetWindowText(inHWND, title, 255);
  GetClassName(inHWND, classname, 255);

  Result := (ppid <> PAEIDEInfo(inParam)^.PID) Or Not IsWindowVisible(inHWND) Or Not IsWindowEnabled(inHWND) Or
    Not (String(title).Contains('RAD Studio') Or String(title).Contains('Delphi')) Or (String(classname) <> 'TAppBuilder');

  If Not Result Then
  Begin
    PAEIDEInfo(inParam)^.outHWND := inHWND;
    PAEIDEInfo(inParam)^.outWindowCaption := title;
  End;
End;

//
// TAEDelphiInstance
//

Procedure TAEDelphiInstance.InternalFindIDEWindow;
Var
  info: PAEIDEInfo;
Begin
  inherited;

  New(info);
  Try
    info^.PID := Self.PID;
    info^.outHWND := 0;
    info^.outWindowCaption := '';

    EnumWindows(@FindDelphiWindow, LParam(info));

    SetIDEHWND(info^.outHWND);
    SetIDECaption(info^.outWindowCaption);
  Finally
    Dispose(info);
  End;
End;

Procedure TAEDelphiInstance.InternalOpenFile(Const inFileName: String; Const inTimeOutInMs: Cardinal = 5000);
Var
  ddemgr: TAEDDEManager;
  version: TAEBorlandDelphiVersion;
Begin
  inherited;

  version := Self.Owner As TAEBorlandDelphiVersion;

  ddemgr := TAEDDEManager.Create(version.DDEService, version.DDETopic, version.DDEANSIMode, version.DDEDiscoveryTimeout);
  Try
    While Not ddemgr.ServerFound(Self.PID) Do
    Begin
      If Self.InternalAbortOpenFile Then
        Exit;

      Sleep(1000);
      ddemgr.RefreshServers;
    End;

    ddemgr.ExecuteCommand('[open("' + inFileName + '")]', Self.PID, inTimeOutInMs);
  Finally
    FreeAndNil(ddemgr);
  End;
End;

//
// TAEBorlandDelphiVersion
//

Class Function TAEBorlandDelphiVersion.BDSRoot: String;
Begin
  Result := 'SOFTWARE\Borland\Delphi';
End;

Procedure TAEBorlandDelphiVersion.InternalRefreshInstances;
Var
  pid: Cardinal;
  ddemgr: TAEDDEManager;
Begin
  inherited;

  ddemgr := TAEDDEManager.Create(Self.DDEService, Self.DDETopic, Self.DDEANSIMode, Self.DDEDiscoveryTimeout);
  Try
    For pid In ddemgr.DDEServerPIDs Do
      If ProcessName(pid).ToLower = Self.ExecutablePath.ToLower Then
        AddInstance(TAEDelphiInstance.Create(Self, pid));
  Finally
    FreeAndNil(ddemgr);
  End;
End;

Procedure TAEBorlandDelphiVersion.SetDDEDiscoveryTimeout(Const inDDEDiscoveryTimeout: Cardinal);
Begin
  If inDDEDiscoveryTimeout = _ddediscoverytimeout Then
    Exit;

  _ddediscoverytimeout := inDDEDiscoveryTimeout;

  Self.RefreshInstances;
End;

Constructor TAEBorlandDelphiVersion.Create(inOwner: TComponent; Const inExecutablePath: String; Const inVersionNumber: Integer; Const inDDEDiscoveryTimeout: Cardinal);
Begin
  inherited Create(inOwner, inExecutablePath, inVersionNumber);

  _ddeansimode := True;
  _ddediscoverytimeout := inDDEDiscoveryTimeout;
  _ddeservice := 'delphi32';
  _ddetopic := 'system';
end;

Function TAEBorlandDelphiVersion.InternalGetEdition: String;
Begin
  Result := FileInfo(Self.ExecutablePath, 'ProductName');
End;

Function TAEBorlandDelphiVersion.InternalGetName: String;
Begin
  Case Self.VersionNumber Of
    6:
      Result := IDEVER_DELPHI6;
    7:
      Result := IDEVER_DELPHI7;
    Else
      Result := '';
  End;

  // IMPORTANT! IN CASE NEW VERSIONS ARE ADDED, MODIFY THE MAXDELPHIVERSION CONSTANT ACCORDINGLY FOR PROPER REGISTRY ENTRY VALIDATION!
End;

//
// TAEBorland2DelphiVersion
//

Class function TAEBorland2DelphiVersion.BDSRoot: String;
Begin
  Result := 'SOFTWARE\Borland\BDS';
End;

Function TAEBorland2DelphiVersion.InternalGetName: String;
Begin
  Case Self.VersionNumber Of
    3:
      Result := IDEVER_DELPHI2005;
    4:
      Result := IDEVER_DELPHI2006;
    5:
      Result := IDEVER_DELPHI2007;
    Else
      Result := '';
  End;

  // IMPORTANT! IN CASE NEW VERSIONS ARE ADDED, MODIFY THE MAXDELPHIVERSION CONSTANT ACCORDINGLY FOR PROPER REGISTRY ENTRY VALIDATION!
End;

//
// TAECodegearDelphiVersion
//

Class Function TAECodegearDelphiVersion.BDSRoot: String;
Begin
  Result := 'SOFTWARE\CodeGear\BDS';
End;

Constructor TAECodegearDelphiVersion.Create(inOwner: TComponent; Const inExecutablePath: String; Const inVersionNumber: Integer; Const inDiscoveryTimeout: Cardinal);
Begin
  inherited;

  Self.InternalDDEService := 'bds';

  // The first Unicode version was Delphi 2009
  Self.InternalDDEANSIMode := False;
End;

Function TAECodegearDelphiVersion.InternalGetName: String;
Begin
  Case Self.VersionNumber Of
    6:
      Result := IDEVER_DELPHI2009;
    7:
      Result := IDEVER_DELPHI2010;
    Else
      Result := '';
  End;
End;

//
// TAEEmbarcaderoDelphiVersion
//

Class Function TAEEmbarcaderoDelphiVersion.BDSRoot: String;
Begin
  Result := 'SOFTWARE\Embarcadero\BDS';
End;

Function TAEEmbarcaderoDelphiVersion.InternalGetName: String;
Begin
  Case Self.VersionNumber Of
    8:
      Result := IDEVER_DELPHIXE;
    9:
      Result := IDEVER_DELPHIXE2;
    10:
      Result := IDEVER_DELPHIXE3;
    11:
      Result := IDEVER_DELPHIXE4;
    12:
      Result := IDEVER_DELPHIXE5;
    14:
      Result := IDEVER_DELPHIXE6;
    15:
      Result := IDEVER_DELPHIXE7;
    16:
      Result := IDEVER_DELPHIXE8;
    17:
      Result := IDEVER_DELPHI10;
    18:
      Result := IDEVER_DELPHI101;
    19:
      Result := IDEVER_DELPHI102;
    20:
      Result := IDEVER_DELPHI103;
    21:
      Result := IDEVER_DELPHI104;
    22:
      Result := IDEVER_DELPHI11;
    23:
      Result := IDEVER_DELPHI12;
    37:
      Result := IDEVER_DELPHI13;
    Else
      Result := '';
  End;

  // IMPORTANT! IN CASE NEW VERSIONS ARE ADDED, MODIFY THE MAXDELPHIVERSION CONSTANT ACCORDINGLY FOR PROPER REGISTRY ENTRY VALIDATION!
End;

//
// TAEDelphiVersions
//

Constructor TAEDelphiVersions.Create(inOwner: TComponent);
Begin
  inherited;

  _ddediscoverytimeout := 1;
End;

Procedure TAEDelphiVersions.DiscoverVersions(Const inRegistry: TRegistry; Const inDelphiVersionClass: TAEDelphiVersionClass);
Var
  s: String;
  sl: TStringList;
  vernumber: Integer;
Begin
  sl := TStringList.Create;
  Try
    If Not inRegistry.OpenKey(inDelphiVersionClass.BDSRoot, False) Then
      Exit;

    Try
      inRegistry.GetKeyNames(sl);
    Finally
      inRegistry.CloseKey;
    End;

    sl.Sort;

    For s In sl Do
    Begin
      If Not inRegistry.OpenKey(inDelphiVersionClass.BDSRoot + '\' + s, False) Then
        Continue;

      Try
        // Entries in the registry might be invalid keys (e.g. not created by Delphi installer)
        // See a valid report at https://en.delphipraxis.net/topic/8086-ae-bdslauncher/?do=findComment&comment=68459
        // To avoid an exception in this case, try to validate it

        If Not Integer.TryParse(s.Substring(0, s.IndexOf('.')), vernumber) Or (vernumber < MINDELPHIVERSION) Or (vernumber > MAXDELPHIVERSION) Or
           Not inRegistry.ValueExists('App') Then
          Continue;

        Self.AddVersion(inDelphiVersionClass.Create(Self, inRegistry.ReadString('App'), vernumber, _ddediscoverytimeout));
      Finally
        inRegistry.CloseKey;
      End;
    End;
  Finally
    FreeAndNil(sl);
  End;
End;

Procedure TAEDelphiVersions.InternalRefreshInstalledVersions;
Var
  reg: TRegistry;
Begin
  inherited;

  reg := TRegistry.Create;
  Try
    reg.RootKey := HKEY_CURRENT_USER;

    DiscoverVersions(reg, TAEBorlandDelphiVersion);
    DiscoverVersions(reg, TAEBorland2DelphiVersion);
    DiscoverVersions(reg, TAECodegearDelphiVersion);
    DiscoverVersions(reg, TAEEmbarcaderoDelphiVersion);
  Finally
    FreeAndNil(reg);
  End;
End;

Procedure TAEDelphiVersions.SetDDEDiscoveryTimeout(Const inDDEDiscoveryTimeout: Cardinal);
Var
  ver: TAEIDEVersion;
Begin
  If inDDEDiscoveryTimeout = _ddediscoverytimeout Then
    Exit;

  _ddediscoverytimeout := inDDEDiscoveryTimeout;

  For ver In Self.InstalledVersions Do
    (ver As TAEBorlandDelphiVersion).DDEDiscoveryTimeout := inDDEDiscoveryTimeout;
End;

End.
