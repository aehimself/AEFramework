Unit AE.IDE.DelphiVersions;

Interface

Uses System.SysUtils,  AE.DDEManager, AE.IDE.Versions, System.Win.Registry;

Type
  TDelphiDDEManager = Class(TAEDDEManager)
  public
    Constructor Create; ReIntroduce;
    Procedure OpenFile(Const inFileName: String; Const inPID: Cardinal; Const inTimeOutInMs: Cardinal = 5000);
  End;

  TDelphiInstance = Class(TIDEInstance)
  strict protected
    Procedure InternalFindIDEWindow; Override;
  public
    Procedure OpenFile(Const inFileName: String; Const inTimeOutInMs: Cardinal = 5000);
  End;

  TBorlandDelphiVersion = Class(TIDEVersion)
  strict protected
    Procedure InternalRefreshInstances; Override;
    Function InternalGetName: String; Override;
  public
    Class Function BDSRoot: String; Virtual;
  End;

  TDelphiVersionClass = Class Of TBorlandDelphiVersion;

  TBorland2DelphiVersion = Class(TBorlandDelphiVersion)
  strict protected
    Function InternalGetName: String; Override;
  public
    Class Function BDSRoot: String; Override;
  End;

  TCodegearDelphiVersion = Class(TBorlandDelphiVersion)
  strict protected
    Function InternalGetName: String; Override;
  public
    Class Function BDSRoot: String; Override;
  End;

  TEmbarcaderoDelphiVersion = Class(TBorlandDelphiVersion)
  strict protected
    Function InternalGetName: String; Override;
  public
    Class Function BDSRoot: String; Override;
  End;

  TDelphiVersions = Class(TIDEVersions)
  strict private
    Procedure DiscoverVersions(Const inRegistry: TRegistry; Const inDelphiVersionClass: TDelphiVersionClass);
  strict protected
    Procedure InternalRefreshInstalledVersions; Override;
  End;

  EDelphiVersionException = Class(Exception);

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

  Result := (ppid <> PIDEInfo(inParam)^.PID) Or Not IsWindowVisible(inHWND) Or Not IsWindowEnabled(inHWND) Or
    Not (String(title).Contains('RAD Studio') Or String(title).Contains('Delphi')) Or (String(classname) <> 'TAppBuilder');

  If Not Result Then
  Begin
    PIDEInfo(inParam)^.outHWND := inHWND;
    PIDEInfo(inParam)^.outWindowCaption := title;
  End;
End;

//
// TDelphiDDEManager
//

Constructor TDelphiDDEManager.Create;
Begin
  inherited Create('bds', 'system');
End;

Procedure TDelphiDDEManager.OpenFile(Const inFileName: String; Const inPID: Cardinal; Const inTimeOutInMs: Cardinal);
Begin
  Self.ExecuteCommand('[open("' + inFileName + '")]', inPID, inTimeoutInMs);
End;


//
// TDelphiInstance
//

Procedure TDelphiInstance.InternalFindIDEWindow;
Var
  info: PIDEInfo;
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

Procedure TDelphiInstance.OpenFile(Const inFileName: String; Const inTimeOutInMs: Cardinal = 5000);
Var
  ddemgr: TDelphiDDEManager;
Begin
  ddemgr := TDelphiDDEManager.Create;
  Try
    ddemgr.OpenFile(inFileName, Self.PID, inTimeOutInMs);
  Finally
    FreeAndNil(ddemgr);
  End;
End;

//
// TBorlandDelphiVersion
//

Class Function TBorlandDelphiVersion.BDSRoot: String;
Begin
  Result := 'SOFTWARE\Borland\Delphi';
End;

Procedure TBorlandDelphiVersion.InternalRefreshInstances;
Var
  pid: Cardinal;
  ddemgr: TDelphiDDEManager;
Begin
  inherited;

  ddemgr := TDelphiDDEManager.Create;
  Try
    For pid In ddemgr.DDEServerPIDs Do
      If ProcessName(pid).ToLower = Self.ExecutablePath.ToLower Then
        AddInstance(TDelphiInstance.Create(Self, pid));
  Finally
    FreeAndNil(ddemgr);
  End;
End;

Function TBorlandDelphiVersion.InternalGetName: String;
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
// TBorland2DelphiVersion
//

Class function TBorland2DelphiVersion.BDSRoot: String;
Begin
  Result := 'SOFTWARE\Borland\BDS';
End;

Function TBorland2DelphiVersion.InternalGetName: String;
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
// TCodegearDelphiVersion
//

Class Function TCodegearDelphiVersion.BDSRoot: String;
Begin
  Result := 'SOFTWARE\CodeGear\BDS';
End;

Function TCodegearDelphiVersion.InternalGetName: String;
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
// TEmbarcaderoDelphiVersion
//

Class Function TEmbarcaderoDelphiVersion.BDSRoot: String;
Begin
  Result := 'SOFTWARE\Embarcadero\BDS';
End;

Function TEmbarcaderoDelphiVersion.InternalGetName: String;
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
// TDelphiVersions
//

Procedure TDelphiVersions.DiscoverVersions(Const inRegistry: TRegistry; Const inDelphiVersionClass: TDelphiVersionClass);
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

Procedure TDelphiVersions.InternalRefreshInstalledVersions;
Var
  reg: TRegistry;
Begin
  inherited;

  reg := TRegistry.Create;
  Try
    reg.RootKey := HKEY_CURRENT_USER;

    DiscoverVersions(reg, TBorlandDelphiVersion);
    DiscoverVersions(reg, TBorland2DelphiVersion);
    DiscoverVersions(reg, TCodegearDelphiVersion);
    DiscoverVersions(reg, TEmbarcaderoDelphiVersion);
  Finally
    FreeAndNil(reg);
  End;
End;

End.
