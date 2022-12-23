Unit AE.DDEManager;

Interface

Uses WinAPI.Messages, WinAPI.Windows, System.Generics.Collections, System.SysUtils;

Type
  TAEDDEManager = Class
  strict private
    _servers: TObjectDictionary<Cardinal, TList<HWND>>;
    _service: String;
    _topic: String;
    Procedure DiscoveryHandler(Var inMessage: TMessage);
    Procedure InternalExecuteCommand(Const inCommand: String; Const inWindowHandle: HWND; Const inTimeOutInMs: Cardinal = 5000);
    Procedure Purge;
    Procedure CheckPID(Const inPID: Cardinal);
    Function GetDDEServerPIDs: TArray<Cardinal>;
    Function GetDDEServerWindows(Const inPID: Cardinal): TArray<HWND>;
    Function GlobalLockString(Const inValue: String; Const inFlags: Cardinal): THandle;
  public
    Constructor Create(Const inService, inTopic: String); ReIntroduce;
    Destructor Destroy; Override;
    Procedure ExecuteCommand(Const inCommand: String; Const inPID: Cardinal; Const inTimeOutInMs: Cardinal = 5000);
    Procedure RefreshServers;
    Function ServerFound(Const inPID: Cardinal): Boolean;
    Property DDEServerPIDs: TArray<Cardinal> Read GetDDEServerPIDs;
    Property DDEServerWindows[Const inPID: Cardinal]: TArray<HWND> Read GetDDEServerWindows;
  End;

  EAEDDEManagerException = Class(Exception);

Function UnpackDDElParam(msg: UINT; lParam: LPARAM; puiLo, puiHi: PUINT_PTR): BOOL; StdCall; External user32;
Function FreeDDElParam(msg: UINT; lParam: LPARAM): BOOL; StdCall; External user32;

Implementation

Uses System.Classes;

Const
  POSTED_DDE_ACK = WM_USER + 663;

Procedure TAEDDEManager.CheckPID(Const inPID: Cardinal);
Begin
  If Not _servers.ContainsKey(inPID) Then
    Raise EAEDDEManagerException.Create('Process with PID ' + inPID.ToString + ' was not detected as a valid DDE target for service ' + _service + ', topic ' + _topic + '!');
End;

Constructor TAEDDEManager.Create(Const inService, inTopic: String);
Begin
  inherited Create;

  _servers := TObjectDictionary<Cardinal, TList<HWND>>.Create([doOwnsValues]);
  _service := inService;
  _topic := inTopic;

  Self.RefreshServers;
End;

Destructor TAEDDEManager.Destroy;
Begin
  FreeAndNil(_servers);

  inherited;
End;

Procedure TAEDDEManager.DiscoveryHandler(Var inMessage: TMessage);
Var
  whandle: HWND;
  pid: Cardinal;
Begin
  If inMessage.Msg <> WM_DDE_ACK Then
    Exit;

  whandle := inMessage.WParam;
  GetWindowThreadProcessId(whandle, pid);

  If Not _servers.ContainsKey(pid) Then
    _servers.Add(pid, TList<HWND>.Create);

  If Not _servers[pid].Contains(whandle) Then
    _servers[pid].Add(whandle);
End;

Procedure TAEDDEManager.ExecuteCommand(Const inCommand: String; Const inPID: Cardinal; Const inTimeOutInMs: Cardinal = 5000);
Var
  hw: HWND;
Begin
  CheckPID(inPID);

  Self.Purge;

  If Not _servers.ContainsKey(inPID) Then
    Raise EAEDDEManagerException.Create('Process with PID ' + inPID.ToString + ' has gone away as a valid DDE target for service ' + _service + ', topic ' + _topic + '!');

  For hw In _servers[inPID] Do
    InternalExecuteCommand(inCommand, hw, inTimeOutInMs);
End;

Function TAEDDEManager.GetDDEServerPIDs: TArray<Cardinal>;
Begin
  Self.Purge;

  Result := _servers.Keys.ToArray;
End;

Function TAEDDEManager.GetDDEServerWindows(Const inPID: Cardinal): TArray<HWND>;
Begin
  CheckPID(inPID);

  Result := _servers[inPID].ToArray;
End;

Function TAEDDEManager.GlobalLockString(Const inValue: String; Const inFlags: Cardinal): THandle;
Var
  p: Pointer;
