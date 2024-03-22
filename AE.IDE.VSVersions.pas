{
  AE Framework © 2022 by Akos Eigler is licensed under CC BY 4.0.
  To view a copy of this license, visit http://creativecommons.org/licenses/by/4.0/

  This license requires that reusers give credit to the creator. It allows reusers to distribute, remix, adapt,
  and build upon the material in any medium or format, even for commercial purposes.
}

Unit AE.IDE.VSVersions;

Interface

Uses AE.IDE.Versions, System.Classes, AE.DDEManager;

Type
  TAEVSDDEManager = Class(TAEDDEManager)
  public
    Constructor Create(Const inVersion: Integer; Const inDiscoveryTimeout: Cardinal); ReIntroduce;
  End;

  TAEVSInstance = Class(TAEIDEInstance)
  strict private
    _versionnumber: Integer;
  strict protected
    Procedure InternalFindIDEWindow; Override;
    Procedure InternalOpenFile(Const inFileName: String; Const inTimeOutInMs: Cardinal = 5000); Override;
  public
    Constructor Create(inOwner: TComponent; Const inPID: Cardinal; Const inVersionNumber: Integer); ReIntroduce;
  End;

  TAEVSVersion = Class(TAEIDEVersion)
  strict private
    _ddediscoverytimeout: Cardinal;
    Procedure SetDDEDiscoveryTimeout(Const inDDEDiscoveryTimeout: Cardinal);
  strict protected
    Function InternalGetName: String; Override;
    Procedure InternalRefreshInstances; Override;
  public
    Constructor Create(inOwner: TComponent; Const inExecutablePath: String; Const inVersionNumber: Integer; Const inDDEDiscoveryTimeout: Cardinal); ReIntroduce;
    Property DDEDiscoveryTimeout: Cardinal Read _ddediscoverytimeout Write SetDDEDiscoveryTimeout;
  End;

  TAEVSVersions = Class(TAEIDEVersions)
  strict private
    _ddediscoverytimeout: Cardinal;
    _vswhere: String;
    Procedure AddFromRegistry;
    Procedure AddFromVSWhere;
    Procedure AddFromWMI;
    Procedure SetDDEDiscoveryTimeout(Const inDDEDiscoveryTimeout: Cardinal);
    Procedure SetVSWhere(Const inVSWhereLocation: String);
    Function GetDOSOutput(Const inCommandLine: String): String;
  strict protected
    Procedure InternalRefreshInstalledVersions; Override;
  public
    Constructor Create(inOwner: TComponent); Override;
    Property DDEDiscoveryTimeout: Cardinal Read _ddediscoverytimeout Write SetDDEDiscoveryTimeout;
    Property VSWhereExeLocation: String Read _vswhere Write SetVSWhere;
  End;

Implementation

Uses Win.Registry, System.SysUtils, WinApi.Windows, System.JSON, AE.IDE.Versions.Consts, WinApi.ActiveX, System.Win.ComObj, System.Variants;

Type
  PTOKEN_USER = ^TOKEN_USER;

Function FindVSWindow(inHWND: HWND; inParam: LParam): Boolean; StdCall;
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
    Not String(title).Contains('Microsoft Visual Studio') Or Not String(classname).StartsWith('HwndWrapper[DefaultDomain;;');

  If Not Result Then
  Begin
    PAEIDEInfo(inParam)^.outHWND := inHWND;
    PAEIDEInfo(inParam)^.outWindowCaption := title;
  End;
End;

//
// TAEVSDDEManager
//

Constructor TAEVSDDEManager.Create(const inVersion: Integer; Const inDiscoveryTimeout: Cardinal);
Begin
 inherited Create('VisualStudio.' + inVersion.ToString + '.0', 'system', False, inDiscoveryTimeout);
End;

//
// TAEVSInstance
//

Constructor TAEVSInstance.Create(inOwner: TComponent; Const inPID: Cardinal; Const inVersionNumber: Integer);
Begin
  inherited Create(inOwner, inPID);;

  _versionnumber := inVersionNumber;
End;

Procedure TAEVSInstance.InternalFindIDEWindow;
Var
  info: PAEIDEInfo;
Begin
  inherited;

  New(info);
  Try
    info^.PID := Self.PID;
    info^.outHWND := 0;
    info^.outWindowCaption := '';

    EnumWindows(@FindVSWindow, LParam(info));

    SetIDEHWND(info^.outHWND);
    SetIDECaption(info^.outWindowCaption);
  Finally
    Dispose(info);
  End;
End;

Procedure TAEVSInstance.InternalOpenFile(Const inFileName: String; Const inTimeOutInMs: Cardinal);
Var
  ddemgr: TAEVSDDEManager;
Begin
  inherited;

  ddemgr := TAEVSDDEManager.Create(_versionnumber, (Self.Owner As TAEVSVersion).DDEDiscoveryTimeout);
  Try
    While Not ddemgr.ServerFound(Self.PID) Do
    Begin
      If Self.InternalAbortOpenFile Then
        Exit;

      Sleep(1000);
      ddemgr.RefreshServers;
    End;

    ddemgr.ExecuteCommand('[Open("' + inFileName + '")]', Self.PID, inTimeOutInMs);
  Finally
    FreeAndNil(ddemgr);
  End;
