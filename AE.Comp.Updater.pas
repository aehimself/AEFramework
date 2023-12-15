{
  AE Framework © 2022 by Akos Eigler is licensed under CC BY 4.0.
  To view a copy of this license, visit http://creativecommons.org/licenses/by/4.0/

  This license requires that reusers give credit to the creator. It allows reusers to distribute, remix, adapt,
  and build upon the material in any medium or format, even for commercial purposes.
}

Unit AE.Comp.Updater;

Interface

Uses System.Classes, AE.Comp.Updater.UpdateFile, System.SysUtils, System.Generics.Collections, AE.Comp.Updater.FileProvider;

Type
  EAEUpdaterException = Class(Exception);

  TAEUpdater = Class(TComponent)
  strict private
    _availablemessages: TList<UInt64>;
    _availableupdates: TObjectDictionary<String, TList<UInt64>>;
    _channel: TAEUpdaterChannel;
    _filehashes: TDictionary<String, String>;
    _fileprovider: TAEUpdaterFileProvider;
    _lastmessagedate: UInt64;
    _localupdateroot: String;
    _product: String;
    _updatefile: TAEUpdateFile;
    Procedure CheckFileProvider;
    Procedure InternalCheckForUpdates;
    Procedure SetFileHash(Const inFileName, inFileHash: String);
    Procedure SetLocalUpdateRoot(Const inLocalUpdateRoot: String);
    Procedure SetProduct(Const inProduct: String);
    Function ChannelVisible(Const inChannel: TAEUpdaterChannel): Boolean;
    Function DownloadFile(Const inURL: String; Const outStream: TStream): Boolean;
    Function GetActualProduct: TAEUpdaterProduct;
    Function GetFileHash(Const inFileName: String): String;
    Function GetFileHashes: TArray<String>;
    Function GetMessages: TArray<UInt64>;
    Function GetUpdateableFiles: TArray<String>;
    Function GetUpdateableFileVersions(Const inFileName: String): TArray<UInt64>;
  public
    Class Procedure Cleanup(Const inLocalUpdateRoot: String = '');
    Constructor Create(AOwner: TComponent); Override;
    Destructor Destroy; Override;
    Procedure CheckForUpdates;
    Procedure Rollback(Const inFileName: String);
    Procedure Update(Const inFileName: String; inVersion: UInt64 = 0);
    Property ActualProduct: TAEUpdaterProduct Read GetActualProduct;
    Property Channel: TAEUpdaterChannel Read _channel Write _channel;
    Property FileHash[Const inFileName: String]: String Read GetFileHash Write SetFileHash;
    Property FileHashes: TArray<String> Read GetFileHashes;
    Property LastMessageDate: UInt64 Read _lastmessagedate Write _lastmessagedate;
    Function LoadUpdateFile: Boolean;
    Property LocalUpdateRoot: String Read _localupdateroot Write SetLocalUpdateRoot;
    Property Messages: TArray<UInt64> Read GetMessages;
    Property UpdateableFiles: TArray<String> Read GetUpdateableFiles;
    Property UpdateableFileVersions[Const inFileName: String]: TArray<UInt64> Read GetUpdateableFileVersions;
  published
    Property FileProvider: TAEUpdaterFileProvider Read _fileprovider Write _fileprovider;
    Property Product: String Read _product Write SetProduct;
  End;

Implementation

Uses AE.Misc.FileUtils, System.IOUtils, System.Generics.Defaults;

Const
  OLDVERSIONEXT = '.aeupdater.tmp';

Procedure TAEUpdater.CheckForUpdates;
Var
  fname: String;
  fver: TFileVersion;
Begin
  CheckFileProvider;

  _availablemessages.Clear;
  _availableupdates.Clear;

  // Verify files previously updated. If any of these files do not exist now OR the file hash is different,
  // clear all ETags causing the updater to actually download the update file and perform all verifications.
  For fname In _filehashes.Keys Do
  Begin
    fver := FileVersion(fname);
    If Not TFile.Exists(fname) Or (CompareText(_filehashes[fname], fver.MD5Hash) <> 0) Then
    Begin
      _fileprovider.ResetCache;
      Break;
    End;
  End;

  _filehashes.Clear;

  If Not LoadUpdateFile Then
    Exit;

  InternalCheckForUpdates;
End;

Procedure TAEUpdater.CheckFileProvider;
Begin
  If Not Assigned(_fileprovider) Then
    Raise EAEUpdaterException.Create('File provider is not assigned!');
End;

Class Procedure TAEUpdater.Cleanup(Const inLocalUpdateRoot: String = '');
Var
  fname: String;
Begin
  For fname In TDirectory.GetFiles(inLocalUpdateRoot, '*' + OLDVERSIONEXT, TSearchOption.soAllDirectories) Do
    TFile.Delete(fname);
