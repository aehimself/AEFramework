Unit AE.DelphiVersions;

Interface

Uses System.Generics.Collections, WinApi.Windows, System.SysUtils, System.Classes, WinApi.Messages, WinApi.DDEml;

Type
  TDelphiDDEManager = Class
  strict private
    _ddeid: Integer;
    _service: String;
    _servicehandle: HSZ;
    _topic: String;
    _topichandle: HSZ;
    Procedure SetService(Const inService: String);
    Procedure SetTopic(Const inTopic: String);
    Function GetDDEInstances: TArray<HWND>;
    Function GlobalLockString(inString: string; inFlags: UINT): THandle;
  public
    Constructor Create; ReIntroduce;
    Destructor Destroy; Override;
    Procedure OpenFile(Const inFileName: String; Const inDDEServerHWND: HWND; Const inTimeOutInMs: Integer = 5000);
    Property DDEId: Integer Read _ddeid;
    Property DDEInstances: TArray<HWND> Read GetDDEInstances;
    Property Service: String Read _service Write SetService;
    Property ServiceHandle: HSZ Read _servicehandle;
    Property Topic: String Read _topic Write SetTopic;
    Property TopicHandle: HSZ Read _topichandle;
  End;

  TDelphiInstance = Class(TComponent)
  strict private
    _ddemgr: TDelphiDDEManager;
    _ddehwnd: HWND;
    _idehwnd: HWND;
    _idecaption: String;
    _pid: Cardinal;
  public
    Constructor Create(inOwner: TComponent; Const inDDEManager: TDelphiDDEManager; Const inPID: Cardinal; Const inDDEHWND: HWND); ReIntroduce;
    Procedure OpenFile(Const inFileName: String);
    Function FindIdeWindow: Boolean;
    Function IsIDEBusy: Boolean;
    Property IDECaption: String Read _idecaption;
    Property IDEHWND: HWND Read _idehwnd;
    Property PID: Cardinal Read _pid;
    Property DDEHWND: HWND Read _ddehwnd;
  End;

  TBorlandDelphiVersion = Class(TComponent)
  strict private
    _bdspath: String;
    _ddemgr: TDelphiDDEManager;
    _instances: TObjectList<TDelphiInstance>;
    _name: String;
    _versionnumber: Byte;
    Function GetInstances: TArray<TDelphiInstance>;
    Function ProcessName(Const inPID: Cardinal): String;
  strict protected
    Function GetDelphiName: String; Virtual;
  public
    Class Function BDSRoot: String; Virtual;
    Constructor Create(inOwner: TComponent; Const inDDEManager: TDelphiDDEManager; Const inBDSPath: String; Const inVersionNumber: Byte); ReIntroduce;
    Destructor Destroy; Override;
    Procedure RefreshInstances;
    Function InstanceByPID(Const inPID: Cardinal): TDelphiInstance;
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

  TDelphiVersions = Class(TComponent)
  strict private
    _ddemgr: TDelphiDDEManager;
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

Function UnpackDDElParam(msg: UINT; lParam: LPARAM; puiLo, puiHi: PUINT_PTR): BOOL; StdCall; External user32;
Function FreeDDElParam(msg: UINT; lParam: LPARAM): BOOL; StdCall; External user32;

Implementation

Uses System.Win.Registry, WinApi.PsAPI;

Type
  TWindowInfo = Record
    outHWND: HWND;
    outWindowCaption: String;
    PID: Cardinal;
  End;
  PWindowInfo = ^TWindowInfo;

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

  Result := (ppid <> PWindowInfo(inParam)^.PID) Or Not IsWindowVisible(inHWND) Or (Not IsWindowEnabled(inHWND)) Or Not
    (String(title).Contains('RAD Studio') Or String(title).Contains('Delphi')) Or (String(classname) <> 'TAppBuilder');

  If Not Result Then
  Begin
    PWindowInfo(inParam)^.outHWND := inHWND;
    PWindowInfo(inParam)^.outWindowCaption := title;
  End;
End;

//
// TDelphiDDEManager
// DDE logic by Attila Kovacs
// https://en.delphipraxis.net/topic/7955-how-to-open-a-file-in-the-already-running-ide/?do=findComment&comment=66850
//

Constructor TDelphiDDEManager.Create;
Begin
  inherited;

  _ddeid := 0;
  _service := '';
  _servicehandle := 0;
  _topic := '';
  _topichandle := 0;

  If DdeInitializeW(_ddeid, nil, APPCMD_CLIENTONLY, 0) <> DMLERR_NO_ERROR Then
    Raise EDelphiVersionException.Create('DDE initialization failed!');

  Self.Service := 'bds';
  Self.Topic := 'system';
