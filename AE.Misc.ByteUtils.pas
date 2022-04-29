Unit AE.Misc.ByteUtils;

Interface

Uses System.SysUtils;

Procedure ClearArray(Var outBytes: TBytes); InLine;
Function BytesToHex(Const inBytes: TBytes): String;
Function BytesToString(Const inBytes: TBytes;
  Const inCompress: Boolean = False): String;
Function Compress(Const inBytes: TBytes): TBytes;
Function Decompress(Const inBytes: TBytes): TBytes;
Function Equal(Const inBytes1, inBytes2: TBytes): Boolean;
Function HexToBytes(Const inString: String): TBytes;
Function StringToBytes(Const inString: String;
  Const inTryDecompress: Boolean = False): TBytes;

Implementation

Uses System.ZLib, System.Classes, System.NetEncoding;

Function BytesToHex(Const inBytes: TBytes): String;
Begin
  SetLength(Result, Length(inBytes) * SizeOf(Char));
  BinToHex(inBytes[0], PWideChar(Result), Length(inBytes));
End;

Function HexToBytes(Const inString: String): TBytes;
Begin
  SetLength(Result, Length(inString) Div SizeOf(Char));
  HexToBin(PWideChar(inString), Result[0], Length(inString) Div SizeOf(Char));
End;

Function BytesToString(Const inBytes: TBytes;
  Const inCompress: Boolean = False): String;
Begin
  If inCompress Then
    Result := TNetEncoding.Base64.EncodeBytesToString(Compress(inBytes))
      .Replace(sLineBreak, '').Replace('=', '')
  Else
    Result := TNetEncoding.Base64.EncodeBytesToString(inBytes)
      .Replace(sLineBreak, '').Replace('=', '');
End;

Procedure ClearArray(Var outBytes: TBytes); InLine;
Begin
  FillChar(outBytes[0], Length(outBytes), #0);
  SetLength(outBytes, 0);
End;

Function Compress(Const inBytes: TBytes): TBytes;
Var
  compressor: TZCompressionStream;
  output: TBytesStream;
Begin
  output := TBytesStream.Create;
  Try
    compressor := TZCompressionStream.Create(clMax, output);
    Try
      compressor.Write(inBytes, Length(inBytes));
    Finally
      FreeAndNil(compressor);
    End;

    // 2 bytes = ZLib header which is always the same: $78 $01 (fastest) / $9C (default) / $DA (max)
    // Our compression method is using clMax, so the first two bytes are ALWAYS going to be $78 $DA
    // Upon decompression we simply can write these two bytes back so we can save on transfer / storage!

    output.Position := 2;
    SetLength(Result, output.Size - 2);
    output.Read(Result[0], output.Size - 2);
  Finally
    FreeAndNil(output);
  End;
End;

Function Decompress(Const inBytes: TBytes): TBytes;
Var
  compressor: TZDecompressionStream;
  input: TBytesStream;
Begin
  input := TBytesStream.Create;
  Try
    // 2 bytes = ZLib header which is always the same: $78 $01 (fastest) / $9C (default) / $DA (max)
    // Our compression method cuts down the header to further decrease the size so we simply can
    // add it back
    //
    // For backwards compatibility a check if implemented: to prevent this if the header is already
    // present. In a couple of builds we can get rid of that, too

    If (Length(inBytes) > 2) And
      ((inBytes[0] <> $78) Or ((inBytes[1] <> $01) And (inBytes[1] <> $9C) And
      (inBytes[1] <> $DA))) Then
      input.Write([$78, $DA], 2);

    input.Write(inBytes, Length(inBytes));
    input.Position := 0;
    compressor := TZDecompressionStream.Create(input);
    Try
      SetLength(Result, compressor.Size);
      compressor.Read(Result, Length(Result));
    Finally
      FreeAndNil(compressor);
    End;
  Finally
    FreeAndNil(input);
  End;
End;

Function Equal(Const inBytes1, inBytes2: TBytes): Boolean;
Begin
  Result := (Length(inBytes1) = Length(inBytes2)) And
    CompareMem(@inBytes1[0], @inBytes2[0], Length(inBytes1));
End;

Function StringToBytes(Const inString: String;
  Const inTryDecompress: Boolean = False): TBytes;
Begin
  If inTryDecompress Then
    Result := Decompress(TNetEncoding.Base64.DecodeStringToBytes(inString))
  Else
    Result := TNetEncoding.Base64.DecodeStringToBytes(inString);
End;

End.
