{
  AE Framework © 2022 by Akos Eigler is licensed under CC BY 4.0.
  To view a copy of this license, visit http://creativecommons.org/licenses/by/4.0/

  This license requires that reusers give credit to the creator. It allows reusers to distribute, remix, adapt,
  and build upon the material in any medium or format, even for commercial purposes.
}

Unit AE.Comp.Updater.FileProvider;

Interface

Uses System.Classes, System.SysUtils;

Type
  EAEUpdaterFileProviderException = Class(Exception)
  strict private
    _filename: String;
  public
    Constructor Create(Const inMessage: String; Const inFileName: String = ''); ReIntroduce; Virtual;
    Property URL: String Read _filename;
  End;

  TAEUpdaterFileProviderOnFileRequestedEvent = Procedure(Sender: TObject; Const inFileName: String) Of Object;

  TAEUpdaterFileProviderOnFileProvided = Procedure(Sender: TObject; Const inFileName: String; Const outStream: TStream) Of Object;

  TAEUpdaterFileProvider = Class(TComponent)
  strict private
    _onfileprovided: TAEUpdaterFileProviderOnFileProvided;
    _onfilerequested: TAEUpdaterFileProviderOnFileRequestedEvent;
    _updatefilename: String;
  strict protected
    Procedure InternalProvideFile(Const inURL: String; Const outStream: TStream); Virtual; Abstract;
    Procedure InternalResetCache; Virtual;
    Function InternalUpdateRoot: String; Virtual; Abstract;
  public
    Constructor Create(AOwner: TComponent); Override;
    Procedure ProvideFile(Const inFileName: String; Const outStream: TStream);
    Procedure ProvideUpdateFile(Const outStream: TStream);
    Procedure ResetCache;
    Function UpdateRoot: String;
  published
    Property OnFileProvided: TAEUpdaterFileProviderOnFileProvided Read _onfileprovided Write _onfileprovided;
    Property OnFileRequested: TAEUpdaterFileProviderOnFileRequestedEvent Read _onfilerequested Write _onfilerequested;
    Property UpdateFileName: String Read _updatefilename Write _updatefilename;
  End;

Implementation

//
// EAEUpdaterFileProviderException
//

Constructor EAEUpdaterFileProviderException.Create(Const inMessage, inFileName: String);
Begin
  inherited Create(inMessage);

  _filename := inFileName;
End;

//
// TAEUpdaterFileProvider
//

Constructor TAEUpdaterFileProvider.Create(AOwner: TComponent);
Begin
  inherited;

  _onfileprovided := nil;
  _onfilerequested := nil;
  _updatefilename := '';
End;

Procedure TAEUpdaterFileProvider.InternalResetCache;
Begin
  // Dummy
End;

Procedure TAEUpdaterFileProvider.ProvideFile(Const inFileName: String; Const outStream: TStream);
Begin
  If Assigned(_onfilerequested) Then
    _onfilerequested(Self, inFileName);

  Self.InternalProvideFile(inFileName, outStream);

  If Assigned(_onfileprovided) Then
    _onfileprovided(Self, inFileName, outStream);
End;

Procedure TAEUpdaterFileProvider.ProvideUpdateFile(Const outStream: TStream);
Begin
  If _updatefilename.IsEmpty Then
    Raise EAEUpdaterFileProviderException.Create('Update file is not defined!');

  Self.ProvideFile(Self.UpdateFileName, outStream);
End;

Procedure TAEUpdaterFileProvider.ResetCache;
Begin
  Self.InternalResetCache;
End;

Function TAEUpdaterFileProvider.UpdateRoot: String;
Begin
  Result := Self.InternalUpdateRoot;
End;

End.
