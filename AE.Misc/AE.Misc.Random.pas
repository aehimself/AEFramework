{
  AE Framework © 2022 by Akos Eigler is licensed under CC BY 4.0.
  To view a copy of this license, visit http://creativecommons.org/licenses/by/4.0/

  This license requires that reusers give credit to the creator. It allows reusers to distribute, remix, adapt,
  and build upon the material in any medium or format, even for commercial purposes.
}

Unit AE.Misc.Random;

Interface

Type
  TAERandomSeed = Array Of Integer;

  TAERandom = Class
  strict private
    Procedure SetSeed(inSeed: TAERandomSeed);
    Function GetSeed: TAERandomSeed;
  strict protected
    Procedure InternalRandomSeed; Virtual; Abstract;
    Procedure InternalSetSeed(inSeed: TAERandomSeed); Virtual; Abstract;
    Function InternalGetSeed: TAERandomSeed; Virtual; Abstract;
    Function InternalNext: Integer; Virtual; Abstract;
  public
    Constructor Create; ReIntroduce;
    Procedure RandomSeed;
    Function Next: Integer; Overload;
    Function Next(inUpperRange: Integer): Integer; Overload;
    Property Seed: TAERandomSeed Read GetSeed Write SetSeed;
  End;

  TAEDelphiRandom = Class(TAERandom)
  strict private
    _seed: Integer;
  strict protected
    Procedure InternalRandomSeed; Override;
    Procedure InternalSetSeed(inSeed: TAERandomSeed); Override;
    Function InternalGetSeed: TAERandomSeed; Override;
    Function InternalNext: Integer; Override;
  End;

  TAEXORShift = Class(TAERandom)
  Type
    TXORShiftSeed = Record
      p0, p1, p2, p3: Cardinal;
    End;
  strict private
    _seed: TXORShiftSeed;
  strict protected
    Procedure InternalRandomSeed; Override;
    Procedure InternalSetSeed(inSeed: TAERandomSeed); Override;
    Function InternalGetSeed: TAERandomSeed; Override;
    Function InternalNext: Integer; Override;
  End;

Implementation

Uses System.SysUtils, System.Math;

{$R-}

Var
  _randomized: Boolean;

  //
  // Internal, helper functions
  //

Function SysRndInt: Integer;
Begin
  Result := RandomRange(Integer.MinValue, Integer.MaxValue);
End;

//
// TAESHMRandom
//

Constructor TAERandom.Create;
Begin
  inherited;
  Self.RandomSeed;
End;

Function TAERandom.GetSeed: TAERandomSeed;
Begin
  Result := InternalGetSeed;
End;

Function TAERandom.Next(inUpperRange: Integer): Integer;
Var
  tmp: UInt32;
Begin
  tmp := Self.Next;
  Result := (UInt64(UInt32(inUpperRange)) * UInt64(tmp)) Shr 32;
End;

Function TAERandom.Next: Integer;
Begin
  Result := InternalNext;
End;

Procedure TAERandom.RandomSeed;
Begin
  If Not _randomized Then
  Begin
    Randomize;
    _randomized := True;
  End;
  Self.InternalRandomSeed;
End;

Procedure TAERandom.SetSeed(inSeed: TAERandomSeed);
Begin
  InternalSetSeed(inSeed);
End;

//
// TDelphi
//

Function TAEDelphiRandom.InternalGetSeed: TAERandomSeed;
Begin
  SetLength(Result, 1);
  Result[0] := _seed;
End;

Function TAEDelphiRandom.InternalNext: Integer;
Begin
  _seed := Integer(_seed * $08088405) + 1;
  Result := _seed * Integer.MaxValue Shr 32;
End;

Procedure TAEDelphiRandom.InternalRandomSeed;
Begin
  _seed := SysRndInt;
End;

Procedure TAEDelphiRandom.InternalSetSeed(inSeed: TAERandomSeed);
Begin
  If Length(inSeed) > 0 Then
    _seed := inSeed[0]
  Else
    _seed := 0;
End;

//
// TXORShift
//

Function TAEXORShift.InternalNext: Integer;
Var
  t: UInt32;
Begin
  t := _seed.p0 XOr (_seed.p0 Shl 11);
  _seed.p0 := _seed.p1;
  _seed.p1 := _seed.p2;
  _seed.p2 := _seed.p3;
  _seed.p3 := _seed.p3 XOr (_seed.p3 Shr 19) XOr (t XOr (t Shr 8));
  Result := _seed.p3;
End;

Function TAEXORShift.InternalGetSeed: TAERandomSeed;
Begin
  SetLength(Result, 4);
  Result[0] := _seed.p0;
  Result[1] := _seed.p1;
  Result[2] := _seed.p2;
  Result[3] := _seed.p3;
End;

Procedure TAEXORShift.InternalRandomSeed;
Begin
  _seed.p0 := SysRndInt;
  _seed.p1 := SysRndInt;
  _seed.p2 := SysRndInt;
  _seed.p3 := SysRndInt;
End;

Procedure TAEXORShift.InternalSetSeed(inSeed: TAERandomSeed);
Begin
  If Length(inSeed) > 0 Then
    _seed.p0 := inSeed[0]
  Else
    _seed.p0 := 0;
  If Length(inSeed) > 1 Then
    _seed.p1 := inSeed[1]
  Else
    _seed.p1 := 1;
  If Length(inSeed) > 2 Then
    _seed.p2 := inSeed[2]
  Else
    _seed.p2 := 2;
  If Length(inSeed) > 3 Then
    _seed.p3 := inSeed[3]
  Else
    _seed.p3 := 3;
End;

Initialization

_randomized := False;

End.