End;

Destructor TDelphiDDEManager.Destroy;
Begin
  Self.Service := '';
  Self.Topic := '';

  If _ddeid <> 0 Then
  Begin
    DdeUninitialize(_ddeid);
    _ddeid := 0;
  End;

  inherited;
End;

Function TDelphiDDEManager.GetDDEInstances: TArray<HWND>;
Var
  convlist: HConvList;
  conv: HConv;
  convinfo: TConvInfo;
  res: Cardinal;
Begin
  SetLength(Result, 0);

  convlist := DdeConnectList(ddeid, _servicehandle, _topichandle, 0, nil);
  If convlist = 0 Then
  Begin
    res := DdeGetLastError(ddeid);

    // A DMLERR_NO_CONV_ESTABLISHED error means that there are no DDE servers currently running handling. In this case
    // exception should not be raised, it simply means no Delphi IDEs are running!
    If res = DMLERR_NO_CONV_ESTABLISHED Then
      Exit
    Else
      Raise EDelphiVersionException.Create('Retrieving the list of Delphi DDE servers failed, DDE error ' + res.ToString);
  End;

  Try
    conv := 0;
    Repeat
      conv := DdeQueryNextServer(convlist, conv);
      If conv = 0 Then
        Break;

      convinfo.cb := SizeOf(TConvInfo);
      If DdeQueryConvInfo(conv, QID_SYNC, @convinfo) = 0 Then
        Raise EDelphiVersionException.Create('Retrieving conversation information failed, DDE error ' + DdeGetLastError(ddeid).ToString);

      SetLength(Result, Length(Result) + 1);
      Result[High(Result)] := convinfo.hwndPartner;
    Until (conv = 0);
  Finally
    If Not DdeDisconnectList(convlist) Then
      Raise EDelphiVersionException.Create('Releasing the list of Delphi DDE servers failed, DDE error ' + DdeGetLastError(ddeid).ToString);
  End;
End;

Procedure TDelphiDDEManager.OpenFile(Const inFileName: String; Const inDDEServerHWND: HWND; Const inTimeOutInMs: Integer = 5000);
Var
  atomservice, atomtopic: Word;
  commandhandle: THandle;
  cmd: String;
  msg: TMsg;
  msghwnd: HWND;
  pLo, pHi: PUINT_PTR;
Begin
  msghwnd := AllocateHWnd(nil);
  Try
    atomservice := GlobalAddAtom(PChar(_service));
    Try
      atomtopic := GlobalAddAtom(PChar(_topic));
      Try
        SendMessage(inDDEServerHWND, WM_DDE_INITIATE, msghwnd, Makelong(atomservice, atomtopic));
      Finally
        GlobalDeleteAtom(atomtopic);
      End;
    Finally
      GlobalDeleteAtom(atomservice);
    End;

    // Make sure we deplete all messages arrived in response to WM_DDE_INITIATE in the message queue
    // before the next part
    While PeekMessage(msg, msghwnd, 0, 0, PM_REMOVE) Do
      Sleep(0); // Please, do not optimize me out :)

    cmd := '[open("' + inFileName + '")]';
    commandhandle := GlobalLockString(cmd, GMEM_DDESHARE);

    PostMessage(inDDEServerHWND, WM_DDE_EXECUTE, msghwnd, commandhandle);
    SetTimer(msghwnd, 1, inTimeOutInMs, nil);

    Repeat
      If PeekMessage(msg, msghwnd, 0, 0, PM_REMOVE) Then
        Case msg.message Of
          WM_TIMER:
          Begin
            GlobalUnlock(commandhandle);
            GlobalFree(commandhandle);

            Raise EDelphiVersionException.Create('Opening the file failed, DDE server did not acknowledge the request!');
          End;
          WM_DDE_ACK:
          Begin
            If UnpackDDElParam(msg.message, msg.lParam, @pLo, @pHi) Then
            Begin
              GlobalUnlock(pHi^);
              GlobalFree(pHi^);
              FreeDDElParam(msg.message, msg.lParam);

              PostMessage(msg.wParam, WM_DDE_TERMINATE, msghwnd, 0);
              PostMessage(msghwnd, WM_QUIT, 0, 0);

              Exit;
            End;
          End;
          Else
          Begin
            TranslateMessage(msg);
            DispatchMessage(msg);
          End;
        End;

      Sleep(100);
    Until False;
  Finally
   DeallocateHWnd(msghwnd);
  End;
