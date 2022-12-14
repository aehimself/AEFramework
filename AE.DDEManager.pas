Unit AE.DDEManager;

Interface

Uses System.Classes, WinApi.DDEml, WinApi.Windows, System.SysUtils, System.Generics.Collections;

Type
  TAEDDEManager = Class
  strict private
    _convs: TDictionary<Cardinal, HConv>;
    _convlist: HConvList;
    _ddeid: LongInt;
    _service: String;
    _servicehandle: HSZ;
    _topic: String;
    _topichandle: HSZ;
    Procedure CloseConvList;
    Function GetDDEServerPIDs: TArray<Cardinal>;
  public
    Constructor Create(Const inService, inTopic: String); ReIntroduce;
    Destructor Destroy; Override;
    Procedure ExecuteCommand(Const inCommand: String; Const inPID: Cardinal; Const inTimeoutInMs: Cardinal = 5000);
    Procedure RefreshServers;
    Property DDEServerPIDs: TArray<Cardinal> Read GetDDEServerPIDs;
  End;

  EAEDDEManagerException = Class(Exception);

Function DdeInitializeW(Var Inst: LongInt; Callback: TFNCallback; Cmd, Res: LongInt): LongInt; StdCall; External user32;

Implementation

//
// TAEDDEManager
//
// DDE logic by Attila Kovacs
// https://en.delphipraxis.net/topic/7955-how-to-open-a-file-in-the-already-running-ide/?do=findComment&comment=66850
//

Procedure TAEDDEManager.CloseConvList;
Begin
  If (_convlist <> 0) And Not DdeDisconnectList(_convlist) Then
    Raise EAEDDEManagerException.Create('Releasing the list of DDE servers failed, DDE error ' + DdeGetLastError(_ddeid).ToString);

  _convlist := 0;
End;

Constructor TAEDDEManager.Create(Const inService, inTopic: String);
Begin
  inherited Create;

  _convs := TDictionary<Cardinal, HConv>.Create;
  _convlist := 0;
  _service := inService;
  _topic := inTopic;

  If DdeInitializeW(_ddeid, nil, APPCMD_CLIENTONLY, 0) <> DMLERR_NO_ERROR Then
    Raise EAEDDEManagerException.Create('DDE initialization failed!');

  If Not _service.IsEmpty Then
  Begin
    _servicehandle := DdeCreateStringHandleW(_ddeid, PChar(_service), CP_WINUNICODE);
    If _servicehandle = 0 Then
      Raise EAEDDEManagerException.Create('Creating service handle failed, DDE error ' + DdeGetLastError(_ddeid).ToString);

    DdeKeepStringHandle(_ddeid, _servicehandle);
  End
  Else
    _servicehandle := 0;

  If Not _topic.IsEmpty Then
  Begin
    _topichandle := DdeCreateStringHandleW(_ddeid, PChar(_topic), CP_WINUNICODE);
    If (_topichandle = 0) And Not _topic.IsEmpty  Then
      Raise EAEDDEManagerException.Create('Creating topic handle failed, DDE error ' + DdeGetLastError(_ddeid).ToString);

    DdeKeepStringHandle(_ddeid, _topichandle);
  End
  Else
    _topichandle := 0;

  RefreshServers;
end;

Destructor TAEDDEManager.Destroy;
Begin
  CloseConvList;

  If _servicehandle <> 0 Then
    DdeFreeStringHandle(_ddeid, _servicehandle);

  If _topichandle <> 0 Then
    DdeFreeStringHandle(_ddeid, _topichandle);

  If _ddeid <> 0 Then
    DdeUninitialize(_ddeid);

  FreeAndNil(_convs);

  inherited;
End;

Procedure TAEDDEManager.ExecuteCommand(Const inCommand: String; Const inPID: Cardinal; Const inTimeoutInMs: Cardinal = 5000);
Var
  datahandle: HDDEData;
  res: LongInt;
Begin
  datahandle := DdeCreateDataHandle(_ddeid, @PChar(inCommand)[0], Length(inCommand) * SizeOf(Char), 0, 0, CF_TEXT, 0);
  If datahandle = 0 Then
    Raise EAEDDEManagerException.Create('Creating data handle failed, DDE error ' + DdeGetLastError(_ddeid).ToString);

  If DdeClientTransaction(Pointer(datahandle), DWORD(-1), _convs[inPID], 0, CF_TEXT, XTYP_EXECUTE, inTimeOutInMs, @res) = 0 Then
    Raise EAEDDEManagerException.Create('Executing command failed, DDE error ' + DdeGetLastError(_ddeid).ToString);

//  If Not DdeFreeDataHandle(hszCmd) Then
//    Raise EDelphiVersionException.Create('Could not free data handle, DDE error ' + DdeGetLastError(_ddeid).ToString);
End;

Function TAEDDEManager.GetDDEServerPIDs: TArray<Cardinal>;
Begin
  Result := _convs.Keys.ToArray;
End;

Procedure TAEDDEManager.RefreshServers;
Var
  conv: HConv;
  convinfo: TConvInfo;
  a: Cardinal;
Begin
  _convs.Clear;

  CloseConvList;

  _convlist := DdeConnectList(_ddeid, _servicehandle, _topichandle, 0, nil);
  If _convlist = 0 Then
  Begin
    a := DdeGetLastError(_ddeid);

    // A DMLERR_NO_CONV_ESTABLISHED error means that there are no DDE servers currently running handling. In this case
    // exception should not be raised, it simply means no Delphi IDEs are running!
    If a = DMLERR_NO_CONV_ESTABLISHED Then
      Exit
    Else
      Raise EAEDDEManagerException.Create('Retrieving the list of DDE servers failed, DDE error ' + a.ToString);
  End;

  Try
    conv := 0;
    Repeat
      conv := DdeQueryNextServer(_convlist, conv);
      If conv = 0 Then
        Break;

      convinfo.cb := SizeOf(TConvInfo);
      If DdeQueryConvInfo(conv, QID_SYNC, @convinfo) = 0 Then
        Raise EAEDDEManagerException.Create('Retrieving DDE server information failed, DDE error ' + DdeGetLastError(_ddeid).ToString);

      GetWindowThreadProcessId(convinfo.hwndPartner, a);
      _convs.Add(a, conv);
    Until (conv = 0);
  Finally
  End;
End;

End.
