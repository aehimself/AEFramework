{
  AE Framework © 2025 by Akos Eigler is licensed under CC BY 4.0.
  To view a copy of this license, visit http://creativecommons.org/licenses/by/4.0/

  This license requires that reusers give credit to the creator. It allows reusers to distribute, remix, adapt,
  and build upon the material in any medium or format, even for commercial purposes.
}

Unit AE.Comp.TagEditor;

Interface

Uses Vcl.ExtCtrls, Vcl.Forms, System.Classes, Vcl.Buttons, WinApi.Messages, Vcl.Controls;

Const
  WM_REMOVEBTN = WM_USER + 199;

Type
  TTagRemovedEvent = Procedure(Sender: TObject; Const inTag: String) Of Object;

  TTagComponent = Class(TCustomPanel)
  strict private
    _drawactive: Boolean;
    Procedure CMMOUSEENTER(Var inMessage: TMessage); Message CM_MOUSEENTER;
    Procedure CMMOUSELEAVE(Var inMessage: TMessage); Message CM_MOUSELEAVE;
  protected
    Procedure Paint; Override;
  public
    Constructor Create(AOwner: TComponent); Override;
  End;

  TAETagEditor = Class(TCustomPanel)
  strict private
    _selectedtags: TStringList;
    _scrollbox: TScrollBox;
    _ontagremoved: TTagRemovedEvent;
    _tagwidth: Integer;
    Procedure TagClick(Sender: TObject);
    Procedure SelectedTagsChanged(Sender: TObject);
    Procedure SetSelectedTags(Const inSelectedTags: TStringList);
    Procedure SetTagWidth(Const inTagWidth: Integer);
    Procedure WMREMOVEBTN(Var inMessage: TMessage); Message WM_REMOVEBTN;
  strict protected
    Procedure AddTagButton(Const inTag: String);
    Procedure TagRemoved(Const inTag: String); Virtual;
    Procedure RemoveButton(Const inTag: String);
    Function FindTagButton(Const inTag: String): TTagComponent;
  protected
    Procedure Loaded; Override;
  public
    Constructor Create(AOwner: TComponent); Override;
    Destructor Destroy; Override;
  published
    Property SelectedTags: TStringList Read _selectedtags Write SetSelectedTags;
    Property TagWidth: Integer Read _tagwidth Write SetTagWidth Default 75;
  published // From TPanel
    property Align;
    property Alignment;
    property Anchors;
    property AutoSize;
    property BevelEdges;
    property BevelInner;
    property BevelKind;
    property BevelOuter;
    property BevelWidth;
    property BiDiMode;
    property BorderWidth;
    property BorderStyle;
    property Color;
    property Constraints;
    property Ctl3D;
    property DoubleBuffered;
    property DoubleBufferedMode;
    property Enabled;
    property FullRepaint;
    property Font;
    property Locked;
    property Padding;
    property ParentBiDiMode;
    property ParentBackground;
    property ParentColor;
    property ParentCtl3D;
    property ParentDoubleBuffered;
    property ParentFont;
    property ParentShowHint;
    property PopupMenu;
    property TabOrder;
    property TabStop;
    property Visible;
    property StyleElements;
    property StyleName;
    property OnAlignInsertBefore;
    property OnAlignPosition;
    property OnCanResize;
    property OnConstrainedResize;
    property OnContextPopup;
    property OnDblClick;
    property OnEnter;
    property OnExit;
    property OnGesture;
    property OnGetSiteInfo;
    property OnMouseActivate;
    property OnMouseDown;
    property OnMouseEnter;
    property OnMouseLeave;
    property OnMouseMove;
    property OnMouseUp;
    property OnResize;
    Property OnTagRemoved: TTagRemovedEvent Read _ontagremoved Write _ontagremoved;
  End;

Implementation

Uses System.SysUtils, WinApi.Windows, Vcl.Graphics, Vcl.Themes;

//
// TTagComponent
//

Procedure TTagComponent.CMMOUSEENTER(Var inMessage: TMessage);
Begin
  inherited;

  _drawactive := True;

  Self.Repaint;
End;

Procedure TTagComponent.CMMOUSELEAVE(Var inMessage: TMessage);
Begin
  inherited;

  _drawactive := False;

  Self.Repaint;
End;

Constructor TTagComponent.Create(AOwner: TComponent);
Begin
  inherited;

  _drawactive := False;
  Self.ShowHint := True;
  Self.ParentBackground := True;
End;

Procedure TTagComponent.Paint;
Var
  textrect: TRect;
  s: String;
Begin
  Self.Canvas.Brush.Color := TStyleManager.ActiveStyle.GetStyleColor(scEdit);

  If _drawactive Then
  Begin
    Self.Canvas.Pen.Color := TStyleManager.ActiveStyle.GetStyleFontColor(sfWindowTextDisabled);
    Self.Canvas.Pen.Width := 2;
  End
  Else
  Begin
    Self.Canvas.Pen.Color := TStyleManager.ActiveStyle.GetStyleColor(scBorder);
    Self.Canvas.Pen.Width := 1;
  End;

  Self.Canvas.Polygon([
    TPoint.Create(1, 1),                                              // Top left point
    TPoint.Create(Self.ClientWidth - 8, 1),                          // Top right point
    TPoint.Create(Self.ClientWidth - 1, Self.ClientHeight Div 2),     // Right arrowhead
    TPoint.Create(Self.ClientWidth - 8, Self.ClientHeight - 1),          // Bottom right point
    TPoint.Create(1, Self.ClientHeight - 1),                              // Bottom left point
    TPoint.Create(8, Self.ClientHeight Div 2)                        // Left arrowtail
  ]);

  textrect := TRect.Create(10, 3, Self.ClientWidth - 10, Self.ClientHeight - 3);
  s := Trim(Self.Caption);

  Self.Canvas.Font.Assign(Self.Font);
  Self.Canvas.Font.Color := TStyleManager.ActiveStyle.GetStyleFontColor(sfWindowTextNormal);
  Self.Canvas.TextRect(textrect, s, [tfSingleLine, tfVerticalCenter, tfCenter, tfEndEllipsis]);