End;

//
// TAEVSVersion
//

Constructor TAEVSVersion.Create(inOwner: TComponent; Const inExecutablePath: String; Const inVersionNumber: Integer; Const inDDEDiscoveryTimeout: Cardinal);
Begin
  inherited Create(inOwner, inExecutablePath, inVersionNumber);

  _ddediscoverytimeout := inDDEDiscoveryTimeout;
End;

Function TAEVSVersion.InternalGetName: String;
Begin
  Case Round(Self.VersionNumber) Of
    8:
      Result := IDEVER_VS2005;
    9:
      Result := IDEVER_VS2008;
    10:
      Result := IDEVER_VS2010;
    11:
      Result := IDEVER_VS2012;
    12:
      Result := IDEVER_VS2013;
    14:
      Result := IDEVER_VS2015;
    15:
      Result := IDEVER_VS2017;
    16:
      Result := IDEVER_VS2019;
    17:
      Result := IDEVER_VS2022;
    Else
      Result := 'Microsoft Visual Studio v' + Self.VersionNumber.ToString;
  End;
End;

Procedure TAEVSVersion.InternalRefreshInstances;
Var
  ddemgr: TAEVSDDEManager;
  pid: Cardinal;
Begin
  ddemgr := TAEVSDDEManager.Create(Self.VersionNumber, _ddediscoverytimeout);
  Try
    For pid In ddemgr.DDEServerPIDs Do
      If ProcessName(pid).ToLower = Self.ExecutablePath.ToLower Then
        Self.AddInstance(TAEVSInstance.Create(Self, pid, Self.VersionNumber));
  Finally
    FreeAndNil(ddemgr);
  End;
End;

Procedure TAEVSVersion.SetDDEDiscoveryTimeout(Const inDDEDiscoveryTimeout: Cardinal);
Begin
  If inDDEDiscoveryTimeout = _ddediscoverytimeout Then
    Exit;

  _ddediscoverytimeout := inDDEDiscoveryTimeout;

  Self.RefreshInstances;
End;

//
// TAEVSVersions
//

Procedure TAEVSVersions.AddFromRegistry;
Var
  reg: TRegistry;
  sl: TStringList;
  s, loc: String;
Begin
  sl := TStringList.Create;
  Try
    reg := TRegistry.Create(KEY_READ Or KEY_WOW64_64KEY);
    Try
      reg.RootKey := HKEY_LOCAL_MACHINE;

      If Not reg.OpenKey('SOFTWARE\WOW6432Node\Microsoft\VisualStudio\SxS\VS7', False) And
         Not reg.OpenKey('SOFTWARE\Microsoft\VisualStudio\SxS\VS7', False) Then
        Exit;

      Try
        reg.GetValueNames(sl);

        For s In sl Do
        Begin
          loc := IncludeTrailingPathDelimiter(reg.ReadString(s)) + 'Common7\IDE\devenv.exe';
          If FileExists(loc) Then
            Self.AddVersion(TAEVSVersion.Create(Self, loc, Integer.Parse(s.Substring(0, s.IndexOf('.'))), _ddediscoverytimeout));
        End;
      Finally
        reg.CloseKey;
      End;
    Finally
      FreeAndNil(reg);
    End;
  Finally
    FreeAndNil(sl);
  End;
End;

Procedure TAEVSVersions.AddFromVSWhere;
Var
 json: TJSONArray;
 ver, loc: String;
 jv: TJSONValue;
 jo: TJSONObject;
Begin
  {$IF CompilerVersion > 32} // Everything above 10.2...?
  json := TJSONArray(TJSONObject.ParseJSONValue(GetDOSOutput(_vswhere + ' -format json -legacy'), True, True));
  {$ELSE}
  json := TJSONArray(TJSONObject.ParseJSONValue(GetDOSOutput(_vswhere + ' -format json -legacy'), True));
  If Not Assigned(json) Then
    Raise EJSONException.Create('VSWhere.exe did not return a valid JSON document!');
  {$ENDIF}

  Try
    For jv In json Do
    Begin
      jo := TJSONObject(jv);

      ver := jo.GetValue('installationVersion').Value;
      loc := jo.GetValue('productPath').Value;

      Self.AddVersion(TAEVSVersion.Create(Self, loc, Integer.Parse(ver.Substring(0, ver.IndexOf('.'))), _ddediscoverytimeout));
    End;
  Finally
    FreeAndNil(json);
  End;
End;

Procedure TAEVSVersions.AddFromWMI;
Var
  needuninit: Boolean;
  wbemlocator, wmiservice, objectset, wbemobject: OLEVariant;
  enum: IEnumvariant;
  value: LongWord;
  ver: String;
