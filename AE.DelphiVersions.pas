Unit AE.DelphiVersions;

Interface

Uses System.Generics.Collections, WinApi.Windows;

Type
  TDelphiVersion = Class
  strict private
    _bdspath: String;
    _name: String;
    _versionnumber: Integer;
    Function GlobalLockString(AValue: string; AFlags: UINT): THandle;
    Function ProcessName(Const inPID: Cardinal): String;
  public
    Constructor Create(Const inBDSPath: String; Const inVersionNumber: Integer); ReIntroduce;
    Procedure OpenFile(Const inFileName: String);
    Function IDEHandles: TArray<HWND>;
    Function IsRunning: Boolean;
    Property BDSPath: String Read _bdspath;
    Property Name: String Read _name;
    Property VersionNumber: Integer Read _versionnumber;
  End;

  TDelphiVersions = Class
  strict private
    _versions: TObjectList<TDelphiVersion>;
    Function GetInstalledVersions: TArray<TDelphiVersion>;
  public
    Constructor Create; ReIntroduce;
    Destructor Destroy; Override;
    Function ByName(Const inName: String): TDelphiVersion;
    Function ByVersionNumber(Const inVersionNumber: Integer): TDelphiVersion;
    Property InstalledVersions: TArray<TDelphiVersion> Read GetInstalledVersions;
  End;

Implementation

Uses System.Win.Registry, System.SysUtils, System.Classes, Vcl.DdeMan, WinApi.DDEml, WinApi.PsAPI;

Const
  BDSROOT = 'SOFTWARE\Embarcadero\BDS';
  DDESERVICE = 'bds';
  DDETOPIC = 'system';

//
// TDelphiVersion
//

Constructor TDelphiVersion.Create(Const inBDSPath: String; Const inVersionNumber: Integer);
Begin
  inherited Create;

  _bdspath := inBDSPath;
  _versionnumber := inVersionNumber;

  Case inVersionNumber Of
    17:
      _name := 'Delphi 10 Seattle';
    18:
      _name := 'Delphi 10.1 Berlin';
    19:
      _name := 'Delphi 10.2 Tokyo';
    20:
      _name := 'Delphi 10.3 Rio';
    21:
      _name := 'Delphi 10.4 Sydney';
    22:
      _name := 'Delphi 11 Alexandria';
  Else
    _name := 'BDS ' + inVersionNumber.ToString + '.0';
  End;
End;

Function TDelphiVersion.IDEHandles: TArray<HWND>;
Var
  lHszApp, lHszTopic: HSZ;
  ConvList: HConvList;
  Conv: HConv;
  ci: TConvInfo;
  pid: Cardinal;
Begin
  // DDE logic by Attila Kovacs
  // https://en.delphipraxis.net/topic/7955-how-to-open-a-file-in-the-already-running-ide/?do=findComment&comment=66850

  SetLength(Result, 0);

  lHszApp := DdeCreateStringHandleW(ddeMgr.DdeInstId, PChar(DDESERVICE), CP_WINUNICODE);
  lHszTopic := DdeCreateStringHandleW(ddeMgr.DdeInstId, PChar(DDETOPIC), CP_WINUNICODE);

  ConvList := DdeConnectList(ddeMgr.DdeInstId, lHszApp, lHszTopic, 0, nil);

  Conv := 0;
  Repeat
    Conv := DdeQueryNextServer(ConvList, Conv);
    If Conv = 0 Then
      Break;

    ci.cb := SizeOf(TConvInfo);
    DdeQueryConvInfo(Conv, QID_SYNC, @ci);

    GetWindowThreadProcessId(ci.hwndPartner, pid);
    If ProcessName(pid).ToLower = _bdspath.ToLower Then
    Begin
      SetLength(Result, Length(Result) + 1);
      Result[High(Result)] := ci.hwndPartner;
    End;
  Until (Conv = 0);
End;

Function TDelphiVersion.IsRunning: Boolean;
Begin
  Result := Length(Self.IDEHandles) > 0;
End;

Procedure TDelphiVersion.OpenFile(Const inFileName: String);
Var
  aService, aTopic: word;
  idehwnd: HWND;
  ddeCommandH: THandle;
  msghwnd: HWND;
  cmd: String;
Begin
  idehwnd := Self.IDEHandles[0];

  msghwnd := AllocateHwnd(nil);
  Try
    aService := GlobalAddAtom(PChar(DDESERVICE));
    aTopic := GlobalAddAtom(PChar(DDETOPIC));
    Try
      SendMessage(idehwnd, WM_DDE_INITIATE, msghwnd, Makelong(aService, aTopic));
    Finally
      GlobalDeleteAtom(aService);
      GlobalDeleteAtom(aTopic);
    End;

    cmd := '[open("' + inFileName + '")]';
    ddeCommandH := GlobalLockString(cmd, GMEM_DDESHARE);
    Try
      PostMessage(idehwnd, WM_DDE_EXECUTE, msghwnd, ddeCommandH);
    Finally
      GlobalUnlock(ddeCommandH);
      GlobalFree(ddeCommandH);
    End;
  Finally
    DeAllocateHwnd(msghwnd);
  End;
End;

Function TDelphiVersion.ProcessName(const inPID: Cardinal): String;
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

//
// TDelphiVersions
//

Constructor TDelphiVersions.Create;
Var
  reg: TRegistry;
  sl: TStringList;
  s: String;
Begin
  inherited;

  _versions := TObjectList<TDelphiVersion>.Create(True);

  sl := TStringList.Create;
  Try
    reg := TRegistry.Create;
    Try
      reg.RootKey := HKEY_CURRENT_USER;

      If Not reg.OpenKey(BDSROOT, False) Then
        Exit;

      Try
        reg.GetKeyNames(sl);
      Finally
        reg.CloseKey;
      End;

      For s In sl Do
      Begin
        If Not reg.OpenKey(BDSROOT + '\' + s, False) Then
          Continue;

        Try
          _versions.Add(TDelphiVersion.Create(reg.ReadString('App'),
            Integer.Parse(s.Substring(0, s.IndexOf('.')))));
        Finally
          reg.CloseKey;
        End;
      End;
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

Function TDelphiVersions.GetInstalledVersions: TArray<TDelphiVersion>;
Begin
  Result := _versions.ToArray;
End;

Function TDelphiVersions.ByName(Const inName: String): TDelphiVersion;
Begin
  For Result In _versions Do
    If Result.Name = inName Then
      Exit;

  Result := nil;
End;

Function TDelphiVersions.ByVersionNumber(Const inVersionNumber: Integer): TDelphiVersion;
Begin
  For Result In _versions Do
    If Result.VersionNumber = inVersionNumber Then
      Exit;

  Result := nil;
End;

Function TDelphiVersion.GlobalLockString(AValue: String; AFlags: UINT): THandle;
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

End.
