Unit AE.Application.Engine;

//
// This library is being used by the following applications:
// AEWOLDaemon, VStarCamDownloader
//

Interface

Uses AE.Application.Helper, System.Classes, System.SysUtils;

Type
  TAEApplicationThread = Class(TThread)
  strict private
    _afterwork: TProcedureOfObject;
    _beforework: TProcedureOfObject;
    _threaderror: TErrorHandler;
    _workcycle: TProcedureOfObject;
  protected
    Procedure Execute; Override;
  public
    Constructor Create; ReIntroduce;
    Property AfterWork: TProcedureOfObject Read _afterwork Write _afterwork;
    Property BeforeWork: TProcedureOfObject Read _beforework Write _beforework;
    Property ThreadError: TErrorHandler Read _threaderror Write _threaderror;
    Property Terminated;
    Property WorkCycle: TProcedureOfObject Read _workcycle Write _workcycle;
  End;

  TAEApplicationEngine = Class
  strict private
    _log: TLogProcedure;
    Function GetTerminated: Boolean;
    Function GetThreadID: Cardinal;
  strict protected
    EngineThread: TAEApplicationThread;
    Procedure AfterWork; Virtual;
    Procedure BeforeWork; Virtual;
    Procedure Creating; Virtual;
    Procedure Destroying; Virtual;
    Procedure HandleException(inException: Exception; inWhile: String); Virtual;
    Procedure Log(inString: String); Virtual;
    Procedure ThreadError(inException: Exception); Virtual;
    Procedure WorkCycle; Virtual;
  public
    Constructor Create(inLogProcedure: TLogProcedure); ReIntroduce; Virtual;
    Destructor Destroy; Override;
    Procedure Start;
    Procedure Terminate;
    Function EndedExecution(inTimeout: Cardinal = 50): Boolean;
    Function GracefullyEnd(inTimeout: Cardinal): Boolean; Virtual;
    Property Terminated: Boolean Read GetTerminated;
    Property ThreadID: Cardinal Read GetThreadID;
  End;

Implementation

Uses WinApi.Windows;

//
// TAEApplicationThread
//

Constructor TAEApplicationThread.Create;
Begin
  inherited Create(True);
  Self.FreeOnTerminate := False;
  _afterwork := nil;
  _beforework := nil;
  _workcycle := nil;
  _threaderror := nil;
End;

Procedure TAEApplicationThread.Execute;
Begin
  If Assigned(_beforework) Then
    _beforework;
  Try
    If Terminated Then
      Exit;
    Repeat
      Try
        If Assigned(_workcycle) Then
          _workcycle;
        Sleep(5);
      Except
        On E: Exception Do
          If Assigned(_threaderror) Then
            _threaderror(E)
          Else
            Raise;
      End;
    Until Terminated;
  Finally
    If Assigned(_afterwork) Then
      _afterwork;
  End;
End;

//
// TAEApplicationEngine
//

Procedure TAEApplicationEngine.AfterWork;
Begin
{$IFDEF DEBUG}
  Log('Terminate signal received.');
{$ENDIF}
end;

Procedure TAEApplicationEngine.BeforeWork;
Begin
{$IFDEF DEBUG}
  Log('Sarted with ID: ' + EngineThread.ThreadID.ToString + ', Handle: ' +
    EngineThread.Handle.ToString);
{$ENDIF}
End;

Constructor TAEApplicationEngine.Create(inLogProcedure: TLogProcedure);
Begin
  inherited Create;
  If Not Assigned(inLogProcedure) Then
    Raise EArgumentException.Create('LogProcedure can not be empty!');
  _log := inLogProcedure;
  Self.EngineThread := TAEApplicationThread.Create;
  Self.EngineThread.AfterWork := Self.AfterWork;
  Self.EngineThread.BeforeWork := Self.BeforeWork;
  Self.EngineThread.WorkCycle := Self.WorkCycle;
  Self.EngineThread.ThreadError := Self.ThreadError;
{$IFDEF DEBUG}
  TThread.NameThreadForDebugging(Self.ClassName, EngineThread.ThreadID);
{$ENDIF}
  Self.Creating;
End;

Procedure TAEApplicationEngine.Creating;
Begin
  // Dummy
End;

Destructor TAEApplicationEngine.Destroy;
Begin
  If Assigned(EngineThread) Then
  Begin
    Self.GracefullyEnd(0);
    FreeAndNil(EngineThread);
  End;
  _log := nil;
  Self.Destroying;
  inherited;
End;

Procedure TAEApplicationEngine.Destroying;
Begin
  // Dummy
End;

Function TAEApplicationEngine.EndedExecution(inTimeout: Cardinal): Boolean;
Begin
  Result := WaitForSingleObject(Self.EngineThread.Handle, inTimeout)
    = WAIT_OBJECT_0;
End;

Function TAEApplicationEngine.GetTerminated: Boolean;
Begin
  Result := Self.EngineThread.Terminated;
End;

Function TAEApplicationEngine.GetThreadID: Cardinal;
Begin
  Result := EngineThread.ThreadID;
End;

Function TAEApplicationEngine.GracefullyEnd(inTimeout: Cardinal): Boolean;
Var
  totalwaited: Cardinal;
Begin
  If Not Self.EngineThread.Terminated Then
    Self.EngineThread.Terminate;
  If Self.EngineThread.Suspended Then
    Self.EngineThread.Start;
  If inTimeout = 0 Then
  Begin
    Self.EngineThread.WaitFor;
    Result := True;
  End
  Else
  Begin
    totalwaited := 0;
    Result := False;
    Repeat
      If Self.EndedExecution(POLLINTERVAL) Then
        Result := True
      Else
        totalwaited := totalwaited + POLLINTERVAL;
    Until (Result) Or (totalwaited >= inTimeout);
    If Not Result Then
      TerminateThread(Self.EngineThread.Handle, 0);
  End;
End;

Procedure TAEApplicationEngine.HandleException(inException: Exception;
  inWhile: String);
Var
  errormsg: String;
Begin
  If inWhile = '' Then
    errormsg := inException.ClassName + ' was raised with the message: ' +
      inException.Message
  Else
    errormsg := inException.ClassName + ' was raised ' + inWhile +
      ' with the message: ' + inException.Message;
  Log(errormsg);
End;

Procedure TAEApplicationEngine.Log(inString: String);
Begin
  If Assigned(_log) Then
    _log('[' + Self.ClassName + '] ' + inString)
End;

Procedure TAEApplicationEngine.Start;
Begin
  Self.EngineThread.Start;
End;

Procedure TAEApplicationEngine.Terminate;
Begin
  Self.EngineThread.Terminate;
End;

Procedure TAEApplicationEngine.ThreadError(inException: Exception);
Begin
  If Not(inException Is EAbort) Then
    Self.HandleException(inException, 'during ' + Self.ClassName +
      ' exectution');
End;

Procedure TAEApplicationEngine.WorkCycle;
Begin
  CustomMessagePump;
End;

End.
