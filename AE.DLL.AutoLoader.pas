Unit AE.DLL.AutoLoader;

Interface

Uses AE.DLL.Loader;

Type
  TAEDLLAutoLoader = Class(TAEDLLLoader)
  strict protected
    Procedure LoadMethods; Override;
  End;

Implementation

Uses WinApi.Windows, System.SysUtils;

Type
  PIMAGE_NT_HEADERS = ^IMAGE_NT_HEADERS;
  PIMAGE_EXPORT_DIRECTORY = ^IMAGE_EXPORT_DIRECTORY;

Function ImageNtHeader(Base: Pointer): PIMAGE_NT_HEADERS; StdCall; External 'dbghelp.dll';
Function ImageRvaToVa(NtHeaders: Pointer; Base: Pointer; Rva: ULONG; LastRvaSection: Pointer): Pointer; StdCall; External 'dbghelp.dll';

Procedure TAEDLLAutoLoader.LoadMethods;
Var
  a: Integer;
  filehandle, imagehandle: THandle;
  imageptr: Pointer;
  header: PIMAGE_NT_HEADERS;
  exporttable: PIMAGE_EXPORT_DIRECTORY;
  namesptr: PCardinal;
  nameptr: PAnsiChar;
Begin
  inherited;

  // https://stackoverflow.com/questions/31917322/how-to-get-all-the-exported-functions-in-a-dll

  filehandle := CreateFile(PChar(Self.DLLName), GENERIC_READ, FILE_SHARE_READ, nil, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0);

  If filehandle = INVALID_HANDLE_VALUE Then
    RaiseLastOSError;

  Try
    imagehandle := CreateFileMapping(filehandle, nil, PAGE_READONLY, 0, 0, nil);

    If imagehandle = 0 Then
      RaiseLastOSError;

    Try
      imageptr := MapViewOfFile(imagehandle, FILE_MAP_READ, 0, 0, 0);

      If Not Assigned(imageptr) Then
        RaiseLastOSError;

      Try
        header := ImageNtHeader(imageptr);

        If Not Assigned(header) Then
          RaiseLastOSError;

        If header.Signature <> $00004550 Then // "PE\0\0" as a DWORD.
          Raise EOSError.Create('Incorrect image NT header signature!');

        exporttable := ImageRvaToVa(header, imageptr, header.OptionalHeader.DataDirectory[0].VirtualAddress, nil);

        If Not Assigned(exporttable) Then
          RaiseLastOSError;

        namesptr := ImageRvaToVa(header, imageptr, Cardinal(exporttable.AddressOfNames), nil);

        If Not Assigned(namesptr) Then
          RaiseLastOSError;

        For a := 0 To exporttable.NumberOfNames-1 Do
        Begin
          nameptr := ImageRvaToVa(header, imageptr, namesptr^, nil);

          If Not Assigned(nameptr) Then
            RaiseLastOSError;

          Self.LoadMethod(String(nameptr));

          Inc(namesptr);
        End;
      Finally
        UnmapViewOfFile(imageptr);
      End;
    Finally
      CloseHandle(imagehandle);
    End;
  Finally
    CloseHandle(filehandle);
  End;
End;

End.
