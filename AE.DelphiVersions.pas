Unit AE.DelphiVersions;

Interface

Uses System.Generics.Collections, WinApi.Windows, System.SysUtils;

Type
  TDelphiInstance = Class
  strict private
    _ddehwnd: HWND;
    _idehwnd: HWND;
    _pid: Cardinal;
    Function GlobalLockString(inString: string; inFlags: UINT): THandle;
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

  EDelphiVersionException = Class(Exception);

Implementation

Uses System.Win.Registry, System.Classes, Vcl.DdeMan, WinApi.DDEml, WinApi.PsAPI, WinAPi.Messages;

Type
  TWindowInfo = Record
    ProcessID: Cardinal;
    HWND: HWND;
  End;
  PWindowInfo = ^TWindowInfo;

Const
  DDESERVICE = 'bds';
  DDETOPIC = 'system';


Function EnumWindowsProc(inHWND: HWND; inParam: LParam): Boolean; StdCall;
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

  Result := (ppid <> PWindowInfo(inParam)^.ProcessID) Or Not IsWindowVisible(inHWND) Or (Not IsWindowEnabled(inHWND)) Or Not (String(title).Contains('RAD Studio') Or String(title).Contains('Delphi')) Or (String(classname) <> 'TAppBuilder');
  If Not Result Then
    PWindowInfo(inParam)^.HWND := inHWND;
End;

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
  atomservice, atomtopic: Word;
  commandhandle: THandle;
  msghwnd: HWND;
  cmd: String;
Begin
  msghwnd := AllocateHwnd(nil);
  Try
    atomservice := GlobalAddAtom(PChar(DDESERVICE));
    atomtopic := GlobalAddAtom(PChar(DDETOPIC));
    Try
      SendMessage(_ddehwnd, WM_DDE_INITIATE, msghwnd, Makelong(atomservice, atomtopic));
    Finally
      GlobalDeleteAtom(atomservice);
      GlobalDeleteAtom(atomtopic);
    End;

    cmd := '[open("' + inFileName + '")]';
    commandhandle := GlobalLockString(cmd, GMEM_DDESHARE);
    Try
      PostMessage(_ddehwnd, WM_DDE_EXECUTE, msghwnd, commandhandle);
    Finally
      GlobalUnlock(commandhandle);
      GlobalFree(commandhandle);
    End;
  Finally
    DeAllocateHwnd(msghwnd);
  End;
End;

Procedure TDelphiInstance.FindIdeWindow;
Var
  info: PWindowInfo;
Begin
  New(info);
  Try
   info^.ProcessID := _pid;
   info^.HWND := 0;

   EnumWindows(@EnumWindowsProc, LParam(info));

   _idehwnd := info^.HWND;
  Finally
   Dispose(info);
  End;
End;

Function TDelphiInstance.GlobalLockString(inString: String; inFlags: UINT): THandle;
Var
  strlock: Pointer;
  tb: TBytes;
Begin
  Result := GlobalAlloc(GMEM_ZEROINIT Or inFlags, (Length(inString) + 1) * SizeOf(Char));
  Try
    strlock := GlobalLock(Result);
    tb := BytesOf(inString);
    SetLength(tb, Length(tb) + 1);
    Move(PChar(inString)^, strlock^, Length(inString) * SizeOf(Char));
  Except
    GlobalFree(Result);
    Raise;
  End;
End;

Function TDelphiInstance.IsIDEBusy: Boolean;
Var
  res: NativeInt;
Begin
  If _idehwnd = 0 Then
    Raise EDelphiVersionException.Create('Delphi IDE window is not found yet!');

  Result := SendMessageTimeout(_idehwnd, WM_NULL, 0, 0, SMTO_BLOCK, 250, nil) <> 0;

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
  apphandle, topichandle: HSZ;
  convlist: HConvList;
  conv: HConv;
  convinfo: TConvInfo;
  pid: Cardinal;
Begin
  // DDE logic by Attila Kovacs
  // https://en.delphipraxis.net/topic/7955-how-to-open-a-file-in-the-already-running-ide/?do=findComment&comment=66850

  _instances.Clear;

  apphandle := DdeCreateStringHandleW(ddeMgr.DdeInstId, PChar(DDESERVICE), CP_WINUNICODE);
  topichandle := DdeCreateStringHandleW(ddeMgr.DdeInstId, PChar(DDETOPIC), CP_WINUNICODE);
  Try
    convlist := DdeConnectList(ddeMgr.DdeInstId, apphandle, topichandle, 0, nil);
    Try
      conv := 0;
      Repeat
        conv := DdeQueryNextServer(convlist, conv);
        If conv = 0 Then
          Break;

        convinfo.cb := SizeOf(TConvInfo);
        DdeQueryConvInfo(conv, QID_SYNC, @convinfo);

        GetWindowThreadProcessId(convinfo.hwndPartner, pid);
        If ProcessName(pid).ToLower = _bdspath.ToLower Then
          _instances.Add(TDelphiInstance.Create(pid, convinfo.hwndPartner));
      Until (conv = 0);
    Finally
     DdeDisconnectList(convlist);
    End;
  Finally
    DdeFreeStringHandle(ddeMgr.DdeInstId, apphandle);
    DdeFreeStringHandle(ddeMgr.DdeInstId, topichandle);
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
