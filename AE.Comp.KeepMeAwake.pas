Unit AE.Comp.KeepMeAwake;

Interface

Uses System.Classes, Vcl.ExtCtrls, WinApi.Windows;

Type
  TAEKeepMeAwakeMode = ( kamNone, kamMouseMove, kamMouseWheel, kamKeyPress, kamMouseClick );

  TAEKeepMeAwakeModeChangeEvent = Procedure(Sender: TObject; Const inNewMode: TAEKeepMeAwakeMode) Of Object;

  TAEKeepMeAwake = Class(TComponent)
  strict private
    _interval: Integer;
    _onmodechange: TAEKeepMeAwakeModeChangeEvent;
    _prevmode: TAEKeepMeAwakeMode;
    _timer: TTimer;
    Procedure InternalClickMouse;
    Procedure InternalMoveMouse;
    Procedure InternalPressKey;
    Procedure InternalScrollMouseWheel;
    Procedure SendInputs(inInputs: Array Of TInput);
    Procedure SetActive(Const inActive: Boolean);
    Procedure TimerTimer(Sender: TObject);
    Procedure ZeroInputs(Const inInputs: Array Of TInput);
    Function GetActive: Boolean;
    Function InternalDetectKeepMeAwakeMethod(Const inInitialIdleTime: Integer): Boolean;
    Function SecondsIdle: Integer;
  public
    Constructor Create(Owner: TComponent); Override;
  published
    Property Active: Boolean Read GetActive Write SetActive;
    Property Interval: Integer Read _interval Write _interval;
    Property OnKeepMeAwakeModeChanged: TAEKeepMeAwakeModeChangeEvent Read _onmodechange Write _onmodechange;
  End;

Implementation

Uses System.SysUtils;

Constructor TAEKeepMeAwake.Create(Owner: TComponent);
Begin
  inherited;

  // Default interval: 4 minutes (240 seconds)
  _interval := 240;

  _onmodechange := nil;

  _prevmode := kamNone;

  _timer := TTimer.Create(Self);
  _timer.Interval := 1000;
  _timer.Enabled := False;
  _timer.OnTimer := TimerTimer;
End;

Function TAEKeepMeAwake.GetActive: Boolean;
Begin
  Result := _timer.Enabled;
End;

Procedure TAEKeepMeAwake.InternalClickMouse;
Var
  inputs: Array[0..1] Of TInput;
Begin
  // Absolutely invasive method: simulate a middle click with the mouse. This can cause the cursor to switch to scroll mode
  // if it's hovering over a multi-line text input field

  ZeroInputs(inputs);

  // Define first input: press middle button
  inputs[0].Itype := INPUT_MOUSE;
  inputs[0].mi.dwFlags := MOUSEEVENTF_MIDDLEDOWN;

  // Define second input: release middle button
  inputs[1].Itype := INPUT_MOUSE;
  inputs[1].mi.dwFlags := MOUSEEVENTF_MIDDLEUP;

  SendInputs(inputs);
End;

Function TAEKeepMeAwake.InternalDetectKeepMeAwakeMethod(Const inInitialIdleTime: Integer): Boolean;
Var
  mode: TAEKeepMeAwakeMode;
Begin
  Result := True;

  mode := kamMouseMove;
  InternalMoveMouse;

  If SecondsIdle >= inInitialIdleTime Then
  Begin
    mode := kamMouseWheel;
    InternalScrollMouseWheel;

    If SecondsIdle >= inInitialIdleTime Then
    Begin
      mode := kamKeyPress;
      InternalPressKey;

      If SecondsIdle >= inInitialIdleTime Then
      Begin
        mode := kamMouseClick;
        InternalClickMouse;

        If SecondsIdle >= inInitialIdleTime Then
        Begin
          mode := kamNone;

          Result := False;
        End;
      End;
    End;
  End;

  If mode <> _prevmode Then
  Begin
    If Assigned(_onmodechange) Then
      _onmodechange(Self, mode);

    _prevmode := mode;
  End;
End;

