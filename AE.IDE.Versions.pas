{
  AE Framework © 2022 by Akos Eigler is licensed under CC BY 4.0.
  To view a copy of this license, visit http://creativecommons.org/licenses/by/4.0/

  This license requires that reusers give credit to the creator. It allows reusers to distribute, remix, adapt,
  and build upon the material in any medium or format, even for commercial purposes.
}

Unit AE.IDE.Versions;

Interface

Uses System.Classes, WinApi.Windows, System.SysUtils, System.Generics.Collections;

Type
  TAEIDEInstance = Class(TComponent)
  strict private
    _abortopenfile: Boolean;
    _idehwnd: HWND;
    _idecaption: String;
    _pid: Cardinal;
    Function GetName: String;
  strict protected
    Procedure InternalFindIDEWindow; Virtual;
    Procedure InternalOpenFile(Const inFileName: String; Const inTimeOutInMs: Cardinal = 5000); Virtual;
    Procedure SetIDECaption(Const inIDECaption: String);
    Procedure SetIDEHWND(Const inIDEHWND: HWND);
    Function InternalIsIDEBusy: Boolean; Virtual;
    Property InternalAbortOpenFile: Boolean Read _abortopenfile;
  public
    Constructor Create(inOwner: TComponent; Const inPID: Cardinal); ReIntroduce; Virtual;
    Procedure AbortOpenFile;
    Procedure OpenFile(Const inFileName: String; Const inTimeOutInMs: Cardinal = 5000);
    Procedure UpdateCaption;
    Function FindIdeWindow(Const inForceSearch: Boolean = False): Boolean;
    Function IsIDEBusy: Boolean;
    Property IDECaption: String Read _idecaption;
    Property IDEHWND: HWND Read _idehwnd;
    Property Name: String Read GetName;
    Property PID: Cardinal Read _pid;
  End;

  TAEIDEVersion = Class(TComponent)
  strict private
    _abortnewinstance: Boolean;
    _executablepath: String;
    _instances: TObjectList<TAEIDEInstance>;
    _name: String;
    _versionnumber: Integer;
    Function GetInstances: TArray<TAEIDEInstance>;
  strict protected
    Procedure AddInstance(Const inInstance: TAEIDEInstance);
    Procedure InternalRefreshInstances; Virtual;
    Function InternalGetName: String; Virtual;
    Function InternalNewIDEInstance(Const inParams: String): Cardinal; Virtual;
    Function ProcessName(Const inPID: Cardinal): String;
  public
    Constructor Create(inOwner: TComponent; Const inExecutablePath: String; Const inVersionNumber: Integer); ReIntroduce; Virtual;
    Destructor Destroy; Override;
    Procedure AbortNewInstance;
    Procedure AfterConstruction; Override;
    Procedure RefreshInstances;
    Function InstanceByPID(Const inPID: Cardinal): TAEIDEInstance;
    Function IsRunning: Boolean;
    Function NewIDEInstance(Const inParams: String = ''): TAEIDEInstance;
    Property ExecutablePath: String Read _executablepath;
    Property Instances: TArray<TAEIDEInstance> Read GetInstances;
    Property Name: String Read _name;
    Property VersionNumber: Integer Read _versionnumber;
  End;

  TAEIDEVersions = Class(TComponent)
  strict private
    _latestversion: TAEIDEVersion;
    _versions: TObjectList<TAEIDEVersion>;
    Function GetInstalledVersions: TArray<TAEIDEVersion>;
  strict protected
    Procedure AddVersion(Const inVersion: TAEIDEVersion);
    Procedure InternalRefreshInstalledVersions; Virtual;
  public
    Constructor Create(inOwner: TComponent); Override;
    Destructor Destroy; Override;
    Procedure AfterConstruction; Override;
    Procedure RefreshInstalledVersions;
    Function VersionByName(Const inName: String): TAEIDEVersion;
    Function VersionByVersionNumber(Const inVersionNumber: Integer): TAEIDEVersion;
    Property LatestVersion: TAEIDEVersion Read _latestversion;
    Property InstalledVersions: TArray<TAEIDEVersion> Read GetInstalledVersions;
  End;

  EAEIDEVersionException = Class(Exception);

  TAEIDEInfo = Record
    outHWND: HWND;
    outWindowCaption: String;
    PID: Cardinal;
  End;
  PAEIDEInfo = ^TAEIDEInfo;

