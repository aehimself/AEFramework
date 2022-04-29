Unit AE.Comp.ThreadedTimer;

Interface

Uses System.Classes;

Type
  TAEThreadedTimer = Class(TComponent)
  strict private
    _enabled: Boolean;
    _thread: TThread;
    _ontimer: TNotifyEvent;
    Procedure ThreadTimer;
    Procedure SetEnabled(Const inEnabled: Boolean);
    Procedure SetInterval(Const inInterval: Integer);
    Procedure SetOnTimer(Const inOnTimer: TNotifyEvent);
    Function GetInterval: Integer;
  public
    Constructor Create(AOwner: TComponent); Override;
    Destructor Destroy; Override;
  published
    Property Enabled: Boolean Read _enabled Write SetEnabled Default True;
    Property Interval: Integer Read GetInterval Write SetInterval Default 1000;
    Property OnTimer: TNotifyEvent Read _ontimer Write SetOnTimer;
  End;

Implementation

Uses WinApi.Windows, System.SysUtils;

Type
  TTimerThread = Class(TThread)
  strict private
    _events: Array [0 .. 2] Of THandle; // Enabled - Cancelled - Restar timer
    _ontimer: TThreadProcedure;
    _interval: Integer;
    Procedure SetEnabled(Const inEnabled: Boolean);
    Procedure SetInterval(Const inInterval: Integer);
    Function GetEnabled: Boolean;
  protected
    Procedure Execute; Override;
    Procedure TerminatedSet; Override;
  public
    Constructor Create;
    Destructor Destroy; Override;
    Property Enabled: Boolean Read GetEnabled Write SetEnabled;
    Property Interval: Integer Read _interval Write SetInterval;
    Property OnTimer: TThreadProcedure Read _ontimer Write _ontimer;
  End;

  //
  // TTimerThread
  //

Constructor TTimerThread.Create;
Begin
  inherited Create(False);

  _events[0] := CreateEvent(nil, True, False, nil); // Enabled flag
  _events[1] := CreateEvent(nil, True, False, nil); // Cancelled flag
  _events[2] := CreateEvent(nil, True, False, nil); // Restar timer flag

  _ontimer := nil;
  _interval := 1000;
  Self.FreeOnTerminate := False;
  Self.Enabled := True;
End;

Destructor TTimerThread.Destroy;
Begin
  Self.Terminate;

  If GetCurrentThreadID = MainThreadID Then
    Self.Waitfor;

  CloseHandle(_events[2]); // Restar timer flag
  CloseHandle(_events[1]); // Cancelled flag
  CloseHandle(_events[0]); // Enabled flag

  inherited;
End;

Procedure TTimerThread.SetEnabled(Const inEnabled: Boolean);
Begin
  // Enabled flag
  If inEnabled Then
    SetEvent(_events[0])
  Else
    ResetEvent(_events[0]);

  SetEvent(_events[2]); // Restar timer flag
End;

Procedure TTimerThread.SetInterval(Const inInterval: Integer);
Begin
  _interval := inInterval;

  SetEvent(_events[2]); // Restar timer flag
End;

Procedure TTimerThread.TerminatedSet;
Begin
  inherited;

  ResetEvent(_events[0]); // Enabled flag
  SetEvent(_events[1]); // Cancelled flag
  SetEvent(_events[2]); // Restar timer flag
End;

Procedure TTimerThread.Execute;
Var
  winterval, lastexectime: Int64;
  freq, scount, ecount: Int64;
  res: Cardinal;
Begin
  QueryPerformanceFrequency(freq);

  lastexectime := 0;
  While Not Terminated Do
  Begin
    // Wait for the Enabled and Cancelled flags for an infinite amount of time. If not Object_0 (Enabled) was
    // signaled (thus, the timer thread was cancelled) exit the thread immediately.
    If WaitForMultipleObjects(2, @_events[0], False, INFINITE) <>
      WAIT_OBJECT_0 Then
      Break;

    If Assigned(_ontimer) Then
    Begin
      winterval := _interval - lastexectime;
      If (winterval < 0) Then
        winterval := 0;

      ResetEvent(_events[2]); // Enabled reset

      // Wait for Cancelled and Restart Timer flags for "winterval" amount of time.
      // Possible outcomes:
      // Object_0 (Cancelled flag) was signaled - exit the thread immediately
      // Object_1 (Reset timer flag) was signaled - don't call the OnTimer event but go for the next cycle
      // Wait_Timeout - No flags were signaled, OnTimer event can be called
      res := WaitForMultipleObjects(2, @_events[1], False, winterval);
      If res = WAIT_OBJECT_0 Then
        Break // Cancelled flag
      Else If (res = WAIT_TIMEOUT) And Self.Enabled Then
      Begin
        QueryPerformanceCounter(scount);
        Synchronize(_ontimer);
        QueryPerformanceCounter(ecount);
        lastexectime := 1000 * (ecount - scount) Div freq;
      End;
    End;
  End;
End;

Function TTimerThread.GetEnabled: Boolean;
Begin
  Result := Not Self.Terminated And
    (WaitForSingleObject(_events[0], 0) = WAIT_OBJECT_0);
End;

//
// TAEThreadedTimer
//

Constructor TAEThreadedTimer.Create(AOwner: TComponent);
Begin
  inherited;

  _ontimer := nil;

  _thread := TTimerThread.Create;
  TTimerThread(_thread).OnTimer := Self.ThreadTimer;
  Self.Enabled := True;
  Self.Interval := 1000;
End;

Destructor TAEThreadedTimer.Destroy;
Begin
  If Assigned(_thread) Then
  Begin
    _thread.Terminate;
    _thread.Waitfor;
    FreeAndNil(_thread);
  End;

  inherited;
End;

Function TAEThreadedTimer.GetInterval: Integer;
Begin
  Result := TTimerThread(_thread).Interval;
End;

Procedure TAEThreadedTimer.ThreadTimer;
Begin
  If Assigned(_ontimer) Then
    _ontimer(Self);
End;

Procedure TAEThreadedTimer.SetEnabled(Const inEnabled: Boolean);
Begin
  _enabled := inEnabled;

  TTimerThread(_thread).Enabled := _enabled And Assigned(_ontimer);
End;

Procedure TAEThreadedTimer.SetInterval(Const inInterval: Integer);
Begin
  TTimerThread(_thread).Interval := inInterval;
End;

Procedure TAEThreadedTimer.SetOnTimer(Const inOnTimer: TNotifyEvent);
Begin
  _ontimer := inOnTimer;

  TTimerThread(_thread).Enabled := _enabled And Assigned(_ontimer);
End;

End.
