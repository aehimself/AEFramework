{
  AE Framework © 2022 by Akos Eigler is licensed under CC BY 4.0.
  To view a copy of this license, visit http://creativecommons.org/licenses/by/4.0/

  This license requires that reusers give credit to the creator. It allows reusers to distribute, remix, adapt,
  and build upon the material in any medium or format, even for commercial purposes.
}

Unit AEFrameworkReg;

Interface

Procedure Register;

Implementation

Uses System.Classes, AE.Comp.HeaderMenuItem, AE.Comp.PageControl, AE.Comp.ComboBox, AE.Comp.ThreadedTimer, AE.Comp.Updater,
     AE.Comp.DBGrid, AE.Comp.Updater.FileProvider.HTTP, AE.Comp.Updater.FileProvider.Flat, AE.Comp.Updater.FileProvider.Custom;

Procedure Register;
Begin
  RegisterComponents('AE Components', [TAEHeaderMenuItem, TAEPageControl, TAEComboBox, TAEThreadedTimer, TAEDBGrid]);
  RegisterComponents('AE Updater components', [TAEUpdater, TAEUpdaterHTTPFileProvider, TAEUpdaterFlatFileProvider, TAEUpdaterCustomFileProvider]);

  // RegisterComponentEditor(TMyComponent, TMyEditor);
End;

End.
