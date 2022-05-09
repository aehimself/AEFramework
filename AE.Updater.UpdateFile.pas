Unit AE.Updater.UpdateFile;

Interface

Uses AE.Application.Settings, System.JSON, System.Generics.Collections, System.Classes;

Type
  TAEUpdaterProductFileVersion = Class(TAEApplicationSetting)
  strict private
    _archivefilename: String;
    _changelog: String;
    _deploymentdate: UInt64;
    _filehash: String;
  strict protected
    Procedure InternalClear; Override;
    Procedure SetAsJSON(Const inJSON: TJSONObject); Override;
    Function GetAsJSON: TJSONObject; Override;
  public
    Property ArchiveFileName: String Read _archivefilename Write _archivefilename;
    Property Changelog: String Read _changelog Write _changelog;
    Property DeploymentDate: UInt64 Read _deploymentdate Write _deploymentdate;
    Property FileHash: String Read _filehash Write _filehash;
  End;

  TAEUpdaterProductFile = Class(TAEApplicationSetting)
  strict private
    _localfilename: String;
    _versions: TObjectDictionary<UInt64, TAEUpdaterProductFileVersion>;
    Procedure SetVersion(Const inVersion: UInt64; Const inFileVersion: TAEUpdaterProductFileVersion);
    Function GetVersion(Const inVersion: UInt64): TAEUpdaterProductFileVersion;
    Function GetVersions: TArray<UInt64>;
  strict protected
    Procedure InternalClear; Override;
    Procedure SetAsJSON(Const inJSON: TJSONObject); Override;
    Function GetAsJSON: TJSONObject; Override;
  public
    Constructor Create; Override;
    Destructor Destroy; Override;
    Procedure RenameVersion(Const inOldVersion, inNewVersion: UInt64);
    Function ContainsVersion(Const inVersion: UInt64): Boolean;
    Function LatestVersion(Const inIncludeUndeployed: Boolean = False): UInt64;
    Property LocalFileName: String Read _localfilename Write _localfilename;
    Property Versions: TArray<UInt64> Read GetVersions;
    Property Version[Const inVersion: UInt64]: TAEUpdaterProductFileVersion Read GetVersion Write SetVersion;
  End;

  TAEUpdaterProduct = Class(TAEApplicationSetting)
  strict private
    _productfiles: TObjectDictionary<String, TAEUpdaterProductFile>;
    _url: String;
    Procedure SetProductFile(Const inFileName: String; Const inProjectFile: TAEUpdaterProductFile);
    Function GetProductFile(Const inFileName: String): TAEUpdaterProductFile;
    Function GetProductFiles: TArray<String>;
  strict protected
    Procedure InternalClear; Override;
    Procedure SetAsJSON(Const inJSON: TJSONObject); Override;
    Function GetAsJSON: TJSONObject; Override;
  public
    Constructor Create; Override;
    Destructor Destroy; Override;
    Procedure RenameProductFile(Const inOldName, inNewName: String);
    Function ContainsFile(Const inFileName: String): Boolean;
    Property ProductFile[Const inFileName: String]: TAEUpdaterProductFile Read GetProductFile Write SetProductFile;
    Property ProductFiles: TArray<String> Read GetProductFiles;
    Property URL: String Read _url Write _url;
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
    Procedure SetAsJSON(Const inJSON: TJSONObject); Override;
    Function GetAsJSON: TJSONObject; Override;
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

Uses System.SysUtils, AE.Misc.ByteUtils;

Const
  TXT_ARCHIVEFILENAME = 'archivefilename';
  TXT_CHANGELOG = 'changelog';
  TXT_DEPLOYMENTDATE = 'deploymentdate';
  TXT_FILEHASH = 'filehash';
  TXT_FILES = 'files';
  TXT_FILENAME = 'filename';
  TXT_PRODUCTS = 'products';
  TXT_URL = 'url';
  TXT_VERSIONS = 'versions';

  //
  // TAEFileVersion
  //

Function TAEUpdaterProductFileVersion.GetAsJSON: TJSONObject;
Begin
  Result := inherited;

  If Not _archivefilename.IsEmpty Then
    Result.AddPair(TXT_ARCHIVEFILENAME, _archivefilename);
  If Not _changelog.IsEmpty Then
    Result.AddPair(TXT_CHANGELOG, _changelog);
  If _deploymentdate > 0 Then
    Result.AddPair(TXT_DEPLOYMENTDATE, _deploymentdate);
  If Not _filehash.IsEmpty Then
    Result.AddPair(TXT_FILEHASH, _filehash);
End;

Procedure TAEUpdaterProductFileVersion.InternalClear;
Begin
  inherited;

  _archivefilename := '';
  _changelog := '';
  _deploymentdate := 0;
  _filehash := '';
End;

Procedure TAEUpdaterProductFileVersion.SetAsJSON(Const inJSON: TJSONObject);
Begin
  inherited;

  If inJSON.GetValue(TXT_ARCHIVEFILENAME) <> nil Then
    _archivefilename := (inJSON.GetValue(TXT_ARCHIVEFILENAME) As TJSONString).Value;
  If inJSON.GetValue(TXT_CHANGELOG) <> nil Then
    _changelog := (inJSON.GetValue(TXT_CHANGELOG) As TJSONString).Value;
  If inJSON.GetValue(TXT_DEPLOYMENTDATE) <> nil Then
    _deploymentdate := (inJSON.GetValue(TXT_DEPLOYMENTDATE) As TJSONNumber).AsType<UInt64>;
  If inJSON.GetValue(TXT_FILEHASH) <> nil Then
    _filehash := (inJSON.GetValue(TXT_FILEHASH) As TJSONString).Value;
End;

