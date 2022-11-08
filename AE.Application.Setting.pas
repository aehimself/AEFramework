Unit AE.Application.Setting;

Interface

Uses System.JSON;

Type
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

Implementation

Uses System.SysUtils;

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

Class Function TAEApplicationSetting.NewFromJSON(Const inJSON: TJSONValue): TAEApplicationSetting;
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

End.