Begin
  Case CoInitializeEx(nil, COINIT_MULTITHREADED) Of
    S_OK:
      needuninit := True;
    S_FALSE:
      needuninit := True;
    Else
      needuninit := False;
  End;

  Try
    Try
      wbemlocator := CreateOleObject('WbemScripting.SWbemLocator');
      Try
        wmiservice := wbemlocator.ConnectServer('', 'root\cimv2', '', '');
        Try
          objectset := wmiservice.ExecQuery('SELECT ProductLocation, Version from MSFT_VSInstance', 'WQL', 32);
          Try
            enum := IUnknown(objectset._NewEnum) As IEnumVariant;
            Try
              While enum.Next(1, wbemobject, value) = 0 Do
              Try
                If (wbemobject.ProductLocation <> null) And FileExists(wbemobject.ProductLocation) And (wbemobject.Version <> null) Then
                Begin
                  ver := wbemobject.Version;

                  Self.AddVersion(TAEVSVersion.Create(Self, wbemobject.ProductLocation, Integer.Parse(ver.Substring(0, ver.IndexOf('.'))), _ddediscoverytimeout));
                End;
              Finally
                VarClear(wbemobject);
              End;
            Finally
              enum := nil;
            End;
          Finally
            VarClear(objectset);
          End;
        Finally
          VarClear(wmiservice);
        End;
      Finally
        VarClear(wbemlocator);
      End;
    Except
      On E:EOleException Do
      Begin
        // Swallowing exceptions is generally a bad idea. However, if the WMI provider is not installed an exception is thrown by the
        // WMI service. For us though, that doesn't mean an actual error; it's simply not supported.
      End
      Else
        Raise;
    End;
  Finally
    If needuninit Then
      CoUnInitialize;
  End;
End;

Constructor TAEVSVersions.Create(inOwner: TComponent);
Begin
  inherited;

  _ddediscoverytimeout := 1;
  _vswhere := '';
End;

Function TAEVSVersions.GetDOSOutput(Const inCommandLine: String): String;
Const
  LOGON_WITH_PROFILE = $00000001;
Var
  secattrib: TSecurityAttributes;
  startinfo: TStartupInfo;
  procinfo: TProcessInformation;
  piperead, pipewrite: THandle;
  buf: Array[0..1023] Of AnsiChar;
  a: Cardinal;
Begin
  Result := '';

  FillChar(secattrib, SizeOf(secattrib), 0);
  secattrib.nLength := SizeOf(secattrib);
  secattrib.bInheritHandle := True;
  secattrib.lpSecurityDescriptor := nil;
  CreatePipe(piperead, pipewrite, @secattrib, 0);
  Try
    FillChar(startinfo, SizeOf(startinfo), 0);
    startinfo.cb := SizeOf(startinfo);
    startinfo.dwFlags := STARTF_USESHOWWINDOW Or STARTF_USESTDHANDLES;
    startinfo.wShowWindow := SW_HIDE;
    startinfo.hStdInput := GetStdHandle(STD_INPUT_HANDLE); // don't redirect stdin
    startinfo.hStdOutput := pipewrite;
    startinfo.hStdError := pipewrite;

    Try
      If Not CreateProcess(nil, PChar(inCommandLine), nil, nil, True, CREATE_NEW_PROCESS_GROUP Or CREATE_NEW_CONSOLE, nil, nil, startinfo, procinfo) Then
        RaiseLastOSError;
    Finally
      // If this is not here, ReadFile might hang until infinity
      CloseHandle(pipewrite);
    End;

    Try
      Repeat
        If Not ReadFile(piperead, buf, Length(buf) - 1, a, nil) Then
        Begin
          a := GetLastError;

          // ERROR_BROKEN_PIPE means the process terminated and the pipe was closed
          If a = ERROR_BROKEN_PIPE Then
            Break;

          RaiseLastOSError(a);
        End;

        If a > 0 Then
        Begin
          buf[a] := #0;
          Result := Result + String(buf);
        End;
      Until (a = 0);

      Result := Result.Trim;
    Finally
      CloseHandle(procinfo.hThread);
      CloseHandle(procinfo.hProcess);
    End;
  Finally
    CloseHandle(piperead);
  End;
End;

Procedure TAEVSVersions.InternalRefreshInstalledVersions;
Begin
  inherited;

  If Not _vswhere.IsEmpty Then
    Self.AddFromVSWhere;

  If Length(Self.InstalledVersions) = 0 Then
    Self.AddFromWMI;

  If Length(Self.InstalledVersions) = 0 Then
    Self.AddFromRegistry;
End;

Procedure TAEVSVersions.SetDDEDiscoveryTimeout(Const inDDEDiscoveryTimeout: Cardinal);
Var
  ver: TAEIDEVersion;
Begin
  If inDDEDiscoveryTimeout = _ddediscoverytimeout Then
    Exit;

  _ddediscoverytimeout := inDDEDiscoveryTimeout;

  For ver In Self.InstalledVersions Do
    (ver As TAEVSVersion).DDEDiscoveryTimeout := inDDEDiscoveryTimeout;
End;

Procedure TAEVSVersions.SetVSWhere(const inVSWhereLocation: String);
Begin
  If _vswhere = inVSWhereLocation Then
    Exit;

  _vswhere := inVSWhereLocation;

  Self.RefreshInstalledVersions;
End;

End.
