{
  AE Framework © 2022 by Akos Eigler is licensed under CC BY 4.0.
  To view a copy of this license, visit http://creativecommons.org/licenses/by/4.0/

  This license requires that reusers give credit to the creator. It allows reusers to distribute, remix, adapt,
  and build upon the material in any medium or format, even for commercial purposes.
}

Unit AE.Comp.PageControl;

Interface

Uses Winapi.Windows, Winapi.Messages, Vcl.Graphics, Vcl.Controls, Vcl.ComCtrls, System.Classes, Vcl.Themes;

Const
  TCM_FIRST = $1300;
  TCM_ADJUSTRECT = TCM_FIRST + 40;

Type
  TTabControlStyleHookBtnClose = Class(TTabControlStyleHook)
  private
    _hoverindex: Integer;
    Procedure WMMouseMove(Var outMsg: TMessage); Message WM_MOUSEMOVE;
    Procedure WMLButtonDown(Var outMsg: TWMMouse); Message WM_LBUTTONDOWN;
    Function GetButtonCloseRect(inTabIndex: Integer): TRect;
  strict protected
    Procedure DrawTab(inCanvas: TCanvas; inIndex: Integer); Override;
    Procedure MouseEnter; Override;
    Procedure MouseLeave; Override;
  public
    Constructor Create(inOwner: TWinControl); Override;
    Procedure DrawControlText(Canvas: TCanvas; Details: TThemedElementDetails; Const S: String; Var R: TRect; Flags: Cardinal); {$IF CompilerVersion > 32}Override;{$ENDIF} // Everything above 10.2...?
  End;

  TAEPageControl = Class(TPageControl)
  strict private
    _closebuttons: Array Of TRect;
    _hoverindex: Integer;
    _closeindex: Integer;
    _dragbegin: TPoint;
    _onclosepage: TNotifyEvent;
    _closingmouse: Boolean;
    Procedure AngleTextOut2(inCanvas: TCanvas; inAngle: Integer; inX, inY: Integer; Const inText: String);
    Procedure CMMouseLeave(Var outMessage: TMessage); Message CM_MOUSELEAVE;
    Procedure DrawControlText(inCanvas: TCanvas; inDetails: TThemedElementDetails; Const inText: String; Var outRect: TRect; inFlags: Cardinal);
    Procedure WMContextMenu(Var Message: TWMContextMenu); Message WM_CONTEXTMENU;
    Function UnThemedButtonState(inTabIndex: Integer): Cardinal;
    Function ThemedButtonState(inTabIndex: Integer): Cardinal;
  private
    Procedure TCMAdjustRect(Var Msg: TMessage); Message TCM_ADJUSTRECT;
    Procedure DoDraw(inDC: HDC; inDrawTabs: Boolean);
  protected
    Procedure DoStartDrag(Var DragObject: TDragObject); Override;
    Procedure DragOver(inSource: TObject; inX, inY: Integer; inState: TDragState; Var outAccept: Boolean); Override;
    Procedure DrawTab(inCanvas: TCanvas; inTabIndex: Integer; inCloseButtonOnly: Boolean); ReIntroduce;
    Procedure Loaded; Override;
    Procedure MouseDown(inButton: TMouseButton; inShift: TShiftState; inX, inY: Integer); Override;
    Procedure MouseMove(inShift: TShiftState; inX, inY: Integer); Override;
    Procedure MouseUp(inButton: TMouseButton; inShift: TShiftState; inX, inY: Integer); Override;
    Procedure PaintWindow(inDC: HDC); Override;
  public
    Constructor Create(AOwner: TComponent); Override;
    Procedure DragDrop(inSource: TObject; inX, inY: Integer); Override;
    Procedure CloseTab(Const inTabIndex: Integer; Const inSetMouseClosing: Boolean = False);
  published
    Property OnClosePage: TNotifyEvent Read _onclosepage Write _onclosepage;
  end;

Implementation

Uses Vcl.Styles, System.Types, System.Math, System.SysUtils, UxTheme;

