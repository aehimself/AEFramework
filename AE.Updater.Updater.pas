Unit AE.Updater.Updater;

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
    _availableupdates: TObjectDictionary<String, TList<UInt64>>;
    _httpclient: TNetHTTPClient;
    _product: TAEUpdaterProduct;
    _updatefile: TAEUpdateFile;
    _updatefileetag: String;
    _updatefileurl: String;
    Procedure DownloadAndParseUpdateFile;
    Procedure DownloadFile(Const inURL: String; Const outStream: TStream; Const inUseEtag: Boolean = False);
    Function GetFileVersionChangelog(Const inFileName: String; Const inVersion: UInt64): String;
    Function GetUpdateableFiles: TArray<String>;
    Function GetUpdateableFileVersions(Const inFileName: String): TArray<UInt64>;
  public
    Class Procedure Cleanup;
    Constructor Create(AOwner: TComponent); Override;
    Destructor Destroy; Override;
    Procedure CheckForUpdates;
    Procedure Update(Const inFileName: String);
    Property FileVersionChangelog[Const inFileName: String; Const inVersion: UInt64]: String Read GetFileVersionChangelog;
    Property UpdateableFiles: TArray<String> Read GetUpdateableFiles;
    Property UpdateableFileVersions[Const inFileName: String]: TArray<UInt64> Read GetUpdateableFileVersions;
  published
    Property UpdateFileEtag: String Read _updatefileetag Write _updatefileetag;
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
  fname, prod: String;
  ver: UInt64;
  fver: TFileVersion;
  pfile: TAEUpdaterProductFile;
  pver: TAEUpdaterProductFileVersion;
Begin
  _availableupdates.Clear;
  _product := nil;

  Try
    DownloadAndParseUpdateFile;
  Except
    On E: EAEUpdaterURLException Do
      If E.StatusCode = 304 Then
        Exit // StatusCode 304 = unchanged; no content was supplied because of ETag
      Else
        Raise;
  End;

  prod := FileProduct(ParamStr(0));
  If prod.IsEmpty Then
    Raise EAEUpdaterException.Create('Product name of running executable can not be determined!');

  If Not _updatefile.ContainsProduct(prod) Then
    Exit;

  _product := _updatefile.Product[prod];
  fname := ExtractFileName(ParamStr(0));

  If Not _product.ContainsFile(fname) Then
    Raise EAEUpdaterException.Create(prod + ' does not contain a file named ' + fname);

  For fname In _product.ProjectFiles Do
  Begin
    fver := FileVersion(fname);
    pfile := _product.ProjectFile[fname];

    For ver In pfile.Versions Do
    Begin
      pver := pfile.Version[ver];

      If pver.DeploymentDate > 0 Then
        Continue;

      If (ver > fver.VersionNumber) Or
        ((ver = fver.VersionNumber) And Not pver.FileHash.IsEmpty And (pver.FileHash <> fver.MD5Hash)) Then
      Begin
        If Not _availableupdates.ContainsKey(fname) Then
          _availableupdates.Add(fname, TList<UInt64>.Create);
        _availableupdates[fname].Add(ver);
      End;
    End;
  End;
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

  _availableupdates := TObjectDictionary <String, TList <UInt64>>.Create([doOwnsValues]);
  _httpclient := TNetHTTPClient.Create(Self);
  _product := nil;
  _updatefile := TAEUpdateFile.Create;
  _updatefileetag := '';
End;

Destructor TAEUpdater.Destroy;
Begin
  FreeAndNil(_availableupdates);
  FreeAndNil(_updatefile);

  inherited;
End;

Procedure TAEUpdater.DownloadAndParseUpdateFile;
Var
  ms: TMemoryStream;
Begin
  If _updatefileurl.IsEmpty Then
    Raise EAEUpdaterException.Create('Update file URL is not defined!');

  If _updatefile.IsLoaded Then
    Exit;

  ms := TMemoryStream.Create;
  Try
    DownloadFile(_updatefileurl, ms, True);
    ms.Position := 0;

    _updatefile.LoadFromStream(ms);
  Finally
    FreeAndNil(ms);
  End;
End;

Procedure TAEUpdater.DownloadFile(Const inURL: String; Const outStream: TStream; Const inUseEtag: Boolean = False);
Var
  headers: TArray<TNameValuePair>;
  hr: IHTTPResponse;
Begin
  If Not inUseEtag Or (_updatefileetag.IsEmpty) Then
    SetLength(headers, 0)
  Else
  Begin
    SetLength(headers, 1);
    headers[0].Name := 'If-None-Match';
    headers[0].Value := _updatefileetag;
  End;

  hr := _httpclient.Get(inURL, nil, headers);

  If Not Assigned(hr) Then
    Raise EAEUpdaterException.Create(inURL + ' could not be downloaded!');
  If hr.StatusCode <> 200 Then
    Raise EAEUpdaterURLException.Create('Requested file could not be downloaded!', inURL, hr.StatusCode, hr.StatusText);

  outStream.CopyFrom(hr.ContentStream);

  If inUseEtag And hr.ContainsHeader('ETag') Then
    _updatefileetag := hr.HeaderValue['ETag'];
End;

Function TAEUpdater.GetFileVersionChangelog(Const inFileName: String; Const inVersion: UInt64): String;
Begin
  Result := _product.ProjectFile[inFileName].Version[inVersion].Changelog;
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

Procedure TAEUpdater.Update(Const inFileName: String);
Var
  ms: TMemoryStream;
  zip: TZIPFile;
  tb: TBytes;
Begin
  ms := TMemoryStream.Create;
  Try
    DownloadFile(_updatefileurl.Substring(0, _updatefileurl.LastIndexOf('/') + 1) + _product.URL + '/' + _product.ProjectFile[inFileName].LatestVersion.ArchiveFileName, ms);
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
