{
  AE Framework © 2022 by Akos Eigler is licensed under CC BY 4.0.
  To view a copy of this license, visit http://creativecommons.org/licenses/by/4.0/

  This license requires that reusers give credit to the creator. It allows reusers to distribute, remix, adapt,
  and build upon the material in any medium or format, even for commercial purposes.
}

Unit AE.Comp.Updater.UpdateFile;

Interface

Uses AE.Application.Setting, System.JSON, System.Generics.Collections, System.Classes;

Type
  TAEUpdaterChannel = (aucProduction, aucEarlyAccess, aucInternal);

  TAEUpdaterProductFileVersion = Class(TAEApplicationSetting)
  strict private
    _archivefilename: String;
    _changelog: String;
    _channel: TAEUpdaterChannel;
    _deploymentdate: UInt64;
    _filehash: String;
    _parent: TAEApplicationSetting;
    Procedure SetArchiveFileName(Const inArchiveFileName: String);
    Procedure SetChannel(Const inChannel: TAEUpdaterChannel);
    Procedure SetChangelog(Const inChangelog: String);
    Procedure SetDeploymentDate(Const inDeploymentDate: UInt64);
    Procedure SetFileHash(Const inFileHash: String);
  private
    Procedure SetParent(Const inParent: TAEApplicationSetting);
  strict protected
    Procedure InternalClear; Override;
    Procedure SetAsJSON(Const inJSON: TJSONObject); Override;
    Function GetAsJSON: TJSONObject; Override;
  public
    Function RelativeArchiveFileName(Const inSeparator: Char): String;
    Property ArchiveFileName: String Read _archivefilename Write SetArchiveFileName;
    Property Channel: TAEUpdaterChannel Read _channel Write SetChannel;
    Property Changelog: String Read _changelog Write SetChangelog;
    Property DeploymentDate: UInt64 Read _deploymentdate Write SetDeploymentDate;
    Property FileHash: String Read _filehash Write SetFileHash;
    Property Parent: TAEApplicationSetting Read _parent;
  End;

  TAEUpdaterProductFile = Class(TAEApplicationSetting)
  strict private
    _localfilename: String;
    _optional: Boolean;
    _parent: TAEApplicationSetting;
    _versions: TObjectDictionary<UInt64, TAEUpdaterProductFileVersion>;
    Procedure SetLocalFileName(Const inLocalFileName: String);
    Procedure SetOptional(Const inOptional: Boolean);
    Procedure SetVersion(Const inVersion: UInt64; Const inFileVersion: TAEUpdaterProductFileVersion);
    Function GetVersion(Const inVersion: UInt64): TAEUpdaterProductFileVersion;
    Function GetVersions: TArray<UInt64>;
  private
    Procedure SetParent(Const inParent: TAEApplicationSetting);
  strict protected
    Procedure InternalClear; Override;
    Procedure InternalClearChanged; Override;
    Procedure SetAsJSON(Const inJSON: TJSONObject); Override;
    Function GetAsJSON: TJSONObject; Override;
    Function InternalGetChanged: Boolean; Override;
  public
    Constructor Create; Override;
    Destructor Destroy; Override;
    Procedure RenameVersion(Const inOldVersion, inNewVersion: UInt64);
    Function ContainsVersion(Const inVersion: UInt64): Boolean;
    Function LatestVersion(Const inIncludeUndeployed: Boolean = False): UInt64;
    Property LocalFileName: String Read _localfilename Write SetLocalFileName;
    Property Parent: TAEApplicationSetting Read _parent;
    Property Optional: Boolean Read _optional Write SetOptional;
    Property Versions: TArray<UInt64> Read GetVersions;
    Property Version[Const inVersion: UInt64]: TAEUpdaterProductFileVersion Read GetVersion Write SetVersion;
  End;

  TAEUpdaterProductMessage = Class(TAEApplicationSetting)
  strict private
    _channel: TAEUpdaterChannel;
    _message: String;
    Procedure SetChannel(Const inChannel: TAEUpdaterChannel);
    Procedure SetMessage(Const inMessage: String);
  strict protected
    Procedure InternalClear; Override;
    Procedure SetAsJSON(Const inJSON: TJSONObject); Override;
    Function GetAsJSON: TJSONObject; Override;
  public
    Property Channel: TAEUpdaterChannel Read _channel Write SetChannel;
    Property Message: String Read _message Write SetMessage;
  End;

  TAEUpdaterProduct = Class(TAEApplicationSetting)
  strict private
    _messages: TObjectDictionary<UInt64, TAEUpdaterProductMessage>;
    _productfiles: TObjectDictionary<String, TAEUpdaterProductFile>;
    _url: String;
    Procedure SetMessage(Const inMessageDate: UInt64; Const inMessage: TAEUpdaterProductMessage);
    Procedure SetProductFile(Const inFileName: String; Const inProjectFile: TAEUpdaterProductFile);
    Procedure SetURL(Const inURL: String);
    Function GetMessage(Const inMessageDate: UInt64): TAEUpdaterProductMessage;
    Function GetMessages: TArray<UInt64>;
    Function GetProductFile(Const inFileName: String): TAEUpdaterProductFile;
    Function GetProductFiles: TArray<String>;
  strict protected
    Procedure InternalClear; Override;
    Procedure InternalClearChanged; Override;
    Procedure SetAsJSON(Const inJSON: TJSONObject); Override;
    Function GetAsJSON: TJSONObject; Override;
    Function InternalGetChanged: Boolean; Override;
  public
    Constructor Create; Override;
    Destructor Destroy; Override;
    Procedure RenameProductFile(Const inOldName, inNewName: String);
    Function ContainsFile(Const inFileName: String): Boolean;
    Property Message[Const inMessageDate: UInt64]: TAEUpdaterProductMessage Read GetMessage Write SetMessage;
    Property Messages: TArray<UInt64> Read GetMessages;
    Property ProductFile[Const inFileName: String]: TAEUpdaterProductFile Read GetProductFile Write SetProductFile;
    Property ProductFiles: TArray<String> Read GetProductFiles;
    Property URL: String Read _url Write SetURL;
  End;

  TAEUpdateFile = Class(TAEApplicationSetting)
  strict private
    _loaded: Boolean;
    _productbind: String;
    _products: TObjectDictionary<String, TAEUpdaterProduct>;
    Procedure SetProduct(Const inProductName: String; Const inProduct: TAEUpdaterProduct);
    Function GetProduct(Const inProductName: String): TAEUpdaterProduct;
    Function GetProducts: TArray<String>;
  strict protected
    Procedure InternalClear; Override;
    Procedure InternalClearChanged; Override;
    Procedure SetAsJSON(Const inJSON: TJSONObject); Override;
    Function GetAsJSON: TJSONObject; Override;
    Function InternalGetChanged: Boolean; Override;
  public
    Constructor Create; Override;
    Destructor Destroy; Override;
    Procedure LoadFromStream(Const inStream: TStream);
    Procedure RenameProduct(Const inOldName, inNewName: String);
    Procedure SaveToStream(Const outStream: TStream);
    Function ContainsProduct(Const inProductName: String): Boolean;
    Property IsLoaded: Boolean Read _loaded;
    Property Product[Const inProductName: String]: TAEUpdaterProduct Read GetProduct Write SetProduct;
    Property ProductBind: String Read _productbind Write _productbind;
    Property Products: TArray<String> Read GetProducts;
  End;