Type
  TCustomTabControlClass = Class(TCustomTabControl);

  TPageControlExtraDragObject = Class(TDragObjectEx)
  strict private
    _imagelist: TImageList;
  protected
    Function GetDragImages: TDragImageList; Override;
  public
    Constructor Create(inDragBitmap: TBitMap); ReIntroduce;
    Destructor Destroy; Override;
  End;

//
// TPageControlExtraDragObject
//

Constructor TPageControlExtraDragObject.Create(inDragBitmap: TBitMap);
Begin
  inherited Create;

  _imagelist := TImageList.Create(nil);
  _imagelist.Height := inDragBitmap.Height;
  _imagelist.Width := inDragBitmap.Width;
  _imagelist.Add(inDragBitmap, nil);
  _imagelist.SetDragImage(0, 0, 0);
End;

Destructor TPageControlExtraDragObject.Destroy;
Begin
  FreeAndNil(_imagelist);

  inherited;
End;

Function TPageControlExtraDragObject.GetDragImages: TDragImageList;
Begin
  Result := _imagelist
End;

//
// Add close buttons on tabs if any style is active
//

Constructor TTabControlStyleHookBtnClose.Create(inOwner: TWinControl);
Begin
  inherited;

  _hoverindex := -1;
End;

Procedure TTabControlStyleHookBtnClose.DrawControlText(Canvas: TCanvas; Details: TThemedElementDetails; Const S: String; Var R: TRect; Flags: Cardinal);
Var
  newflags: Cardinal;
Begin
  newflags := Flags;

  If Control Is TAEPageControl Then
  Begin
    If R.Left = 0 Then
      Exit;

    If Self.TabPosition In [tpTop, tpBottom] Then
      R.Right := R.Right - GetButtonCloseRect(0).Width;

    If newflags And DT_WORD_ELLIPSIS = 0 Then
      newflags := newflags Or DT_WORD_ELLIPSIS;

    If newflags And DT_WORDBREAK <> 0 Then
      newflags := newflags - DT_WORDBREAK;
  End;

  inherited DrawControlText(Canvas, Details, S, R, newflags);
End;

Procedure TTabControlStyleHookBtnClose.DrawTab(inCanvas: TCanvas; inIndex: Integer);
Var
  Details: TThemedElementDetails;
  vrect: TRect;
Begin
  inherited;

  If Not(Control Is TAEPageControl) Then
    Exit;

  If (_hoverindex >= 0) And (inIndex = _hoverindex) Then
    Details := StyleServices.GetElementDetails(twSmallCloseButtonHot)
  Else If inIndex = TabIndex Then
    Details := StyleServices.GetElementDetails(twSmallCloseButtonNormal)
  Else
    Details := StyleServices.GetElementDetails(twSmallCloseButtonDisabled);

  vrect := GetButtonCloseRect(inIndex);

  If vrect.Bottom - vrect.Top > 0 Then
    StyleServices.DrawElement(inCanvas.Handle, Details, vrect);
End;

Function TTabControlStyleHookBtnClose.GetButtonCloseRect(inTabIndex: Integer): TRect;
Var
  vrect: TRect;
Begin
  vrect := TabRect[inTabIndex];

  If vrect.Left < 0 Then
    Exit;

  If Self.TabPosition In [tpTop, tpBottom] Then
  Begin
    If inTabIndex = TabIndex Then
      InflateRect(vrect, 0, 2);
  End
  Else If inTabIndex = Self.TabIndex Then
    Dec(vrect.Left, 2)
  Else
    Dec(vrect.Right, 2);

  Result := vrect;

  If Not StyleServices.GetElementContentRect(0, StyleServices.GetElementDetails(twSmallCloseButtonNormal), Result, vrect) Then
    vrect := Rect(0, 0, 0, 0);
  If inTabIndex = TabIndex Then
    Result.Top := 2
  Else
    Result.Top := 4;

  Result.Height := vrect.Height;
  Result.Left := Result.Right - (vrect.Width) - 2;
  Result.Width := vrect.Width;
End;

