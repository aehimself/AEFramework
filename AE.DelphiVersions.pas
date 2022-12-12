Unit AE.DelphiVersions;

Interface

Uses System.Generics.Collections, WinApi.Windows, System.SysUtils, System.Classes, WinApi.Messages, AE.DDEManager;

Type
  TDelphiDDEManager = Class(TAEDDEManager)
  public
    Constructor Create; ReIntroduce;
    Procedure OpenFile(Const inFileName: String; Const inPID: Cardinal; Const inTimeOutInMs: Cardinal = 5000);
  End;

  TDelphiInstance = Class(TComponent)
  strict private
    _idehwnd: HWND;
    _idecaption: String;
    _pid: Cardinal;
  public
    Constructor Create(inOwner: TComponent; Const inPID: Cardinal); ReIntroduce;
    Procedure OpenFile(Const inFileName: String; Const inTimeOutInMs: Cardinal = 5000);
    Procedure UpdateCaption;
    Function FindIdeWindow(Const inForceSearch: Boolean = False): Boolean;
    Function IsIDEBusy: Boolean;
    Property IDECaption: String Read _idecaption;
    Property IDEHWND: HWND Read _idehwnd;
    Property PID: Cardinal Read _pid;
  End;

  TBorlandDelphiVersion = Class(TComponent)
  strict private
    _bdspath: String;
    _instances: TObjectList<TDelphiInstance>;
    _name: String;
    _versionnumber: Byte;
    Function GetInstances: TArray<TDelphiInstance>;
    Function ProcessName(Const inPID: Cardinal): String;
  strict protected
    Function GetDelphiName: String; Virtual;
  public
    Class Function BDSRoot: String; Virtual;
    Constructor Create(inOwner: TComponent; Const inBDSPath: String; Const inVersionNumber: Byte); ReIntroduce;
    Destructor Destroy; Override;
    Procedure RefreshInstances;
    Function InstanceByPID(Const inPID: Cardinal): TDelphiInstance;
    Function IsRunning: Boolean;
    Function NewDelphiInstance: TDelphiInstance;
    Property BDSPath: String Read _bdspath;
    Property Instances: TArray<TDelphiInstance> Read GetInstances;
    Property Name: String Read _name;
    Property VersionNumber: Byte Read _versionnumber;
  End;

  TDelphiVersionClass = Class Of TBorlandDelphiVersion;

  TBorland2DelphiVersion = Class(TBorlandDelphiVersion)
  strict protected
    Function GetDelphiName: String; Override;
  public
    Class Function BDSRoot: String; Override;
  End;

  TCodegearDelphiVersion = Class(TBorlandDelphiVersion)
  strict protected
    Function GetDelphiName: String; Override;
  public
    Class Function BDSRoot: String; Override;
  End;

  TEmbarcaderoDelphiVersion = Class(TBorlandDelphiVersion)
  strict protected
    Function GetDelphiName: String; Override;
  public
    Class Function BDSRoot: String; Override;
  End;

  TDelphiVersions = Class(TComponent)
  strict private
    _latestversion: TBorlandDelphiVersion;
    _versions: TObjectList<TBorlandDelphiVersion>;
    Function GetInstalledVersions: TArray<TBorlandDelphiVersion>;
  public
    Constructor Create(inOwner: TComponent); Override;
    Destructor Destroy; Override;
    Function ByName(Const inName: String): TBorlandDelphiVersion;
    Function ByVersionNumber(Const inVersionNumber: Integer): TBorlandDelphiVersion;
    Property InstalledVersions: TArray<TBorlandDelphiVersion> Read GetInstalledVersions;
    Property LatestVersion: TBorlandDelphiVersion Read _latestversion;
  End;

  EDelphiVersionException = Class(Exception);

Implementation

Uses System.Win.Registry, WinApi.PsAPI;

Type
  TDelphiIDEInfo = Record
    outHWND: HWND;
    outWindowCaption: String;
    PID: Cardinal;
  End;
  PDelphiIDEInfo = ^TDelphiIDEInfo;

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

  Result := (ppid <> PDelphiIDEInfo(inParam)^.PID) Or Not IsWindowVisible(inHWND) Or (Not IsWindowEnabled(inHWND)) Or Not
    (String(title).Contains('RAD Studio') Or String(title).Contains('Delphi')) Or (String(classname) <> 'TAppBuilder');

  If Not Result Then
  Begin
    PDelphiIDEInfo(inParam)^.outHWND := inHWND;
    PDelphiIDEInfo(inParam)^.outWindowCaption := title;
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

