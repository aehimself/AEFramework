object Form2: TForm2
  Left = 0
  Top = 0
  Caption = 'TAEDelphiInstances demo'
  ClientHeight = 441
  ClientWidth = 624
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  OnCreate = FormCreate
  TextHeight = 15
  object Splitter1: TSplitter
    Left = 185
    Top = 0
    Width = 5
    Height = 441
  end
  object InstancesPanel: TPanel
    Left = 190
    Top = 0
    Width = 434
    Height = 441
    Align = alClient
    BevelOuter = bvNone
    TabOrder = 0
    object InstancesListBox: TListBox
      Left = 0
      Top = 0
      Width = 434
      Height = 400
      Align = alClient
      ItemHeight = 15
      TabOrder = 0
    end
    object InstanceButtonsPanel: TPanel
      Left = 0
      Top = 400
      Width = 434
      Height = 41
      Align = alBottom
      BevelOuter = bvNone
      TabOrder = 1
      DesignSize = (
        434
        41)
      object OpenFileButton: TButton
        Left = 6
        Top = 5
        Width = 423
        Height = 25
        Anchors = [akLeft, akTop, akRight]
        Caption = 'Open file'
        TabOrder = 0
        OnClick = OpenFileButtonClick
      end
    end
  end
  object InstallationsPanel: TPanel
    Left = 0
    Top = 0
    Width = 185
    Height = 441
    Align = alLeft
    Caption = 'InstallationsPanel'
    TabOrder = 1
    object InstallationsListBox: TListBox
      Left = 1
      Top = 1
      Width = 257
      Height = 398
      Align = alLeft
      ItemHeight = 15
      TabOrder = 0
      OnClick = InstallationsListBoxClick
    end
    object InstallationButtonsPanel: TPanel
      Left = 1
      Top = 399
      Width = 183
      Height = 41
      Align = alBottom
      BevelOuter = bvNone
      TabOrder = 1
      DesignSize = (
        183
        41)
      object NewInstanceButton: TButton
        Left = 6
        Top = 6
        Width = 170
        Height = 25
        Anchors = [akLeft, akTop, akRight]
        Caption = 'New instance'
        TabOrder = 0
        OnClick = NewInstanceButtonClick
      end
    end
  end
  object OpenDialog: TOpenDialog
    Filter = 
      'Delphi projects (*.dproj, *.dpr)|*.dproj;*.dpr|Delphi source fil' +
      'es (*.pas)|*.pas|Delphi group projects (*.groupproj)|*.groupproj'
    Options = [ofHideReadOnly, ofPathMustExist, ofFileMustExist, ofEnableSizing]
    Left = 40
    Top = 16
  end
end
