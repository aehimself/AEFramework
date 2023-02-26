{
  AE Framework © 2022 by Akos Eigler is licensed under CC BY 4.0.
  To view a copy of this license, visit http://creativecommons.org/licenses/by/4.0/

  This license requires that reusers give credit to the creator. It allows reusers to distribute, remix, adapt,
  and build upon the material in any medium or format, even for commercial purposes.
}

Unit AE.VirtualKeyboard.HuHu;

Interface

Uses AE.VirtualKeyboard.Foreign, AE.VirtualKeyboard, System.SysUtils;

Type
  TAEVirtualHuHuKeyboard = Class(TAEVirtualForeignKeyboard)
  strict protected
    Class Function LanguageID: Cardinal; Override;
    Function InternalTranslateForeignKey(Const inKey: Char): TInputs; Override;
  End;

Implementation

Type
  TSpecialKey = (skNone, skShift, skAltGr);

Function TAEVirtualHuHuKeyboard.InternalTranslateForeignKey(Const inKey: Char): TInputs;
Var
 code: Word;
 kpos: Integer;
 speckey: TSpecialKey;
Begin
  SetLength(Result, 0);

  speckey := skNone;
  code := Ord(inKey);

  {$REGION 'Change key code and shift state for specific keys'}
  Case inKey Of
    '!':
    Begin
      speckey := skShift;
      code := 52;
    End;
    '"':
    Begin
      speckey := skShift;
      code := 50;
    End;
    '#':
    Begin
      speckey := skAltGr;
      code := 88;
    End;
    '$':
    Begin
      speckey := skAltGr;
      code := 186;
    End;
    '%':
    Begin
      speckey := skShift;
      code := 53;
    End;
    '&':
    Begin
      speckey := skAltGr;
      code := 67;
    End;
    '''':
    Begin
      speckey := skShift;
      code := 49;
    End;
    '(':
    Begin
      speckey := skShift;
      code := 56;
    End;
    ')':
    Begin
      speckey := skShift;
      code := 57;
    End;
    '*':
    Begin
      speckey := skAltGr;
      code := 189;
    End;
    '+':
    Begin
      speckey := skShift;
      code := 51;
    End;
    ',':
      code := 188;
    '-':
      code := 189;
    '.':
      code := 190;
    '/':
    Begin
      speckey := skShift;
      code := 54;
    End;
    ':':
    Begin
      speckey := skShift;
      code := 190;
    End;
    ';':
    Begin
      speckey := skAltGr;
      code := 188;
    End;
    '<':
    Begin
      speckey := skAltGr;
      code := 226;
    End;
    '=':
    Begin
      speckey := skShift;
      code := 55;
    End;
    '>':
    Begin
      speckey := skAltGr;
      code := 89;
    End;
    '?':
    Begin
      speckey := skShift;
      code := 188;
    End;
    '@':
    Begin
      speckey := skAltGr;
      code := 86;
    End;
    'A'..'Z':
      speckey := skShift;
    '[':
    Begin
      speckey := skAltGr;
      code := 70;
    End;
    '\':
    Begin
      speckey := skAltGr;
      code := 81;
    End;
    ']':
    Begin
      speckey := skAltGr;
      code := 71;
    End;
    '_':
    Begin
      speckey := skShift;
      code := 189;
    End;
    'a'..'z':
      code := code - 32;
    '{':
    Begin
      speckey := skAltGr;
      code := 66;
    End;
    '|':
    Begin
      speckey := skAltGr;
      code := 87;
    End;
    '}':
    Begin
      speckey := skAltGr;
      code := 78;
    End;
    '~':
    Begin
      speckey := skAltGr;
      code := 49;
    End;
    '€':
    Begin
      speckey := skAltGr;
      code := 85;
    End;
    'Á':
    Begin
      speckey := skShift;
      code := 222;
    End;
    'É':
    Begin
      speckey := skShift;
      code := 186;
    End;
    'Í':
    Begin
      speckey := skShift;
      code := 226;
    End;
    'Ó':
    Begin
      speckey := skShift;
      code := 187;
    End;
    'Ö':
    Begin
      speckey := skShift;
      code := 192;
    End;
    'Ú':
    Begin
      speckey := skShift;
      code := 221;
    End;
    'Ü':
    Begin
      speckey := skShift;
      code := 191;
    End;
    'Ő':
    Begin
      speckey := skShift;
      code := 219;
    End;
    'Ű':
    Begin
      speckey := skShift;
      code := 220;
    End;
    'á':
      code := 222;
    'é':
      code := 186;
    'í':
      code := 226;
    'ó':
      code := 187;
    'ö':
      code := 192;
    'ú':
      code := 221;
    'ü':
      code := 191;
    'ő':
      code := 219;
    'ű':
      code := 220;
  End;
  {$ENDREGION}

  Case speckey Of
    skNone:
    Begin
      SetLength(Result, 2);

      kpos := 0;
    End;
    skShift:
    Begin
      SetLength(Result, 4);

      kpos := 1;

      Result[0] := KeyInput(16, vkbPress);    // Press Shift
      Result[3] := KeyInput(16, vkbRelease);  // Release Shift
    End;
    skAltGr:
    Begin
      SetLength(Result, 6);

      kpos := 2;

      Result[0] := KeyInput(17, vkbPress);    // Press Ctrl
      Result[1] := KeyInput(18, vkbPress);    // Press Alt
      Result[4] := KeyInput(18, vkbRelease);  // Release Alt
      Result[5] := KeyInput(17, vkbRelease);  // Release Ctrl
    End;
    Else
      Exit;
  End;

  Result[kpos] := KeyInput(code, vkbPress);
  Result[kpos + 1] := KeyInput(code, vkbRelease);
End;

Class Function TAEVirtualHuHuKeyboard.LanguageID: Cardinal;
Begin
  Result := 1038;
End;

Initialization
  RegisterKeyboard(TAEVirtualHuHuKeyboard);

End.
