{
  AE Framework © 2022 by Akos Eigler is licensed under CC BY 4.0.
  To view a copy of this license, visit http://creativecommons.org/licenses/by/4.0/

  This license requires that reusers give credit to the creator. It allows reusers to distribute, remix, adapt,
  and build upon the material in any medium or format, even for commercial purposes.
}

Unit AE.VirtualKeyboard;

Interface

Uses WinApi.Windows;

Type
  TInputs = TArray<TInput>;

  TAEVirtualKeyboard = Class
  strict protected
    Class Function InternalGetKeyboardName: String; Virtual;
    Class Function LanguageID: Cardinal; Virtual;
    Procedure InternalTypeText(Const inText: String; Const inDelayInMs: Word); Virtual;
    Function InternalTranslateKey(Const inKey: Char): TInputs; Virtual;
  public
    Procedure TypeText(Const inText: String; inDelayInMs: Word = 10);
    Class Function KeyboardName: String;
  End;

  TAEVirtualKeyboardClass = Class Of TAEVirtualKeyboard;

Procedure RegisterKeyboard(inKeyboardClass: TAEVirtualKeyboardClass);
Function Keyboards: TArray<TAEVirtualKeyboardClass>;

Implementation

Uses System.SysUtils, System.Generics.Collections;

Var
  _keyboards: TArray<TAEVirtualKeyboardClass>;

//
// Internal, helper functions
//

Procedure RegisterKeyboard(inKeyboardClass: TAEVirtualKeyboardClass);
Begin
  SetLength(_keyboards, Length(_keyboards) + 1);
  _keyboards[High(_keyboards)] := inKeyboardClass;
End;

Function Keyboards: TArray<TAEVirtualKeyboardClass>;
Begin
  Result := _keyboards;
End;

//
// TAEVirtualKeyboard
//

Class Function TAEVirtualKeyboard.InternalGetKeyboardName: String;
Var
  buf: Array[0..LOCALE_NAME_MAX_LENGTH - 1] Of WideChar;
Begin
  If LCIDToLocaleName(Self.LanguageID, buf, LOCALE_NAME_MAX_LENGTH, 0) = 0 Then
    RaiseLastOSError;

  Result := 'AE virtual ' + buf + ' keyboard';
End;

Function TAEVirtualKeyboard.InternalTranslateKey(Const inKey: Char): TInputs;
Begin
  ZeroMemory(@Result, SizeOf(Result));

  SetLength(Result, 2);

  Result[0].Itype := INPUT_KEYBOARD;
  Result[0].ki.wScan := Ord(inKey);
  Result[0].ki.dwFlags := KEYEVENTF_UNICODE;

  Result[1].Itype := INPUT_KEYBOARD;
  Result[1].ki.wScan := Ord(inKey);
  Result[1].ki.dwFlags := KEYEVENTF_UNICODE Or KEYEVENTF_KEYUP;
End;

Procedure TAEVirtualKeyboard.InternalTypeText(Const inText: String; Const inDelayInMs: Word);
Var
  allinputs: TList<TInput>;
  inputs: TInputs;
  c: Char;
Begin
  If inDelayInMs > 0 Then
    {$REGION 'Type the text one by one, sleeping between each character press'}
    For c In inText Do
    Begin
      inputs := Self.InternalTranslateKey(c);

      If Length(inputs) > 0 Then
      Begin
        SendInput(Length(inputs), inputs[0], SizeOf(TInput));

        Sleep(inDelayInMs);
      End
    End
    {$ENDREGION}
  Else
  Begin
    {$REGION 'Collect keystrokes required to type the full text and then send all inputs once, without any delay'}
    allinputs := TList<TInput>.Create;
    Try
      For c In inText Do
        allinputs.AddRange(Self.InternalTranslateKey(c));

      If allinputs.Count > 0 Then
      Begin
        inputs := allinputs.ToArray;

        SendInput(Length(inputs), inputs[0], SizeOf(TInput));
      End;
    Finally
      FreeAndNil(allinputs);
    End;
    {$ENDREGION};
  End;
End;

Class Function TAEVirtualKeyboard.KeyboardName: String;
Begin
  Result := Self.InternalGetKeyboardName;
End;

Class Function TAEVirtualKeyboard.LanguageID: Cardinal;
Begin
  // LCID 0 = current
  Result := 0;
End;

Procedure TAEVirtualKeyboard.TypeText(Const inText: String; inDelayInMs: Word = 10);
Var
  oldstate, newstate: TKeyboardState;
Begin
  // Sleeps only matter if we are not typing from the main thread. All SendInput calls are translated to WM_KEYDOWN and WM_KEYUP
  // window messages, which has to be processed before the result shows up. Therefore, only perform sleeps between keystrokes,
  // if we are NOT in the main thread of the application to avoid lockups.
  If GetCurrentThreadID = MainThreadID Then
    inDelayInMs := 0;

  {$REGION 'Save and reset keyboard state'}
  If Not GetKeyboardState(oldstate) Then
    RaiseLastOSError;

  ZeroMemory(@newstate, SizeOf(newstate));

  If Not SetKeyboardState(newstate) Then
    RaiseLastOSError;
  {$ENDREGION}

  Try
    Self.InternalTypeText(inText, inDelayInMs);
  Finally
    {$REGION 'Restore previous keyboard state'}
    If Not SetKeyboardState(oldstate) Then
      RaiseLastOSError;
    {$ENDREGION}
  End;
End;

Initialization
  SetLength(_keyboards, 0);
  RegisterKeyboard(TAEVirtualKeyboard);

End.