Procedure TTabControlStyleHookBtnClose.MouseEnter;
Begin
  inherited;

  _hoverindex := -1;
End;

Procedure TTabControlStyleHookBtnClose.MouseLeave;
Begin
  inherited;

  If _hoverindex >= 0 Then
  Begin
    _hoverindex := -1;
    Self.Invalidate;
  End;
End;

Procedure TTabControlStyleHookBtnClose.WMLButtonDown(Var outMsg: TWMMouse);
Var
  a: Integer;
Begin
  inherited;

  If Not(Control Is TAEPageControl) Then
    Exit;

  For a := 0 To Self.TabCount - 1 Do
    If PtInRect(GetButtonCloseRect(a), outMsg.Pos) Then
    Begin
      (Control As TAEPageControl).CloseTab(a, True);
      outMsg.Result := 1;
      Break;
    End;
End;

Procedure TTabControlStyleHookBtnClose.WMMouseMove(Var outMsg: TMessage);
Var
  a: Integer;
  hoverindex: Integer;
Begin
  inherited;

  If Not(Control Is TAEPageControl) Then
    Exit;

  hoverindex := -1;

  For a := 0 To Self.TabCount - 1 Do
    If PtInRect(GetButtonCloseRect(a), TWMMouseMove(outMsg).Pos) Then
    Begin
      hoverindex := a;
      Break;
    End;

  If _hoverindex <> hoverindex Then
  Begin
    _hoverindex := hoverindex;
    Self.Invalidate;
  End;
End;

//
// Add close buttons on tabs if no styles are active
//

Procedure TAEPageControl.AngleTextOut2(inCanvas: TCanvas; inAngle: Integer; inX, inY: Integer; Const inText: String);
Var
  newfont, oldfont: HFont;
  logfont: TLogFont;
Begin
  GetObject(inCanvas.Font.Handle, SizeOf(logfont), Addr(logfont));
  logfont.lfEscapement := inAngle * 10;
  logfont.lfOrientation := logfont.lfEscapement;
  newfont := CreateFontIndirect(logfont);
  oldfont := SelectObject(inCanvas.Handle, newfont);
  SetBkMode(inCanvas.Handle, TRANSPARENT);
  inCanvas.TextOut(inX, inY, inText);
  newfont := SelectObject(inCanvas.Handle, oldfont);
  DeleteObject(newfont);
End;

Procedure TAEPageControl.DrawControlText(inCanvas: TCanvas; inDetails: TThemedElementDetails; Const inText: String; Var outRect: TRect; inFlags: Cardinal);
Var
  textformat: TTextFormatFlags;
Begin
  inCanvas.Font := Self.Font;
  textformat := TTextFormatFlags(inFlags);
  StyleServices.DrawText(inCanvas.Handle, inDetails, inText, outRect, textformat, inCanvas.Font.Color);
End;

Procedure TAEPageControl.DragDrop(inSource: TObject; inX, inY: Integer);
Var
  a: Integer;
  vrect: TRect;
Begin
  inherited;

  For a := 0 To PageCount - 1 Do
  Begin
    If Not Self.Pages[a].TabVisible Then
      Continue;

    vrect := TabRect(Self.Pages[a].TabIndex);

    If PtInRect(vrect, Point(inX, inY)) Then
    Begin
      If a <> Self.ActivePage.PageIndex Then
        Self.ActivePage.PageIndex := a;

      Break;
    End;
  End;
End;

Procedure TAEPageControl.DragOver(inSource: TObject; inX, inY: Integer; inState: TDragState; Var outAccept: Boolean);
Begin
  inherited;

  outAccept := inSource Is TPageControlExtraDragObject;
End;

Procedure TAEPageControl.DrawTab(inCanvas: TCanvas; inTabIndex: Integer; inCloseButtonOnly: Boolean);
Var
  Details: TThemedElementDetails;
  imageindex, imagewidth, imageheight, offset, textx, texty: Integer;
  themedtab: TThemedTab;
  iconrect, vrect, layoutrect: TRect;
  h: HTheme;
