Unit AE.DelphiVersions;

Interface

Uses System.Generics.Collections, WinApi.Windows;

Type
  TDelphiInstance = Class
  strict private
    _ddehwnd: HWND;
    _idehwnd: HWND;
    _pid: Cardinal;
    Function GlobalLockString(AValue: string; AFlags: UINT): THandle;
  public
    Constructor Create(Const inPID: Cardinal; Const inDDEHWND: HWND);
    Procedure FindIdeWindow;
    Procedure OpenFile(Const inFileName: String);
    Function IsIDEBusy: Boolean;
    Property IDEHWND: HWND Read _idehwnd;
    Property PID: Cardinal Read _pid;
    Property DDEHWND: HWND Read _ddehwnd;
  End;

  TBorlandDelphiVersion = Class
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
    Constructor Create(Const inBDSPath: String; Const inVersionNumber: Byte); ReIntroduce;
    Destructor Destroy; Override;
    Procedure RefreshInstances;
    Function IsRunning: Boolean;
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

  TDelphiVersions = Class
  strict private
    _versions: TObjectList<TBorlandDelphiVersion>;
    Function GetInstalledVersions: TArray<TBorlandDelphiVersion>;
  public
    Constructor Create; ReIntroduce;
    Destructor Destroy; Override;
    Function ByName(Const inName: String): TBorlandDelphiVersion;
    Function ByVersionNumber(Const inVersionNumber: Integer): TBorlandDelphiVersion;
    Property InstalledVersions: TArray<TBorlandDelphiVersion> Read GetInstalledVersions;
  End;

Implementation

Uses System.Win.Registry, System.SysUtils, System.Classes, Vcl.DdeMan, WinApi.DDEml, WinApi.PsAPI, WinAPi.Messages;

Const
  DDESERVICE = 'bds';
  DDETOPIC = 'system';

//
// TDelphiInstance
//

Constructor TDelphiInstance.Create(Const inPID: Cardinal; Const inDDEHWND: HWND);
Begin
 inherited Create;

 _ddehwnd := inDDEHWND;
 _pid := inPID;

 FindIdeWindow;
End;

Procedure TDelphiInstance.OpenFile(Const inFileName: String);
Var
  aService, aTopic: word;
  ddeCommandH: THandle;
  msghwnd: HWND;
  cmd: String;
Begin
  msghwnd := AllocateHwnd(nil);
  Try
    aService := GlobalAddAtom(PChar(DDESERVICE));
    aTopic := GlobalAddAtom(PChar(DDETOPIC));
    Try
      SendMessage(_ddehwnd, WM_DDE_INITIATE, msghwnd, Makelong(aService, aTopic));
    Finally
      GlobalDeleteAtom(aService);
      GlobalDeleteAtom(aTopic);
    End;

    cmd := '[open("' + inFileName + '")]';
    ddeCommandH := GlobalLockString(cmd, GMEM_DDESHARE);
    Try
      PostMessage(_ddehwnd, WM_DDE_EXECUTE, msghwnd, ddeCommandH);
    Finally
      GlobalUnlock(ddeCommandH);
      GlobalFree(ddeCommandH);
    End;
  Finally
    DeAllocateHwnd(msghwnd);
  End;
End;

Procedure TDelphiInstance.FindIdeWindow;
Type
  TEnumInfo = Record
    ProcessID: DWORD;
    HWND: THandle;
  End;

  Function EnumWindowsProc(inHWND: DWORD; Var outEnumInfo: TEnumInfo): Bool; StdCall;
  Var
    ppid: DWORD;
    title, classname: Array[0..255] Of Char;
  Begin
    GetWindowThreadProcessID(inHWND, @ppid);
    GetWindowText(inHWND, title, 255);
    GetClassName(inHWND, classname, 255);

    Result := (ppid <> outEnumInfo.ProcessID) Or Not IsWindowVisible(inHWND) Or (Not IsWindowEnabled(inHWND)) Or Not (String(title).Contains('RAD Studio') Or String(title).Contains('Delphi')) Or (String(classname) <> 'TAppBuilder');
    If Not Result Then
      outEnumInfo.HWND := inHWND;
  End;

Var
  EI: TEnumInfo;

Begin
  EI.ProcessID := _pid;
  EI.HWND := 0;
  EnumWindows(@EnumWindowsProc, Integer(@EI));
  _idehwnd := EI.HWND;
End;

Function TDelphiInstance.GlobalLockString(AValue: String; AFlags: UINT): THandle;
Var
  DataPtr: Pointer;
  B: TBytes;
Begin
  Result := GlobalAlloc(GMEM_ZEROINIT Or AFlags, (Length(AValue) + 1) * SizeOf(Char));
  Try
    DataPtr := GlobalLock(Result);
    B := BytesOf(AValue);
    SetLength(B, Length(B) + 1);
    Move(PChar(AValue)^, DataPtr^, Length(AValue) * SizeOf(Char));
  Except
    GlobalFree(Result);
    Raise;
  End;
End;

Function TDelphiInstance.IsIDEBusy: Boolean;
Var
  res: NativeInt;
