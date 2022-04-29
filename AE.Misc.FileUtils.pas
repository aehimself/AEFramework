Unit AE.Misc.FileUtils;

Interface

Type
  TFileVersion = Record
    Debug: Boolean;
    VersionNumber: UInt64;
    MajorVersion: Word;
    MinorVersion: Word;
    ReleaseVersion: Word;
    BuildNumber: Word;
    VersionString: String End;

    Function FileInfo(Const inFileName, inInfoName: String): String;
    Function FileProduct(Const inFileName: String): String;
    Function FileVersion(Const inFileName: String;
      Const inTranslateDebug: Boolean = False): TFileVersion;
    Function FileVersionToString(inFileVersion: UInt64;
      Const inDebug: Boolean = False): String;

Implementation

Uses WinApi.Windows, System.SysUtils, System.DateUtils;

Const
  MAJORDIV: UInt64 = 1000000000000000; // 100000^3
  MINORDIV: UInt64 = 10000000000; // 100000^2
  RELEASEDIV: UInt64 = 100000; // 100000^1

Function FileInfo(Const inFileName, inInfoName: String): String;
Var
  buf: PChar;
  value: PChar;
  len, n: Cardinal;
Begin
  Result := '';
  n := GetFileVersionInfoSize(PChar(inFileName), n);
  If n = 0 Then
    Exit;
  buf := AllocMem(n);
  Try
    GetFileVersionInfo(PChar(inFileName), 0, n, buf);
    If VerQueryValue(Pointer(buf),
      PChar('StringFileInfo\040904E4\' + inInfoName), Pointer(value), len) Or
    // English (US), multilingual
      VerQueryValue(Pointer(buf),
      PChar('StringFileInfo\040904B0\' + inInfoName), Pointer(value), len) Or
    // English (US), Unicode
      VerQueryValue(Pointer(buf),
      PChar('StringFileInfo\040704B0\' + inInfoName), Pointer(value), len) Then
    Begin // German, Unicode
      value := PChar(Trim(value));
      If Length(value) > 0 Then
        Result := value;
    End;
  Finally
    FreeMem(buf, n);
  End;
End;

Function FileProduct(Const inFileName: String): String;
Begin
  Result := FileInfo(inFileName, 'ProductName');
End;

Function FileVersion(Const inFileName: String;
  Const inTranslateDebug: Boolean = False): TFileVersion;
Var
  len, n: Cardinal;
  buf, p: Pointer;
  fi: TVSFixedFileInfo;
Begin
  Result.Debug := False;
  Result.VersionNumber := 0;
  Result.MajorVersion := 0;
  Result.MinorVersion := 0;
  Result.ReleaseVersion := 0;
  Result.BuildNumber := 0;
  Result.VersionString := '';

  n := GetFileVersionInfoSize(PChar(inFileName), len);
  If n = 0 Then
    Exit;
  GetMem(buf, n);
  Try
    GetFileVersionInfo(PChar(inFileName), 0, n, buf);
    If Not VerQueryValue(buf, '\', p, len) Or
      (len <> SizeOf(TVSFixedFileInfo)) Then
      Exit;

    fi := PVSFixedFileInfo(p)^;

    Result.Debug := fi.dwFileFlags And VS_FF_DEBUG <> 0;
    If Not Result.Debug Or inTranslateDebug Then
    Begin
      Result.MajorVersion := HiWord(fi.dwFileVersionMS);
      Result.MinorVersion := LoWord(fi.dwFileVersionMS);
      Result.ReleaseVersion := HiWord(fi.dwFileVersionLS);
      Result.BuildNumber := LoWord(fi.dwFileVersionLS);

      Result.VersionNumber := Result.MajorVersion * MAJORDIV +
        Result.MinorVersion * MINORDIV + Result.ReleaseVersion * RELEASEDIV +
        Result.BuildNumber;

      Result.VersionString := FileVersionToString(Result.VersionNumber,
        Result.Debug);
    End;
  Finally
    FreeMem(buf, n);
  End;
End;

Function FileVersionToString(inFileVersion: UInt64;
  Const inDebug: Boolean = False): String;
Var
  major, minor, release, build: Word;
  d: TDateTime;
Begin
  major := inFileVersion Div MAJORDIV;
  inFileVersion := inFileVersion - (major * MAJORDIV);

  minor := inFileVersion Div MINORDIV;
  inFileVersion := inFileVersion - (minor * MINORDIV);

  release := inFileVersion Div RELEASEDIV;
  inFileVersion := inFileVersion - (release * RELEASEDIV);

  build := inFileVersion;

  If Not inDebug Then
    Result := Format('%d.%d.%d.%d', [major, minor, release, build])
  Else
  Begin
    d := IncSecond(IncDay(EncodeDateTime(2000, 1, 1, 0, 0, 0, 0),
      release), build);
    If HourOf(d) < 5 Then
      d := IncSecond(d, 65536);
    Result := FormatDateTime('yymmdd.hhmm', d);
  End;
End;

End.
