Unit AE.Comp.Updater;

Interface

Uses System.Classes, AE.Updater.UpdateFile, System.Net.HttpClientComponent, System.SysUtils, System.Generics.Collections;

Type
  EAEUpdaterException = Class(Exception)
  End;

  EAEUpdaterURLException = Class(EAEUpdaterException)
  strict private
    _url: String;
    _statuscode: Integer;
    _statustext: String;
  public
    Constructor Create(Const inMessage: String; Const inURL: String = ''; Const inStatusCode: Integer = -1; Const inStatusText: String = '');
    Property URL: String Read _url;
    Property StatusCode: Integer Read _statuscode;
    Property StatusText: String Read _statustext;
  End;

  TAEUpdaterFileDownloadedEvent = Procedure(Sender: TObject; Const inURL: String; Const inStream, outStream: TStream) Of Object;

  TAEUpdater = Class(TComponent)
  strict private
    _availablemessages: TList<UInt64>;
    _availableupdates: TObjectDictionary<String, TList<UInt64>>;
    _channel: TAEUpdaterChannel;
    _etags: TDictionary<String, String>;
    _filehashes: TDictionary<String, String>;
    _httpclient: TNetHTTPClient;
    _lastmessagedate: UInt64;
    _onfiledownloaded: TAEUpdaterFileDownloadedEvent;
    _product: String;
    _updatefile: TAEUpdateFile;
    _updatefileurl: String;
    Procedure InternalCheckForUpdates;
    Procedure SetETag(Const inURL, inETag: String);
    Procedure SetFileHash(Const inFileName, inFileHash: String);
    Procedure SetUpdateFileEtag(Const inUpdateFileEtag: String);
    Function ChannelVisible(Const inChannel: TAEUpdaterChannel): Boolean;
    Function DownloadFile(Const inURL: String; Const outStream: TStream): Boolean;
    Function GetActualProduct: TAEUpdaterProduct;
    Function GetETag(Const inURL: String): String;
    Function GetETags: TArray<String>;
    Function GetFileHash(Const inFileName: String): String;
    Function GetFileHashes: TArray<String>;
    Function GetMessages: TArray<UInt64>;
    Function GetUpdateableFiles: TArray<String>;
    Function GetUpdateableFileVersions(Const inFileName: String): TArray<UInt64>;
    Function GetUpdateFileEtag: String;
  public
    Class Procedure Cleanup;
    Constructor Create(AOwner: TComponent); Override;
    Destructor Destroy; Override;
    Procedure CheckForUpdates; Overload;
    Procedure CheckForUpdates(Const inUpdateFile: TStream); Overload;
    Procedure Update(Const inFileName: String; inVersion: UInt64 = 0);
    Function DownloadUpdateFile: Boolean;
    Property ActualProduct: TAEUpdaterProduct Read GetActualProduct;
    Property Channel: TAEUpdaterChannel Read _channel Write _channel;
    Property ETag[Const inURL: String]: String Read GetETag Write SetETag;
    Property ETags: TArray<String> Read GetETags;
    Property FileHash[Const inFileName: String]: String Read GetFileHash Write SetFileHash;
    Property FileHashes: TArray<String> Read GetFileHashes;
    Property HTTPClient: TNetHTTPClient Read _httpclient;
    Property LastMessageDate: UInt64 Read _lastmessagedate Write _lastmessagedate;
    Property Messages: TArray<UInt64> Read GetMessages;
    Property UpdateableFiles: TArray<String> Read GetUpdateableFiles;
    Property UpdateableFileVersions[Const inFileName: String]: TArray<UInt64> Read GetUpdateableFileVersions;
  published
    Property UpdateFileEtag: String Read GetUpdateFileEtag Write SetUpdateFileEtag;
    Property UpdateFileURL: String Read _updatefileurl Write _updatefileurl;
    Property OnFileDownloaded: TAEUpdaterFileDownloadedEvent Read _onfiledownloaded Write _onfiledownloaded;
  End;

Implementation

Uses System.Net.URLClient, System.Net.HttpClient, AE.Misc.FileUtils, System.IOUtils;

Const
  OLDVERSIONEXT = '.aeupdater.tmp';

