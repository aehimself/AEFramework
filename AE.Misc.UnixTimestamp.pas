{
  AE Framework © 2022 by Akos Eigler is licensed under CC BY 4.0.
  To view a copy of this license, visit http://creativecommons.org/licenses/by/4.0/

  This license requires that reusers give credit to the creator. It allows reusers to distribute, remix, adapt,
  and build upon the material in any medium or format, even for commercial purposes.
}

Unit AE.Misc.UnixTimestamp;

Interface

Function DateToUnix(Const inDateTime: TDateTime;
  Const inConvertToUTC: Boolean = True): UInt64;
Function UnixToDate(Const inUnix: UInt64;
  Const inConvertFromUTC: Boolean = True): TDateTime;

Implementation

Uses System.DateUtils;

// Delphi's implementation expects to be told if the supplied date is in UTC already or not.
// It will NOT add the timezone AND daylight saving offset if the incoming parameter is True.
//
// Therefore, if we want to convert, we have to send False, if we don't, True; this is why
// we are inverting our incoming variables

Function DateToUnix(Const inDateTime: TDateTime;
  Const inConvertToUTC: Boolean = True): UInt64;
Begin
  Result := DateTimeToUnix(inDateTime, Not inConvertToUTC);
End;

Function UnixToDate(Const inUnix: UInt64;
  Const inConvertFromUTC: Boolean = True): TDateTime;
Begin
  Result := UnixToDateTime(inUnix, Not inConvertFromUTC);
End;

End.