End;

//
// TAETagEditor
//

Procedure TAETagEditor.AddTagButton(Const inTag: String);
Var
  btn: TTagComponent;
Begin
  If Assigned(FindTagButton(inTag)) Then
    Exit;

  btn := TTagComponent.Create(_scrollbox);
  btn.Parent := _scrollbox;
  btn.Height := 25;
  btn.Width := _tagwidth;
  btn.Caption := inTag;
  btn.Top := 0;
  btn.Height := _scrollbox.ClientHeight;
  btn.Anchors := [akLeft, akTop, akBottom];
  btn.Left := ((_scrollbox.ComponentCount - 1) * _tagwidth) - _scrollbox.HorzScrollBar.Position;
  btn.OnClick := TagClick;
  btn.Hint := inTag;
End;

Constructor TAETagEditor.Create(AOwner: TComponent);
Begin
  inherited;

  _selectedtags := TStringList.Create;
  _selectedtags.OnChange := SelectedTagsChanged;

  _scrollbox := TScrollBox.Create(Self);
  _scrollbox.Parent := Self;
  _scrollbox.Align := alClient;
  _scrollbox.BorderStyle := bsNone;
  _scrollbox.HorzScrollBar.Smooth := True;
  _scrollbox.HorzScrollBar.Tracking := True;
  _scrollbox.UseWheelForScrolling := True;
  _scrollbox.ParentBackground := True;

  _tagwidth := 75;
End;

Destructor TAETagEditor.Destroy;
Begin
  FreeAndNil(_selectedtags);

  inherited;
End;

Function TAETagEditor.FindTagButton(Const inTag: String): TTagComponent;
Var
  a: NativeInt;
Begin
  Result := nil;

  For a := 0 To _scrollbox.ComponentCount - 1 Do
    If (_scrollbox.Components[a] As TTagComponent).Caption = inTag Then
    Begin
      Result := TTagComponent(_scrollbox.Components[a]);

      Exit;
    End;
End;

procedure TAETagEditor.Loaded;
begin
  inherited;

  _scrollbox.ParentBackground := True;
end;

Procedure TAETagEditor.RemoveButton(Const inTag: String);
Var
  a: NativeInt;
  found: Boolean;
Begin
  found := False;

  _scrollbox.LockDrawing;
  Try
    a := 0;

    While a < _scrollbox.ComponentCount Do
    Begin
      If found Then
      Begin
        TTagComponent(_scrollbox.Components[a]).Left := (a * _tagwidth) - _scrollbox.HorzScrollBar.Position;

        Inc(a);
      End
      Else If TTagComponent(_scrollbox.Components[a]).Caption = inTag Then
      Begin
        _scrollbox.Components[a].Free;

        Self.TagRemoved(inTag);

        found := True;
      End
      Else
        Inc(a);
    End;

    For a := 0 To _scrollbox.ComponentCount - 1 Do
      TTagComponent(_scrollbox.Components[a]).Height := _scrollbox.ClientHeight;
  Finally
    _scrollbox.UnlockDrawing;
  End;
End;

Procedure TAETagEditor.SelectedTagsChanged(Sender: TObject);
Var
  a: NativeInt;
Begin
  _scrollbox.LockDrawing;
  Try
    For a := 0 To _selectedtags.Count - 1 Do
      If Not Assigned(FindTagButton(_selectedtags[a])) Then
        AddTagButton(_selectedtags[a]);

    a := 0;

    While a < _scrollbox.ComponentCount Do
      If Not _selectedtags.Contains(TTagComponent(_scrollbox.Components[a]).Caption) Then
        RemoveButton(TTagComponent(_scrollbox.Components[a]).Caption)
      Else
        Inc(a);
  Finally
    _scrollbox.UnlockDrawing;
  End;
End;

Procedure TAETagEditor.SetSelectedTags(Const inSelectedTags: TStringList);
Begin
  _selectedtags.Assign(inSelectedTags);
End;

Procedure TAETagEditor.SetTagWidth(Const inTagWidth: Integer);
Var
  a: NativeInt;
Begin
  If inTagWidth = _tagwidth Then
    Exit;

  _tagwidth := inTagWidth;

  _scrollbox.LockDrawing;
  Try
    For a := 0 To _scrollbox.ComponentCount - 1 Do
    Begin
      TTagComponent(_scrollbox.Components[a]).Left := a * _tagwidth;
      TTagComponent(_scrollbox.Components[a]).Width := _tagwidth;
    End;
  Finally
    _scrollbox.UnlockDrawing;
  End;
End;

Procedure TAETagEditor.TagClick(Sender: TObject);
Var
  a: NativeInt;
Begin
  For a := 0 To _selectedtags.Count - 1 Do
    If _selectedtags[a] = TTagComponent(Sender).Caption Then
    Begin
      _selectedtags.Delete(a);

      Break;
    End;
End;

Procedure TAETagEditor.TagRemoved(Const inTag: String);
Begin
  If Assigned(_ontagremoved) Then
    _ontagremoved(Self, inTag);
End;

Procedure TAETagEditor.WMREMOVEBTN(Var inMessage: TMessage);
Begin
  inMessage.Result := 0;

  Self.RemoveButton(TTagComponent(_scrollbox.Components[Integer(inMessage.WParam)]).Caption);
End;

End.
