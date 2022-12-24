Unit AE.Comp.Updater.FileProvider.Flat;

Interface

Uses AE.Comp.Updater.FileProvider, System.Classes;

Type
  TAEUpdaterFlatFileProvider = Class(TAEUpdaterFileProvider)
  strict protected
    Procedure InternalProvideFile(Const inFileName: String; Const outStream: TStream); Override;
    Function InternalUpdateRoot: String; Override;
  End;

Implementation

Uses System.SysUtils, System.IOUtils;

Procedure TAEUpdaterFlatFileProvider.InternalProvideFile(Const inFileName: String; Const outStream: TStream);
Var
  fs: TFileStream;
Begin
  fs := TFileStream.Create(inFileName, fmOpenRead + fmShareDenyWrite);
  Try
    outStream.CopyFrom(fs, fs.Size);
  Finally
    FreeAndNil(fs);
  End;
End;

Function TAEUpdaterFlatFileProvider.InternalUpdateRoot: String;
Begin
  Result := Self.UpdateFileName.Substring(0, Self.UpdateFileName.LastIndexOf(TPath.DirectorySeparatorChar) + 1);
End;

End.