Implementation

Uses WinApi.Messages, WinApi.PsAPI;

//
// TDelphiInstance
//

Procedure TAEIDEInstance.AbortOpenFile;
Begin
  _abortopenfile := True;
End;

Constructor TAEIDEInstance.Create(inOwner: TComponent; Const inPID: Cardinal);
Begin
  inherited Create(inOwner);

  _abortopenfile := False;
  _idehwnd := 0;
  _idecaption := '';
  _pid := inPID;

  FindIdeWindow;
End;

Function TAEIDEInstance.FindIdeWindow(const inForceSearch: Boolean): Boolean;
Begin
  If Not inForceSearch And (_idehwnd <> 0) And IsWindow(_idehwnd) Then
  Begin
    // IDE window was already found and seems to be still valid

    Result := True;
    Exit;
  End;

  _idehwnd := 0;
  _idecaption := '';

  Self.InternalFindIDEWindow;

  Result := _idehwnd <> 0;
End;

Function TAEIDEInstance.GetName: String;
Begin
  If _idecaption.IsEmpty Then
    Result := (Self.Owner As TAEIDEVersion).Name + ' (PID: ' + _pid.ToString + ')'
  Else
    Result := _idecaption + ' (PID: ' + _pid.ToString + ')';
End;

Procedure TAEIDEInstance.InternalFindIDEWindow;
Begin
  // Dummy
End;

Function TAEIDEInstance.InternalIsIDEBusy: Boolean;
Var
  res: NativeInt;
Begin
  If Not FindIdeWindow Then
    Raise EAEIDEVersionException.Create('Delphi IDE window can not be found!');

  Result := Not IsWindowVisible(_idehwnd);

  If Result Then
    Exit;

  Result := SendMessageTimeout(_idehwnd, WM_NULL, 0, 0, SMTO_BLOCK, 250, nil) = 0;

  If Not Result Then
    Exit;

  res := GetLastError;

  If res <> ERROR_TIMEOUT Then
    RaiseLastOSError(res);
End;

Procedure TAEIDEInstance.InternalOpenFile(Const inFileName: String; Const inTimeOutInMs: Cardinal);
Begin
  // Dummy
End;

Function TAEIDEInstance.IsIDEBusy: Boolean;
Begin
  Result := Self.InternalIsIDEBusy;
End;

Procedure TAEIDEInstance.OpenFile(Const inFileName: String; Const inTimeOutInMs: Cardinal);
Begin
  _abortopenfile := False;

  Self.InternalOpenFile(inFileName, inTimeOutInMs);
End;

Procedure TAEIDEInstance.SetIDECaption(Const inIDECaption: String);
Begin
  _idecaption := inIDECaption;
End;

Procedure TAEIDEInstance.SetIDEHWND(Const inIDEHWND: HWND);
Begin
  _idehwnd := inIDEHWND;
End;

Procedure TAEIDEInstance.UpdateCaption;
Var
  title: Array[0..255] Of Char;
Begin
  If Not FindIdeWindow Then
    Raise EAEIDEVersionException.Create('Delphi IDE window can not be found!');

  GetWindowText(_idehwnd, title, 255);

  _idecaption := title;
End;

//
// TIDEVersion
//

Procedure TAEIDEVersion.AbortNewInstance;
Begin
  _abortnewinstance := True;
End;

Procedure TAEIDEVersion.AddInstance(Const inInstance: TAEIDEInstance);
Begin
  _instances.Add(inInstance);
End;

Procedure TAEIDEVersion.AfterConstruction;
Begin
  inherited;

  _name := Self.InternalGetName;
  If _name.IsEmpty Then
    _name := 'IDE v' + _versionnumber.ToString;

  Self.RefreshInstances;
End;

Constructor TAEIDEVersion.Create(inOwner: TComponent; Const inExecutablePath: String; Const inVersionNumber: Integer);
Begin
  inherited Create(inOwner);

  _abortnewinstance := False;
  _executablepath := inExecutablePath.Trim;
  _instances := TObjectList<TAEIDEInstance>.Create(True);
  _name := '';
  _versionnumber := inVersionNumber;
End;

Destructor TAEIDEVersion.Destroy;
Begin
  FreeAndNil(_instances);

  inherited;
End;

Function TAEIDEVersion.GetInstances: TArray<TAEIDEInstance>;
Begin
  Result := _instances.ToArray;
