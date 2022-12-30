{
  AE Framework © 2022 by Akos Eigler is licensed under CC BY 4.0.
  To view a copy of this license, visit http://creativecommons.org/licenses/by/4.0/

  This license requires that reusers give credit to the creator. It allows reusers to distribute, remix, adapt,
  and build upon the material in any medium or format, even for commercial purposes.
}

Unit AE.Comp.DBGrid;

Interface

Uses Data.DB, Vcl.DBGrids, Vcl.Graphics, System.Classes, System.Generics.Collections, System.Types, Vcl.Grids, WinApi.Messages;

Type
 TAEDBGridDataLink = Class(TGridDataLink)
 protected
  Procedure DataEvent(Event: TDataEvent; Info: NativeInt); Override;
 End;

 TAEDBGrid = Class(TDBGrid)
 strict private
  _bitmap: TBitMap;
  _dataset: TDataSet;
  _fieldvisible: TDictionary<String, Boolean>;
  _gridposition: TPoint;
  _selectedfield: String;
  Procedure WMHScroll(Var Msg: TWMHScroll); Message WM_HSCROLL;
  Procedure WMSetCursor(Var Msg: TWMSetCursor); Message WM_SETCURSOR;
  Procedure WMSize(Var Msg: TWMSize); Message WM_SIZE;
  Procedure WMVScroll(Var Msg: TWMVScroll); Message WM_VSCROLL;
 strict protected
  Procedure Fit;
  Function FitFillsEmptySpace: Boolean; Virtual;
  Function GetDataSet: TDataset;
  Function Padding: Integer; Virtual;
  Function ShowingNothing: Boolean; Virtual;
 protected
  Procedure DoExit; Override;
  Procedure DrawCell(ACol, ARow: Longint; ARect: TRect; AState: TGridDrawState); Override;
  Procedure DrawColumnCell(Const Rect: TRect; DataCol: Integer; Column: TColumn; State: TGridDrawState); Override;
  Procedure MouseMove(Shift: TShiftState; X, Y: Integer); Override;
  Procedure Paint; Override;
  Procedure UpdateScrollBar; Override;
  Function CreateDataLink: TGridDataLink; Override;
  Function DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean; Override;
 public
  Constructor Create(AOwner: TComponent); Override;
  Destructor Destroy; Override;
  Procedure BeginUpdate(Const inRemoveDataSet: Boolean = True); ReIntroduce;
  Procedure EndUpdate;
  Procedure RefreshUI(Const inShouldFit: Boolean = True);
 End;

Implementation

Uses System.Diagnostics, System.SysUtils, WinApi.Windows, Vcl.Themes, System.UITypes;

//
// TAEDBGridDataLink
//

Procedure TAEDBGridDataLink.DataEvent(Event: TDataEvent; Info: NativeInt);
Begin
 inherited;

 If (Event = deDataSetChange) Or
    ( (Event = deUpdateState) And
      Assigned(Self.Grid.DataSource) And
      Assigned(Self.Grid.DataSource.DataSet) And
      (Self.DataSource.DataSet.State In [dsBrowse, dsInactive])
    ) Then (Self.Grid As TAEDBGrid).RefreshUI(Event <> deDataSetChange);
End;

//
// TAEDBGrid
//

Function TAEDBGrid.FitFillsEmptySpace: Boolean;
Begin
  Result := False;
End;

Procedure TAEDBGrid.BeginUpdate(Const inRemoveDataSet: Boolean = True);
Var
 a: Integer;
 dc: HWND;
