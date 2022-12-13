Unit AE.IDE.VSVersions;

Interface

Uses AE.IDE.Versions, System.Classes;

Type
  TVSInstance = Class(TIDEInstance)
  strict protected
    Procedure InternalFindIDEWindow; Override;
  End;

  TVSVersion = Class(TIDEVersion)
  strict private
    Function GetUserAndDomainFromPID(inPID: Cardinal; Var outUser, outDomain: String): Boolean;
    Function ProcessBelongsToUser(Const inPID: Cardinal; Const inUser: String): Boolean;
  strict protected
    Function InternalGetName: String; Override;
    Procedure InternalRefreshInstances; Override;
  End;

  TVSVersions = Class(TIDEVersions)
  strict private
    _vswhere: String;
    Procedure AddFromRegistry;
    Procedure AddFromVSWhere;
    Function GetDOSOutput(Const inCommandLine: String): String;
  strict protected
    Procedure InternalRefreshInstalledVersions; Override;
  public
    Constructor Create(inOwner: TComponent; Const inVSWhereExeLocation: String); ReIntroduce;
  End;

Implementation

Uses Win.Registry, System.SysUtils, WinApi.Windows, System.JSON, WinApi.TlHelp32;

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

  Result := (ppid <> PIDEInfo(inParam)^.PID) Or Not IsWindowVisible(inHWND) Or Not IsWindowEnabled(inHWND) Or
    Not String(title).Contains('Microsoft Visual Studio') Or Not String(classname).StartsWith('HwndWrapper[DefaultDomain;;');

  If Not Result Then
  Begin
    PIDEInfo(inParam)^.outHWND := inHWND;
    PIDEInfo(inParam)^.outWindowCaption := title;
  End;
End;

//
// TVSInstance
//

Procedure TVSInstance.InternalFindIDEWindow;
Var
  info: PIDEInfo;
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

//
// TVSVersion
//

Function TVSVersion.InternalGetName: String;
Var
  ver: Double;
Begin
  ver := Self.VersionNumber / 100;

  Case Round(ver) Of
    8:
      Result := 'Microsoft Visual Studio 2005';
    9:
      Result := 'Microsoft Visual Studio 2008';
    10:
      Result := 'Microsoft Visual Studio 2010';
    11:
      Result := 'Microsoft Visual Studio 2012';
    12:
      Result := 'Microsoft Visual Studio 2013';
    14:
      Result := 'Microsoft Visual Studio 2015';
    15:
      Result := 'Microsoft Visual Studio 2017';
    16:
      Result := 'Microsoft Visual Studio 2019';
    17:
      Result := 'Microsoft Visual Studio 2022';
    Else
      Result := 'Microsoft Visual Studio v' + FormatFloat('0.0', ver);
  End;
End;

Function TVSVersion.GetUserAndDomainFromPID(inPID: Cardinal; Var outUser, outDomain: String): Boolean;
Var
  phandle, tokenhandle: THandle;
  len: Cardinal;
  usertoken: PTOKEN_USER;
  snu: SID_NAME_USE;
  userlen, domainlen: DWORD;
Begin
  Result := False;

  phandle := OpenProcess(PROCESS_QUERY_INFORMATION, False, inPID);

  If phandle = 0 Then
    Exit;

//  EnableProcessPrivilege(ProcessHandle, 'SeSecurityPrivilege', True);
  Try
    If Not OpenProcessToken(phandle, TOKEN_QUERY, tokenhandle) Then
      Exit;

    Try
      Result := GetTokenInformation(tokenhandle, TokenUser, nil, 0, len);
      usertoken  := nil;

      While Not Result And (GetLastError = ERROR_INSUFFICIENT_BUFFER) Do
      Begin
        ReallocMem(usertoken, len);
        Result := GetTokenInformation(tokenhandle, TokenUser, usertoken, len, len);
      End;
    Finally
      CloseHandle(tokenhandle);
    End;

    If Not Result Then
      Exit;

    Try
      userlen := 0;
      domainlen := 0;
      LookupAccountSid(nil, usertoken.User.Sid, nil, userlen, nil, domainlen, snu);

      If (userlen = 0) Or (domainlen = 0) Then
        Exit;

      SetLength(outUser, userlen);
      SetLength(outDomain, domainlen);

      If Not LookupAccountSid(nil, usertoken.User.Sid, PChar(outUser), userlen, PChar(outDomain), domainlen, snu) Then
        Exit;

      outUser := StrPas(PChar(outUser));
      outDomain := StrPas(PChar(outDomain));

      Result := True;
    Finally
     FreeMem(usertoken);
    End;
  Finally
    CloseHandle(phandle);
  End;