Begin
  If Not inCloseButtonOnly Then
  Begin
    If (Self.Images <> nil) And (inTabIndex < Self.Images.Count) Then
    Begin
      imagewidth := Images.Width;
      imageheight := Images.Height;
      offset := 3;
    End
    Else
    Begin
      imagewidth := 0;
      imageheight := 0;
      offset := 0;
    End;

    vrect := TabRect(inTabIndex);

    If vrect.Left < 0 Then
      Exit;

    If TabPosition In [tpTop, tpBottom] Then
    Begin
      If inTabIndex = TabIndex Then
        InflateRect(vrect, 0, 2);
    End
    Else If inTabIndex = Self.TabIndex Then
      Dec(vrect.Left, 2)
    Else
      Dec(vrect.Right, 2);

    inCanvas.Font.Assign(Font);
    layoutrect := vrect;
    themedtab := ttTabDontCare;

    Case Self.TabPosition Of
      tpTop:
        If inTabIndex = Self.TabIndex Then
          themedtab := ttTabItemSelected
        Else
          themedtab := ttTabItemNormal;
      tpLeft:
        If inTabIndex = Self.TabIndex Then
          themedtab := ttTabItemLeftEdgeSelected
        Else
          themedtab := ttTabItemLeftEdgeNormal;
      tpBottom:
        If inTabIndex = Self.TabIndex Then
          themedtab := ttTabItemBothEdgeSelected
        Else
          themedtab := ttTabItemBothEdgeNormal;
      tpRight:
        If inTabIndex = Self.TabIndex Then
          themedtab := ttTabItemRightEdgeSelected
        Else
          themedtab := ttTabItemRightEdgeNormal;
    End;

    If StyleServices.Available Then
    Begin
      Details := StyleServices.GetElementDetails(themedtab);
      StyleServices.DrawElement(inCanvas.Handle, Details, vrect);
    End;

    If Self Is TCustomTabControl Then
      imageindex := TCustomTabControlClass(Self).GetImageIndex(inTabIndex)
    Else
      imageindex := inTabIndex;

    If (Images <> nil) And (imageindex >= 0) And (imageindex < Images.Count) Then
    Begin
      iconrect := layoutrect;

      Case Self.TabPosition Of
        tpTop, tpBottom:
          Begin
            iconrect.Left := iconrect.Left + offset;
            iconrect.Right := iconrect.Left + imagewidth;
            layoutrect.Left := iconrect.Right;
            iconrect.Top := iconrect.Top + (iconrect.Bottom - iconrect.Top) Div 2 - imageheight Div 2;

            If (Self.TabPosition = tpTop) And (inTabIndex = Self.TabIndex) Then
              OffsetRect(iconrect, 0, -1)
            Else If (Self.TabPosition = tpBottom) And (inTabIndex = Self.TabIndex) Then
              OffsetRect(iconrect, 0, 1);
          End;
        tpLeft:
          Begin
            iconrect.Bottom := iconrect.Bottom - offset;
            iconrect.Top := iconrect.Bottom - imageheight;
            layoutrect.Bottom := iconrect.Top;
            iconrect.Left := iconrect.Left + (iconrect.Right - iconrect.Left) Div 2 - imagewidth div 2;
          End;
        tpRight:
          Begin
            iconrect.Top := iconrect.Top + offset;
            iconrect.Bottom := iconrect.Top + imageheight;
            layoutrect.Top := iconrect.Bottom;
            iconrect.Left := iconrect.Left + (iconrect.Right - iconrect.Left) Div 2 - imagewidth div 2;
          End;
      End;

      iconrect.Height := Images.Height;
      iconrect.Width := Images.Width;

      If StyleServices.Available Then
        StyleServices.DrawIcon(inCanvas.Handle, Details, iconrect, Self.Images.Handle, imageindex);
    End;

    If StyleServices.Available Then
    Begin
      Case Self.TabPosition Of
        tpTop, tpBottom:
          Begin
            layoutrect.Left := layoutrect.Left + 5;
            layoutrect.Right := layoutrect.Right - 20;
          End;
      End;
      Case Self.TabPosition Of
        tpLeft:
          Begin
            textx := layoutrect.Left + (layoutrect.Right - layoutrect.Left) Div 2 - inCanvas.TextHeight(Self.Tabs[inTabIndex]) Div 2;
            texty := layoutrect.Top + (layoutrect.Bottom - layoutrect.Top) Div 2 + inCanvas.TextWidth(Self.Tabs[inTabIndex]) Div 2;

            AngleTextOut2(inCanvas, 90, textx, texty, Self.Tabs[inTabIndex]);
          End;
        tpRight:
          Begin
            textx := layoutrect.Left + (layoutrect.Right - layoutrect.Left) Div 2 + inCanvas.TextHeight(Self.Tabs[inTabIndex]) Div 2;
            texty := layoutrect.Top + (layoutrect.Bottom - layoutrect.Top) Div 2 - inCanvas.TextWidth(Self.Tabs[inTabIndex]) Div 2;

            AngleTextOut2(inCanvas, -90, textx, texty, Self.Tabs[inTabIndex]);
          End;
      Else
        DrawControlText(inCanvas, Details, Self.Tabs[inTabIndex], layoutrect, DT_VCENTER Or DT_SINGLELINE Or DT_NOCLIP Or DT_WORD_ELLIPSIS);
      End;
    End;

    Case Self.TabPosition Of
      tpTop, tpBottom:
        _closebuttons[inTabIndex].Top := vrect.Top + (vrect.Bottom - vrect.Top) Div 2 - 7;
      tpLeft:
        _closebuttons[inTabIndex].Top := vrect.Top + 7;
      tpRight:
        _closebuttons[inTabIndex].Top := vrect.Bottom - 17;
    End;

    _closebuttons[inTabIndex].Bottom := _closebuttons[inTabIndex].Top + 14;
    _closebuttons[inTabIndex].Right := vrect.Right - 4;
    _closebuttons[inTabIndex].Left := _closebuttons[inTabIndex].Right - 14;
  End;

  If UseThemes Then
  Begin
    h := OpenThemeData(Handle, 'WINDOW');
    If h <> 0 Then
      Try
        DrawThemeBackground(h, inCanvas.Handle, WP_CLOSEBUTTON, ThemedButtonState(inTabIndex), _closebuttons[inTabIndex], nil);
      Finally
        CloseThemeData(h);
      End;
  End
  Else
    DrawFrameControl(inCanvas.Handle, _closebuttons[inTabIndex], DFC_CAPTION, DFCS_CAPTIONCLOSE Or UnThemedButtonState(inTabIndex));