Implementation

Uses System.SysUtils, System.Generics.Defaults;

Const
  TXT_ARCHIVEFILENAME = 'archivefilename';
  TXT_CHANGELOG = 'changelog';
  TXT_CHANNEL = 'channel';
  TXT_DEPLOYMENTDATE = 'deploymentdate';
  TXT_FILEHASH = 'filehash';
  TXT_FILES = 'files';
  TXT_FILENAME = 'filename';
  TXT_PRODUCTS = 'products';
  TXT_URL = 'url';
  TXT_VERSIONS = 'versions';
  TXT_MESSAGE = 'message';
  TXT_MESSAGES = 'messages';
  TXT_OPTIONAL = 'optional';

//
// TAEProductFileVersion
//

Function TAEUpdaterProductFileVersion.GetAsJSON: TJSONObject;
Begin
  Result := inherited;

  If Not _archivefilename.IsEmpty Then
    Result.AddPair(TXT_ARCHIVEFILENAME, _archivefilename);
  If Not _changelog.IsEmpty Then
    Result.AddPair(TXT_CHANGELOG, _changelog);
  If _channel <> aucProduction Then
    Result.AddPair(TXT_CHANNEL, TJSONNumber.Create(Integer(_channel)));
  If _deploymentdate > 0 Then
    Result.AddPair(TXT_DEPLOYMENTDATE, TJSONNumber.Create(_deploymentdate));
  If Not _filehash.IsEmpty Then
    Result.AddPair(TXT_FILEHASH, _filehash);