Constructor TDelphiInstance.Create(inOwner: TComponent; Const inPID: Cardinal);
Begin
  inherited Create(inOwner);

  _idehwnd := 0;
  _idecaption := '';
  _pid := inPID;

  FindIdeWindow;
End;

Procedure TDelphiInstance.OpenFile(Const inFileName: String; Const inTimeOutInMs: Cardinal = 5000);
Var
  ddemgr: TDelphiDDEManager;
Begin
  ddemgr := TDelphiDDEManager.Create;
  Try
    ddemgr.OpenFile(inFileName, _pid, inTimeOutInMs);
  Finally
    FreeAndNil(ddemgr);
  End;
End;

Procedure TDelphiInstance.UpdateCaption;
Var
  title: Array[0..255] Of Char;
Begin
  If Not FindIdeWindow Then
    Raise EDelphiVersionException.Create('Delphi IDE window can not be found!');

  GetWindowText(_idehwnd, title, 255);

  _idecaption := title;
End;

Function TDelphiInstance.FindIdeWindow(Const inForceSearch: Boolean = False): Boolean;
Var
  info: PDelphiIDEInfo;
Begin
  If Not inForceSearch And (_idehwnd <> 0) And IsWindow(_idehwnd) Then
  Begin
    // IDE window was already found and seems to be still valid

    Result := True;
    Exit;
  End;

  _idehwnd := 0;
  _idecaption := '';

  New(info);
  Try
    info^.PID := _pid;
    info^.outHWND := 0;
    info^.outWindowCaption := '';

    EnumWindows(@FindDelphiWindow, LParam(info));

    _idehwnd := info^.outHWND;
    _idecaption := info^.outWindowCaption;
  Finally
    Dispose(info);
  End;

  Result := _idehwnd <> 0;
End;

Function TDelphiInstance.IsIDEBusy: Boolean;
Var
  res: NativeInt;
Begin
  If Not FindIdeWindow Then
    Raise EDelphiVersionException.Create('Delphi IDE window can not be found!');

  Result := Not IsWindowVisible(_idehwnd);

  If Not Result Then
    Exit;

  Result := SendMessageTimeout(_idehwnd, WM_NULL, 0, 0, SMTO_BLOCK, 250, nil) = 0;

  If Not Result Then
    Exit;

  res := GetLastError;

  If res <> ERROR_TIMEOUT Then
    RaiseLastOSError(res);
End;

//
// TBorlandDelphiVersion
//

Class Function TBorlandDelphiVersion.BDSRoot: String;
Begin
  Result := 'SOFTWARE\Borland\Delphi';
End;

Constructor TBorlandDelphiVersion.Create(inOwner: TComponent; Const inBDSPath: String; Const inVersionNumber: Byte);
Begin
  inherited Create(inOwner);

  _bdspath := inBDSPath;
  _instances := TObjectList<TDelphiInstance>.Create(True);
  _versionnumber := inVersionNumber;

  _name := GetDelphiName;
  If _name.IsEmpty Then
    _name := 'BDS ' + _versionnumber.ToString + '.0';

  Self.RefreshInstances;
End;

Function TBorlandDelphiVersion.InstanceByPID(Const inPID: Cardinal): TDelphiInstance;
Var
  inst: TDelphiInstance;
Begin
  Result := nil;

  For inst In _instances Do
    If inst.PID = inPID Then
    Begin
      Result := inst;
      Break;
    End;
End;

Function TBorlandDelphiVersion.IsRunning: Boolean;
Begin
  Result := _instances.Count > 0;
End;

Function TBorlandDelphiVersion.NewDelphiInstance: TDelphiInstance;
Var
  startinfo: TStartupInfo;
  procinfo: TProcessInformation;
