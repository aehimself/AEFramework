Unit AE.Comp.MenuTreeParser;

Interface

Uses System.Classes;

Type
  TAEMenuTreeParser = Class(TComponent)
  strict private
    _allmenuitems: TStringList;
    _location: String;
    _locationfolders: TArray<String>;
    _locationmenuitems: TArray<String>;
    _separator: Char;
    Procedure AllMenuItemsChanged(Sender: TObject);
    Procedure SetAllMenuItems(Const inMenuItems: TStringList);
    Procedure SetLocation(inLocation: String);
  public
    Constructor Create(AOwner: TComponent); Override;
    Destructor Destroy; Override;
  published
    Property Location: String Read _location Write SetLocation;
    Property LocationFolders: TArray<String> Read _locationfolders;
    Property LocationMenuItems: TArray<String> Read _locationmenuitems;
    Property AllMenuItems: TStringList Read _allmenuitems Write SetAllMenuItems;
    Property SeparatorChar: Char Read _separator Write _separator;
  End;

Implementation

Uses System.SysUtils, System.Generics.Collections;

Procedure TAEMenuTreeParser.AllMenuItemsChanged(Sender: TObject);
Begin
  Self.Location := '';
End;

Constructor TAEMenuTreeParser.Create(AOwner: TComponent);
Begin
  inherited;

  _allmenuitems := TStringList.Create;
  _allmenuitems.OnChange := AllMenuItemsChanged;

  _separator := '\';

  Self.Location := '';
End;

Destructor TAEMenuTreeParser.Destroy;
Begin
  FreeAndNil(_allmenuitems);

  inherited;
End;

Procedure TAEMenuTreeParser.SetAllMenuItems(Const inMenuItems: TStringList);
Begin
  _allmenuitems.Assign(inMenuItems);
End;

Procedure TAEMenuTreeParser.SetLocation(inLocation: String);
Var
  a: NativeInt;
  itemname: String;
  folders: TList<String>;
Begin
  _location := inLocation;

  If Not inLocation.IsEmpty And Not inLocation.EndsWith(_separator) Then
    inLocation := inLocation + _separator;

  SetLength(_locationfolders, 0);
  SetLength(_locationmenuitems, 0);

  folders := TList<String>.Create;
  Try
    For a := 0 To _allmenuitems.Count - 1 Do
      If _allmenuitems[a].StartsWith(inLocation) Then
      Begin
        itemname := _allmenuitems[a].Substring(inLocation.Length);

        If itemname.Contains(_separator) Then
        Begin
          itemname := itemname.Substring(0, itemname.IndexOf(_separator));

          If Not folders.Contains(itemname) Then
            folders.Add(itemname);
        End
        Else
        Begin
          SetLength(_locationmenuitems, Length(_locationmenuitems) + 1);

          _locationmenuitems[High(_locationmenuitems)] := itemname;
        End;
      End;

    _locationfolders := folders.ToArray;

    TArray.Sort<String>(_locationfolders);
    TArray.Sort<String>(_locationmenuitems);
  Finally
    FreeAndNil(folders);
  End;
End;

End.