End;

Procedure TDelphiDDEManager.SetService(Const inService: String);
Begin
  If inService = _service Then
    Exit;

  If _servicehandle <> 0 Then
  Begin
    DdeFreeStringHandle(_ddeid, _servicehandle);
    _servicehandle := 0;
  End;

  _service := inService;

  If inService.IsEmpty Then
    Exit;

  _servicehandle := DdeCreateStringHandleW(ddeid, PChar(_service), CP_WINUNICODE);
  If _servicehandle = 0 Then
    Raise EDelphiVersionException.Create('Creating service handle failed, DDE error ' + DdeGetLastError(ddeid).ToString);

  DdeKeepStringHandle(ddeid, _servicehandle);
End;

Procedure TDelphiDDEManager.SetTopic(Const inTopic: String);
Begin
  If inTopic = _topic Then
    Exit;

  If _topichandle <> 0 Then
  Begin
    DdeFreeStringHandle(_ddeid, _topichandle);
    _topichandle := 0;
  End;

  _topic := inTopic;

  If _topic.IsEmpty Then
    Exit;

  _topichandle := DdeCreateStringHandleW(ddeid, PChar(_topic), CP_WINUNICODE);
  If topichandle = 0 Then
    Raise EDelphiVersionException.Create('Creating topic handle failed, DDE error ' + DdeGetLastError(ddeid).ToString);

  DdeKeepStringHandle(ddeid, topichandle);
End;

Function TDelphiDDEManager.GlobalLockString(inString: String; inFlags: UINT): THandle;
Var
  DataPtr: Pointer;
Begin
  Result := GlobalAlloc(GMEM_ZEROINIT Or inFlags, (Length(inString) * SizeOf(Char)) + 1);
  Try
    DataPtr := GlobalLock(Result);
    Move(PChar(inString)^, DataPtr^, Length(inString) * SizeOf(Char));
  Except
    GlobalFree(Result);
    Raise;
  End;
End;

//
// TDelphiInstance
//

Constructor TDelphiInstance.Create(inOwner: TComponent; Const inDDEManager: TDelphiDDEManager; Const inPID: Cardinal; Const inDDEHWND: HWND);
Begin
  inherited Create(inOwner);

  _ddehwnd := inDDEHWND;
  _ddemgr := inDDEManager;
  _idehwnd := 0;
  _idecaption := '';
  _pid := inPID;

  FindIdeWindow;
End;

Procedure TDelphiInstance.OpenFile(Const inFileName: String);
Begin
  If Not IsWindow(_ddehwnd) Then
    Raise EDelphiVersionException.Create('DDE server gone away!');

  _ddemgr.OpenFile(inFileName, _ddehwnd);
End;

Function TDelphiInstance.FindIdeWindow: Boolean;
Var
  info: PWindowInfo;
Begin
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
  If (_idehwnd = 0) And Not FindIdeWindow Then
    Raise EDelphiVersionException.Create('Delphi IDE window is not found yet!');

  If Not IsWindow(_idehwnd) And Not FindIdeWindow Then
    Raise EDelphiVersionException.Create('Delphi IDE window gone away!');

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

Constructor TBorlandDelphiVersion.Create(inOwner: TComponent; Const inDDEManager: TDelphiDDEManager; Const inBDSPath: String; Const inVersionNumber: Byte);
Begin
  inherited Create(inOwner);

  _bdspath := inBDSPath;
  _ddemgr := inDDEManager;
  _instances := TObjectList<TDelphiInstance>.Create(True);
  _versionnumber := inVersionNumber;

  _name := GetDelphiName;
  If _name.IsEmpty Then
    _name := 'BDS ' + _versionnumber.ToString + '.0';

  RefreshInstances;
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
  a: Cardinal;
  h: HWND;
Begin
  _instances.Clear;

  For h In _ddemgr.DDEInstances Do
  Begin
    GetWindowThreadProcessId(h, a);
    If ProcessName(a).ToLower = _bdspath.ToLower Then
      _instances.Add(TDelphiInstance.Create(Self, _ddemgr, a, h));
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
        _latestversion := inDelphiVersionClass.Create(Self, _ddemgr, reg.ReadString('App'), Byte.Parse(s.Substring(0, s.IndexOf('.'))));

        _versions.Add(_latestversion);
      Finally
        reg.CloseKey;
      End;
    End;
  End;

Begin
  inherited;

  _ddemgr := TDelphiDDEManager.Create;
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
  FreeAndNil(_ddemgr);

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