End;

Function TAEIDEVersion.InstanceByPID(Const inPID: Cardinal): TAEIDEInstance;
Var
  inst: TAEIDEInstance;
Begin
  Result := nil;

  For inst In _instances Do
    If inst.PID = inPID Then
    Begin
      Result := inst;
      Break;
    End;
End;

Procedure TAEIDEVersion.InternalRefreshInstances;
Begin
  // Dummy
End;

Function TAEIDEVersion.InternalGetName: String;
Begin
  // Dummy

  Result := '';
End;

Function TAEIDEVersion.InternalNewIDEInstance(Const inParams: String): Cardinal;
Var
  startinfo: TStartupInfo;
  procinfo: TProcessInformation;
  cmd: String;
Begin
  FillChar(startinfo, SizeOf(TStartupInfo), #0);
  startinfo.cb := SizeOf(TStartupInfo);
  FillChar(procinfo, SizeOf(TProcessInformation), #0);

  cmd := Self.ExecutablePath;

  If Not cmd.StartsWith('"') Then
    cmd := '"' + cmd;

  If Not cmd.EndsWith('"') Then
    cmd := cmd + '"';

  If Not inParams.IsEmpty Then
    cmd := cmd + ' ' + inParams;

  If Not CreateProcess(nil, PChar(cmd), nil, nil, False, CREATE_NEW_PROCESS_GROUP, nil, nil, startinfo, procinfo) Then
    RaiseLastOSError;

  Try
    WaitForInputIdle(procinfo.hProcess, INFINITE);

    Result := procinfo.dwProcessId;
  Finally
    CloseHandle(procinfo.hThread);
    CloseHandle(procinfo.hProcess);
  End;
End;

Function TAEIDEVersion.IsRunning: Boolean;
Begin
  Result := _instances.Count > 0;
End;

Function TAEIDEVersion.NewIDEInstance(Const inParams: String = ''): TAEIDEInstance;
Var
  newpid: Cardinal;
Begin
  _abortnewinstance := False;

  newpid := Self.InternalNewIDEInstance(inParams);

  Result := nil;
  Repeat
    If _abortnewinstance Then
      Exit;

    Result := Self.InstanceByPID(newpid);

    If Not Assigned(Result) Then
    Begin
      Sleep(1000);

      Self.RefreshInstances;
    End;
  Until Assigned(Result) And Result.FindIdeWindow And Not Result.IsIDEBusy;
End;

Function TAEIDEVersion.ProcessName(Const inPID: Cardinal): String;
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

Procedure TAEIDEVersion.RefreshInstances;
Begin
  _instances.Clear;

  Self.InternalRefreshInstances;
End;

//
// TIDEVersions
//

Procedure TAEIDEVersions.AddVersion(Const inVersion: TAEIDEVersion);
Begin
  _versions.Add(inVersion);

  If Not Assigned(_latestversion) Or (inVersion.VersionNumber > _latestversion.VersionNumber) Then
    _latestversion := inVersion;
End;

Procedure TAEIDEVersions.AfterConstruction;
Begin
  inherited;

  Self.RefreshInstalledVersions;
End;

Constructor TAEIDEVersions.Create(inOwner: TComponent);
Begin
  inherited;

  _latestversion := nil;
  _versions := TObjectList<TAEIDEVersion>.Create(True);
End;

Destructor TAEIDEVersions.Destroy;
Begin
  FreeAndNil(_versions);

  inherited;
End;

Function TAEIDEVersions.GetInstalledVersions: TArray<TAEIDEVersion>;
Begin
  Result := _versions.ToArray;
End;

Procedure TAEIDEVersions.InternalRefreshInstalledVersions;
Begin
  // Dummy
End;

Procedure TAEIDEVersions.RefreshInstalledVersions;
begin
  _versions.Clear;

  Self.InternalRefreshInstalledVersions;
End;

Function TAEIDEVersions.VersionByName(Const inName: String): TAEIDEVersion;
Begin
  For Result In _versions Do
    If Result.Name = inName Then
      Exit;

  Result := nil;
End;

Function TAEIDEVersions.VersionByVersionNumber(Const inVersionNumber: Integer): TAEIDEVersion;
Begin
  For Result In _versions Do
    If Result.VersionNumber = inVersionNumber Then
      Exit;

  Result := nil;
End;

End.