End;

Function TAEUpdaterProductFileVersion.RelativeArchiveFileName(Const inSeparator: Char): String;
Var
  s: String;
Begin
  s := ((Self.Parent As TAEUpdaterProductFile).Parent As TAEUpdaterProduct).URL;
  If Not s.IsEmpty Then
    s := s + inSeparator;

  Result := s + _archivefilename;
End;

Procedure TAEUpdaterProductFileVersion.InternalClear;
Begin
  inherited;

  _archivefilename := '';
  _changelog := '';
  _channel := aucProduction;
  _deploymentdate := 0;
  _filehash := '';
End;

Procedure TAEUpdaterProductFileVersion.SetArchiveFileName(Const inArchiveFileName: String);
Begin
  If _archivefilename = inArchiveFileName Then
    Exit;

  _archivefilename := inArchiveFileName;

  Self.SetChanged;
End;

Procedure TAEUpdaterProductFileVersion.SetAsJSON(Const inJSON: TJSONObject);
Begin
  inherited;

  If inJSON.GetValue(TXT_ARCHIVEFILENAME) <> nil Then
    _archivefilename := (inJSON.GetValue(TXT_ARCHIVEFILENAME) As TJSONString).Value;
  If inJSON.GetValue(TXT_CHANGELOG) <> nil Then
    _changelog := (inJSON.GetValue(TXT_CHANGELOG) As TJSONString).Value;
  If inJSON.GetValue(TXT_CHANNEL) <> nil Then
    _channel := TAEUpdaterChannel((inJSON.GetValue(TXT_CHANNEL) As TJSONNumber).AsInt);
  If inJSON.GetValue(TXT_DEPLOYMENTDATE) <> nil Then
    _deploymentdate := inJSON.GetValue(TXT_DEPLOYMENTDATE).GetValue<UInt64>;
  If inJSON.GetValue(TXT_FILEHASH) <> nil Then
    _filehash := (inJSON.GetValue(TXT_FILEHASH) As TJSONString).Value;
End;

Procedure TAEUpdaterProductFileVersion.SetChangelog(Const inChangelog: String);
Begin
  If _changelog = inChangelog Then
    Exit;

  _changelog := inChangelog;

  Self.SetChanged;
End;

Procedure TAEUpdaterProductFileVersion.SetChannel(Const inChannel: TAEUpdaterChannel);
Begin
  If _channel = inChannel Then
    Exit;

  _channel := inChannel;

  Self.SetChanged;
End;

Procedure TAEUpdaterProductFileVersion.SetDeploymentDate(Const inDeploymentDate: UInt64);
Begin
  If _deploymentdate = inDeploymentDate Then
    Exit;

  _deploymentdate := inDeploymentDate;

  Self.SetChanged;
End;

Procedure TAEUpdaterProductFileVersion.SetFileHash(Const inFileHash: String);
Begin
  If _filehash = inFileHash Then
    Exit;

  _filehash := inFileHash;

  Self.SetChanged;
End;

Procedure TAEUpdaterProductFileVersion.SetParent(Const inParent: TAEApplicationSetting);
Begin
  _parent := inParent;
End;

//
// TAEProductFile
//

Function TAEUpdaterProductFile.ContainsVersion(Const inVersion: UInt64): Boolean;
Begin
  Result := _versions.ContainsKey(inVersion);
End;

Constructor TAEUpdaterProductFile.Create;
Begin
  inherited;

  _versions := TObjectDictionary<UInt64, TAEUpdaterProductFileVersion>.Create([doOwnsValues]);
End;

Destructor TAEUpdaterProductFile.Destroy;
Begin
  FreeAndNil(_versions);

  inherited;
End;

Function TAEUpdaterProductFile.GetAsJSON: TJSONObject;
Var
  ver: UInt64;
  jo, jover: TJSONObject;
