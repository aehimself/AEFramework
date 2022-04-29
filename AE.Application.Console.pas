Unit AE.Application.Console;

Interface

Uses AE.Application.Application;

Procedure StartWithConsole(inAEApplicationClass: TAEApplicationClass);

Implementation

Uses WinApi.Windows, System.SysUtils, AE.Application.Helper;

Type
  TConsole = Class
    Class Procedure Log(inMessage: String = '');
  End;

Var
  ConsoleHandle: THandle;
  TerminateSignalreceived, Ended, ConsoleHandlerEnded, WaitForKey,
    OSShutdown: Boolean;
  LogCS: TRTLCriticalSection;
  ConsoleBufferInfo: Console_Screen_Buffer_Info;

Class Procedure TConsole.Log(inMessage: String = '');
Var
  textcolor: Word;
  nocolor, color: String;
Begin
  EnterCriticalSection(LogCS);
  Try
    If inMessage.ToLower.Contains(' raised ') Or
      inMessage.ToLower.Contains('exception ') Or
      inMessage.ToLower.Contains(' terminate') Or
      inMessage.ToLower.Contains(' fail') Or inMessage.ToLower.Contains
      (' error ') Then
      textcolor := FOREGROUND_RED Or FOREGROUND_INTENSITY // RED
    Else If inMessage.Contains('[') And inMessage.Contains(']') And
      Not inMessage.ToLower.Contains('starting up') Then
      textcolor := FOREGROUND_RED Or FOREGROUND_GREEN Or FOREGROUND_INTENSITY
      // Yellow
    Else If inMessage.ToLower.Contains(' success') Then
      textcolor := FOREGROUND_GREEN Or FOREGROUND_INTENSITY // Green
    Else
      textcolor := ConsoleBufferInfo.wAttributes;
    If inMessage.Contains(' - ') Then
    Begin
      nocolor := inMessage.Substring(0, inMessage.IndexOf(' - ') + 3);
      color := inMessage.Substring(inMessage.IndexOf(' - ') + 3);
    End
    Else
    Begin
      nocolor := '';
      color := inMessage;
    End;
    Write(nocolor);
    If textcolor <> ConsoleBufferInfo.wAttributes Then
      SetConsoleTextAttribute(ConsoleHandle, textcolor);
    WriteLn(color);
    If textcolor <> ConsoleBufferInfo.wAttributes Then
      SetConsoleTextAttribute(ConsoleHandle, ConsoleBufferInfo.wAttributes);
    Flush(OUTPUT);
  Finally
    LeaveCriticalSection(LogCS);
  End;
End;

Function ConsoleFound: Boolean;
Begin
  ConsoleHandle := GetStdHandle(Std_Output_Handle);
  If ConsoleHandle = Invalid_Handle_Value Then
    RaiseLastOSError;
  Result := ConsoleHandle <> 0;
End;

Function console_handler(inCtrlType: DWORD): Bool; StdCall;
Begin
  If TerminateSignalreceived Then
    Exit(True);
  TConsole.Log;
  Case inCtrlType Of
    CTRL_C_EVENT:
      TConsole.Log('Ctrl-C caught!');
    CTRL_BREAK_EVENT:
      TConsole.Log('Ctrl-Break caught!');
    CTRL_CLOSE_EVENT:
      TConsole.Log('Console exit caught!');
    CTRL_LOGOFF_EVENT:
      TConsole.Log('User logoff event caught!');
    CTRL_SHUTDOWN_EVENT:
      Begin
        OSShutdown := True;
        TConsole.Log('Shutdown event caught!');
      End;
  End;
  WaitForKey := Not((inCtrlType = CTRL_CLOSE_EVENT) Or
    (inCtrlType = CTRL_LOGOFF_EVENT) Or (inCtrlType = CTRL_SHUTDOWN_EVENT));
  TerminateSignalreceived := True; // Signal main program that we should quit
  While Not Ended Do // Wait for clean shutdown
    Sleep(50);
  Result := True;
  ConsoleHandlerEnded := True;
  // Signal main program that console handler finished
End;

Procedure StartWithConsole(inAEApplicationClass: TAEApplicationClass);
Var
  aeapp: TAEApplication;
  consoleallocated: Boolean;
Begin
  InitializeCriticalSection(LogCS);
  Try
    Try
      consoleallocated := Not ConsoleFound;
      If consoleallocated Then
      Begin
        AllocConsole;
        ConsoleFound;
      End;
      Try
        // SetConsoleTitle(PChar(AESHMClass.ServiceDisplayName + ' ' + TranslateFileVersion(ParamStr(0))));
        GetConsoleScreenBufferInfo(ConsoleHandle, ConsoleBufferInfo);
        Ended := False;
        ConsoleHandlerEnded := False;
        TerminateSignalreceived := False;
        WaitForKey := True;
        OSShutdown := False;
        TConsole.Log('Setting up console handler...');
        If Not SetConsoleCtrlHandler(@console_handler, True) Then
          RaiseLastOSError;
        Try
          TConsole.Log('Press Ctrl-C or Ctrl-Break to send a terminate signal');
          TConsole.Log;
          aeapp := inAEApplicationClass.Create(TConsole.Log);
          Try
            Repeat
              CustomMessagePump;
              Sleep(100);
            Until TerminateSignalreceived;
            aeapp.OSShutdown := OSShutdown;
          Finally
            TConsole.Log;
            aeapp.Free;
          End;
          Ended := True;
          // Signal console handler that clean shutdown is completed
          While Not ConsoleHandlerEnded Do
          // Wait for console handler to finish...
            Sleep(50);
          If WaitForKey Then
          Begin
            TConsole.Log;
            TConsole.Log('Press Enter to exit.');
            ReadLn;
          End;
        Finally
          TConsole.Log('Removing console handler...');
          If Not SetConsoleCtrlHandler(@console_handler, False) Then
            RaiseLastOSError;
        End;
      Finally
        If consoleallocated Then
          FreeConsole;
      End;
    Except
      On E: Exception Do
        TConsole.Log(E.ClassName + ' was raised with the message ' + E.Message);
    End;
  Finally
    DeleteCriticalSection(LogCS);
  End;
End;

End.