Begin
  // If there is any valuable information visible on the grid, create a screenshot of it
  // and save it in _bitmap. This image will be re-drawn instead of painting between each
  // BeginUpdate - EndUpdate pairs. Useful if we remove the dataset so a background
  // thread can open it: normally the grid would go blank. This way at least something is
  // shown...

  inherited BeginUpdate;

  If Self.UpdateLock <> 1 Then
    Exit;

  If Not Self.ShowingNothing Then
  Begin
    _bitmap.SetSize(Self.Width, Self.Height);
    dc := GetDC(Self.Handle);
    Try
      BitBlt(_bitmap.Canvas.Handle, 0, 0, _bitmap.Width, _bitmap.Height, dc, 0, 0, SRCCOPY);
    Finally
      ReleaseDC(Self.Handle, dc);
    End;
  End;

//  SendMessage(Self.Handle, WM_SETREDRAW, Ord(False), 0);
  If Assigned(Self.SelectedField) Then
    _selectedfield := Self.SelectedField.FieldName
  Else
    _selectedfield := '';

  // Save all information to be restored when we re-add the dataset during .EndUpdate.
  // This way the grid will show exactly the same thing as before, has the same field
  // selected and the same fields visible e.g. after a background refresh
  _fieldvisible.Clear;
  _gridposition.X := Self.LeftCol;
  _gridposition.Y := Self.TopRow;

  If Not inRemoveDataSet Or Not Assigned(Self.DataSource) Then
    _dataset := nil // _dataset should always be nil here, but just to be sure...
  Else
  Begin
    _dataset := Self.GetDataSet;
    Self.DataSource.DataSet := nil;

    If Assigned(_dataset) And _dataset.Active Then
      For a := 0 To _dataset.FieldCount - 1 Do
        _fieldvisible.Add(_dataset.Fields[a].FieldName, _dataset.Fields[a].Visible);
  End;
End;

Constructor TAEDBGrid.Create(AOwner: TComponent);
Begin
 inherited;

 _bitmap := Vcl.Graphics.TBitmap.Create;
 _bitmap.PixelFormat := pf24bit;
 _bitmap.SetSize(0, 0);

 _fieldvisible := TDictionary<String, Boolean>.Create;
 _selectedfield := '';
End;

Function TAEDBGrid.CreateDataLink: TGridDataLink;
Begin
  Result := TAEDBGridDataLink.Create(Self);
End;

Destructor TAEDBGrid.Destroy;
Begin
 FreeAndNil(_bitmap);
 FreeAndNil(_fieldvisible);

 inherited;
End;

Procedure TAEDBGrid.DoExit;
Begin
  inherited;

  Self.Repaint;
End;

Function TAEDBGrid.DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean;
Var
 dataset: TDataSet;
 dir, scrollines: Integer;
Begin
  // Make the grid respond to mouse wheel scrolling

  Result := False;

  Try
    dataset := Self.GetDataSet;

    If (WheelDelta = 0) Or Not Assigned(dataset) Or Not dataset.Active Then
      Exit;

    SystemParametersInfo(SPI_GETWHEELSCROLLLINES, 0, @scrollines, 0);

    If WheelDelta > 0 Then
      dir := -1
    Else
      dir := 1;

    dataset.MoveBy(dir * scrollines);
    Self.Invalidate;
    Result := True;
  Finally
    If Not Result Then
      Result := inherited;
  End;
End;

Procedure TAEDBGrid.DrawCell(ACol, ARow: Longint; ARect: TRect; AState: TGridDrawState);
Begin
 If Self.UpdateLock > 0 Then
   Exit;

 If Not Self.ShowingNothing Then
 Begin
   inherited;
   Exit;
 End;

 Self.Canvas.Brush.Color := TStyleManager.ActiveStyle.GetStyleColor(scEdit);
 InflateRect(ARect, 1, 1);
 Self.Canvas.FillRect(ARect);
End;

Procedure TAEDBGrid.DrawColumnCell(Const Rect: TRect; DataCol: Integer; Column: TColumn; State: TGridDrawState);
Var
 dataset: TDataSet;
 editcolor: TColor;
 hidefocus: Boolean;
