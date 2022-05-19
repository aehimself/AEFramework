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

  TAEUpdater = Class(TComponent)
  strict private
    _availablemessages: TList<UInt64>;
    _availableupdates: TObjectDictionary<String, TList<UInt64>>;
    _etags: TDictionary<String, String>;
    _httpclient: TNetHTTPClient;
    _lastmessagedate: UInt64;
    _product: String;
    _updatefile: TAEUpdateFile;
    _updatefileurl: String;
    Procedure SetETag(Const inURL, inETag: String);
    Procedure SetUpdateFileEtag(Const inUpdateFileEtag: String);
    Function DownloadFile(Const inURL: String; Const outStream: TStream): Boolean;
    Function GetActualProduct: TAEUpdaterProduct;
    Function GetETag(Const inURL: String): String;
    Function GetETags: TArray<String>;
    Function GetMessages: TArray<UInt64>;
    Function GetUpdateableFiles: TArray<String>;
    Function GetUpdateableFileVersions(Const inFileName: String): TArray<UInt64>;
    Function GetUpdateFileEtag: String;
  public
    Class Procedure Cleanup;
    Constructor Create(AOwner: TComponent); Override;
    Destructor Destroy; Override;
    Procedure CheckForUpdates;
    Procedure Update(Const inFileName: String; inVersion: UInt64 = 0);
    Function DownloadUpdateFile: Boolean;
    Property ActualProduct: TAEUpdaterProduct Read GetActualProduct;
    Property ETag[Const inURL: String]: String Read GetETag Write SetETag;
    Property ETags: TArray<String> Read GetETags;
    Property LastMessageDate: UInt64 Read _lastmessagedate Write _lastmessagedate;
    Property Messages: TArray<UInt64> Read GetMessages;
    Property UpdateableFiles: TArray<String> Read GetUpdateableFiles;
    Property UpdateableFileVersions[Const inFileName: String]: TArray<UInt64> Read GetUpdateableFileVersions;
  published
    Property UpdateFileEtag: String Read GetUpdateFileEtag Write SetUpdateFileEtag;
    Property UpdateFileURL: String Read _updatefileurl Write _updatefileurl;
  End;

Implementation

Uses System.Net.URLClient, System.Net.HttpClient, AE.Misc.FileUtils, System.IOUtils, System.Zip;

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
  a, b: UInt64;
  fver: TFileVersion;
  product: TAEUpdaterProduct;
  pfile: TAEUpdaterProductFile;
  pver: TAEUpdaterProductFileVersion;
Begin
  _availablemessages.Clear;
  _availableupdates.Clear;

  If Not DownloadUpdateFile Or Not _updatefile.ContainsProduct(_product) Then
    Exit;

  fname := ExtractFileName(ParamStr(0));
  product := _updatefile.Product[_product];

  If Not product.ContainsFile(fname) Then
    Raise EAEUpdaterException.Create(_product + ' does not contain a file named ' + fname);

  For fname In product.ProductFiles Do
  Begin
    fver := FileVersion(fname);
    pfile := product.ProductFile[fname];

    For a In pfile.Versions Do
    Begin
      pver := pfile.Version[a];

      If pver.DeploymentDate = 0 Then
        Continue;

      If (a > fver.VersionNumber) Or
        ((a = fver.VersionNumber) And Not pver.FileHash.IsEmpty And (CompareText(pver.FileHash, fver.MD5Hash) <> 0)) Then
      Begin
        If Not _availableupdates.ContainsKey(fname) Then
          _availableupdates.Add(fname, TList<UInt64>.Create);
        _availableupdates[fname].Add(a);
      End;
    End;
  End;

  b := 0;
  For a In product.Messages Do
  Begin
    If a > _lastmessagedate Then
      _availablemessages.Add(a);
    If a > b Then
      b := a;
  End;
  _lastmessagedate := b;
End;

Class Procedure TAEUpdater.Cleanup;
Var
  fname: String;
Begin
  For fname In TDirectory.GetFiles(ExtractFilePath(ParamStr(0)), '*' + OLDVERSIONEXT) Do
    TFile.Delete(fname);
End;

Constructor TAEUpdater.Create(AOwner: TComponent);
Begin
  inherited;

  _availablemessages := TList<UInt64>.Create;
  _availableupdates := TObjectDictionary <String, TList <UInt64>>.Create([doOwnsValues]);
  _etags := TDictionary<String, String>.Create;
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

  outStream.CopyFrom(hr.ContentStream);

  If hr.ContainsHeader('ETag') Then
    If Not hr.HeaderValue['ETag'].IsEmpty Then
      _etags.AddOrSetValue(inURL, hr.HeaderValue['ETag'])
    Else
      _etags.Remove(inURL);

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
    Try
      If Not DownloadFile(_updatefileurl, ms) Then
        Exit;

      ms.Position := 0;

      _updatefile.LoadFromStream(ms);

      Result := True;
    Except
      On E: EAEUpdaterURLException Do
        If E.StatusCode <> 304 Then // StatusCode 304 = unchanged; no content was supplied because of ETag
          Raise;
    End;
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

Procedure TAEUpdater.SetETag(Const inURL, inETag: String);
Begin
  If Not inETag.IsEmpty Then
    _etags.AddOrSetValue(inURL, inETag)
  Else
    _etags.Remove(inURL);
End;

Procedure TAEUpdater.SetUpdateFileEtag(const inUpdateFileEtag: String);
Begin
  If Not (csDesigning In Self.ComponentState) And Not (csLoading In Self.ComponentState) And _updatefileurl.IsEmpty Then
    Raise EAEUpdaterException.Create('Update file URL is not defined!');

  _etags.AddOrSetValue(_updatefileurl, inUpdateFileEtag);
End;

Procedure TAEUpdater.Update(Const inFileName: String; inVersion: UInt64 = 0);
Var
  ms: TMemoryStream;
  zip: TZIPFile;
  tb: TBytes;
  fileurl: String;
  product: TAEUpdaterProduct;
Begin
  ms := TMemoryStream.Create;
  Try
    product := _updatefile.Product[_product];

    If Not product.ContainsFile(inFileName) Then
      Raise EAEUpdaterException.Create(inFileName + ' does not exist in the current product!');

    // If no version number was provided, use the available latest. Else, perform verification
    If inVersion = 0 Then
      inVersion := product.ProductFile[inFileName].LatestVersion
    Else
    If Not product.ProductFile[inFileName].ContainsVersion(inVersion) Then
      Raise EAEUpdaterException.Create('Version ' + FileVersionToString(inVersion) + ' does not exist for ' + inFileName + '!');

    // To get the file's complete download URL, we concatenate:
    // - The update file URL, cutting down the update file name
    // - Current products base URL plus a forward slash
    // - Archive file name of the version
    fileurl := _updatefileurl.Substring(0, _updatefileurl.LastIndexOf('/') + 1) +
               product.ProductFile[inFileName].Version[inVersion].RelativeArchiveFileName('/');

    If Not DownloadFile(fileurl, ms) Then
      Exit;

    ms.Position := 0;

    zip := TZIPFile.Create;
    Try
      zip.Open(ms, zmRead);
      Try
        zip.Read(0, tb);
      Finally
        zip.Close;
      End;
    Finally
      FreeAndNil(zip);
    End;
  Finally
    ms.Free;
  End;

  If TFile.Exists(inFileName) then
    TFile.Move(inFileName, inFileName + OLDVERSIONEXT);
  TFile.WriteAllBytes(inFileName, tb);
End;

End.
