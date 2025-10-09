Unit AE.DLL.Loader;

Interface

Uses Generics.Collections;

Type
  TAEDLLLoader = Class
  strict private
    _dllname: String;
    _dllhandle: THandle;
    _methods: TDictionary<String, Pointer>;
    Function GetMethod(Const inMethodName: String): Pointer;
    Function GetMethods: TArray<String>;
  strict protected
    Procedure LoadMethods; Virtual;
    Function LoadMethod(Const inMethodName: String): Boolean;
    Function RaiseExceptionIfUnloadFails: Boolean; Virtual;
    Property DLLHandle: THandle Read _dllhandle;
    Property DLLName: String Read _dllname;
  public
    Constructor Create(Const inDLLName: String); ReIntroduce; Virtual;
    Destructor Destroy; Override;
    Property Method[Const inMethodName: String]: Pointer Read GetMethod; Default;
    Property Methods: TArray<String> Read GetMethods;
  End;

Implementation

Uses WinApi.Windows, System.SysUtils;

Constructor TAEDLLLoader.Create(Const inDLLName: String);
Begin
  inherited Create;

  _methods := TDictionary<String, Pointer>.Create;
  _dllname := inDLLName;
  _dllhandle := 0;

  _dllhandle := LoadLibrary(PChar(_dllname));

  If _dllhandle = 0 Then
    RaiseLastOSError;

  Self.LoadMethods;
End;

Destructor TAEDLLLoader.Destroy;
Begin
  If _dllhandle <> 0 Then
  Begin
    If Not FreeLibrary(_dllhandle) And Self.RaiseExceptionIfUnloadFails Then
      RaiseLastOSError;

    _dllhandle := 0;
  End;

  FreeAndNil(_methods);

  inherited;
End;

Function TAEDLLLoader.GetMethod(Const inMethodName: String): Pointer;
Begin
  _methods.TryGetValue(inMethodName, Result);
End;

Function TAEDLLLoader.GetMethods: TArray<String>;
Begin
  Result := _methods.Keys.ToArray;

  TArray.Sort<String>(Result);
End;

Function TAEDLLLoader.LoadMethod(Const inMethodName: String): Boolean;
Var
  tmp: Pointer;
Begin
  tmp := getProcAddress(_dllhandle, PChar(inMethodName));

  If Assigned(tmp) Then
  Begin
    Result := True;

    _methods.Add(inMethodName, tmp);
  End
  Else
    Result := False;
End;

Procedure TAEDLLLoader.LoadMethods;
Begin
  _methods.Clear;
End;

Function TAEDLLLoader.RaiseExceptionIfUnloadFails: Boolean;
Begin
  Result := True;
End;

End.