Begin
  Result := nil;

  FillChar(startinfo, SizeOf(TStartupInfo), #0);
  startinfo.cb := SizeOf(TStartupInfo);
  FillChar(procinfo, SizeOf(TProcessInformation), #0);

  If Not CreateProcess(PChar(_bdspath), nil, nil, nil, False, CREATE_NEW_PROCESS_GROUP, nil, nil, startinfo, procinfo) Then
    RaiseLastOSError;

  Try
    WaitForInputIdle(procinfo.hProcess, INFINITE);

    Repeat
      Sleep(1000);

      If Not Assigned(Result) Then
      Begin
        Self.RefreshInstances;
        Result := Self.InstanceByPID(procinfo.dwProcessId);
      End;
    Until Assigned(Result) And Result.FindIdeWindow And Not Result.IsIDEBusy;
  Finally
    CloseHandle(procinfo.hThread);
    CloseHandle(procinfo.hProcess);
  End;
End;

Function TBorlandDelphiVersion.ProcessName(Const inPID: Cardinal): String;
Var
  processhandle: THandle;
Begin
  processhandle := OpenProcess(PROCESS_QUERY_INFORMATION Or PROCESS_VM_READ, False, inPID);
  If processhandle = 0 Then
    RaiseLastOSError;

  Try
    SetLength(Result, MAX_PATH);
    FillChar(Result[1], Length(Result) * SizeOf(Char), 0);
    If GetModuleFileNameEx(processhandle, 0, PChar(Result), Length(Result)) = 0 Then
      RaiseLastOSError;

    Result := Trim(Result);
  Finally
    CloseHandle(processhandle)
  End;
End;

Procedure TBorlandDelphiVersion.RefreshInstances;
Var
  pid: Cardinal;
  ddemgr: TDelphiDDEManager;
Begin
  _instances.Clear;

  ddemgr := TDelphiDDEManager.Create;
  Try
    For pid In ddemgr.DDEServerPIDs Do
      If ProcessName(pid).ToLower = _bdspath.ToLower Then
        _instances.Add(TDelphiInstance.Create(Self, pid));
  Finally
    FreeAndNil(ddemgr);
  End;
End;

Destructor TBorlandDelphiVersion.Destroy;
Begin
  FreeAndNil(_instances);

  inherited;
End;

Function TBorlandDelphiVersion.GetDelphiName: String;
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

Function TBorlandDelphiVersion.GetInstances: TArray<TDelphiInstance>;
Begin
  Result := _instances.ToArray;
End;

//
// TBorland2DelphiVersion
//

Class function TBorland2DelphiVersion.BDSRoot: String;
Begin
  Result := 'SOFTWARE\Borland\BDS';
End;

Function TBorland2DelphiVersion.GetDelphiName: String;
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

Function TCodegearDelphiVersion.GetDelphiName: String;
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

Function TEmbarcaderoDelphiVersion.GetDelphiName: String;
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

Constructor TDelphiVersions.Create(inOwner: TComponent);
Var
  reg: TRegistry;
  sl: TStringList;

  Procedure DiscoverVersions(Const inDelphiVersionClass: TDelphiVersionClass);
  Var
    s: String;
  Begin
    If Not reg.OpenKey(inDelphiVersionClass.BDSRoot, False) Then
      Exit;

    Try
      reg.GetKeyNames(sl);
    Finally
      reg.CloseKey;
    End;

    sl.Sort;

    For s In sl Do
    Begin
      If Not reg.OpenKey(inDelphiVersionClass.BDSRoot + '\' + s, False) Then
        Continue;

      Try
        _latestversion := inDelphiVersionClass.Create(Self, reg.ReadString('App'), Byte.Parse(s.Substring(0, s.IndexOf('.'))));

        _versions.Add(_latestversion);
      Finally
        reg.CloseKey;
      End;
    End;
  End;

Begin
  inherited;

  _latestversion := nil;
  _versions := TObjectList<TBorlandDelphiVersion>.Create(True);

  sl := TStringList.Create;
  Try
    reg := TRegistry.Create;
    Try
      reg.RootKey := HKEY_CURRENT_USER;

      DiscoverVersions(TBorlandDelphiVersion);
      DiscoverVersions(TBorland2DelphiVersion);
      DiscoverVersions(TCodegearDelphiVersion);
      DiscoverVersions(TEmbarcaderoDelphiVersion);
    Finally
      FreeAndNil(reg);
    End;
  Finally
    FreeAndNil(sl);
  End;
End;

Destructor TDelphiVersions.Destroy;
Begin
  FreeAndNil(_versions);

  inherited;
End;

Function TDelphiVersions.GetInstalledVersions: TArray<TBorlandDelphiVersion>;
Begin
  Result := _versions.ToArray;
End;

Function TDelphiVersions.ByName(Const inName: String): TBorlandDelphiVersion;
Begin
  For Result In _versions Do
    If Result.Name = inName Then
      Exit;

  Result := nil;
End;

Function TDelphiVersions.ByVersionNumber(Const inVersionNumber: Integer): TBorlandDelphiVersion;
Begin
  For Result In _versions Do
    If Result.VersionNumber = inVersionNumber Then
      Exit;

  Result := nil;
End;

End.