Begin
  Result := inherited;

  If Not _localfilename.IsEmpty Then
    Result.AddPair(TXT_FILENAME, _localfilename);

  If _optional Then
    Result.AddPair(TXT_OPTIONAL, TJSONBool.Create(_optional));

  If _versions.Count > 0 Then
  Begin
    jo := TJSONObject.Create;
    Try
      For ver In Self.Versions Do
      Begin
        jover := _versions[ver].AsJSON;
        If jover.Count = 0 Then
          FreeAndNil(jover)
        Else
          jo.AddPair(ver.ToString, jover);
      End;
    Finally
      If jo.Count = 0 Then
        FreeAndNil(jo)
      Else
        Result.AddPair(TXT_VERSIONS, jo);
    End;
  End;
End;

Function TAEUpdaterProductFile.LatestVersion(Const inIncludeUndeployed: Boolean = False): UInt64;
Var
  ver: UInt64;
Begin
  Result := 0;

  For ver In _versions.Keys Do
    If (ver > Result) And (inIncludeUndeployed Or (_versions[ver].DeploymentDate > 0)) Then
      Result := ver;
End;

Function TAEUpdaterProductFile.GetVersion(Const inVersion: UInt64): TAEUpdaterProductFileVersion;
Begin
  If Not _versions.ContainsKey(inVersion) Then
  Begin
    _versions.Add(inVersion, TAEUpdaterProductFileVersion.Create);
    _versions[inversion].SetParent(Self);
  End;
  Result := _versions[inVersion];
End;

Function TAEUpdaterProductFile.GetVersions: TArray<UInt64>;
Begin
  Result := _versions.Keys.ToArray;

  TArray.Sort<UInt64>(Result, TComparer<UInt64>.Construct(
    Function(Const Left, Right: UInt64): Integer
    Begin
      Result := -1 * TComparer<Double>.Default.Compare(Left, Right);
    End
  ));
End;

Procedure TAEUpdaterProductFile.InternalClear;
Begin
  inherited;

  _localfilename := '';
  _optional := False;
  _versions.Clear;
End;

Procedure TAEUpdaterProductFile.InternalClearChanged;
Var
  ver: TAEUpdaterProductFileVersion;
Begin
  inherited;

  For ver In _versions.Values Do
    ver.ClearChanged;
End;

Function TAEUpdaterProductFile.InternalGetChanged: Boolean;
Var
  ver: TAEUpdaterProductFileVersion;
Begin
  Result := False;

  For ver In _versions.Values Do
    Result := Result Or ver.Changed;
End;

Procedure TAEUpdaterProductFile.RenameVersion(Const inOldVersion, inNewVersion: UInt64);
Begin
  _versions.Add(inNewVersion, _versions.ExtractPair(inOldVersion).Value);

  Self.SetChanged;
End;

Procedure TAEUpdaterProductFile.SetAsJSON(Const inJSON: TJSONObject);
Var
  jp: TJSONPair;
Begin
  inherited;

  If inJSON.GetValue(TXT_FILENAME) <> nil Then
    _localfilename := (inJSON.GetValue(TXT_FILENAME) As TJSONString).Value;
  If inJSON.GetValue(TXT_OPTIONAL) <> nil Then
    _optional := (inJSON.GetValue(TXT_OPTIONAL) As TJSONBool).AsBoolean;
  If inJSON.GetValue(TXT_VERSIONS) <> nil Then
    For jp In (inJSON.GetValue(TXT_VERSIONS) As TJSONObject) Do
      Self.Version[UInt64.Parse(jp.JsonString.Value)].AsJSON := TJSONObject(jp.JsonValue);
End;

Procedure TAEUpdaterProductFile.SetLocalFileName(Const inLocalFileName: String);
Begin
  If _localfilename = inLocalFileName Then
    Exit;

  _localfilename := inLocalFileName;

  Self.SetChanged;
End;

Procedure TAEUpdaterProductFile.SetOptional(Const inOptional: Boolean);
Begin
  If _optional = inOptional Then
    Exit;

  _optional := inOptional;

  Self.SetChanged;
End;

Procedure TAEUpdaterProductFile.SetParent(Const inParent: TAEApplicationSetting);
Begin
  _parent := inParent;
End;