//
// EAEUpdaterException
//

Constructor EAEUpdaterURLException.Create(Const inMessage: String; Const inURL: String = ''; Const inStatusCode: Integer = -1; Const inStatusText: String = '');
Begin
  inherited Create(inMessage);

  _url := inURL;
  _statustext := inStatusText;
  _statuscode := inStatusCode;
End;

//
// TAEUpdater
//

Procedure TAEUpdater.CheckForUpdates;
Var
  fname: String;
  fver: TFileVersion;
Begin
  _availablemessages.Clear;
  _availableupdates.Clear;

  // Verify files previously updated. If any of these files do not exist now OR the file hash is different,
  // clear all ETags causing the updater to actually download the update file and perform all verifications.
  For fname In _filehashes.Keys Do
  Begin
    fver := FileVersion(fname);
    If Not TFile.Exists(fname) Or (CompareText(_filehashes[fname], fver.MD5Hash) <> 0) Then
    Begin
      _etags.Clear;
      Break;
    End;
  End;

  _filehashes.Clear;

  If Not DownloadUpdateFile Then
    Exit;

  InternalCheckForUpdates;
End;

Procedure TAEUpdater.CheckForUpdates(Const inUpdateFile: TStream);
Begin
  _availablemessages.Clear;
  _availableupdates.Clear;
  _filehashes.Clear;

  _updatefile.LoadFromStream(inUpdateFile);

  InternalCheckForUpdates;
End;

Class Procedure TAEUpdater.Cleanup;
Var
  fname: String;
Begin
  For fname In TDirectory.GetFiles(ExtractFilePath(ParamStr(0)), '*' + OLDVERSIONEXT, TSearchOption.soAllDirectories) Do
    TFile.Delete(fname);
End;

Constructor TAEUpdater.Create(AOwner: TComponent);
Begin
  inherited;

  _availablemessages := TList<UInt64>.Create;
  _availableupdates := TObjectDictionary <String, TList <UInt64>>.Create([doOwnsValues]);
  _channel := aucProduction;
  _etags := TDictionary<String, String>.Create;
  _filehashes := TDictionary<String, String>.Create;
  _httpclient := TNetHTTPClient.Create(Self);
  _updatefile := TAEUpdateFile.Create;

  _product := FileProduct(ParamStr(0));
  If _product.IsEmpty Then
    Raise EAEUpdaterException.Create('Product name of running executable can not be determined!');

  _updatefile.ProductBind := _product;
End;

Destructor TAEUpdater.Destroy;
Begin
  FreeAndNil(_availablemessages);
  FreeAndNil(_availableupdates);
  FreeAndNil(_etags);
  FreeANdNil(_filehashes);
  FreeAndNil(_updatefile);

  inherited;
End;

Function TAEUpdater.DownloadFile(Const inURL: String; Const outStream: TStream): Boolean;
Var
  headers: TArray<TNameValuePair>;
  hr: IHTTPResponse;
Begin
  Result := False;

  If Not _etags.ContainsKey(inURL) Then
    SetLength(headers, 0)
  Else
  Begin
    SetLength(headers, 1);
    headers[0].Name := 'If-None-Match';
    headers[0].Value := _etags[inURL];
  End;

  hr := _httpclient.Get(inURL, nil, headers);

  If Not Assigned(hr) Then
    Raise EAEUpdaterException.Create(inURL + ' could not be downloaded!');

  If hr.StatusCode = 304 Then // 304 was provided because of ETag = no updates are available
    Exit
  Else
  If hr.StatusCode <> 200 Then
    Raise EAEUpdaterURLException.Create('Requested file could not be downloaded!', inURL, hr.StatusCode, hr.StatusText);

  If Assigned(_onfiledownloaded) Then
    _onfiledownloaded(Self, inURL, hr.ContentStream, outStream)
  Else
    outStream.CopyFrom(hr.ContentStream);

  If hr.ContainsHeader('ETag') Then
    Self.ETag[inURL] :=  hr.HeaderValue['ETag'];

  Result := True;
End;

Function TAEUpdater.DownloadUpdateFile: Boolean;
Var
  ms: TMemoryStream;