Begin
  dataset := Self.GetDataSet;

  // This method is only being called on DATA cells, which only happens if there is a
  // dataset connected. Therefore, no need to perform an assigned check here.

  hidefocus := Not (csDesigning In Self.ComponentState) And (gdSelected In State) And Not Self.Focused;

  If dataset.IsEmpty Then
  Begin
    editcolor := TStyleManager.ActiveStyle.GetStyleColor(scEdit);
    Self.Canvas.Brush.Color := editcolor;
    Self.Canvas.Font.Color := editcolor;
  End
  Else
// This code imitates the highlight of the whole row even if RowSelect is disabled.
// Note that it needs MultiSelect to be enabled!
//  If Not (gdSelected In State) And grid.SelectedRows.CurrentRowSelected Then
//    grid.Canvas.Brush.Color := clHighLight
//  Else
  If (dataset.RecNo Mod 2 = 0) And ((State = []) Or hidefocus) Then
    Self.Canvas.Brush.Color := TStyleManager.ActiveStyle.GetStyleColor(scButtonDisabled)
  Else
  If (dataset.RecNo Mod 2 = 1) And hidefocus Then
    Self.Canvas.Brush.Color := TStyleManager.ActiveStyle.GetStyleColor(scEdit);

  If hidefocus Then Self.Canvas.Brush.Color := TStyleManager.ActiveStyle.GetStyleColor(scCategoryButtonsGradientBase);

  inherited;

  Self.DefaultDrawColumnCell(Rect, DataCol, Column, State);
End;

Procedure TAEDBGrid.EndUpdate;
Var
 samefields: Boolean;
 sfield: String;
 a: Integer;
Begin
  Try
    If Self.UpdateLock > 1 Then
      Exit;

    _bitmap.SetSize(0, 0);
//    SendMessage(Self.Handle, WM_SETREDRAW, Ord(True), 0);
    If Not Assigned(_dataset) Then
    Begin
      Self.RefreshUI(False);
      Exit;
    End;

    samefields := False;
    If _dataset.Active Then
    Begin
      samefields := True;
      For sfield In _fieldvisible.Keys Do
      Begin
        samefields := samefields And Assigned(_dataset.FindField(sfield));
        If Not samefields Then
          Break;
      End;

      If samefields Then
      Begin
        For a := 0 To _dataset.FieldCount - 1 Do
        Begin
          samefields := samefields And _fieldvisible.ContainsKey(_dataset.Fields[a].FieldName);
          If Not samefields Then
            Break;
        End;

      If samefields Then
        For sfield In _fieldvisible.Keys Do
          _dataset.FieldByName(sfield).Visible := _fieldvisible[sfield];
      End;

      _fieldvisible.Clear;
    End;

    // Assigning an active dataset will cause a DataLink event which will trigger
    // RefreshUI, which will call .Fit. So in this block, no explicit call to
    // .RefreshUI is needed!

    inherited EndUpdate;
    Self.DataSource.DataSet := _dataset;

    If samefields And Not _selectedfield.IsEmpty Then
    Begin
      Self.SelectedField := _dataset.FindField(_selectedfield);
      _selectedfield := '';

      // Reposition top-left visible cell to have the exact same view after updating
      Self.LeftCol := _gridposition.X;
      _gridposition.X := -1;
      Self.TopRow := _gridposition.Y;
      _gridposition.Y := -1;
    End;

    _dataset := nil;
  Finally
    inherited EndUpdate;
  End;
End;

Procedure TAEDBGrid.Fit;
Var
 dataset: TDataSet;
 a, w, viscol: Integer;
 cols: Array Of Integer;
 {$IFDEF FITVISIBLEONLY}
 gdinfo: TGridDrawInfo;
 {$ENDIF}
 sw: TStopWatch;
 alternativefit: Boolean;
 bm: TBookMark;

 Procedure HalfScreenMax(Var outWidth: Integer);
 Begin
   If outWidth >= Self.ClientWidth Div 2 Then
     outWidth := Self.ClientWidth Div 2;
 End;

