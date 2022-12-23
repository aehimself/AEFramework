﻿Unit AE.IDE.DelphiVersions;

Interface

Uses System.SysUtils,  AE.DDEManager, AE.IDE.Versions, System.Win.Registry;

Type
  TAEDelphiDDEManager = Class(TAEDDEManager)
  public
    Constructor Create; ReIntroduce;
    Procedure OpenFile(Const inFileName: String; Const inPID: Cardinal; Const inTimeOutInMs: Cardinal = 5000);
  End;

  TAEDelphiInstance = Class(TAEIDEInstance)
  strict protected
    Procedure InternalFindIDEWindow; Override;
    Procedure InternalOpenFile(Const inFileName: String; Const inTimeOutInMs: Cardinal = 5000); Override;
  End;

  TAEBorlandDelphiVersion = Class(TAEIDEVersion)
  strict protected
    Procedure InternalRefreshInstances; Override;
    Function InternalGetName: String; Override;
  public
    Class Function BDSRoot: String; Virtual;
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
  End;

  TAEEmbarcaderoDelphiVersion = Class(TAEBorlandDelphiVersion)
  strict protected
    Function InternalGetName: String; Override;
  public
    Class Function BDSRoot: String; Override;
  End;

  TAEDelphiVersions = Class(TAEIDEVersions)
  strict private
    Procedure DiscoverVersions(Const inRegistry: TRegistry; Const inDelphiVersionClass: TAEDelphiVersionClass);
  strict protected
    Procedure InternalRefreshInstalledVersions; Override;
  End;

  EAEDelphiVersionException = Class(Exception);

Implementation

Uses System.Classes, WinApi.Windows;

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
// TAEDelphiDDEManager
//

Constructor TAEDelphiDDEManager.Create;
Begin
  inherited Create('bds', 'system');
End;

Procedure TAEDelphiDDEManager.OpenFile(Const inFileName: String; Const inPID: Cardinal; Const inTimeOutInMs: Cardinal);
Begin
  Self.ExecuteCommand('[open("' + inFileName + '")]', inPID, inTimeoutInMs);
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
  ddemgr: TAEDelphiDDEManager;
Begin
  inherited;

  ddemgr := TAEDelphiDDEManager.Create;
  Try
    While Not ddemgr.ServerFound(Self.PID) Do
    Begin
      If Self.InternalAbortOpenFile Then
        Exit;

      Sleep(1000);
      ddemgr.RefreshServers;
    End;

    ddemgr.OpenFile(inFileName, Self.PID, inTimeOutInMs);
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
  ddemgr: TAEDelphiDDEManager;
Begin
  inherited;

  ddemgr := TAEDelphiDDEManager.Create;
  Try
    For pid In ddemgr.DDEServerPIDs Do
      If ProcessName(pid).ToLower = Self.ExecutablePath.ToLower Then
        AddInstance(TAEDelphiInstance.Create(Self, pid));
  Finally
    FreeAndNil(ddemgr);
  End;
End;

Function TAEBorlandDelphiVersion.InternalGetName: String;
Begin
  Case Self.VersionNumber Of
    6:
      Result := 'Borland Delphi 6';
    7:
      Result := 'Borland Delphi 7';
    Else
      Result := '';
  End;
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
      Result := 'Borland Delphi 2005';
    4:
      Result := 'Borland Delphi 2006';
    5:
      Result := 'Borland Delphi 2007';
    Else
      Result := '';
  End;
End;

//
// TAECodegearDelphiVersion
//

Class Function TAECodegearDelphiVersion.BDSRoot: String;
Begin
  Result := 'SOFTWARE\CodeGear\BDS';
End;

Function TAECodegearDelphiVersion.InternalGetName: String;
Begin
  Case Self.VersionNumber Of
    6:
      Result := 'CodeGear Delphi 2009';
    7:
      Result := 'CodeGear Delphi 2010';
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
      Result := 'Embarcadero Delphi XE';
    9:
      Result := 'Embarcadero Delphi XE2';
    10:
      Result := 'Embarcadero Delphi XE3';
    11:
      Result := 'Embarcadero Delphi XE4';
    12:
      Result := 'Embarcadero Delphi XE5';
    14:
      Result := 'Embarcadero Delphi XE6';
    15:
      Result := 'Embarcadero Delphi XE7';
    16:
      Result := 'Embarcadero Delphi XE8';
    17:
      Result := 'Embarcadero Delphi 10 Seattle';
    18:
      Result := 'Embarcadero Delphi 10.1 Berlin';
    19:
      Result := 'Embarcadero Delphi 10.2 Tokyo';
    20:
      Result := 'Embarcadero Delphi 10.3 Rio';
    21:
      Result := 'Embarcadero Delphi 10.4 Sydney';
    22:
      Result := 'Embarcadero Delphi 11 Alexandria';
  End;
End;

//
// TAEDelphiVersions
//

Procedure TAEDelphiVersions.DiscoverVersions(Const inRegistry: TRegistry; Const inDelphiVersionClass: TAEDelphiVersionClass);
Var
  s: String;
  sl: TStringList;
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
        Self.AddVersion(inDelphiVersionClass.Create(Self, inRegistry.ReadString('App'), Integer.Parse(s.Substring(0, s.IndexOf('.')))));
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

End.
