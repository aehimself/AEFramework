{
  AE Framework © 2022 by Akos Eigler is licensed under CC BY 4.0.
  To view a copy of this license, visit http://creativecommons.org/licenses/by/4.0/

  This license requires that reusers give credit to the creator. It allows reusers to distribute, remix, adapt,
  and build upon the material in any medium or format, even for commercial purposes.
}

Unit AE.VirtualKeyboard.EnUs;

Interface

Uses AE.VirtualKeyboard.Foreign, AE.VirtualKeyboard;

Type
  TAEVirtualEnUsKeyboard = Class(TAEVirtualForeignKeyboard)
  strict protected
    Class Function LanguageID: Cardinal; Override;
    Function InternalTranslateForeignKey(Const inKey: Char): TInputs; Override;
  End;

Implementation

Function TAEVirtualEnUsKeyboard.InternalTranslateForeignKey(Const inKey: Char): TInputs;
Var
 shift: Boolean;
 code: Word;
 kpos: Integer;
Begin
  SetLength(Result, 0);

  shift := False;
  code := Ord(inKey);

  {$REGION 'Change key code and shift state for specific keys'}
  Case inKey Of
    '!':
    Begin
      shift := True;
      code := 49;
    End;
    '"':
    Begin
      shift := True;
      code := 222;
    End;
    '#':
    Begin
      shift := True;
      code := 51;
    End;
    '$':
    Begin
      shift := True;
      code := 52;
    End;
    '%':
    Begin
      shift := True;
      code := 53;
    End;
    '&':
    Begin
      shift := True;
      code := 55;
    End;
    '''':
      code := 222;
    '(':
    Begin
      shift := True;
      code := 57;
    End;
    ')':
    Begin
      shift := True;
      code := 48;
    End;
    '*':
    Begin
      shift := True;
      code := 56;
    End;
    '+':
    Begin
      shift := True;
      code := 187;
    End;
    ',':
      code := 188;
    '-':
      code := 189;
    '.':
      code := 190;
    '/':
      code := 191;
    ':':
    Begin
      shift := True;
      code := 186;
    End;
    ';':
      code := 186;
    '<':
    Begin
      shift := True;
      code := 188;
    End;
    '=':
      code := 187;
    '>':
    Begin
      shift := True;
      code := 190;
     End;
    '?':
    Begin
      shift := True;
      code := 191;
    End;
    '@':
    Begin
      shift := True;
      code := 50;
    End;
    'A'..'Z':
      shift := True;
    '[':
      code := 219;
    '\':
      code := 220;
    ']':
      code := 221;
    '^':
    Begin
      shift := True;
      code := 54;
    End;
    '_':
    Begin
      shift := True;
      code := 189;
    End;
    '`':
      code := 192;
    'a'..'z':
      code := code - 32;
    '{':
    Begin
      shift := True;
      code := 219;
    End;
    '|':
    Begin
      shift := True;
      code := 220
    End;
    '}':
    Begin
      shift := True;
      code := 221;
    End;
    '~':
    Begin
      shift := True;
      code := 49;
    End;
  End;
  {$ENDREGION}

  If shift Then
  Begin
    SetLength(Result, 4);

    kpos := 1;

    Result[0] := KeyInput(16, vkbPress);    // Press Shift
    Result[3] := KeyInput(16, vkbRelease);  // Release Shift
  End
  Else
  Begin
    SetLength(Result, 2);

    kpos := 0;
  End;

  Result[kpos] := KeyInput(code, vkbPress);
  Result[kpos + 1] := KeyInput(code, vkbRelease);
End;

Class Function TAEVirtualEnUsKeyboard.LanguageID: Cardinal;
Begin
  Result := 1033;
End;

Initialization
  RegisterKeyboard(TAEVirtualEnUsKeyboard);

End.
