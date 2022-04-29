//
// Origin: Unknown
// Collected from: Unknown
//
// Purpose: Get the OS name and version number in a standardized format
//

Unit OSVersion;

Interface

Uses Windows, SysUtils, TlHelp32;

Type
  TGPI = Function(dwOSMajorVersion, dwOSMinorVersion, dwSpMajorVersion,
    dwSpMinorVersion: DWORD; var pdwReturnedProductType: DWORD): BOOL; stdcall;

Function GetOSVersionInfo(Var Info: TOSVersionInfoEx): Boolean;
Function IsWow64: Boolean;
Function GetOSVersionText: String;

Implementation

Function GetOSVersionInfo(Var Info: TOSVersionInfoEx): Boolean;
Begin
  FillChar(Info, SizeOf(TOSVersionInfoEx), 0);
  Info.dwOSVersionInfoSize := SizeOf(TOSVersionInfoEx);
  Result := GetVersionEx(TOSVersionInfo(Addr(Info)^));
  If Not Result Then
  Begin
    FillChar(Info, SizeOf(TOSVersionInfoEx), 0);
    Info.dwOSVersionInfoSize := SizeOf(TOSVersionInfoEx);
    Result := GetVersionEx(TOSVersionInfo(Addr(Info)^));
    If Not Result Then
      Info.dwOSVersionInfoSize := 0;
  End;
end;

function ProcessRuns(exeFileName: String): Boolean;
var
  ContinueLoop: BOOL;
  FSnapshotHandle: THandle;
  FProcessEntry32: TProcessEntry32;
begin
  FSnapshotHandle := CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
  FProcessEntry32.dwSize := SizeOf(FProcessEntry32);
  ContinueLoop := Process32First(FSnapshotHandle, FProcessEntry32);
  Result := False;
  While Integer(ContinueLoop) <> 0 Do
  Begin
    If ((UpperCase(ExtractFileName(FProcessEntry32.szExeFile))
      = UpperCase(exeFileName)) Or (UpperCase(FProcessEntry32.szExeFile)
      = UpperCase(exeFileName))) Then
    Begin
      Result := True;
      Break;
    End;
    ContinueLoop := Process32Next(FSnapshotHandle, FProcessEntry32);
  End;
  CloseHandle(FSnapshotHandle);
end;

function IsWow64: Boolean;
Type
  TIsWow64Process = function(Handle: THandle; var Res: BOOL): BOOL; stdcall;
Var
  IsWow64Result: BOOL;
  IsWow64Process: TIsWow64Process;
Begin
  IsWow64Process := GetProcAddress(GetModuleHandle('kernel32.dll'),
    'IsWow64Process');
  If Assigned(IsWow64Process) And IsWow64Process(GetCurrentProcess,
    IsWow64Result) Then
    Result := IsWow64Result
  Else
    Result := False;
end;

function GetOSVersionText: string;
Var
  vn: Cardinal;
  Info: TOSVersionInfoEx;
  dwType: DWORD;
  pGPI: TGPI;
  server: Boolean;
