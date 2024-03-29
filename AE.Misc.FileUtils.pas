﻿{
  AE Framework © 2022 by Akos Eigler is licensed under CC BY 4.0.
  To view a copy of this license, visit http://creativecommons.org/licenses/by/4.0/

  This license requires that reusers give credit to the creator. It allows reusers to distribute, remix, adapt,
  and build upon the material in any medium or format, even for commercial purposes.
}

Unit AE.Misc.FileUtils;

Interface

Type
  TFileVersion = Record
    Debug: Boolean;
    VersionNumber: UInt64;
    MajorVersion: Word;
    MD5Hash: String;
    MinorVersion: Word;
    ReleaseVersion: Word;
    BuildNumber: Word;
    VersionString: String
  End;

Function FileInfo(Const inFileName, inInfoName: String): String;
Function FileProduct(Const inFileName: String): String;
Function FileVersion(Const inFileName: String; Const inTranslateDebug: Boolean = False): TFileVersion;
Function FileVersionToString(inFileVersion: UInt64; Const inDebug: Boolean = False): String;

Implementation

Uses WinApi.Windows, System.SysUtils, System.DateUtils, System.Hash;

Type
  TTranslation = Record
    Language: Word;
    CharSet: Word;
  End;
  TTranslations = Array[0..20] Of TTranslation;
  PTranslations = ^TTranslations;

Const
  MAJORDIV: UInt64 = 1000000000000000; // 100000^3
  MINORDIV: UInt64 = 10000000000; // 100000^2
  RELEASEDIV: UInt64 = 100000; // 100000^1

Function FileInfo(Const inFileName, inInfoName: String): String;
Var
  buf, value, infoname: PChar;
  len, n, count: Cardinal;
  trans: PTranslations;
  a: Integer;
Begin
  Result := '';

  n := GetFileVersionInfoSize(PChar(inFileName), n);
  If n = 0 Then
    Exit;

  buf := AllocMem(n);
  Try
    If Not GetFileVersionInfo(PChar(inFileName), 0, n, buf) Or
       Not VerQueryValue(Pointer(buf), '\VarFileInfo\Translation', Pointer(trans), count) Then
      Exit;

    For a := 0 To count Div SizeOf(TTranslation) - 1 Do
    Begin
      infoname := PChar('StringFileInfo\' + IntToHex(trans^[a].Language, 4) + IntToHex(trans^[a].CharSet,4) + '\' + inInfoName);

      If VerQueryValue(Pointer(buf), infoname, Pointer(value), len) Then
        Exit(Copy(value, 1, len));
    End;
  Finally
    FreeMem(buf, n);
  End;
End;

Function FileProduct(Const inFileName: String): String;
Begin
  Result := FileInfo(inFileName, 'ProductName');
End;

Function FileVersion(Const inFileName: String; Const inTranslateDebug: Boolean = False): TFileVersion;
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

  If FileExists(inFileName) Then
    Result.MD5Hash := THashMD5.GetHashStringFromFile(inFileName)
  Else
    Result.MD5Hash := '';

  n := GetFileVersionInfoSize(PChar(inFileName), len);
  If n = 0 Then
    Exit;

  GetMem(buf, n);
  Try
    GetFileVersionInfo(PChar(inFileName), 0, n, buf);
    If Not VerQueryValue(buf, '\', p, len) Or (len <> SizeOf(TVSFixedFileInfo)) Then
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
        Result.MinorVersion * MINORDIV +
        Result.ReleaseVersion * RELEASEDIV +
        Result.BuildNumber;

      Result.VersionString := FileVersionToString(Result.VersionNumber, Result.Debug);
    End;
  Finally
    FreeMem(buf, n);
  End;
End;

Function FileVersionToString(inFileVersion: UInt64; Const inDebug: Boolean = False): String;
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
    // From https://docwiki.embarcadero.com/RADStudio/Alexandria/en/Version_Info

    // Release = number of days since Jan 1 2000
    // Build = number of seconds since midnight (00:00:00), divided by 2

    d := IncSecond(IncDay(EncodeDateTime(2000, 1, 1, 0, 0, 0, 0),
      release), build * 2);
    Result := FormatDateTime('yymmdd.hhmm', d);
  End;
End;

End.
