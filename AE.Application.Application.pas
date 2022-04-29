Unit AE.Application.Application;

Interface

Uses AE.Application.Helper;

Type
  TAEApplication = Class
  strict private
    _osshutdown: Boolean;
    _logprocedure: TLogProcedure;
  strict protected
    LogDateFormat: TLogDateFormat;
    Procedure Log(inMessage: String);
    Procedure Creating; Virtual;
    Procedure Destroying; Virtual;
  public
    Constructor Create(inLogProcedure: TLogProcedure); ReIntroduce;
    Destructor Destroy; Override;
    Property OSShutdown: Boolean Read _osshutdown Write _osshutdown;
  End;

  TAEApplicationClass = Class Of TAEApplication;

Implementation

Uses System.SysUtils;

Constructor TAEApplication.Create(inLogProcedure: TLogProcedure);
Begin
  inherited Create;
{$IFDEF DEBUG}
  LogDateFormat := dfDebug;
  ReportMemoryLeaksOnShutdown := True;
{$ELSE}
  LogDateFormat := dfSystemDefault;
{$ENDIF}
  _logprocedure := inLogProcedure;
  _osshutdown := False;
  Self.Creating;
End;

Procedure TAEApplication.Creating;
Begin
  // Dummy
End;

Destructor TAEApplication.Destroy;
Begin
  Self.Destroying;
  inherited;
End;

Procedure TAEApplication.Destroying;
Begin
  // Dummy
End;

Procedure TAEApplication.Log(inMessage: String);
Var
  datetime: String;
Begin
  If Assigned(_logprocedure) Then
  Begin
    Case LogDateFormat Of
      dfNone:
        datetime := '';
      dfSystemDefault:
        datetime := DateTimeToStr(Now) + ' - ';
      dfNormal:
        datetime := FormatDateTime('yyyy.mm.dd hh:nn:ss', Now) + ' - ';
      dfDebug:
        datetime := FormatDateTime('yyyy.mm.dd hh:nn:ss.zzzz', Now) + ' - ';
    End;
    _logprocedure(datetime + inMessage);
  End;
End;

End.