Begin
  If Self.ShowingNothing Then
    Exit;

  viscol := 0;
  dataset := Self.GetDataSet;

  // First run: if the field is visible, put the width of the column caption in
  // the array, else put 0. We also count the amount of visible fields which will
  // be used if we have to expand the fields
  Self.Canvas.Font.Assign(Self.TitleFont);
  Try
    SetLength(cols, Self.Columns.Count);
    For a := Low(cols) To High(cols) Do
      If (Self.Columns[a].Visible) And
         Assigned(Self.Columns[a].Field) And
         (Self.Columns[a].Field.Visible) Then
      Begin
        cols[a] := Self.Canvas.TextWidth(Self.Columns[a].Title.Caption) + Self.Padding;
        HalfScreenMax(cols[a]);
        Inc(viscol);
      End
      Else
        cols[a] := 0;

    If viscol = 0 Then
      Exit;
  Finally
   Self.Canvas.Font.Assign(Self.Font);
  End;

  // Second run: go through the (visible portion) of the dataset, measuring the
  // width of the contents of each field. As this can take a long time, we break
  // out and switch to an alternate fitting mode after 1 second
  alternativefit := False;
  sw := TStopWatch.StartNew;
  dataset.DisableControls;
  Try
    bm := dataset.GetBookmark;
    Try
      {$IFDEF FITVISIBLEONLY}
      Self.CalcDrawInfo(gdinfo);
      dataset.RecNo := gdinfo.Vert.FirstGridCell;
      {$ELSE}
      dataset.First;
      {$ENDIF}
      While Not dataset.Eof {$IFDEF FITVISIBLEONLY} And (dataset.RecNo <= gdinfo.Vert.LastFullVisibleCell){$ENDIF} Do
      Begin
        alternativefit := sw.ElapsedMilliseconds >= 1000;
        If alternativefit Then
          Break;

        For a := Low(cols) To High(cols) Do
        Begin
          If cols[a] = 0 Then
            Continue;

          w := Self.Canvas.TextWidth(Self.Columns[a].Field.DisplayText);
          HalfScreenMax(w);
          If cols[a] < w Then
            cols[a] := w;
        End;
        dataset.Next;
      End;
    Finally
      dataset.GotoBookmark(bm);
    End;
  Finally
    dataset.EnableControls;
  End;

  // Third run: if regular fitting took too long, measure the width of field size
  // times the letter 'm'. Very inaccurate but very fast
  If alternativefit Then
    For a := Low(cols) To High(cols) Do
    Begin
      If cols[a] = 0 Then
        Continue;

      w := Self.Canvas.TextWidth(String.Empty.PadRight(Self.Columns[a].Field.Size, 'm'));
      HalfScreenMax(w);
      If cols[a] < w Then
        cols[a] := w;
    End;

  // Fourth run: if we have to expand columns to fill all available empty space,
  w := 0;
  If Self.FitFillsEmptySpace Then
  Begin
    For a := Low(cols) To High(cols) Do
      Inc(w, cols[a]);
    w := (Self.ClientWidth - w - 20) Div viscol;
    If w < 0 Then
      w := 0;
  End;

  Self.Columns.BeginUpdate;
  Try
    For a := Low(cols) To High(cols) Do
      If cols[a] > 0 Then
        Self.Columns[a].Width := cols[a] + Self.Padding + w
      Else
      Begin
        Self.Columns[a].Visible := False;
        Self.Columns[a].Width := 0;
      End;
  Finally
    Self.Columns.EndUpdate;
  End;
End;

Function TAEDBGrid.GetDataSet: TDataset;
Begin
 If Assigned(Self.DataSource) And Assigned(Self.DataSource.DataSet) Then
   Result := Self.DataSource.DataSet
 Else
   Result := nil;
End;