Procedure TAEUpdaterProductFile.SetVersion(Const inVersion: UInt64; Const inFileVersion: TAEUpdaterProductFileVersion);
Begin
  If Assigned(inFileVersion) Then
  Begin
    _versions.AddOrSetValue(inVersion, inFileVersion);

    Self.SetChanged;
  End
  Else If _versions.ContainsKey(inVersion) Then
  Begin
    _versions.Remove(inVersion);

    Self.SetChanged;
  End;
End;

//
// TAEUpdaterProductMessage
//

Function TAEUpdaterProductMessage.GetAsJSON: TJSONObject;
Begin
 Result := inherited;

 If _channel <> aucProduction Then Result.AddPair(TXT_CHANNEL, TJSONNumber.Create(Integer(_channel)));
 If Not _message.IsEmpty Then Result.AddPair(TXT_MESSAGE, _message);
End;

Procedure TAEUpdaterProductMessage.InternalClear;
Begin
 inherited;

 _channel := aucProduction;
 _message := '';
End;

Procedure TAEUpdaterProductMessage.SetAsJSON(Const inJSON: TJSONObject);
Begin
 inherited;

 If inJSON.GetValue(TXT_CHANNEL) <> nil Then _channel := TAEUpdaterChannel((inJSON.GetValue(TXT_CHANNEL) As TJSONNumber).AsInt);
 If inJSON.GetValue(TXT_MESSAGE) <> nil Then _message := (inJSON.GetValue(TXT_MESSAGE) As TJSONString).Value;
End;

Procedure TAEUpdaterProductMessage.SetChannel(Const inChannel: TAEUpdaterChannel);
Begin
  If _channel = inChannel Then
    Exit;

  _channel := inChannel;

  Self.SetChanged;
End;

Procedure TAEUpdaterProductMessage.SetMessage(Const inMessage: String);
Begin
  If _message = inMessage Then
    Exit;

  _message := inMessage;

  Self.SetChanged;
End;

//
// TAEUpdaterProduct
//

Function TAEUpdaterProduct.ContainsFile(Const inFileName: String): Boolean;
Begin
  Result := _productfiles.ContainsKey(inFileName);
End;

Constructor TAEUpdaterProduct.Create;
Begin
  inherited;

  _messages := TObjectDictionary<UInt64, TAEUpdaterProductMessage>.Create([doOwnsValues]);
  _productfiles := TObjectDictionary<String, TAEUpdaterProductFile>.Create([doOwnsValues]);
End;

Destructor TAEUpdaterProduct.Destroy;
Begin
  FreeAndNil(_messages);
  FreeAndNil(_productfiles);

  inherited;
End;

Function TAEUpdaterProduct.GetAsJSON: TJSONObject;
Var
  fname: String;
  jo, jofile: TJSONObject;
  md: UInt64;
Begin
  Result := inherited;

  If _messages.Count > 0 Then
  Begin
    jo := TJSONObject.Create;
    Try
      For md In Self.Messages Do
        jo.AddPair(md.ToString, _messages[md].AsJSON);
    Finally
      If jo.Count = 0 Then
        FreeAndNil(jo)
      Else
        Result.AddPair(TXT_MESSAGES, jo);
    End;
  End;

  If _productfiles.Count > 0 Then
  Begin
    jo := TJSONObject.Create;
    Try
      For fname In Self.ProductFiles Do
      Begin
        jofile := _productfiles[fname].AsJSON;
        If jofile.Count = 0 Then
          FreeAndNil(jofile)
        Else
          jo.AddPair(fname, jofile);
      End;
    Finally
      If jo.Count = 0 Then
        FreeAndNil(jo)
      Else
        Result.AddPair(TXT_FILES, jo);
    End;
  End;

  If Not _url.IsEmpty Then
    Result.AddPair(TXT_URL, _url);
End;

Function TAEUpdaterProduct.GetMessage(Const inMessageDate: UInt64): TAEUpdaterProductMessage;
Begin
  If Not _messages.ContainsKey(inMessageDate) Then _messages.Add(inMessageDate, TAEUpdaterProductMessage.Create);
  Result := _messages[inMessageDate];
End;

Function TAEUpdaterProduct.GetMessages: TArray<UInt64>;
Var
  a, b: Integer;
  tmp: UInt64;
Begin
  Result := _messages.Keys.ToArray;

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