End;

Procedure TAEPageControl.Loaded;
Begin
  inherited;

  Self.ControlStyle := Self.ControlStyle + [csDisplayDragImage];
End;

Procedure TAEPageControl.MouseDown(inButton: TMouseButton; inShift: TShiftState;
  inX, inY: Integer);
Var
  a: Integer;
Begin
  inherited;

  If _closingmouse Then
  Begin
    _closingmouse := False;
    Exit;
  End;

  If inButton = mbMiddle Then
  Begin
    a := Self.IndexOfTabAt(inX, inY);

    If a > -1 Then
    Begin
      CloseTab(a);
      _closeindex := -1;
      _hoverindex := -1;
      Self.Repaint;
    End;
  End
  Else If inButton = mbLeft Then
  Begin
    For a := Low(_closebuttons) To High(_closebuttons) Do
      If PtInRect(_closebuttons[a], Point(inX, inY)) Then
      Begin
        _closeindex := a;
        Self.DrawTab(Self.Canvas, _closeindex, True);
        Break;
      End;

    If _closeindex = -1 Then
      _dragbegin := ScreenToClient(Mouse.CursorPos);
  End;
End;

Procedure TAEPageControl.MouseMove(inShift: TShiftState; inX, inY: Integer);
Var
  cpos: TPoint;
  a, oldhoverindex, invisible: Integer;
