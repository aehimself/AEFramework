Unit AE.IDE.Versions;

Interface

Uses System.Classes, WinApi.Windows, System.SysUtils, System.Generics.Collections;

Type
  TIDEInstance = Class(TComponent)
  strict private
    _idehwnd: HWND;
    _idecaption: String;
    _pid: Cardinal;
  strict protected
    Procedure InternalFindIDEWindow; Virtual;
    Procedure SetIDECaption(Const inIDECaption: String);
    Procedure SetIDEHWND(Const inIDEHWND: HWND);
    Function InternalIsIDEBusy: Boolean; Virtual;
  public
    Constructor Create(inOwner: TComponent; Const inPID: Cardinal); ReIntroduce; Virtual;
    Procedure UpdateCaption;
    Function FindIdeWindow(Const inForceSearch: Boolean = False): Boolean;
    Function IsIDEBusy: Boolean;
    Property IDECaption: String Read _idecaption;
    Property IDEHWND: HWND Read _idehwnd;
    Property PID: Cardinal Read _pid;
  End;

  TIDEVersion = Class(TComponent)
  strict private
    _executablepath: String;
    _instances: TObjectList<TIDEInstance>;
    _name: String;
    _versionnumber: Integer;
    Function GetInstances: TArray<TIDEInstance>;
  strict protected
    Procedure AddInstance(Const inInstance: TIDEInstance);
    Procedure InternalRefreshInstances; Virtual;
    Function InternalGetName: String; Virtual;
    Function InternalNewIDEInstance: Cardinal; Virtual;
    Function ProcessName(Const inPID: Cardinal): String;
  public
    Constructor Create(inOwner: TComponent; Const inExecutablePath: String; Const inVersionNumber: Integer); ReIntroduce; Virtual;
    Destructor Destroy; Override;
    Procedure AfterConstruction; Override;
    Procedure RefreshInstances;
    Function InstanceByPID(Const inPID: Cardinal): TIDEInstance;
    Function IsRunning: Boolean;
    Function NewIDEInstance: TIDEInstance;
    Property ExecutablePath: String Read _executablepath;
    Property Instances: TArray<TIDEInstance> Read GetInstances;
    Property Name: String Read _name;
    Property VersionNumber: Integer Read _versionnumber;
  End;

  TIDEVersions = Class(TComponent)
  strict private
    _latestversion: TIDEVersion;
    _versions: TObjectList<TIDEVersion>;
    Function GetInstalledVersions: TArray<TIDEVersion>;
  strict protected
    Procedure AddVersion(Const inVersion: TIDEVersion);
    Procedure InternalRefreshInstalledVersions; Virtual;
  public
    Constructor Create(inOwner: TComponent); Override;
    Destructor Destroy; Override;
    Procedure AfterConstruction; Override;
    Procedure RefreshInstalledVersions;
    Function VersionByName(Const inName: String): TIDEVersion;
    Function VersionByVersionNumber(Const inVersionNumber: Integer): TIDEVersion;
    Property LatestVersion: TIDEVersion Read _latestversion;
    Property InstalledVersions: TArray<TIDEVersion> Read GetInstalledVersions;
  End;

  EAEIDEVersionException = Class(Exception);

Implementation

Uses WinApi.Messages, WinApi.PsAPI;

//
// TDelphiInstance
//

Constructor TIDEInstance.Create(inOwner: TComponent; Const inPID: Cardinal);
Begin
  inherited Create(inOwner);

  _idehwnd := 0;
  _idecaption := '';
  _pid := inPID;

  FindIdeWindow;
End;

Function TIDEInstance.FindIdeWindow(const inForceSearch: Boolean): Boolean;
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

Procedure TIDEInstance.InternalFindIDEWindow;
Begin
  // Dummy
End;

Function TIDEInstance.InternalIsIDEBusy: Boolean;
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

Function TIDEInstance.IsIDEBusy: Boolean;
Begin
  Result := Self.InternalIsIDEBusy;
End;

Procedure TIDEInstance.SetIDECaption(Const inIDECaption: String);
Begin
  _idecaption := inIDECaption;
End;