//
// TAEProjectFile
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
    _versions.Add(inVersion, TAEUpdaterProductFileVersion.Create);
  Result := _versions[inVersion];
End;

Function TAEUpdaterProductFile.GetVersions: TArray<UInt64>;
Var
  a, b: Integer;
  tmp: UInt64;
Begin
  Result := _versions.Keys.ToArray;

  // Quickly sort the results in a descending order => latest version first
  For a := Low(Result) To High(Result) - 1 Do
    For b := a + 1 To High(Result) Do
      If Result[a] < Result[b] Then
      Begin
        tmp := Result[a];
        Result[a] := Result[b];
        Result[b] := tmp;
      End;
End;

Procedure TAEUpdaterProductFile.InternalClear;
Begin
  inherited;

  _localfilename := '';
  _versions.Clear;
End;

Procedure TAEUpdaterProductFile.RenameVersion(Const inOldVersion, inNewVersion: UInt64);
Begin
 _versions.Add(inNewVersion, _versions.ExtractPair(inOldVersion).Value);
End;

Procedure TAEUpdaterProductFile.SetAsJSON(Const inJSON: TJSONObject);
Var
  jp: TJSONPair;
Begin
  inherited;

  If inJSON.GetValue(TXT_FILENAME) <> nil Then
    _localfilename := (inJSON.GetValue(TXT_FILENAME) As TJSONString).Value;
  If inJSON.GetValue(TXT_VERSIONS) <> nil Then
    For jp In (inJSON.GetValue(TXT_VERSIONS) As TJSONObject) Do
      _versions.Add(UInt64.Parse(jp.JsonString.Value), TAEUpdaterProductFileVersion.NewFromJSON(jp.JsonValue) As TAEUpdaterProductFileVersion);
End;

Procedure TAEUpdaterProductFile.SetVersion(Const inVersion: UInt64; Const inFileVersion: TAEUpdaterProductFileVersion);
Begin
  If Assigned(inFileVersion) Then
    _versions.AddOrSetValue(inVersion, inFileVersion)
  Else
    _versions.Remove(inVersion);
End;

//
// TAEUpdaterProject
//

Function TAEUpdaterProduct.ContainsFile(Const inFileName: String): Boolean;
Begin
  Result := _productfiles.ContainsKey(inFileName);
End;

Constructor TAEUpdaterProduct.Create;
Begin
  inherited;

  _productfiles := TObjectDictionary<String, TAEUpdaterProductFile>.Create([doOwnsValues]);
End;

Destructor TAEUpdaterProduct.Destroy;
Begin
  FreeAndNil(_productfiles);

  inherited;
End;

Function TAEUpdaterProduct.GetAsJSON: TJSONObject;
Var
  fname: String;
  jo, jofile: TJSONObject;
Begin
  Result := inherited;

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

Function TAEUpdaterProduct.GetProductFile(Const inFileName: String): TAEUpdaterProductFile;
Begin
  If Not _productfiles.ContainsKey(inFileName) Then
    _productfiles.Add(inFileName, TAEUpdaterProductFile.Create);
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

  _productfiles.Clear;
  _url := ''
End;

Procedure TAEUpdaterProduct.RenameProductFile(Const inOldName, inNewName: String);
Begin
  _productfiles.Add(inNewName, _productfiles.ExtractPair(inOldName).Value);
End;

Procedure TAEUpdaterProduct.SetAsJSON(Const inJSON: TJSONObject);
Var
  jp: TJSONPair;
Begin
  inherited;

  If inJSON.GetValue(TXT_FILES) <> nil Then
    For jp In (inJSON.GetValue(TXT_FILES) As TJSONObject) Do
      _productfiles.Add(jp.JsonString.Value, TAEUpdaterProductFile.NewFromJSON(jp.JsonValue) As TAEUpdaterProductFile);
  If inJSON.GetValue(TXT_URL) <> nil Then
    _url := (inJSON.GetValue(TXT_URL) As TJSONString).Value;
End;

Procedure TAEUpdaterProduct.SetProductFile(Const inFileName: String; Const inProjectFile: TAEUpdaterProductFile);
Begin
  If Assigned(inProjectFile) Then
    _productfiles.AddOrSetValue(inFileName, inProjectFile)
  Else
    _productfiles.Remove(inFileName);
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

Procedure TAEUpdateFile.LoadFromStream(Const inStream: TStream);
Var
  json: TJSONObject;
  tb: TBytes;
Begin
  Self.Clear;

  SetLength(tb, inStream.Size - inStream.Position);
  inStream.Read(tb, Length(tb));

  tb := Decompress(tb);

  json := TJSONObject(TJSONObject.ParseJSONValue(tb, 0, [TJSONObject.TJSONParseOption.IsUTF8, TJSONObject.TJSONParseOption.RaiseExc]));
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

  tb := Compress(tb);

  outStream.Write(tb, Length(tb));
End;

procedure TAEUpdateFile.SetAsJSON(Const inJSON: TJSONObject);
Var
  jp: TJSONPair;
begin
  inherited;

  If inJSON.GetValue(TXT_PRODUCTS) <> nil Then
    For jp In (inJSON.GetValue(TXT_PRODUCTS) As TJSONObject) Do
      If _productbind.IsEmpty Or (_productbind = jp.JsonString.Value) Then
        _products.Add(jp.JsonString.Value, TAEUpdaterProduct.NewFromJSON(jp.JsonValue) As TAEUpdaterProduct);
End;

Procedure TAEUpdateFile.SetProduct(Const inProductName: String; Const inProduct: TAEUpdaterProduct);
Begin
  If Assigned(inProduct) Then
    _products.AddOrSetValue(inProductName, inProduct)
  Else
    _products.Remove(inProductName);
End;

End.