End;

Constructor TAEUpdater.Create(AOwner: TComponent);
Begin
  inherited;

  _availablemessages := TList<UInt64>.Create;
  _availableupdates := TObjectDictionary <String, TList <UInt64>>.Create([doOwnsValues]);
  _channel := aucProduction;
  _filehashes := TDictionary<String, String>.Create;
  _fileprovider := nil;
  _lastmessagedate := 0;
  _localupdateroot := '';
  _product := '';
  _updatefile := TAEUpdateFile.Create;
End;

Destructor TAEUpdater.Destroy;
Begin
  FreeAndNil(_availablemessages);
  FreeAndNil(_availableupdates);
  FreeAndNil(_filehashes);
  FreeAndNil(_updatefile);

  inherited;
End;

Function TAEUpdater.DownloadFile(Const inURL: String; Const outStream: TStream): Boolean;
Var
  prevsize: Int64;
Begin
  CheckFileProvider;

  prevsize := outStream.Size;

  _fileprovider.ProvideFile(inURL, outStream);

  Result := outStream.Size > prevsize;
End;

Function TAEUpdater.LoadUpdateFile: Boolean;
Var
  ms: TMemoryStream;
Begin
  CheckFileProvider;

  Result := False;

  ms := TMemoryStream.Create;
  Try
    _fileprovider.ProvideUpdateFile(ms);

    If ms.Size = 0 Then
      Exit;

    ms.Position := 0;

    _updatefile.LoadFromStream(ms);

    Result := True;
  Finally
    FreeAndNil(ms);
  End;
End;

Procedure TAEUpdater.Rollback(Const inFileName: String);
Begin
  If Not TFile.Exists(_localupdateroot + inFileName + OLDVERSIONEXT) Then
    Exit;

  If TFile.Exists(_localupdateroot + inFileName) Then
    TFile.Delete(_localupdateroot + inFileName);

  TFile.Move(_localupdateroot + inFileName + OLDVERSIONEXT, _localupdateroot + inFileName);
End;

Function TAEUpdater.GetActualProduct: TAEUpdaterProduct;
Begin
  Result := _updatefile.Product[_product];
End;

Function TAEUpdater.GetFileHash(Const inFileName: String): String;
Begin
  _filehashes.TryGetValue(inFileName, Result);
End;

Function TAEUpdater.GetFileHashes: TArray<String>;
Begin
  Result := _filehashes.Keys.ToArray;
End;

Function TAEUpdater.GetMessages: TArray<UInt64>;
Begin
  Result := _availablemessages.ToArray;

  TArray.Sort<UInt64>(Result, TComparer<UInt64>.Construct(
    Function(Const Left, Right: UInt64): Integer
    Begin
      Result := -1 * TComparer<Double>.Default.Compare(Left, Right);
    End
  ));
End;

Function TAEUpdater.GetUpdateableFiles: TArray<String>;
Begin
  Result := _availableupdates.Keys.ToArray;
  TArray.Sort<String>(Result);
End;

Function TAEUpdater.GetUpdateableFileVersions(Const inFileName: String): TArray<UInt64>;
Begin
  Result := _availableupdates[inFileName].ToArray;
End;

Procedure TAEUpdater.InternalCheckForUpdates;
Var
  fname: String;
  a, b: UInt64;
  fver: TFileVersion;
  fexists: Boolean;
  product: TAEUpdaterProduct;
  pfile: TAEUpdaterProductFile;
  pver: TAEUpdaterProductFileVersion;