Function TAEUpdaterProduct.GetProductFile(Const inFileName: String): TAEUpdaterProductFile;
Begin
  If Not _productfiles.ContainsKey(inFileName) Then
  Begin
    _productfiles.Add(inFileName, TAEUpdaterProductFile.Create);
    _productfiles[inFileName].SetParent(Self);
  End;
  Result := _productfiles[inFileName];
End;

Function TAEUpdaterProduct.GetProductFiles: TArray<String>;
Begin
  Result := _productfiles.Keys.ToArray;
  TArray.Sort<String>(Result);
End;

Procedure TAEUpdaterProduct.InternalClear;
Begin
  inherited;

  _messages.Clear;
  _productfiles.Clear;
  _url := ''
End;

Procedure TAEUpdaterProduct.InternalClearChanged;
Var
  msg: TAEUpdaterProductMessage;
  pfile: TAEUpdaterProductFile;
Begin
  inherited;

  For msg In _messages.Values Do
    msg.ClearChanged;

  For pfile In _productfiles.Values Do
    pfile.ClearChanged;
End;

Function TAEUpdaterProduct.InternalGetChanged: Boolean;
Var
  msg: TAEUpdaterProductMessage;
  pfile: TAEUpdaterProductFile;
Begin
  Result := False;

  For msg In _messages.Values Do
    Result := Result Or msg.Changed;

  For pfile In _productfiles.Values Do
    Result := Result Or pfile.Changed;
End;

Procedure TAEUpdaterProduct.RenameProductFile(Const inOldName, inNewName: String);
Begin
  _productfiles.Add(inNewName, _productfiles.ExtractPair(inOldName).Value);

  Self.SetChanged;
End;

Procedure TAEUpdaterProduct.SetAsJSON(Const inJSON: TJSONObject);
Var
  jp: TJSONPair;
Begin
  inherited;

  If inJSON.GetValue(TXT_MESSAGES) <> nil Then
    For jp In (inJSON.GetValue(TXT_MESSAGES) As TJSONObject) Do
      Self.Message[UInt64.Parse(jp.JsonString.Value)].AsJSON := TJSONObject(jp.JsonValue);
  If inJSON.GetValue(TXT_FILES) <> nil Then
    For jp In (inJSON.GetValue(TXT_FILES) As TJSONObject) Do
      Self.ProductFile[jp.JsonString.Value].AsJSON := TJSONObject(jp.JsonValue);
  If inJSON.GetValue(TXT_URL) <> nil Then
    _url := (inJSON.GetValue(TXT_URL) As TJSONString).Value;
End;

Procedure TAEUpdaterProduct.SetMessage(Const inMessageDate: UInt64; Const inMessage: TAEUpdaterProductMessage);
Begin
  If Assigned(inMessage) Then
  Begin
    _messages.AddOrSetValue(inMessageDate, inMessage);

    Self.SetChanged;
  End
  Else If _messages.ContainsKey(inMessageDate) Then
  Begin
    _messages.Remove(inMessageDate);

    Self.SetChanged;
  End;
End;

Procedure TAEUpdaterProduct.SetProductFile(Const inFileName: String; Const inProjectFile: TAEUpdaterProductFile);
Begin
  If Assigned(inProjectFile) Then
  Begin
    _productfiles.AddOrSetValue(inFileName, inProjectFile);

    Self.SetChanged;
  End
  Else If _productfiles.ContainsKey(inFileName) Then
  Begin
    _productfiles.Remove(inFileName);

    Self.SetChanged;
  End;
End;

Procedure TAEUpdaterProduct.SetURL(Const inURL: String);
Begin
  If _url = inURL Then
    Exit;

  _url := inURL;

  Self.SetChanged;
End;

//
// TAEUpdaterFile
//

Function TAEUpdateFile.ContainsProduct(Const inProductName: String): Boolean;
Begin
  Result := _products.ContainsKey(inProductName);
End;

Constructor TAEUpdateFile.Create;
Begin
  inherited;

  _productbind := '';
  _products := TObjectDictionary<String, TAEUpdaterProduct>.Create([doOwnsValues]);
End;

Destructor TAEUpdateFile.Destroy;
Begin
  FreeAndNil(_products);

  inherited;
End;

Function TAEUpdateFile.GetAsJSON: TJSONObject;
Var
  jo, joprod: TJSONObject;
  prod: String;
