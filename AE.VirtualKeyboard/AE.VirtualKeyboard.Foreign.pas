{
  AE Framework © 2022 by Akos Eigler is licensed under CC BY 4.0.
  To view a copy of this license, visit http://creativecommons.org/licenses/by/4.0/

  This license requires that reusers give credit to the creator. It allows reusers to distribute, remix, adapt,
  and build upon the material in any medium or format, even for commercial purposes.
}

Unit AE.VirtualKeyboard.Foreign;

Interface

Uses AE.VirtualKeyboard, WinApi.Windows;

Type
  TAEVirtualKeyboardButtonAction = ( vkbPress, vkbRelease);

  TAEVirtualForeignKeyboard = Class(TAEVirtualKeyboard)
  strict private
    _klayout: HKL;
  strict protected
    Procedure InternalTypeText(Const inText: String; Const inDelayInMs: Word); Override;
    Function InternalTranslateForeignKey(Const inKey: Char): TInputs; Virtual; Abstract;
    Function InternalTranslateKey(Const inKey: Char): TInputs; Override;
    Function KeyInput(Const inKey: Word; Const inAction: TAEVirtualKeyboardButtonAction): TInput;
  public
    Constructor Create; ReIntroduce;
  End;

Implementation

Uses System.SysUtils;

Const
  KLF_SETFORPROCESS = $00000100; // https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-loadkeyboardlayouta

Constructor TAEVirtualForeignKeyboard.Create;
Begin
  inherited;

  _klayout := 0;
End;

Function TAEVirtualForeignKeyboard.InternalTranslateKey(Const inKey: Char): TInputs;
Begin
  Result := Self.InternalTranslateForeignKey(inKey);
End;

Procedure TAEVirtualForeignKeyboard.InternalTypeText(Const inText: String; Const inDelayInMs: Word);
Begin
  {$REGION 'Attempt to load the keyboard layout specified by the class'}
  _klayout := LoadKeyboardLayout(IntToHex(Self.LanguageID, 8), KLF_ACTIVATE Or KLF_SETFORPROCESS);

  If _klayout = 0 Then
    RaiseLastOSError;
  {$ENDREGION}

  Try
    inherited;
  Finally
    {$REGION 'Unload the keyboard layout'}
    If Not UnloadKeyboardLayout(_klayout) Then
      RaiseLastOSError;
    {$ENDREGION}
  End;
End;

Function TAEVirtualForeignKeyboard.KeyInput(Const inKey: Word; Const inAction: TAEVirtualKeyboardButtonAction): TInput;
Begin
  ZeroMemory(@Result, SizeOf(Result));

  Result.Itype := INPUT_KEYBOARD;
  Result.ki.wVk := inKey;
  Result.ki.wScan := MapVirtualKeyEx(Result.ki.wVk, 0, _klayout);

  Case InAction Of
    vkbPress:
      Result.ki.dwFlags := 0;
    vkbRelease:
      Result.ki.dwFlags := KEYEVENTF_KEYUP;
  End;
End;

End.
