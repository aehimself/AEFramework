{
  AE Framework © 2022 by Akos Eigler is licensed under CC BY 4.0.
  To view a copy of this license, visit http://creativecommons.org/licenses/by/4.0/

  This license requires that reusers give credit to the creator. It allows reusers to distribute, remix, adapt,
  and build upon the material in any medium or format, even for commercial purposes.
}

Unit AE.Comp.HeaderMenuItem;

Interface

Uses Vcl.Menus, Vcl.Graphics, WinApi.Windows, System.Classes;

Type
  TAEHeaderMenuItem = Class(TMenuItem)
  strict private
    Procedure SetEnabled(Const inEnabled: Boolean);
    Function GetEnabled: Boolean;
  protected
    Procedure AdvancedDrawItem(ACanvas: TCanvas; ARect: TRect;
      State: TOwnerDrawState; TopLevel: Boolean); Override;
    Procedure DoAdvancedDrawItem(Sender: TObject; ACanvas: TCanvas;
      ARect: TRect; State: TOwnerDrawState);
    procedure DrawItem(ACanvas: TCanvas; ARect: TRect;
      Selected: Boolean); Override;
    Procedure Loaded; Override;
  Public
    Constructor Create(AOwner: TComponent); Override;
  published
    Property Enabled: Boolean Read GetEnabled Write SetEnabled;
  End;

Implementation

Uses Vcl.Themes, System.SysUtils;

Procedure TAEHeaderMenuItem.AdvancedDrawItem(ACanvas: TCanvas; ARect: TRect;
  State: TOwnerDrawState; TopLevel: Boolean);
Begin
  DoAdvancedDrawItem(Self, ACanvas, ARect, State);
End;

Constructor TAEHeaderMenuItem.Create(AOwner: TComponent);
Begin
  inherited;

  Self.Enabled := False;
  OnAdvancedDrawItem := DoAdvancedDrawItem;
End;

Procedure TAEHeaderMenuItem.DoAdvancedDrawItem(Sender: TObject;
  ACanvas: TCanvas; ARect: TRect; State: TOwnerDrawState);
Begin
  ACanvas.Brush.Color := TStyleManager.ActiveStyle.GetStyleColor
    (scPanelDisabled);
  ACanvas.FillRect(ARect);
  ACanvas.Font.Color := TStyleManager.ActiveStyle.GetStyleFontColor
    (sfWindowTextNormal);
  ACanvas.Font.Style := [fsBold];
  ACanvas.TextRect(ARect, ARect.Left + 3, ARect.Top + 3, StripHotkey(Caption));
End;

procedure TAEHeaderMenuItem.DrawItem(ACanvas: TCanvas; ARect: TRect;
  Selected: Boolean);
begin
  inherited;
  //
end;

Function TAEHeaderMenuItem.GetEnabled: Boolean;
Begin
  Result := inherited Enabled;
End;

Procedure TAEHeaderMenuItem.Loaded;
Begin
  inherited;

  Self.Enabled := False;
End;

Procedure TAEHeaderMenuItem.SetEnabled(Const inEnabled: Boolean);
Begin
  inherited Enabled := False;
End;

End.
