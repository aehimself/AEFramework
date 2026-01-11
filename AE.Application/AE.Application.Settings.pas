{
  AE Framework © 2022 by Akos Eigler is licensed under CC BY 4.0.
  To view a copy of this license, visit http://creativecommons.org/licenses/by/4.0/

  This license requires that reusers give credit to the creator. It allows reusers to distribute, remix, adapt,
  and build upon the material in any medium or format, even for commercial purposes.
}

Unit AE.Application.Settings;

Interface

Uses System.JSON, System.SysUtils, AE.Application.Setting;

Type
  TSettingsFileLocation = (slNextToExe, slAppData, slDocuments);

  TSettingsFileCompresion = (scAutoDetect, scUncompressed, scCompressed);

  TAEApplicationSettings = Class(TAEApplicationSetting)
  strict private
    _checkchangedwhensaving: Boolean;
    _destroying: Boolean;
    _loaded: Boolean;
    _loading: Boolean;
    _settingsfilename: String;
    _settingsmigrated: Boolean;
    _compressed: Boolean;
    Procedure SetFileBytes(Const inBytes: TBytes);
    Function GetFileBytes: TBytes;
  strict protected
    Procedure AfterLoad; Virtual;
    Procedure AfterSave; Virtual;
    Procedure BeforeLoad(Var outByteArray: TBytes); Virtual;
    Procedure BeforeSave(Var outByteArray: TBytes); Virtual;
    Procedure InternalClear; Override;
    Procedure SettingsMigrated;
  public
    Class Function SettingsFileDir(Const inFileLocation: TSettingsFileLocation): String;
    Class Function New(Const inFileLocation: TSettingsFileLocation; Const inCompression: TSettingsFileCompresion = scAutoDetect): TAEApplicationSettings;
    Constructor Create(Const inSettingsFileName: String); ReIntroduce; Virtual;
    Procedure BeforeDestruction; Override;
    Procedure Load;
    Procedure Save;
    Property CheckChangedWhenSaving: Boolean Read _checkchangedwhensaving Write _checkchangedwhensaving;
    Property Compressed: Boolean Read _compressed Write _compressed;
    Property FileBytes: TBytes Read GetFileBytes Write SetFileBytes;
    Property IsLoaded: Boolean Read _loaded;
    Property SettingsFileName: String Read _settingsfilename;
  End;

Implementation

Uses System.IOUtils, AE.Helper.TBytes, System.Classes;

Procedure TAEApplicationSettings.InternalClear;
Begin
  _loaded := False;
  If Not _loading Then
    _settingsmigrated := False;
End;

Procedure TAEApplicationSettings.AfterLoad;
Begin
  Self.ClearChanged;
End;

Procedure TAEApplicationSettings.AfterSave;
Begin
  Self.ClearChanged;
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
  _checkchangedwhensaving := True;
  _destroying := False;
  _loading := False;
  _compressed := {$IFDEF DEBUG}False{$ELSE}True{$ENDIF};

  inherited Create;
End;

Function TAEApplicationSettings.GetFileBytes: TBytes;
Begin
  If Not TFile.Exists(_settingsfilename) Then
  Begin
    SetLength(Result, 0);
    Exit;
  End;

  Result := TFile.ReadAllBytes(_settingsfilename);
  If _compressed Then
    Result.Decompress;
End;

Procedure TAEApplicationSettings.Load;
Var
  json: TJSONObject;
  tb: TBytes;
Begin
  If Not FileExists(_settingsfilename) Then
  Begin
    _loaded := True;
    Exit;
  End;

  Try
    _loading := True;
    tb := Self.FileBytes;

    Self.BeforeLoad(tb);

    {$IF CompilerVersion > 32} // Everything above 10.2...?
    json := TJSONObject(TJSONObject.ParseJSONValue(tb, 0, [TJSONObject.TJSONParseOption.IsUTF8, TJSONObject.TJSONParseOption.RaiseExc]));
    {$ELSE}
    json := TJSONObject(TJSONObject.ParseJSONValue(tb, 0, [TJSONObject.TJSONParseOption.IsUTF8]));
    If Not Assigned(json) Then
      Raise EJSONException.Create('Settings file is not a valid JSON document!');
    {$ENDIF}

    Try
      Self.AsJSON := json;
      _loaded := True;
    Finally
      FreeAndNil(json);
    End;

    If _loaded And _settingsmigrated Then
      Save;
  Finally
    _loading := False;
  End;

  Self.AfterLoad;
End;

Class Function TAEApplicationSettings.New(Const inFileLocation: TSettingsFileLocation; Const inCompression: TSettingsFileCompresion = scAutoDetect): TAEApplicationSettings;
Var
  compressed: Boolean;
  ext: String;
Begin
  compressed := (inCompression = scCompressed) {$IFNDEF DEBUG} Or (inCompression = scAutoDetect){$ENDIF};
  If compressed Then
    ext := '.settings'
  Else
    ext := '.json';

  Result := Self.Create(TAEApplicationSettings.SettingsFileDir(inFileLocation) + ChangeFileExt(ExtractFileName(ParamStr(0)), ext));
  Result.Compressed := compressed;
End;

Procedure TAEApplicationSettings.Save;
Var
  json: TJSONObject;
  tb: TBytes;
Begin
  If _checkchangedwhensaving And Not Self.Changed Then
    Exit;

  json := Self.AsJSON;
  If Assigned(json) Then
  Try
    If Not _compressed Then
      {$IF CompilerVersion > 32} // Everything above 10.2...?
      tb := TEncoding.UTF8.GetBytes(json.Format)
      {$ELSE}
      tb := TEncoding.UTF8.GetBytes(json.ToJSON)
      {$ENDIF}
    Else
    Begin
      SetLength(tb, json.EstimatedByteSize);
      SetLength(tb, json.ToBytes(tb, 0));
    End;

    Self.BeforeSave(tb);

    Self.FileBytes := tb;

    _loaded := True;
    _settingsmigrated := False;
  Finally
    FreeAndNil(json);
  End;

  Self.AfterSave;
End;

Procedure TAEApplicationSettings.SetFileBytes(Const inBytes: TBytes);
Var
 dir: String;
Begin
  dir := ExtractfilePath(_settingsfilename);
  If Not TDirectory.Exists(dir) Then
    TDirectory.CreateDirectory(dir);

  If _compressed Then
    inBytes.Compress;

  TFile.WriteAllBytes(_settingsfilename, inBytes);
  If Not _destroying And Not _loading Then
    Self.Load;
End;

Class Function TAEApplicationSettings.SettingsFileDir(Const inFileLocation: TSettingsFileLocation): String;
Begin
  Case inFileLocation Of
    slNextToExe:
      Result := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0)));
    Else
    Begin
      If inFileLocation = slAppData Then
        Result := IncludeTrailingPathDelimiter(TPath.GetHomePath)
      Else
      If inFileLocation = slDocuments Then
        Result := IncludeTrailingPathDelimiter(TPath.GetDocumentsPath);

      Result := IncludeTrailingPathDelimiter(Result + ChangeFileExt(ExtractFileName(ParamStr(0)), ''));
    End;
  End;
End;

Procedure TAEApplicationSettings.SettingsMigrated;
Begin
  _loaded := True;
  _settingsmigrated := True;
End;

End.