begin
  Result := '';
  If Not GetOSVersionInfo(Info) Then
    Exit;
  vn := Info.dwMajorVersion * 10 + Info.dwMinorVersion;
  server := Info.wProductType <> VER_NT_WORKSTATION;

  Case vn Of
    50:
      If server Then
        Result := 'Windows Server 2000 '
      Else
        Result := 'Windows 2000 ';
    51:
      Result := 'Windows XP ';
    52:
      If server Then
      Begin
        Result := 'Windows Server 2003 ';
        If GetSystemMetrics(SM_SERVERR2) <> 0 Then
          Result := Result + 'R2 ';
      End
      Else
        Result := 'Windows XP ';
    60:
      If server Then
        Result := 'Windows Server 2008 '
      Else
        Result := 'Windows Vista ';
    61:
      If server Then
        Result := 'Windows Server 2008 R2 '
      Else
        Result := 'Windows 7 ';
    62:
      If server Then
        Result := 'Windows Server 2012 '
      Else
        Result := 'Windows 8 ';
    63:
      If server Then
        Result := 'Windows Server 2012 R2 '
      Else
        Result := 'Windows 8.1 ';
    64, 100:
      Begin
        If server And (Info.dwBuildNumber < 17677) Then
        Begin
          Result := 'Windows Server 2016 ';
          Case Info.dwBuildNumber Of
            14300:
              Result := Result + '1010 ';
            14393:
              Result := Result + '1607 ';
            16299:
              Result := Result + '1709 ';
            17134:
              Result := Result + '1803 ';
          End;
        End
        Else If vn = 100 Then
          If Info.dwBuildNumber < 22000 Then
            If server Then
            Begin
              Result := 'Windows Server 2019 ';
              Case Info.dwBuildNumber Of
                17677:
                  Result := Result + '1803 ';
                17763:
                  Result := Result + '1809 ';
                18362:
                  Result := Result + '1903 ';
                18363:
                  Result := Result + '1909 ';
                19041:
                  Result := Result + '2004 ';
              End;
            End
            Else
            Begin
              Result := 'Windows 10 ';
              Case Info.dwBuildNumber Of
                10240:
                  Result := Result + '1507 ';
                10586:
                  Result := Result + '1511 ';
                14393:
                  Result := Result + '1607 ';
                15063:
                  Result := Result + '1703 ';
                16299:
                  Result := Result + '1709 ';
                17134:
                  Result := Result + '1803 ';
                17763:
                  Result := Result + '1809 ';
                18362:
                  Result := Result + '1903 ';
                18363:
                  Result := Result + '1909 ';
                19041:
                  Result := Result + '2004 ';
                19042:
                  Result := Result + '20H2 ';
                19043:
                  Result := Result + '21H1 ';
                19044:
                  Result := Result + '21H2 ';
              End;
            End
          Else If server Then
          Begin
            Result := 'Windows Server 2022 ';
          End
          Else
          Begin
            Result := 'Windows 11 ';
            Case Info.dwBuildNumber Of
              22000:
                Result := Result + '21H2 ';
            End;
          End;
      End;
  Else
    Begin
      Result := 'Windows ';
      If server Then
        Result := Result + 'Server '
      Else
        Result := Result + 'Workstation ';
      Result := Result + IntToStr(Info.dwMajorVersion) + '.' +
        IntToStr(Info.dwMinorVersion) + ' ';
    End;
  End;
  dwType := 0;
  @pGPI := GetProcAddress(GetModuleHandle('kernel32.dll'), 'GetProductInfo');
  If Assigned(pGPI) Then
  Begin
    pGPI(Info.dwMajorVersion, Info.dwMinorVersion, 0, 0, dwType);
    Case dwType Of
      PRODUCT_BUSINESS:
        Result := Result + 'Business';
      PRODUCT_BUSINESS_N:
        Result := Result + 'Business N';
      PRODUCT_CLUSTER_SERVER:
        Result := Result + 'Cluster Server';
      PRODUCT_DATACENTER_SERVER:
        Result := Result + 'Datacenter';
      PRODUCT_DATACENTER_SERVER_CORE:
        Result := Result + 'Datacenter Core';
      PRODUCT_DATACENTER_SERVER_CORE_V:
        Result := Result + 'Core Datacenter (without Hyper-V)';
      PRODUCT_DATACENTER_SERVER_V:
        Result := Result + 'Datacenter (without Hyper-V)';
      PRODUCT_ENTERPRISE:
        Result := Result + 'Enterprise';
      PRODUCT_ENTERPRISE_N:
        Result := Result + 'Enterprise N';
      PRODUCT_ENTERPRISE_SERVER:
        Result := Result + 'Enterprise';
      PRODUCT_ENTERPRISE_SERVER_CORE:
        Result := Result + 'Enterprise Core';
      PRODUCT_ENTERPRISE_SERVER_CORE_V:
        Result := Result + 'Enterprise Core (without Hyper-V)';
      PRODUCT_ENTERPRISE_SERVER_IA64:
        Result := Result + 'Enterprise for Itanium-based systems';
      PRODUCT_ENTERPRISE_SERVER_V:
        Result := Result + 'Enterprise (without Hyper-V)';
      PRODUCT_HOME_BASIC:
        Result := Result + 'Home Basic';
      PRODUCT_HOME_BASIC_N:
        Result := Result + 'Home Basic N';
      PRODUCT_HOME_PREMIUM:
        Result := Result + 'Home Premium';
      PRODUCT_HOME_PREMIUM_N:
        Result := Result + 'Home Premium N';
      PRODUCT_HYPERV:
        Result := Result + 'Hyper-V';
      PRODUCT_PROFESSIONAL:
        Result := Result + 'Professional';
      PRODUCT_PROFESSIONAL_N:
        Result := Result + 'Profesional N';
      PRODUCT_SMALLBUSINESS_SERVER:
        Result := Result + 'Small Business';
      PRODUCT_SMALLBUSINESS_SERVER_PREMIUM:
        Result := Result + 'Small Business Premium';
      PRODUCT_STANDARD_SERVER:
        Result := Result + 'Standard';
      PRODUCT_STANDARD_SERVER_CORE:
        Result := Result + 'Standard Core';
      PRODUCT_STANDARD_SERVER_CORE_V:
        Result := Result + 'Standard Core (without Hyper-V)';
      PRODUCT_STANDARD_SERVER_V:
        Result := Result + 'Standard (without Hyper-V)';
      PRODUCT_STARTER:
        Result := Result + ' Starter';
      PRODUCT_STORAGE_ENTERPRISE_SERVER:
        Result := Result + 'Storage Enterprise';
      PRODUCT_STORAGE_EXPRESS_SERVER:
        Result := Result + 'Storage Express';
      PRODUCT_STORAGE_STANDARD_SERVER:
        Result := Result + 'Storage Standard';
      PRODUCT_STORAGE_WORKGROUP_SERVER:
        Result := Result + 'Storage Workgroup';
      PRODUCT_ULTIMATE:
        Result := Result + 'Ultimate';
      PRODUCT_ULTIMATE_N:
        Result := Result + 'Ultimate N';
      PRODUCT_WEB_SERVER:
        Result := Result + 'Web';
      PRODUCT_WEB_SERVER_CORE:
        Result := Result + 'Web Core';
    Else
      dwType := 0;
    End;
  End;
  If dwType = 0 Then
  Begin
    If Not server Then
      If Info.wSuiteMask And VER_SUITE_PERSONAL > 0 Then
        Result := Result + 'Home'
      Else
        Result := Result + 'Professional'
    Else
    Begin
      If Info.wSuiteMask And VER_SUITE_BLADE > 0 Then
        Result := Result + 'Web'
      Else If Info.wSuiteMask And VER_SUITE_DATACENTER > 0 Then
        Result := Result + 'Data Center'
      Else If Info.wSuiteMask And VER_SUITE_ENTERPRISE > 0 Then
        Result := Result + 'Enterprise'
      Else If Info.wSuiteMask And VER_SUITE_EMBEDDEDNT > 0 Then
        Result := Result + 'Embedded'
      Else
        Result := Result + 'Standard';
    End;
  End;
  If (vn >= 62) And server And Not ProcessRuns('dwm.exe') Then
    Result := Result + ' Core';
  If Info.wServicePackMajor > 0 Then
  Begin
    Result := Result + ' SP' + IntToStr(Info.wServicePackMajor);
    If Info.wServicePackMinor > 0 Then
      Result := Result + '.' + IntToStr(Info.wServicePackMinor);
    Result := Result;
  End;
{$IFDEF WIN32} If IsWow64 Then {$ENDIF} Result := Result + ' x64';
end;

end.
