Unit AE.Application.Settings;

Interface

Uses System.JSON, System.SysUtils;

Type
  TSettingsFileLocation = (slNextToExe, slAppData);

  TSettingsFileCompresion = (scAutoDetect, scUncompressed, scCompressed);

  TAEApplicationSetting = Class
  strict protected
    Procedure InternalClear; Virtual;
    Procedure SetAsJSON(Const inJSON: TJSONObject); Virtual;
    Function GetAsJSON: TJSONObject; Virtual;
  public
    Class Function NewFromJSON(Const inJSON: TJSONValue): TAEApplicationSetting;
    Constructor Create; ReIntroduce; Virtual;
    Procedure AfterConstruction; Override;
    Procedure Clear;
    Property AsJSON: TJSONObject Read GetAsJSON Write SetAsJSON;
  End;

  TAEApplicationSettings = Class(TAEApplicationSetting)
  strict private
    _destroying: Boolean;
    _loaded: Boolean;
    _loading: Boolean;
    _settingsfilename: String;
    _settingsmigrated: Boolean;
    _compressed: Boolean;
    Procedure SetFileBytes(Const inBytes: TBytes);
    Function GetFileBytes: TBytes;
  strict protected
    Procedure BeforeLoad(Var outByteArray: TBytes); Virtual;
    Procedure BeforeSave(Var outByteArray: TBytes); Virtual;
    Procedure InternalClear; Override;
    Procedure SettingsMigrated;
  public
    Class Function New(Const inFileLocation: TSettingsFileLocation;
      Const inCompression: TSettingsFileCompresion = scAutoDetect)
      : TAEApplicationSettings;
    Constructor Create(Const inSettingsFileName: String); ReIntroduce; Virtual;
    Procedure BeforeDestruction; Override;
    Procedure Load;
    Procedure Save;
    Property Compressed: Boolean Read _compressed Write _compressed;
    Property FileBytes: TBytes Read GetFileBytes Write SetFileBytes;
    Property IsLoaded: Boolean Read _loaded;
    Property SettingsFileName: String Read _settingsfilename;
  End;

Implementation

Uses System.IOUtils, AE.Misc.ByteUtils, System.Classes;

//
// TAEApplicationSetting
//

Procedure TAEApplicationSetting.AfterConstruction;
Begin
  inherited;
  Self.InternalClear;
End;

Procedure TAEApplicationSetting.Clear;
Begin
  Self.InternalClear;
End;

Constructor TAEApplicationSetting.Create;
Begin
  inherited;
End;

Function TAEApplicationSetting.GetAsJSON: TJSONObject;
Begin
  Result := TJSONObject.Create;
End;

Procedure TAEApplicationSetting.InternalClear;
Begin
  // Dummy
End;

Class Function TAEApplicationSetting.NewFromJSON(Const inJSON: TJSONValue)
  : TAEApplicationSetting;
Begin
  Result := Self.Create;
  Try
    Result.AsJSON := TJSONObject(inJSON);
  Except
    On E: Exception Do
    Begin
      FreeAndNil(Result);
      Raise;
    End;
  End;
End;

Procedure TAEApplicationSetting.SetAsJSON(Const inJSON: TJSONObject);
Begin
  Self.InternalClear;
End;

//
// TAEApplicationSettings
//

Procedure TAEApplicationSettings.InternalClear;
Begin
  _loaded := False;
  If Not _loading Then
    _settingsmigrated := False;
End;

Procedure TAEApplicationSettings.BeforeDestruction;
Begin
  inherited;
  _destroying := True;
End;

Procedure TAEApplicationSettings.BeforeLoad(Var outByteArray: TBytes);
Begin
  // Dummy
End;

Procedure TAEApplicationSettings.BeforeSave(Var outByteArray: TBytes);
Begin
  // Dummy
End;

Constructor TAEApplicationSettings.Create(Const inSettingsFileName: String);
Begin
  _settingsfilename := inSettingsFileName;
  _destroying := False;
  _loading := False;
{$IFDEF DEBUG}
  _compressed := False;
{$ELSE}
  _compressed := True;
{$ENDIF};
  inherited Create;
End;

Function TAEApplicationSettings.GetFileBytes: TBytes;
Begin
  Result := TFile.ReadAllBytes(_settingsfilename);
  If _compressed Then
    Result := Decompress(Result);
End;

Procedure TAEApplicationSettings.Load;
Var
  JSON: TJSONObject;
  tb: TBytes;
Begin
  If Not FileExists(_settingsfilename) Then
    Exit;

  Try
    _loading := True;
    tb := Self.FileBytes;

    Self.BeforeLoad(tb);

    JSON := TJSONObject(TJSONObject.ParseJSONValue(tb, 0,
      [TJSONObject.TJSONParseOption.IsUTF8,
      TJSONObject.TJSONParseOption.RaiseExc]));
    Try
      Self.AsJSON := JSON;
      _loaded := True;
    Finally
      FreeAndNil(JSON);
    End;

    If _loaded And _settingsmigrated Then
      Save;
  Finally
    _loading := False;
  End;
End;

Class Function TAEApplicationSettings.New(Const inFileLocation
  : TSettingsFileLocation;
  Const inCompression: TSettingsFileCompresion = scAutoDetect)
  : TAEApplicationSettings;
Var
  Compressed: Boolean;
  setfile, fileext: String;
Begin
  Compressed := (inCompression = scCompressed)
  {$IFNDEF DEBUG} Or (inCompression = scAutoDetect){$ENDIF};
  If Compressed Then
    fileext := '.settings'
  Else
    fileext := '.json';
  setfile := ExtractFileName(ChangeFileExt(ParamStr(0), fileext));
  Case inFileLocation Of
    slNextToExe:
      setfile := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0)))
        + setfile;
    slAppData:
      setfile := IncludeTrailingPathDelimiter(TPath.GetHomePath) + setfile;
  End;
  Result := Self.Create(setfile);
  Result.Compressed := Compressed;
End;

Procedure TAEApplicationSettings.Save;
Var
  JSON: TJSONObject;
  tb: TBytes;
Begin
  JSON := Self.AsJSON;
  If Assigned(JSON) Then
    Try
      If Not _compressed Then
        tb := TEncoding.UTF8.GetBytes(JSON.Format)
      Else
      Begin
        SetLength(tb, JSON.EstimatedByteSize);
        SetLength(tb, JSON.ToBytes(tb, 0));
      End;

      Self.BeforeSave(tb);

      Self.FileBytes := tb;

      _loaded := True;
      _settingsmigrated := False;
    Finally
      FreeAndNil(JSON);
    End;
End;

Procedure TAEApplicationSettings.SetFileBytes(Const inBytes: TBytes);
Begin
  If _compressed Then
    TFile.WriteAllBytes(_settingsfilename, Compress(inBytes))
  Else
    TFile.WriteAllBytes(_settingsfilename, inBytes);
  If Not _destroying And Not _loading Then
    Self.Load;
End;

Procedure TAEApplicationSettings.SettingsMigrated;
Begin
  _loaded := True;
  _settingsmigrated := True;
End;

End.