Begin
  inherited;

  If _dragbegin <> TPoint.Zero Then
  Begin
    cpos := ScreenToClient(Mouse.CursorPos);
    If (Abs(cpos.X - _dragbegin.X) >= Mouse.DragThreshold) Or (Abs(cpos.Y - _dragbegin.Y) >= Mouse.DragThreshold) Then
    Begin
      BeginDrag(True);
      _dragbegin := TPoint.Zero;
    End;
    Exit;
  End;

  oldhoverindex := -1;
  Try
    If TStyleManager.ActiveStyle <> TStyleManager.SystemStyle Then
      Exit;

    If _closeindex = -1 Then
    Begin
      oldhoverindex := _hoverindex;
      _hoverindex := -1;
      For a := Low(_closebuttons) To High(_closebuttons) Do
        If PtInRect(_closebuttons[a], Point(inX, inY)) Then
        Begin
          _hoverindex := a;
          Break;
        End;
    End;

    If Not(ssLeft In inShift) Or (_closeindex = -1) Then
      Exit;

    If Not PtInRect(_closebuttons[_closeindex], Point(inX, inY)) Then
      _closeindex := -1;
  Finally
    If _hoverindex > -1 Then
      Self.DrawTab(Self.Canvas, _hoverindex, True)
    Else
    Begin
      invisible := 0;
      Self.ShowHint := False;

      For a := 0 To Self.PageCount - 1 Do
        If Not Self.Pages[a].TabVisible Then
          Inc(invisible)
        Else If PtInRect(Self.TabRect(a - invisible), Point(inX, inY)) Then
        Begin
          Self.Hint := Self.Pages[a].Caption;
          Self.ShowHint := True;
          Break;
        End;
    End;

    If (oldhoverindex > -1) And (oldhoverindex <> _hoverindex) Then
      Self.DrawTab(Self.Canvas, oldhoverindex, True);
  End;
End;

Procedure TAEPageControl.MouseUp(inButton: TMouseButton; inShift: TShiftState; inX, inY: Integer);
Begin
  inherited;

  _dragbegin := TPoint.Zero;

  If (TStyleManager.ActiveStyle <> TStyleManager.SystemStyle) Or (inButton <> mbLeft) Or (_closeindex = -1) Then
    Exit;

  If PtInRect(_closebuttons[_closeindex], Point(inX, inY)) Then
  Begin
    CloseTab(_closeindex);

    _closeindex := -1;
    _hoverindex := -1;
  End;
End;

Procedure TAEPageControl.CloseTab(Const inTabIndex: Integer; Const inSetMouseClosing: Boolean = False);
Var
  a: Integer;
Begin
  If inSetMouseClosing Then
    _closingmouse := True;

  For a := 0 To Self.PageCount - 1 Do
    If Self.Pages[a].TabIndex = inTabIndex Then
    Begin
      If Assigned(_onclosepage) Then
        _onclosepage(Self.Pages[a])
      Else
        Self.Pages[a].Free;

      Break;
    End;
End;

Procedure TAEPageControl.CMMouseLeave(Var outMessage: TMessage);
Begin
  inherited;

  _closeindex := -1;
  _hoverindex := -1;
  Self.ShowHint := False;
  outMessage.Result := 1;
End;

Constructor TAEPageControl.Create(AOwner: TComponent);
Begin
  inherited;

  _closingmouse := False;
  _dragbegin := TPoint.Zero;
  _onclosepage := nil;
End;

Procedure TAEPageControl.DoDraw(inDC: HDC; inDrawTabs: Boolean);
Var
  vrect: TRect;
  a, currtab: Integer;