Begin
  Result := False;

  If _updatefileurl.IsEmpty Then
    Raise EAEUpdaterException.Create('Update file URL is not defined!');

  ms := TMemoryStream.Create;
  Try
    If Not DownloadFile(_updatefileurl, ms) Then
      Exit;

    ms.Position := 0;

    _updatefile.LoadFromStream(ms);

    Result := True;
  Finally
    FreeAndNil(ms);
  End;
End;

Function TAEUpdater.GetActualProduct: TAEUpdaterProduct;
Begin
  Result := _updatefile.Product[_product];
End;

Function TAEUpdater.GetETag(Const inURL: String): String;
Begin
  _etags.TryGetValue(inURL, Result);
End;

Function TAEUpdater.GetETags: TArray<String>;
Begin
  Result := _etags.Keys.ToArray;
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
Var
  a, b: Integer;
  tmp: UInt64;
Begin
  Result := _availablemessages.ToArray;

  // Quickly sort the results in a descending order => latest message first
  For a := Low(Result) To High(Result) - 1 Do
    For b := a + 1 To High(Result) Do
      If Result[a] < Result[b] Then
      Begin
        tmp := Result[a];
        Result[a] := Result[b];
        Result[b] := tmp;
      End;
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

Function TAEUpdater.GetUpdateFileEtag: String;
Begin
  If Not (csDesigning In Self.ComponentState) And Not (csLoading In Self.ComponentState) And _updatefileurl.IsEmpty Then
    Raise EAEUpdaterException.Create('Update file URL is not defined!');

  _etags.TryGetValue(_updatefileurl, Result);
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
  If Not _updatefile.ContainsProduct(_product) Then
    Exit;

  fname := ExtractFileName(ParamStr(0));
  product := _updatefile.Product[_product];

  If Not product.ContainsFile(fname) Then
    Raise EAEUpdaterException.Create(_product + ' does not contain a file named ' + fname);

  For fname In product.ProductFiles Do
  Begin
    pfile := product.ProductFile[fname];
    fexists := TFile.Exists(fname);

    If Not fexists And pfile.Optional Then
      Continue;

    fver := FileVersion(fname);

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

Procedure TAEUpdater.SetETag(Const inURL, inETag: String);
Begin
  If Not inETag.IsEmpty Then
    _etags.AddOrSetValue(inURL, inETag)
  Else
    _etags.Remove(inURL);
End;

Procedure TAEUpdater.SetFileHash(Const inFileName, inFileHash: String);
Begin
  If Not inFileHash.IsEmpty Then
    _filehashes.AddOrSetValue(inFileName, inFileHash)
  Else
    _filehashes.Remove(inFileName);
End;

Procedure TAEUpdater.SetUpdateFileEtag(const inUpdateFileEtag: String);
Begin
  If Not (csDesigning In Self.ComponentState) And Not (csLoading In Self.ComponentState) And _updatefileurl.IsEmpty Then
    Raise EAEUpdaterException.Create('Update file URL is not defined!');

  _etags.AddOrSetValue(_updatefileurl, inUpdateFileEtag);
End;

Procedure TAEUpdater.Update(Const inFileName: String; inVersion: UInt64 = 0);
Var
  fs: TFileStream;
  fileurl: String;
  product: TAEUpdaterProduct;
  version: TAEUpdaterProductFileVersion;
Begin
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
  fileurl := _updatefileurl.Substring(0, _updatefileurl.LastIndexOf('/') + 1) + version.RelativeArchiveFileName('/');

  If TFile.Exists(inFileName) then
    TFile.Move(inFileName, inFileName + OLDVERSIONEXT);
  Try
    fs := TFileStream.Create(inFileName, fmCreate);
    Try
      If Not DownloadFile(fileurl, fs) Then
        TFile.Move(inFileName + OLDVERSIONEXT, inFileName);
    Finally
      fs.Free;
    End;
  Except
    On E:Exception Do
    Begin
      // If the extracting failed, make sure to rename the file back to its original name
      // so it still can be accessed the next time the application starts
      TFile.Move(inFileName + OLDVERSIONEXT, inFileName);

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
