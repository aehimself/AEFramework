{
  AE Framework © 2022 by Akos Eigler is licensed under CC BY 4.0.
  To view a copy of this license, visit http://creativecommons.org/licenses/by/4.0/

  This license requires that reusers give credit to the creator. It allows reusers to distribute, remix, adapt,
  and build upon the material in any medium or format, even for commercial purposes.
}

Unit AE.Application.Helper;

Interface

Uses System.SysUtils;

Type
  TLogProcedure = Procedure(inMessageToLog: String) Of Object;
  TProcedureOfObject = Procedure Of Object;
  TErrorHandler = Procedure(inException: Exception) Of Object;
  TLogDateFormat = (dfNone, dfSystemDefault, dfNormal, dfDebug);
  EAEApplicationException = Class(Exception);

Const
  POLLINTERVAL = 100;

Procedure CustomMessagePump;

Implementation

Uses WinApi.Windows;

Procedure CustomMessagePump;
Var
  msg: TagMsg;
Begin
  // TWSocket, TClientSocket and TServerSocket is using the forms message pump to
  // fire off events in non-blocking mode. In a worker thread there are no forms and
  // so we have to create a message pump for ourselves
  While PeekMessage(msg, 0, 0, 0, 0) Do
  Begin
    GetMessage(msg, 0, 0, 0);
    TranslateMessage(msg);
    DispatchMessage(msg);
  End;
End;

End.