Begin
  Result := GlobalAlloc(GMEM_ZEROINIT Or inFlags, (Length(inValue) * SizeOf(Char)) + 1);

  Try
    p := GlobalLock(Result);
    Move(PChar(inValue)^, p^, Length(inValue) * SizeOf(Char));
  Except
    GlobalFree(Result);
    Raise;
  End;
End;

Procedure TAEDDEManager.InternalExecuteCommand(Const inCommand: String; Const inWindowHandle: HWND; Const inTimeOutInMs: Cardinal);
Var
  serviceatom, topicatom: Word;
  commandhandle: THandle;
  msg: TMsg;
  wait: Cardinal;
  pLo, pHi: UIntPtr;
  exechwnd: HWND;
Begin
  commandhandle := GlobalLockString(inCommand, GMEM_DDESHARE);

  exechwnd := AllocateHWnd(nil);
  Try
    serviceatom := GlobalAddAtom(PChar(_service));

    If serviceatom = 0 Then
      RaiseLastOSError;

    Try
      topicatom := GlobalAddAtom(PChar(_topic));

      If topicatom = 0 Then
        RaiseLastOSError;

      Try
        SendMessage(inWindowHandle, WM_DDE_INITIATE, exechwnd, Makelong(serviceatom, topicatom));
      Finally
        GlobalDeleteAtom(topicatom);
      End;
    Finally
      GlobalDeleteAtom(serviceatom);
    End;

    PostMessage(inWindowHandle, WM_DDE_EXECUTE, exechwnd, commandhandle);

    wait := 0;
    Repeat
      If PeekMessage(msg, exechwnd, 0, 0, PM_REMOVE) Then
      Begin
        If msg.message = WM_DDE_ACK Then
        Begin
          If UnpackDDElParam(msg.Message, msg.lParam, @pLo, @pHi) Then
          Begin
            GlobalUnlock(pHi);
            GlobalFree(pHi);
            FreeDDElParam(msg.Message, msg.lParam);

            PostMessage(msg.wParam, WM_DDE_TERMINATE, exechwnd, 0);
          End;

          Exit;
        End;

        TranslateMessage(msg);
        DispatchMessage(msg);
      End;

      Sleep(200);
      Inc(wait, 200);
    Until wait >= inTimeOutInMs;

    // Request timed out, need to free up our resource
    GlobalFree(commandhandle);
    Raise EAEDDEManagerException.Create('Executing DDE command against process timed out!');

  Finally
    DeallocateHWnd(exechwnd);
  End;
End;

Procedure TAEDDEManager.Purge;
Var
  pid: Cardinal;
  hw: HWND;
Begin
  // Throw out all DDE servers where the DDE window is already closed
  For pid In _servers.Keys.ToArray Do
  Begin
    For hw In _servers[pid].ToArray Do
      If Not IsWindow(hw) Then
        _servers[pid].Remove(hw);

    If _servers[pid].Count = 0 Then
      _servers.Remove(pid);
  End;
End;

Procedure TAEDDEManager.RefreshServers;
Var
  serviceatom, topicatom: Word;
  msg: TMsg;
  res: DWord;
  discoverer: HWND;
Begin
  _servers.Clear;

  discoverer := AllocateHWnd(DiscoveryHandler);
  Try
    serviceatom := GlobalAddAtom(PChar(_service));

    If serviceatom = 0 Then
      RaiseLastOSError;

    Try
      topicatom := GlobalAddAtom(PChar(_topic));

      If topicatom = 0 Then
        RaiseLastOSError;

      Try
        SendMessageTimeout(HWND_BROADCAST, WM_DDE_INITIATE, discoverer, Makelong(serviceatom, topicatom), SMTO_BLOCK, 1, @res);

        While PeekMessage(msg, discoverer, 0, 0, PM_REMOVE) Do
        Begin
          TranslateMessage(msg);
          DispatchMessage(msg);
        End;
      Finally
        GlobalDeleteAtom(topicatom);
      End;
    Finally
      GlobalDeleteAtom(serviceatom);
    End;
  Finally
    DeallocateHWnd(discoverer);
  End;
End;

Function TAEDDEManager.ServerFound(Const inPID: Cardinal): Boolean;
Begin
  Result := _servers.ContainsKey(inPID);
End;

End.