Begin
  fname := FileInfo(ParamStr(0), 'OriginalFileName');
  If fname.IsEmpty Then
    fname := ExtractFileName(ParamStr(0));

  If Not _updatefile.ContainsProduct(_product) Then
    Exit;

  product := _updatefile.Product[_product];

  If Not product.ContainsFile(fname) Then
    Raise EAEUpdaterException.Create(_product + ' does not contain a file named ' + fname);

  For fname In product.ProductFiles Do
  Begin
    pfile := product.ProductFile[fname];
    fexists := TFile.Exists(_localupdateroot + fname);

    If Not fexists And pfile.Optional Then
      Continue;

    fver := FileVersion(_localupdateroot + fname);

    For a In pfile.Versions Do
    Begin
      pver := pfile.Version[a];

      If (fver.VersionNumber = 0) And Not pver.FileHash.IsEmpty And (CompareText(pver.FileHash, fver.MD5Hash) = 0) Then
        fver.VersionNumber := a;

      If (pver.DeploymentDate = 0) Or Not ChannelVisible(pver.Channel) Then
        Continue;

      // A file is considered updateable, if any of these conditions are true:
      // - The file does not exist locally (a new file was deployed with an update)
      // - The version number of the local file can be determined and the current version in the update file is greater than the local
      // - The version number of the local file can not be determined or is equal to the current version in the update file, but the hashes mismatch
      If Not fexists Or
        ((a > fver.VersionNumber) And (fver.VersionNumber > 0)) Or
        (Not pver.FileHash.IsEmpty And ((fver.VersionNumber = 0) Or (a = fver.VersionNumber)) And (CompareText(pver.FileHash, fver.MD5Hash) <> 0)) Then
      Begin
        If Not _availableupdates.ContainsKey(fname) Then
          _availableupdates.Add(fname, TList<UInt64>.Create);
        _availableupdates[fname].Add(a);
      End
      Else
      // If the file is not updateable but the version number (or hash) is equal to the existing one, add it to the known hashes list
      If fexists And
         Not pver.FileHash.IsEmpty And
         ((fver.VersionNumber = 0) Or (a = fver.VersionNumber)) And
         (CompareText(pver.FileHash, fver.MD5Hash) = 0) Then
        _filehashes.Add(fname, fver.MD5Hash);
    End;
  End;

  b := 0;
  For a In product.Messages Do
  Begin
    If (a > _lastmessagedate) And ChannelVisible(product.Message[a].Channel) Then
      _availablemessages.Add(a);
    If a > b Then
      b := a;
  End;
  _lastmessagedate := b;
End;

Procedure TAEUpdater.SetFileHash(Const inFileName, inFileHash: String);
Begin
  If Not inFileHash.IsEmpty Then
    _filehashes.AddOrSetValue(inFileName, inFileHash)
  Else
    _filehashes.Remove(inFileName);
End;

Procedure TAEUpdater.SetLocalUpdateRoot(const inLocalUpdateRoot: String);
Begin
  _localupdateroot := inLocalUpdateRoot;

  If Not _localupdateroot.IsEmpty Then
    _localupdateroot := IncludeTrailingPathDelimiter(_localupdateroot);
End;

Procedure TAEUpdater.SetProduct(Const inProduct: String);
Begin
  _product := inProduct;
  _updatefile.ProductBind := inProduct;
End;

Procedure TAEUpdater.Update(Const inFileName: String; inVersion: UInt64 = 0);
Var
  fs: TFileStream;
  fileurl, filepath: String;
  product: TAEUpdaterProduct;
  version: TAEUpdaterProductFileVersion;
Begin
  CheckFileProvider;

  product := _updatefile.Product[_product];

  If Not product.ContainsFile(inFileName) Then
    Raise EAEUpdaterException.Create(inFileName + ' does not exist in the current product!');

  // If no version number was provided, use the available latest. Else, perform verification
  If inVersion = 0 Then
    inVersion := product.ProductFile[inFileName].LatestVersion
  Else
  If Not product.ProductFile[inFileName].ContainsVersion(inVersion) Then
    Raise EAEUpdaterException.Create('Version ' + FileVersionToString(inVersion) + ' does not exist for ' + inFileName + '!');

  version := product.ProductFile[inFileName].Version[inVersion];

  // To get the file's complete download URL, we concatenate:
  // - The update file URL, cutting down the update file name
  // - Current products base URL plus a forward slash
  // - Archive file name of the version
  fileurl := _fileprovider.UpdateRoot + version.RelativeArchiveFileName('/');

  If TFile.Exists(_localupdateroot + inFileName + OLDVERSIONEXT) Then
    TFile.Delete(_localupdateroot + inFileName + OLDVERSIONEXT);

  If TFile.Exists(_localupdateroot + inFileName) Then
    TFile.Move(_localupdateroot + inFileName, _localupdateroot + inFileName + OLDVERSIONEXT);

  filepath := ExtractFilePath(inFileName);
  If Not filepath.IsEmpty And Not TDirectory.Exists(_localupdateroot + filepath) Then
    TDirectory.CreateDirectory(_localupdateroot + filepath);

  Try
    fs := TFileStream.Create(_localupdateroot + inFileName, fmCreate);
    Try
      If Not DownloadFile(fileurl, fs) Then
        TFile.Move(_localupdateroot + inFileName + OLDVERSIONEXT, _localupdateroot + inFileName);
    Finally
      fs.Free;
    End;
  Except
    On E:Exception Do
    Begin
      // If the extracting failed, make sure to rename the file back to its original name
      // so it still can be accessed the next time the application starts
      Self.Rollback(inFileName);

      Raise;
    End;
  End;
End;

Function TAEUpdater.ChannelVisible(Const inChannel: TAEUpdaterChannel): Boolean;
Begin
  // Developer channel should be able to see and update to production deployments if they are higher by version number

  Result := Integer(_channel) >= Integer(inChannel);
End;

End.
