{
  AE Framework © 2022 by Akos Eigler is licensed under CC BY 4.0.
  To view a copy of this license, visit http://creativecommons.org/licenses/by/4.0/

  This license requires that reusers give credit to the creator. It allows reusers to distribute, remix, adapt,
  and build upon the material in any medium or format, even for commercial purposes.
}

Unit AE.Comp.Updater.FileProvider.Custom;

Interface

Uses AE.Comp.Updater.FileProvider, System.Classes;

Type
  TCustomFileProviderGetUpdateRootEvent = Procedure(Sender: TObject; Var outUpdateRoot: String) Of Object;
  TCustomFileProviderProvideFileEvent = Procedure(Sender: TObject; Const inFileName: String; Const outStream: TStream) Of Object;

  TAEUpdaterCustomFileProvider = Class(TAEUpdaterFileProvider)
  strict private
    _ongetupdateroot: TCustomFileProviderGetUpdateRootEvent;
    _onprovidefile: TCustomFileProviderProvideFileEvent;
    _onresetcache: TNotifyEvent;
  strict protected
    Procedure InternalProvideFile(Const inFileName: String; Const outStream: TStream); Override;
    Procedure InternalResetCache; Override;
    Function InternalUpdateRoot: String; Override;
  public
    Constructor Create(AOwner: TComponent); Override;
  published
    Property OnGetUpdateRoot: TCustomFileProviderGetUpdateRootEvent Read _ongetupdateroot Write _ongetupdateroot;
    Property OnProvideFile: TCustomFileProviderProvideFileEvent Read _onprovidefile Write _onprovidefile;
    Property OnResetCache: TNotifyEvent Read _onresetcache Write _onresetcache;
  End;

Implementation

Constructor TAEUpdaterCustomFileProvider.Create(AOwner: TComponent);
Begin
  inherited;

  _ongetupdateroot := nil;
  _onprovidefile := nil;
  _onresetcache := nil;
End;

Procedure TAEUpdaterCustomFileProvider.InternalProvideFile(Const inFileName: String; Const outStream: TStream);
Begin
  inherited;

  If Assigned(_onprovidefile) Then
    _onprovidefile(Self, inFileName, outStream);
End;

Procedure TAEUpdaterCustomFileProvider.InternalResetCache;
Begin
  If Assigned(_onresetcache) Then
    _onresetcache(Self);
End;

Function TAEUpdaterCustomFileProvider.InternalUpdateRoot: String;
Begin
  Result := '';

  If Assigned(_ongetupdateroot) Then
    _ongetupdateroot(Self, Result);
End;

End.
