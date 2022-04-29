//
// Origin: Unknown
// Collected from: https://en.delphipraxis.net/topic/5058-getting-exception-stack-trace-in-2021/?do=findComment&comment=44094
//
// Purpose: Fill the .StackTrace property of Exceptions with caller addresses only
//

Unit StackTrace;

Interface

Implementation

Uses WinApi.Windows, System.SysUtils;

const
  DBG_STACK_LENGTH = 32;

type
  TDbgInfoStack = array [0 .. DBG_STACK_LENGTH - 1] of Pointer;
  PDbgInfoStack = ^TDbgInfoStack;

{$IFDEF MSWINDOWS}
function RtlCaptureStackBackTrace(FramesToSkip: ULONG; FramesToCapture: ULONG;
  BackTrace: Pointer; BackTraceHash: PULONG): USHORT; stdcall;
  external 'kernel32.dll';
{$ENDIF}
{$IFDEF MSWINDOWS}

procedure GetCallStackOS(var Stack: TDbgInfoStack; FramesToSkip: Integer);
begin
  ZeroMemory(@Stack, SizeOf(Stack));

  RtlCaptureStackBackTrace(FramesToSkip, Length(Stack), @Stack, nil);
end;
{$ENDIF}

function CallStackToStr(const Stack: TDbgInfoStack): string;
var
  Ptr: Pointer;
begin
  Result := '';
  for Ptr in Stack do
    if Ptr <> nil then
      Result := Result + Format('$%p', [Ptr]) + sLineBreak
    else
      Break;
end;

function GetExceptionStackInfo(P: PExceptionRecord): Pointer;
begin
  Result := AllocMem(SizeOf(TDbgInfoStack));
  GetCallStackOS(PDbgInfoStack(Result)^, 1);
  // исключаем саму функцию GetCallStackOS
end;

function GetStackInfoStringProc(Info: Pointer): string;
begin
  Result := CallStackToStr(PDbgInfoStack(Info)^);
end;

procedure CleanUpStackInfoProc(Info: Pointer);
begin
  Dispose(PDbgInfoStack(Info));
end;

procedure InstallExceptionCallStack;
begin
  System.SysUtils.Exception.GetExceptionStackInfoProc := GetExceptionStackInfo;
  System.SysUtils.Exception.GetStackInfoStringProc := GetStackInfoStringProc;
  System.SysUtils.Exception.CleanUpStackInfoProc := CleanUpStackInfoProc;
end;

procedure UninstallExceptionCallStack;
begin
  System.SysUtils.Exception.GetExceptionStackInfoProc := nil;
  System.SysUtils.Exception.GetStackInfoStringProc := nil;
  System.SysUtils.Exception.CleanUpStackInfoProc := nil;
end;

Initialization

InstallExceptionCallStack;

Finalization

UninstallExceptionCallStack;

End.
