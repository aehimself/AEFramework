Unit AEFrameworkReg;

Interface

Procedure Register;

Implementation

Uses System.Classes, AE.Comp.HeaderMenuItem, AE.Comp.PageControl, AE.Comp.ComboBox, AE.Comp.ThreadedTimer, AE.Comp.Updater,
     AE.Comp.DBGrid;

Procedure Register;
Begin
  RegisterComponents('AE Components', [TAEHeaderMenuItem]);
  RegisterComponents('AE Components', [TAEPageControl]);
  RegisterComponents('AE Components', [TAEComboBox]);
  RegisterComponents('AE Components', [TAEThreadedTimer]);
  RegisterComponents('AE Components', [TAEUpdater]);
  RegisterComponents('AE Components', [TAEDBGrid]);

  // RegisterComponentEditor(TMyComponent, TMyEditor);
End;

End.
