{
  AE Framework © 2022 by Akos Eigler is licensed under CC BY 4.0.
  To view a copy of this license, visit http://creativecommons.org/licenses/by/4.0/

  This license requires that reusers give credit to the creator. It allows reusers to distribute, remix, adapt,
  and build upon the material in any medium or format, even for commercial purposes.
}

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