Begin
  // !!! Warning !!!
  // Clearing the changed flag only happens in .SaveToStream. If you do not rely on that method because you have a custom
  // saving solution and extract the JSON object only, don't forget to call .ClearChanged to reset the .Changed state of
  // the update file!

  Result := inherited;

  If _products.Count > 0 Then
  Begin
    jo := TJSONObject.Create;

    For prod In Self.Products Do
    Begin
      joprod := _products[prod].AsJSON;

      If joprod.Count = 0 Then
        FreeAndNil(joprod)
      Else
        jo.AddPair(prod, joprod);
    End;

    If jo.Count = 0 Then
      FreeAndNil(jo)
    Else
      Result.AddPair(TXT_PRODUCTS, jo);
  End;
End;

Function TAEUpdateFile.GetProduct(Const inProductName: String): TAEUpdaterProduct;
Begin
  If Not _products.ContainsKey(inProductName) Then
    _products.Add(inProductName, TAEUpdaterProduct.Create);
  Result := _products[inProductName];
End;

Function TAEUpdateFile.GetProducts: TArray<String>;
Begin
  Result := _products.Keys.ToArray;
  TArray.Sort<String>(Result);
End;

Procedure TAEUpdateFile.InternalClear;
Begin
  inherited;

  _loaded := False;
  _products.Clear;
End;

Procedure TAEUpdateFile.InternalClearChanged;
Var
  prod: TAEUpdaterProduct;
Begin
  inherited;

  For prod In _products.Values Do
    prod.ClearChanged;
End;

Function TAEUpdateFile.InternalGetChanged: Boolean;
Var
  prod: TAEUpdaterProduct;
Begin
  Result := False;

  For prod In _products.Values Do
    Result := Result Or prod.Changed;
End;

Procedure TAEUpdateFile.LoadFromStream(Const inStream: TStream);
Var
  json: TJSONObject;
  tb: TBytes;
Begin
  Self.Clear;

  SetLength(tb, inStream.Size - inStream.Position);
  inStream.Read(tb, Length(tb));

  {$IF CompilerVersion > 32} // Everything above 10.2...?
  json := TJSONObject(TJSONObject.ParseJSONValue(tb, 0, [TJSONObject.TJSONParseOption.IsUTF8, TJSONObject.TJSONParseOption.RaiseExc]));
  {$ELSE}
  json := TJSONObject(TJSONObject.ParseJSONValue(tb, 0, [TJSONObject.TJSONParseOption.IsUTF8]));
  If Not Assigned(json) Then
    Raise EJSONException.Create('Update file is not a valid JSON document!');
  {$ENDIF}

  Try
    Self.AsJSON := json;

    _loaded := True;
  Finally
    FreeAndNil(json);
  End;
End;

Procedure TAEUpdateFile.RenameProduct(Const inOldName, inNewName: String);
Begin
 _products.Add(inNewName, _products.ExtractPair(inOldName).Value);
End;

Procedure TAEUpdateFile.SaveToStream(Const outStream: TStream);
Var
  json: TJSONObject;
  tb: TBytes;
Begin
  json := Self.AsJSON;
  Try
    SetLength(tb, json.EstimatedByteSize);
    SetLength(tb, json.ToBytes(tb, 0));
  Finally
    FreeAndNil(json);
  End;

  outStream.Write(tb, Length(tb));

  Self.ClearChanged;
End;

procedure TAEUpdateFile.SetAsJSON(Const inJSON: TJSONObject);
Var
  jp: TJSONPair;
begin
  inherited;

  If inJSON.GetValue(TXT_PRODUCTS) <> nil Then
    For jp In (inJSON.GetValue(TXT_PRODUCTS) As TJSONObject) Do
      If _productbind.IsEmpty Or (_productbind = jp.JsonString.Value) Then
        Self.Product[jp.JsonString.Value].AsJSON := TJSONObject(jp.JsonValue);

  Self.ClearChanged;
End;

Procedure TAEUpdateFile.SetProduct(Const inProductName: String; Const inProduct: TAEUpdaterProduct);
Begin
  If Assigned(inProduct) Then
  Begin
    _products.AddOrSetValue(inProductName, inProduct);

    Self.SetChanged;
  End
  Else If _products.ContainsKey(inProductName) Then
  Begin
    _products.Remove(inProductName);

    Self.SetChanged;
  End;
End;

End.