Procedure TAEKeepMeAwake.InternalMoveMouse;
Var
  inputs: Array[0..0] Of TInput;
Begin
  // Non-invasive way to reset timer: simulate a 0-pixel movement of the mouse cursor

  ZeroInputs(inputs);

  inputs[0].Itype := INPUT_MOUSE;

  inputs[0].mi.dwFlags := MOUSEEVENTF_MOVE;
  inputs[0].mi.dx := 0;
  inputs[0].mi.dy := 0;
  inputs[0].mi.mouseData := 0;
  inputs[0].mi.time := 0;
  inputs[0].mi.dwExtraInfo := 0;

  SendInputs(inputs);
End;

Procedure TAEKeepMeAwake.InternalPressKey;
Var
  inputs: Array[0..1] Of TInput;
Begin
  // Absolutely invasive method: simulate a quick press and release of the Scroll Lock key.
  // Depending on the active application this can have unwanted results.

  ZeroInputs(inputs);

  // Define first input: press scroll lock
  inputs[0].Itype := INPUT_KEYBOARD;

  inputs[0].ki.wVk := VK_SCROLL;
  inputs[0].ki.wScan := MapVirtualKeyEx(inputs[0].ki.wVk, 0, 0);
  inputs[0].ki.dwFlags := 0;

  // Define second input: release scroll lock
  inputs[1].Itype := INPUT_KEYBOARD;

  inputs[1].ki.wVk := VK_SCROLL;
  inputs[1].ki.wScan := MapVirtualKeyEx(inputs[1].ki.wVk, 0, 0);
  inputs[1].ki.dwFlags := KEYEVENTF_KEYUP;

  SendInputs(inputs);
End;

Procedure TAEKeepMeAwake.InternalScrollMouseWheel;
Var
  inputs: Array[0..0] Of TInput;
Begin
  // Non-invasive way to reset timer: simulate a 0-pixel movement of the mouse wheel

  ZeroInputs(inputs);

  inputs[0].Itype := INPUT_MOUSE;

  inputs[0].mi.dwFlags := MOUSEEVENTF_WHEEL;
  inputs[0].mi.mouseData := 0;
  inputs[0].mi.time := 0;
  inputs[0].mi.dwExtraInfo := 0;

  SendInputs(inputs);
End;

Function TAEKeepMeAwake.SecondsIdle: Integer;
Var
  lastinput: TLastInputInfo;
Begin
  lastinput.cbSize := SizeOf(TLastInputInfo);

  If Not GetLastInputInfo(lastinput) Then
    RaiseLastOSError;

  Result := (GetTickCount - lastinput.dwTime) Div 1000;
End;

Procedure TAEKeepMeAwake.SendInputs(inInputs: Array Of TInput);
Var
  len: Cardinal;
Begin
  len := Length(inInputs);

  If SendInput(Length(inInputs), inInputs[0], SizeOf(TInput)) <> len Then
    RaiseLastOSError;
End;

Procedure TAEKeepMeAwake.SetActive(Const inActive: Boolean);
Begin
  _timer.Enabled := inActive;
End;

Procedure TAEKeepMeAwake.TimerTimer(Sender: TObject);
Var
  idle: Integer;
Begin
  idle := SecondsIdle;

  If idle < _interval Then
    Exit;

  Case _prevmode Of
    kamNone:
      If Not InternalDetectKeepMeAwakeMethod(idle) Then
        Self.Active := False;
    kamMouseMove:
      InternalMoveMouse;
    kamMouseWheel:
      InternalScrollMouseWheel;
    kamKeyPress:
      InternalPressKey;
    kamMouseClick:
      InternalClickMouse;
    Else
      Raise ENotImplemented.Create('Keep me awake method isn''t implemented yet!');
  End;
End;

Procedure TAEKeepMeAwake.ZeroInputs(Const inInputs: Array Of TInput);
Var
  a: Integer;
Begin
  For a := Low(inInputs) To High(inInputs) Do
    ZeroMemory(@inInputs[a], SizeOf(TInput));
End;

End.
