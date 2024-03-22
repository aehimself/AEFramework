{
  AE Framework © 2022 by Akos Eigler is licensed under CC BY 4.0.
  To view a copy of this license, visit http://creativecommons.org/licenses/by/4.0/

  This license requires that reusers give credit to the creator. It allows reusers to distribute, remix, adapt,
  and build upon the material in any medium or format, even for commercial purposes.
}

Unit AE.Comp.ComboBox;

Interface

Uses Vcl.StdCtrls, System.Generics.Collections, System.Classes, WinApi.Messages, WinApi.Windows;

Type
  TAEComboBox = Class(TComboBox)
  strict private
    _changecalled: Boolean;
    _closeupchange: Boolean;
    _dropdownchange: Boolean;
    _itemcache: TList<String>;
    _timerwindow: HWnd;
    Procedure CBADDSTRING(Var Msg: TMessage); Message CB_ADDSTRING;
    Procedure CBINSERTSTRING(Var Msg: TMessage); Message CB_INSERTSTRING;
    Procedure CBDELETESTRING(Var Msg: TMessage); Message CB_DELETESTRING;
    Procedure CBRESETCONTENT(Var Msg: TMessage); Message CB_RESETCONTENT;
    Procedure CBSETITEMDATA(Var Msg: TMessage); Message CB_SETITEMDATA;
    Procedure ResetTimer(Const inTimerID: Integer);
    Procedure TimerWindowProc(Var inMessage: TMessage);
  protected
    Procedure Change; Override;
    Procedure CloseUp; Override;
    Procedure DropDown; Override;
    Procedure Select; Override;
  public
    Constructor Create(AOwner: TComponent); Override;
    Destructor Destroy; Override;
  published
    Property AutoDropDown Default True;
  End;

Implementation

Uses System.SysUtils, Vcl.Consts;

Const
  TIMEREVENT_CLOSEUPCHANGE = 1;
  TIMEREVENT_REFRESHCACHE = 2;

Procedure TAEComboBox.CBADDSTRING(Var Msg: TMessage);
Begin
  inherited;

  ResetTimer(TIMEREVENT_REFRESHCACHE);
End;

Procedure TAEComboBox.CBDELETESTRING(Var Msg: TMessage);
Begin
  inherited;

  ResetTimer(TIMEREVENT_REFRESHCACHE);
End;

Procedure TAEComboBox.CBINSERTSTRING(Var Msg: TMessage);
Begin
  inherited;

  ResetTimer(TIMEREVENT_REFRESHCACHE);
End;

Procedure TAEComboBox.CBRESETCONTENT(Var Msg: TMessage);
Begin
  inherited;

  ResetTimer(TIMEREVENT_REFRESHCACHE);
End;

Procedure TAEComboBox.CBSETITEMDATA(Var Msg: TMessage);
Begin
  inherited;

  ResetTimer(TIMEREVENT_REFRESHCACHE);
End;

Procedure TAEComboBox.Change;
Begin
  _changecalled := True;

  If _dropdownchange Then
  Begin
    If Self.Text <> Self.Items.Strings[Self.ItemIndex] Then
      Self.ItemIndex := _itemcache.IndexOf(String(Self.Text).ToLower);

    _dropdownchange := False;
  End;

  If Not _closeupchange And Not Self.DroppedDown And Self.AutoDropDown Then
  Begin
    SendMessage(Self.Handle, CB_SHOWDROPDOWN, Integer(True), 0);
    _closeupchange := False;
  End;

  inherited;
End;

Procedure TAEComboBox.CloseUp;
Begin
  If Self.Style = csDropDown Then
  Begin
    _closeupchange := True;

    // If there is nothing selected OR the text in the box doesn't match the item shown by ItemIndex, set the index from cache
    If Self.ItemIndex = -1 Then
      Self.ItemIndex := _itemcache.IndexOf(String(Self.Text).ToLower);

    // If there is something selected and the text in the box doesn't match, correct the text
    If (Self.ItemIndex > -1) And
      (Self.Text <> Self.Items.Strings[Self.ItemIndex]) Then
      Self.Text := Self.Items[Self.ItemIndex]
    Else If (Self.ItemIndex = -1) And (Self.Text <> '') Then
      Self.Text := '';
  End;

  inherited;

  If Self.Style = csDropDown Then
    ResetTimer(TIMEREVENT_CLOSEUPCHANGE);
End;

Constructor TAEComboBox.Create(AOwner: TComponent);
Begin
  inherited;

  Self.AutoDropDown := True;

  _changecalled := False;

  _closeupchange := False;

  _dropdownchange := False;

  _itemcache := TList<String>.Create;

  _timerwindow := AllocateHWnd(TimerWindowProc);
End;

Destructor TAEComboBox.Destroy;
Begin
  FreeAndNil(_itemcache);

  DeallocateHWnd(_timerwindow);

  inherited;
End;

Procedure TAEComboBox.DropDown;
Begin
  inherited;

  _dropdownchange := True;
End;

Procedure TAEComboBox.ResetTimer(Const inTimerID: Integer);
Begin
  KillTimer(_timerwindow, inTimerID);

  If SetTimer(_timerwindow, inTimerID, 100, nil) = 0 Then
    Raise EOutOfResources.Create(SNoTimers);
End;

Procedure TAEComboBox.Select;
Begin
  _changecalled := False;

  Try
    inherited;
  Finally
    If Not _changecalled Then
      Self.Change;
  End;
End;

Procedure TAEComboBox.TimerWindowProc(var inMessage: TMessage);
Var
  s: String;
Begin
  If inMessage.Msg = WM_TIMER Then
  Begin
    KillTimer(_timerwindow, inMessage.WParam);

    Case inMessage.WParam Of
      TIMEREVENT_CLOSEUPCHANGE:
        _closeupchange := False;
      TIMEREVENT_REFRESHCACHE:
      Begin
        _itemcache.Clear;

        If Self.Style = csDropDown Then
          For s In Self.Items Do
            _itemcache.Add(s.ToLower)
        Else
          _itemcache.Pack;
      End;
    End;

    inMessage.Result := 0;
  End
  Else
    DefWindowProc(_timerwindow, inMessage.Msg, inMessage.wParam, inMessage.lParam);
End;

End.
