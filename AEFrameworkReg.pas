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