Begin
  Result := False;

  res := SendMessageTimeout(_idehwnd, WM_NULL, 0, 0, SMTO_BLOCK, 250, nil);
  If res <> 0 Then
    Exit;

  res := GetLastError;

  If res <> ERROR_TIMEOUT Then
    RaiseLastOSError(res);

  Result := True;
End;

//
// TBorlandDelphiVersion
//

Class Function TBorlandDelphiVersion.BDSRoot: String;
Begin
  Result := 'SOFTWARE\Borland\Delphi'
End;

Constructor TBorlandDelphiVersion.Create(Const inBDSPath: String; Const inVersionNumber: Byte);
Begin
  inherited Create;

  _bdspath := inBDSPath;
  _instances := TObjectList<TDelphiInstance>.Create(True);
  _versionnumber := inVersionNumber;

  _name := GetDelphiName;
  If _name.IsEmpty Then
    _name := 'BDS ' + _versionnumber.ToString + '.0';
End;

Function TBorlandDelphiVersion.IsRunning: Boolean;
Begin
  Result := _instances.Count > 0;
End;

Function TBorlandDelphiVersion.ProcessName(const inPID: Cardinal): String;
Var
  hProcess: THandle;
Begin
  hProcess := OpenProcess(PROCESS_QUERY_INFORMATION Or PROCESS_VM_READ, False, inPID);
  If hProcess = 0 Then
    RaiseLastOSError;

  Try
    SetLength(Result, MAX_PATH);
    FillChar(Result[1], Length(Result) * SizeOf(Char), 0);
    If GetModuleFileNameEx(hProcess, 0, PChar(Result), Length(Result)) = 0 Then
      RaiseLastOSError;

    Result := Trim(Result);
  Finally
    CloseHandle(hProcess)
  End;
End;

Procedure TBorlandDelphiVersion.RefreshInstances;
Var
  lHszApp, lHszTopic: HSZ;
  ConvList: HConvList;
  Conv: HConv;
  ci: TConvInfo;
  pid: Cardinal;
Begin
  // DDE logic by Attila Kovacs
  // https://en.delphipraxis.net/topic/7955-how-to-open-a-file-in-the-already-running-ide/?do=findComment&comment=66850

  _instances.Clear;

  lHszApp := DdeCreateStringHandleW(ddeMgr.DdeInstId, PChar(DDESERVICE), CP_WINUNICODE);
  lHszTopic := DdeCreateStringHandleW(ddeMgr.DdeInstId, PChar(DDETOPIC), CP_WINUNICODE);
  Try
    ConvList := DdeConnectList(ddeMgr.DdeInstId, lHszApp, lHszTopic, 0, nil);
    Try
      Conv := 0;
      Repeat
        Conv := DdeQueryNextServer(ConvList, Conv);
        If Conv = 0 Then
          Break;

        ci.cb := SizeOf(TConvInfo);
        DdeQueryConvInfo(Conv, QID_SYNC, @ci);

        GetWindowThreadProcessId(ci.hwndPartner, pid);
        If ProcessName(pid).ToLower = _bdspath.ToLower Then
          _instances.Add(TDelphiInstance.Create(pid, ci.hwndPartner));
      Until (Conv = 0);
    Finally
     DdeDisconnectList(ConvList);
    End;
  Finally
    DdeFreeStringHandle(ddeMgr.DdeInstId, lHszApp);
    DdeFreeStringHandle(ddeMgr.DdeInstId, lHszTopic);
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
      Result := 'Delphi 6';
    7:
      Result := 'Delphi 7';
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
      Result := 'Delphi 2005';
    4:
      Result := 'Delphi 2006';
    5:
      Result := 'Delphi 2007';
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
      Result := 'Delphi 2009';
    7:
      Result := 'Delphi 2010';
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
      Result := 'Delphi XE';
    9:
      Result := 'Delphi XE2';
    10:
      Result := 'Delphi XE3';
    11:
      Result := 'Delphi XE4';
    12:
      Result := 'Delphi XE5';
    14:
      Result := 'Delphi XE6';
    15:
      Result := 'Delphi XE7';
    16:
      Result := 'Delphi XE8';
    17:
      Result := 'Delphi 10 Seattle';
    18:
      Result := 'Delphi 10.1 Berlin';
    19:
      Result := 'Delphi 10.2 Tokyo';
    20:
      Result := 'Delphi 10.3 Rio';
    21:
      Result := 'Delphi 10.4 Sydney';
    22:
      Result := 'Delphi 11 Alexandria';
  End;
End;

//
// TDelphiVersions
//

Constructor TDelphiVersions.Create;
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

    For s In sl Do
    Begin
      If Not reg.OpenKey(inDelphiVersionClass.BDSRoot + '\' + s, False) Then
        Continue;

      Try
        _versions.Add(inDelphiVersionClass.Create(reg.ReadString('App'), Byte.Parse(s.Substring(0, s.IndexOf('.')))));
      Finally
        reg.CloseKey;
      End;
    End;
  End;

Begin
  inherited;

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