Procedure TAEDBGrid.MouseMove(Shift: TShiftState; X, Y: Integer);
Begin
  // If title clicks or hottracking is enabled, turn the mouse cursor to a hand when
  // hovering over the titles

  inherited;

  If Not (dgTitleClick In Self.Options) And Not (dgTitleHotTrack In Self.Options) Then
    Exit;

  If Self.MouseCoord(x, y).Y = 0 Then
    Self.Cursor := crHandPoint
  Else
    Self.Cursor := crDefault;
End;

Function TAEDBGrid.Padding: Integer;
Begin
  Result := 9;
End;

Procedure TAEDBGrid.Paint;
Begin
  // Between BeginUpdate - EndUpdate only clear the background and paint the screenshot
  // captured in .BeginUpdate

  If Self.UpdateLock = 0 Then
  Begin
    inherited;
    Exit;
  End;

  Self.Canvas.Brush.Color := TStyleManager.ActiveStyle.GetStyleColor(scEdit);
  Self.Canvas.FillRect(Rect(0, 0, Self.Width, Self.Height));
  If (_bitmap.Height > 0) And (_bitmap.Width > 0) Then
    Self.Canvas.Draw(0, 0, _bitmap);
End;

Procedure TAEDBGrid.RefreshUI(Const inShouldFit: Boolean);
Begin
  If Self.ShowingNothing Then Self.Repaint
    Else
  If inShouldFit Then Self.Fit;
End;

Function TAEDBGrid.ShowingNothing: Boolean;
Var
 dataset: TDataSet;
Begin
 dataset := Self.GetDataSet;

 Result := Not Assigned(dataset) Or Not dataset.Active;
End;

Procedure TAEDBGrid.UpdateScrollBar;
Var
 dataset: TDataSet;
 si: TScrollInfo;
Begin
  // No calling to inherited is done here. That code is a mess, we can do it better.

  dataset := Self.GetDataSet;

  If Not Assigned(dataset) Or Not dataset.Active Or (dataset.RecordCount <= Self.RowCount - 1) Then
  Begin
    // Hide the vertical scrollbar, it's not needed

    ShowScrollBar(Self.Handle, SB_VERT, False);
    Exit;
  End;

  // Show the vertical scrollbar
  ShowScrollBar(Self.Handle, SB_VERT, True);
  If Win32MajorVersion >= 6 Then
    SetWindowPos(Self.Handle, 0, 0, 0, 0, 0, SWP_NOSIZE Or SWP_NOMOVE Or SWP_NOZORDER Or SWP_NOACTIVATE Or SWP_NOOWNERZORDER Or SWP_NOSENDCHANGING Or SWP_FRAMECHANGED);
  si.cbSize := sizeof(si);
  si.nMin := 1;
  si.nMax := dataset.RecordCount;
  si.nPos := dataset.RecNo;
  si.fMask := SIF_POS Or SIF_RANGE;
  SetScrollInfo(Self.Handle, SB_VERT, si, True);
End;

Procedure TAEDBGrid.WMHScroll(Var Msg: TWMHScroll);
Begin
  // Make the grid to scroll while dragging the horizontal scrollbar

  If Msg.ScrollCode = SB_THUMBTRACK Then
    Msg.ScrollCode := SB_THUMBPOSITION;

  inherited;
End;

Procedure TAEDBGrid.WMSetCursor(Var Msg: TWMSetCursor);
Begin
  // If there is no valuable information shown, don't change the mouse cursor at all

  If Self.ShowingNothing Then
    Winapi.Windows.SetCursor(LoadCursor(0, IDC_ARROW))
  Else
    inherited;
End;

Procedure TAEDBGrid.WMSize(Var Msg: TWMSize);
Begin
  inherited;

  Self.UpdateScrollBar;
End;

Procedure TAEDBGrid.WMVScroll(Var Msg: TWMVScroll);
Begin
  // Make the grid to scroll while dragging the vertical scrollbar

  If Msg.ScrollCode = SB_THUMBTRACK Then
    Msg.ScrollCode := SB_THUMBPOSITION;

  inherited;
End;

End.
