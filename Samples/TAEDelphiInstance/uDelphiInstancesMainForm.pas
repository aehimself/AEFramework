Unit uDelphiInstancesMainForm;

Interface

Uses System.Classes, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, AE.IDE.DelphiVersions, Vcl.StdCtrls, Vcl.ExtCtrls;

Type
  TForm2 = Class(TForm)
    Splitter1: TSplitter;
    InstancesPanel: TPanel;
    InstancesListBox: TListBox;
    InstanceButtonsPanel: TPanel;
    OpenFileButton: TButton;
    InstallationsPanel: TPanel;
    InstallationsListBox: TListBox;
    InstallationButtonsPanel: TPanel;
    NewInstanceButton: TButton;
    OpenDialog: TOpenDialog;
    Procedure FormCreate(Sender: TObject);
    Procedure InstallationsListBoxClick(Sender: TObject);
    Procedure NewInstanceButtonClick(Sender: TObject);
    Procedure OpenFileButtonClick(Sender: TObject);
  private
    dv: TAEDelphiVersions;
  End;

Var
  Form2: TForm2;

Implementation

Uses AE.IDE.Versions, System.SysUtils;

{$R *.dfm}

Procedure TForm2.NewInstanceButtonClick(Sender: TObject);
Var
  selver: TAEIDEVersion;
  inst: TAEIDEINstance;
Begin
  If InstallationsListBox.ItemIndex = -1 Then
    Exit;

  selver := dv.VersionByName(InstallationsListBox.Items.Strings[InstallationsListBox.ItemIndex]);
  inst := selver.NewIDEInstance;

  InstancesListBox.Items.AddObject(inst.PID.ToString + ', ' + inst.IDECaption, inst);
End;

Procedure TForm2.OpenFileButtonClick(Sender: TObject);
Var
  selinst: TAEIDEInstance;
Begin
  If InstancesListBox.ItemIndex = -1 Then
    Exit;

  If Not OpenDialog.Execute Then
    Exit;

  selinst := TAEIDEInstance(InstancesListBox.Items.Objects[InstancesListBox.ItemIndex]);

  selinst.OpenFile(OpenDialog.FileName);
End;

Procedure TForm2.FormCreate(Sender: TObject);
Var
  iv: TAEIDEVersion;
Begin
  dv := TAEDelphiVersions.Create(Self);

  For iv In dv.InstalledVersions Do
    InstallationsListBox.Items.AddObject(iv.Name, iv);
End;

Procedure TForm2.InstallationsListBoxClick(Sender: TObject);
Var
  selver: TAEIDEVersion;
  inst: TAEIDEInstance;
Begin
  InstancesListBox.Items.Clear;

  If InstallationsListBox.ItemIndex = -1 Then
    Exit;

  selver := TAEIDEVersion(InstallationsListBox.Items.Objects[InstallationsListBox.ItemIndex]);

  For inst In selver.Instances Do
    InstancesListBox.Items.AddObject(inst.PID.ToString + ', ' + inst.IDECaption, inst);
End;

End.