Begin
  SetLength(_closebuttons, Self.PageCount);

  For a := Low(_closebuttons) To High(_closebuttons) Do
    _closebuttons[a] := Rect(0, 0, 0, 0);

  currtab := Self.TabIndex;
  Try
    Self.Canvas.Handle := inDC;

    If inDrawTabs Then
      For a := 0 To Self.Tabs.Count - 1 Do
        If a <> currtab Then
          DrawTab(Self.Canvas, a, False);

    If currtab < 0 Then
      vrect := Rect(0, 0, Self.Width, Self.Height)
    Else
    Begin
      vrect := TabRect(currtab);
      vrect.Left := 0;
      vrect.Top := vrect.Bottom;
      vrect.Right := Width;
      vrect.Bottom := Height;
    End;

    StyleServices.DrawElement(inDC, StyleServices.GetElementDetails(ttPane), vrect);

    If (currtab >= 0) And inDrawTabs Then
      DrawTab(Self.Canvas, currtab, False);
  Finally
    Self.Canvas.Handle := 0;
  End;
End;

Procedure TAEPageControl.DoStartDrag(Var DragObject: TDragObject);
Var
  tab: TRect;
  bmp, tabbmp: TBitMap;
Begin
  inherited;

  If DragObject <> nil Then
    Exit;

  // Create a bitmap of the tab button under cursor
  tab := Self.TabRect(Self.ActivePage.TabIndex);
  bmp := TBitMap.Create;
  bmp.Canvas.Lock;
  tabbmp := TBitMap.Create;
  Try
    bmp.Height := Self.Height;
    bmp.Width := Self.Width;
    tabbmp.Height := tab.Height;
    tabbmp.Width := tab.Width;
    Self.PaintTo(bmp.Canvas.Handle, 0, 0);
    tabbmp.Canvas.CopyRect(tabbmp.Canvas.ClipRect, bmp.Canvas, tab);
    DragObject := TPageControlExtraDragObject.Create(tabbmp);
  Finally
    bmp.Canvas.Unlock;
    FreeAndNil(tabbmp);
    FreeAndNil(bmp);
  End;
End;

Procedure TAEPageControl.PaintWindow(inDC: HDC);
Begin
  DoDraw(inDC, True);
End;

Procedure TAEPageControl.TCMAdjustRect(Var Msg: TMessage);
Begin
  inherited;

  If Msg.WParam = 0 Then
    InflateRect(PRect(Msg.LParam)^, 3, 3)
  Else
    InflateRect(PRect(Msg.LParam)^, -3, -3);

  // If Self.TabPosition = tpTop Then Begin
  // PRect(Msg.LParam)^.Left := 0;
  // PRect(Msg.LParam)^.Right := Self.ClientWidth;
  // Dec(PRect(Msg.LParam)^.Top, 4);
  // PRect(Msg.LParam)^.Bottom := Self.ClientHeight;
  // End
  // Else inherited;
End;

Function TAEPageControl.ThemedButtonState(inTabIndex: Integer): Cardinal;
Begin
  If Not Self.Enabled Then
    Result := CBS_DISABLED
  Else If inTabIndex = _hoverindex Then
    If _hoverindex = _closeindex Then
      Result := CBS_PUSHED
    Else
      Result := CBS_HOT
  Else
    Result := CBS_NORMAL;
End;

Function TAEPageControl.UnThemedButtonState(inTabIndex: Integer): Cardinal;
Begin
  If Not Self.Enabled Then
    Result := DFCS_INACTIVE
  Else If inTabIndex = _hoverindex Then
    If _hoverindex = _closeindex Then
      Result := DFCS_PUSHED
    Else
      Result := DFCS_HOT
  Else
    Result := 0;
End;

Procedure TAEPageControl.WMContextMenu(Var Message: TWMContextMenu);
Var
  mpos: TPoint;
  a: Integer;
Begin
  mpos := Self.ScreenToClient(Mouse.CursorPos);

  For a := 0 To Self.PageCount - 1 Do
    If Self.Pages[a].TabVisible And PtInRect(Self.TabRect(a), mpos) Then
    Begin
      Self.ActivePageIndex := a;

      inherited;

      Break;
    End;
End;

Initialization

TStyleManager.Engine.RegisterStyleHook(TCustomTabControl, TTabControlStyleHookBtnClose);
TStyleManager.Engine.RegisterStyleHook(TTabControl, TTabControlStyleHookBtnClose);

End.