End;

Function TVSVersion.ProcessBelongsToUser(Const inPID: Cardinal; Const inUser: String): Boolean;
Var
  domain, user: String;
Begin
  Result := GetUserAndDomainFromPID(inPid, user, domain) And (user.ToLower = inUser.ToLower);
End;

Procedure TVSVersion.InternalRefreshInstances;
Var
  len: DWord;
  user, exe, exename: String;
  success: Boolean;
  psnapshot: THandle;
  pe: TProcessEntry32;
Begin
  exe := Self.ExecutablePath.ToLower;
  exename := ExtractFileName(exe);

  len := 256;
  SetLength(user, len);
  If Not GetUserName(PChar(user), len) Then
    RaiseLastOSError;

  SetLength(user, len - 1);
  user := user.ToLower;

  psnapshot := CreateToolhelp32Snapshot(TH32CS_SNAPALL, 0);
  Try
    pe.dwSize := SizeOf(pe);
    success := Process32First(psnapshot, pe);

    While success Do
    Begin
      If (String(pe.szExeFile).ToLower = exename) And (ProcessName(pe.th32ProcessID).ToLower = exe) And ProcessBelongsToUser(pe.th32ProcessID, user) Then
        Self.AddInstance(TVSInstance.Create(Self, pe.th32ProcessID));

      success := Process32Next(psnapshot, pe);
    End;
  Finally
    CloseHandle(psnapshot);
  End;
End;

//
// TVSVersions
//

Procedure TVSVersions.AddFromRegistry;
Var
  reg: TRegistry;
  sl: TStringList;
  s: String;
Begin
  sl := TStringList.Create;
  Try
    reg := TRegistry.Create(KEY_READ Or KEY_WOW64_64KEY);
    Try
      reg.RootKey := HKEY_LOCAL_MACHINE;

      If Not reg.OpenKey('SOFTWARE\WOW6432Node\Microsoft\VisualStudio\SxS\VS7', False) And
         Not reg.OpenKey('SOFTWARE\Microsoft\VisualStudio\SxS\VS7', False) Then Exit;

      Try
        reg.GetValueNames(sl);

        For s In sl Do
          Self.AddVersion(TVSVersion.Create(Self, reg.ReadString(s), Round(Double.Parse(s.Replace('.', FormatSettings.DecimalSeparator)) * 100)));
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

Procedure TVSVersions.AddFromVSWhere;
Var
 json: TJSONArray;
 ver, loc: String;
 jv: TJSONValue;
 jo: TJSONObject;
Begin
  json := TJSONArray(TJSONObject.ParseJSONValue(GetDOSOutput(_vswhere + ' -format json -legacy'), True, True));
  Try
    For jv In json Do
    Begin
      jo := TJSONObject(jv);

      ver := jo.GetValue('installationVersion').Value;
      loc := jo.GetValue('productPath').Value;

      While ver.CountChar('.') > 1 Do
        ver := ver.Substring(0, ver.LastIndexOf('.'));

      Self.AddVersion(TVSVersion.Create(Self, loc, Round(Double.Parse(ver.Replace('.', FormatSettings.DecimalSeparator)) * 100)));
    End;
  Finally
    FreeAndNil(json);
  End;
End;

Constructor TVSVersions.Create(inOwner: TComponent; Const inVSWhereExeLocation: String);
Begin
  inherited Create(inOwner);

  _vswhere := inVSWhereExeLocation;
End;

Function TVSVersions.GetDOSOutput(Const inCommandLine: String): String;
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

Procedure TVSVersions.InternalRefreshInstalledVersions;
Begin
  inherited;

  If _vswhere.IsEmpty Then
    Self.AddFromRegistry
  Else
    Self.AddFromVSWhere;
End;

End.
