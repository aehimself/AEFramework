Unit AE.Comp.Updater.FileProvider.HTTP;

Interface

Uses AE.Comp.Updater.FileProvider, System.Net.HttpClientComponent, System.Generics.Collections, System.Classes;

Type
  EAEUpdaterHTTPFileProviderException = Class(EAEUpdaterFileProviderException)
  strict private
    _statuscode: Integer;
    _statustext: String;
  public
    Constructor Create(Const inMessage: String; Const inURL: String = ''; Const inStatusCode: Integer = -1; Const inStatusText: String = ''); ReIntroduce;
    Property StatusCode: Integer Read _statuscode;
    Property StatusText: String Read _statustext;
  End;

  TAEUpdaterHTTPFileProvider = Class(TAEUpdaterFileProvider)
  strict private
    _etags: TDictionary<String, String>;
    _httpclient: TNetHTTPClient;
    Procedure SetETag(Const inURL, inETag: String);
    Function GetETag(Const inURL: String): String;
    Function GetETags: TArray<String>;
  strict protected
    Procedure InternalProvideFile(Const inFileName: String; Const outStream: TStream); Override;
    Procedure InternalResetCache; Override;
    Function InternalUpdateRoot: String; Override;
  public
    Constructor Create(AOwner: TComponent); Override;
    Destructor Destroy; Override;
    Property ETag[Const inURL: String]: String Read GetETag Write SetETag;
    Property ETags: TArray<String> Read GetETags;
    Property HTTPClient: TNetHTTPClient Read _httpclient;
  End;

Implementation

Uses System.SysUtils, System.Net.URLClient, System.Net.HttpClient;

//
// EAEUpdaterException
//

Constructor EAEUpdaterHTTPFileProviderException.Create(Const inMessage: String; Const inURL: String = ''; Const inStatusCode: Integer = -1; Const inStatusText: String = '');
Begin
  inherited Create(inMessage, inURL);

  _statustext := inStatusText;
  _statuscode := inStatusCode;
End;

//
// TAEUpdaterHTTPFileProvider
//

Constructor TAEUpdaterHTTPFileProvider.Create(AOwner: TComponent);
Begin
  inherited;

  _etags := TDictionary<String, String>.Create;
  _httpclient := TNetHTTPClient.Create(Self);
End;

Destructor TAEUpdaterHTTPFileProvider.Destroy;
Begin
  FreeAndNil(_etags);

  inherited;
End;

Function TAEUpdaterHTTPFileProvider.GetETag(Const inURL: String): String;
Begin
  _etags.TryGetValue(inURL, Result);
End;

Function TAEUpdaterHTTPFileProvider.GetETags: TArray<String>;
Begin
  Result := _etags.Keys.ToArray;
End;

Procedure TAEUpdaterHTTPFileProvider.InternalProvideFile(Const inFileName: String; Const outStream: TStream);
Var
  headers: TArray<TNameValuePair>;
  hr: IHTTPResponse;
Begin
  If Not _etags.ContainsKey(inFileName) Then
    SetLength(headers, 0)
  Else
  Begin
    SetLength(headers, 1);
    headers[0].Name := 'If-None-Match';
    headers[0].Value := _etags[inFileName];
  End;

  hr := _httpclient.Get(inFileName, nil, headers);

  If Not Assigned(hr) Then
    Raise EAEUpdaterHTTPFileProviderException.Create('Downloading the requested file failed, web server could not be reached!', inFileName);

  If hr.StatusCode = 304 Then // 304 was provided because of ETag = no updates are available
    Exit
  Else
  If hr.StatusCode <> 200 Then
    Raise EAEUpdaterHTTPFileProviderException.Create('Requested file could not be downloaded!', inFileName, hr.StatusCode, hr.StatusText);

  outStream.CopyFrom(hr.ContentStream);

  If hr.ContainsHeader('ETag') Then
    Self.ETag[inFileName] :=  hr.HeaderValue['ETag'];
End;

Procedure TAEUpdaterHTTPFileProvider.InternalResetCache;
Begin
  inherited;

  _etags.Clear;
End;

Function TAEUpdaterHTTPFileProvider.InternalUpdateRoot: String;
Begin
  Result := Self.UpdateFileName.Substring(0, Self.UpdateFileName.LastIndexOf('/') + 1);
End;

Procedure TAEUpdaterHTTPFileProvider.SetETag(Const inURL, inETag: String);
Begin
  If Not inETag.IsEmpty Then
    _etags.AddOrSetValue(inURL, inETag)
  Else
    _etags.Remove(inURL);
End;

End.
