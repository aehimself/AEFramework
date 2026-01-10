{
  AE Framework © 2022 by Akos Eigler is licensed under CC BY 4.0.
  To view a copy of this license, visit http://creativecommons.org/licenses/by/4.0/

  This license requires that reusers give credit to the creator. It allows reusers to distribute, remix, adapt,
  and build upon the material in any medium or format, even for commercial purposes.
}

Unit AE.Application.Setting;

Interface

Uses System.JSON;

Type
  TAEApplicationSetting = Class
  strict private
    _changed: Boolean;
    Function GetChanged: Boolean;
  strict protected
    Procedure InternalClear; Virtual;
    Procedure InternalClearChanged; Virtual;
    Procedure SetAsJSON(Const inJSON: TJSONObject); Virtual;
    Procedure SetChanged;
    Function InternalGetChanged: Boolean; Virtual;
    Function GetAsJSON: TJSONObject; Virtual;
  public
    Class Function NewFromJSON(Const inJSON: TJSONValue): TAEApplicationSetting;
    Constructor Create; ReIntroduce; Virtual;
    Procedure AfterConstruction; Override;
    Procedure Clear;
    Procedure ClearChanged;
    Property AsJSON: TJSONObject Read GetAsJSON Write SetAsJSON;
    Property Changed: Boolean Read GetChanged;
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

Procedure TAEApplicationSetting.ClearChanged;
Begin
  Self.InternalClearChanged;

  _changed := False;
End;

Constructor TAEApplicationSetting.Create;
Begin
  inherited;
End;

Function TAEApplicationSetting.GetAsJSON: TJSONObject;
Begin
  Result := TJSONObject.Create;
End;

Function TAEApplicationSetting.GetChanged: Boolean;
Begin
  Result := _changed Or Self.InternalGetChanged;
End;

Procedure TAEApplicationSetting.InternalClear;
Begin
  _changed := False;
End;

Procedure TAEApplicationSetting.InternalClearChanged;
Begin
  // Dummy
End;

Function TAEApplicationSetting.InternalGetChanged: Boolean;
Begin
  Result := False;
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

Procedure TAEApplicationSetting.SetChanged;
Begin
  _changed := True;
End;

End.
