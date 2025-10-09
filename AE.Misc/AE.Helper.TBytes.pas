{
  AE Framework © 2023 by Akos Eigler is licensed under CC BY 4.0.
  To view a copy of this license, visit http://creativecommons.org/licenses/by/4.0/

  This license requires that reusers give credit to the creator. It allows reusers to distribute, remix, adapt,
  and build upon the material in any medium or format, even for commercial purposes.
}

Unit AE.Helper.TBytes;

Interface

Uses System.SysUtils;

Type
  TBytesHelper = Record Helper for TBytes
  public
    Class Function FromHexString(Const inHexString: String): TBytes;
    Class Function FromString(Const inString: String; Const inTryDecompress: Boolean = False): TBytes;
    Class Function IsEqual(Const inBytes1, inBytes2: TBytes): Boolean; Overload;
    Class Function ToString(Const inBytes: TBytes; Const inCompress: Boolean = False): String; Overload;
    Procedure Clear; InLine;
    Procedure Compress;
    Procedure Decompress;
    Procedure Insert(inPosition: NativeInt; Const inBytes: TBytes);
    Function Clone: TBytes;
    Function Data: Pointer;
    Function IsEmpty: Boolean;
    Function IsEqual(Const inBytes: TBytes): Boolean; Overload;
    Function Length: Integer; InLine;
    Function Range(Const inStartIndex, inLength: NativeInt): TBytes; Overload;
    Function Range(Const inStartIndex: NativeInt): TBytes; Overload;
    Function ToHexString: String;
    Function ToString(Const inCompress: Boolean = False): String; Overload;
  End;

Implementation

Uses System.ZLib, System.Classes, System.NetEncoding;

Function TBytesHelper.Range(Const inStartIndex, inLength: NativeInt): TBytes;
Begin
  SetLength(Result, inLength);

  Move(Self[inStartIndex], Result[0], inLength);
End;

Procedure TBytesHelper.Clear;
Begin
  If Self.Length = 0 Then
    Exit;

  FillChar(Self[0], Self.Length, #0);
  SetLength(Self, 0);
End;

Function TBytesHelper.Clone: TBytes;
Begin
  SetLength(Result, Self.Length);

  If Not Self.IsEmpty Then
    Move(Self[0], Result[0], Self.Length);
End;

Procedure TBytesHelper.Compress;
Var
  compressor: TZCompressionStream;
  output: TBytesStream;
Begin
  output := TBytesStream.Create;
  Try
    compressor := TZCompressionStream.Create(clMax, output);
    Try
      compressor.Write(Self, Self.Length);
    Finally
      FreeAndNil(compressor);
    End;

    // 2 bytes = ZLib header which is always the same: $78 $01 (fastest) / $9C (default) / $DA (max)
    // Our compression method is using clMax, so the first two bytes are ALWAYS going to be $78 $DA
    // Upon decompression we simply can write these two bytes back so we can save on transfer / storage!

    output.Position := 2;
    SetLength(Self, output.Size - 2);
    output.Read(Self[0], output.Size - 2);
  Finally
    FreeAndNil(output);
  End;
End;

Function TBytesHelper.Data: Pointer;
Begin
  Result := @Self[0];
End;

Procedure TBytesHelper.Decompress;
Var
  compressor: TZDecompressionStream;
  input: TBytesStream;
  zlibheader: TBytes;
Begin
  input := TBytesStream.Create;
  Try
    // 2 bytes = ZLib header which is always the same: $78 $01 (fastest) / $9C (default) / $DA (max)
    // Our compression method cuts down the header to further decrease the size so we simply can
    // add it back
    //
    // For backwards compatibility a check if implemented: to prevent this if the header is already
    // present. In a couple of builds we can get rid of that, too

    zlibheader := [$78, $DA];
    input.Write(zlibheader[0], 2);

    input.Write(Self, Self.Length);
    input.Position := 0;
    compressor := TZDecompressionStream.Create(input);
    Try
      SetLength(Self, compressor.Size);
      compressor.Read(Self, Self.Length);
    Finally
      FreeAndNil(compressor);
    End;
  Finally
    FreeAndNil(input);
  End;
End;

Class Function TBytesHelper.FromHexString(Const inHexString: String): TBytes;
Begin
  SetLength(Result, inHexString.Length Div SizeOf(Char));

  HexToBin(PWideChar(inHexString), Result[0], inHexString.Length Div SizeOf(Char));
End;

Class Function TBytesHelper.FromString(Const inString: String; Const inTryDecompress: Boolean): TBytes;
Begin
  Result := TNetEncoding.Base64.DecodeStringToBytes(inString);

  If inTryDecompress Then
    Result.Decompress;
End;

Class Function TBytesHelper.ToString(Const inBytes: TBytes; Const inCompress: Boolean = False): String;
Var
  tmp: TBytes;
Begin
  tmp := inBytes.Clone;

  If inCompress Then
    tmp.Compress;

  Result := TNetEncoding.Base64.EncodeBytesToString(tmp).Replace(sLineBreak, '').Replace('=', '');
End;

Procedure TBytesHelper.Insert(inPosition: NativeInt; Const inBytes: TBytes);
Var
  appendtoend: Boolean;
Begin
  appendtoend := inPosition = Self.Length - 1;

  SetLength(Self, Self.Length + inBytes.Length);

  If Not appendtoend Then
    // Move the data from inPosition to the end of the array
    Move(Self[inPosition], Self[inPosition + inBytes.Length], Self.Length - inPosition)
  Else
    // We have to increase inPosition with one to avoid overwriting the last value
    Inc(inPosition, 1);

  // Copy inBytes to Self, to position inPosition
  Move(inBytes[0], Self[inPosition], inBytes.Length);
End;

Function TBytesHelper.IsEmpty: Boolean;
Begin
  Result := Self.Length = 0;
End;

Function TBytesHelper.IsEqual(Const inBytes: TBytes): Boolean;
Begin
  Result := TBytes.IsEqual(Self, inBytes);
End;

Class Function TBytesHelper.IsEqual(Const inBytes1, inBytes2: TBytes): Boolean;
Begin
  Result := (inBytes1.Length = inBytes2.Length) And CompareMem(inBytes1.Data, inBytes2.Data, inBytes1.Length);
End;

Function TBytesHelper.Length: Integer;
Begin
  Result := System.Length(Self);
End;

Function TBytesHelper.Range(Const inStartIndex: NativeInt): TBytes;
Begin
  Result := Self.Range(inStartIndex, Self.Length - inStartIndex);
End;

Function TBytesHelper.ToHexString: String;
Begin
  SetLength(Result, Self.Length * SizeOf(Char));

  BinToHex(Self[0], PWideChar(Result), Self.Length);
End;

Function TBytesHelper.ToString(Const inCompress: Boolean): String;
Begin
  Result := TBytes.ToString(Self, inCompress);
End;

End.