Procedure TIDEInstance.SetIDEHWND(Const inIDEHWND: HWND);
Begin
  _idehwnd := inIDEHWND;
End;

Procedure TIDEInstance.UpdateCaption;
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

Procedure TIDEVersion.AddInstance(Const inInstance: TIDEInstance);
Begin
  _instances.Add(inInstance);
End;

Procedure TIDEVersion.AfterConstruction;
Begin
  inherited;

  _name := Self.InternalGetName;
  If _name.IsEmpty Then
    _name := 'IDE v' + _versionnumber.ToString;

  Self.RefreshInstances;
End;

Constructor TIDEVersion.Create(inOwner: TComponent; Const inExecutablePath: String; Const inVersionNumber: Integer);
Begin
  inherited Create(inOwner);

  _executablepath := inExecutablePath;
  _instances := TObjectList<TIDEInstance>.Create(True);
  _name := '';
  _versionnumber := inVersionNumber;
End;

Destructor TIDEVersion.Destroy;
Begin
  FreeAndNil(_instances);

  inherited;
End;

Function TIDEVersion.GetInstances: TArray<TIDEInstance>;
Begin
  Result := _instances.ToArray;
End;

Function TIDEVersion.InstanceByPID(Const inPID: Cardinal): TIDEInstance;
Var
  inst: TIDEInstance;
Begin
  Result := nil;

  For inst In _instances Do
    If inst.PID = inPID Then
    Begin
      Result := inst;
      Break;
    End;
End;

Procedure TIDEVersion.InternalRefreshInstances;
Begin
  // Dummy
End;

Function TIDEVersion.InternalGetName: String;
Begin
  // Dummy

  Result := '';
End;

Function TIDEVersion.InternalNewIDEInstance: Cardinal;
Begin
  // Dummy

  Result := 0;
End;

Function TIDEVersion.IsRunning: Boolean;
Begin
  Result := _instances.Count > 0;
End;

Function TIDEVersion.NewIDEInstance: TIDEInstance;
Var
  newpid: Cardinal;
Begin
  newpid := Self.InternalNewIDEInstance;

  Result := nil;
  Repeat
    Sleep(1000);

    If Not Assigned(Result) Then
    Begin
      Self.RefreshInstances;

      Result := Self.InstanceByPID(newpid);
    End;
  Until Assigned(Result) And Result.FindIdeWindow And Not Result.IsIDEBusy;
End;

Function TIDEVersion.ProcessName(Const inPID: Cardinal): String;
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

Procedure TIDEVersion.RefreshInstances;
Begin
  _instances.Clear;

  Self.InternalRefreshInstances;
End;

//
// TIDEVersions
//

Procedure TIDEVersions.AddVersion(Const inVersion: TIDEVersion);
Begin
  _versions.Add(inVersion);

  If Not Assigned(_latestversion) Or (inVersion.VersionNumber > _latestversion.VersionNumber) Then
    _latestversion := inVersion;
End;

Procedure TIDEVersions.AfterConstruction;
Begin
  inherited;

  Self.RefreshInstalledVersions;
End;

Constructor TIDEVersions.Create(inOwner: TComponent);
Begin
  inherited;

  _latestversion := nil;
  _versions := TObjectList<TIDEVersion>.Create(True);
End;

Destructor TIDEVersions.Destroy;
Begin
  FreeAndNil(_versions);

  inherited;
End;

Function TIDEVersions.GetInstalledVersions: TArray<TIDEVersion>;
Begin
  Result := _versions.ToArray;
End;

Procedure TIDEVersions.InternalRefreshInstalledVersions;
Begin
  // Dummy
End;

Procedure TIDEVersions.RefreshInstalledVersions;
begin
  _versions.Clear;

  Self.InternalRefreshInstalledVersions;
End;

Function TIDEVersions.VersionByName(Const inName: String): TIDEVersion;
Begin
  For Result In _versions Do
    If Result.Name = inName Then
      Exit;

  Result := nil;
End;

Function TIDEVersions.VersionByVersionNumber(Const inVersionNumber: Integer): TIDEVersion;
Begin
  For Result In _versions Do
    If Result.VersionNumber = inVersionNumber Then
      Exit;

  Result := nil;
End;

End.
