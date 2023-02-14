Unit AE.MNB.ExchangeRates;

Interface

Uses System.Generics.Collections, System.Classes;

Type
  TAEMNBExchangeRates = Class(TComponent)
  strict private
    _datadate: TDateTime;
    _rates: TDictionary<String, Double>;
    Function GetCurrencies: TArray<String>;
  public
    Constructor Create(inOwner: TComponent); Override;
    Destructor Destroy; Override;
    Procedure RefreshRates;
    Function ExchangeRate(Const inCurrency: String): Double; Overload;
    Function ExchangeRate(Const inSourceCurrency, inTargetCurrency: String): Double; Overload;
    Property Currencies: TArray<String> Read GetCurrencies;
    Property DataDate: TDateTime Read _datadate;
  End;

Implementation

Uses System.SysUtils, MNB.ExchangeRate.SoapService;

Constructor TAEMNBExchangeRates.Create(inOwner: TComponent);
Begin
  inherited;

  _datadate := Double.MinValue;
  _rates := TDictionary<String, Double>.Create;
End;

Destructor TAEMNBExchangeRates.Destroy;
Begin
  FreeAndNil(_rates);

  inherited;
End;

Function TAEMNBExchangeRates.ExchangeRate(Const inSourceCurrency, inTargetCurrency: String): Double;
Var
  srate, trate: Double;
Begin
  Result := 0;

  If Not _rates.TryGetValue(inSourceCurrency, srate) Then
    Exit;

  If Not _rates.TryGetValue(inTargetCurrency, trate) Then
    Exit;

  Result := srate / trate;
End;

Function TAEMNBExchangeRates.GetCurrencies: TArray<String>;
Begin
  Result := _rates.Keys.ToArray;

  TArray.Sort<String>(Result);
End;

Function TAEMNBExchangeRates.ExchangeRate(Const inCurrency: String): Double;
Begin
  _rates.TryGetValue(inCurrency, Result);
End;

Procedure TAEMNBExchangeRates.RefreshRates;
Const
  DAYDATE = '<Day date="';
  RATEUNIT = '<Rate unit="';
  CURRNAME = 'curr="';

Var
  xml, cname: String;
  cpos, cunit: Integer;
  fs: TFormatSettings;
  crate: Double;
Begin
  // MNB's SOAP service is free and publicly available for everyone. Therefore let's be kind and not cause extra load on their systems
  // if we don't need to.

  // We already have the exchange rates for today. Check back tomorrow!
  If _datadate = Date Then
    Exit;

  _rates.Clear;

  // This is the result of an actual SOAP service call. It might be outdated, but perfect for debugging.

  xml :=
  {$IFDEF DEBUG}
    '<MNBCurrentExchangeRates><Day date="2023-02-14"><Rate unit="1" curr="AUD">247,74</Rate><Rate unit="1" curr="BGN">195,53</Rate>' +
    '<Rate unit="1" curr="BRL">68,87</Rate><Rate unit="1" curr="CAD">266,51</Rate><Rate unit="1" curr="CHF">387,81</Rate>' +
    '<Rate unit="1" curr="CNY">52,16</Rate><Rate unit="1" curr="CZK">16,09</Rate><Rate unit="1" curr="DKK">51,33</Rate>' +
    '<Rate unit="1" curr="EUR">382,44</Rate><Rate unit="1" curr="GBP">433,15</Rate><Rate unit="1" curr="HKD">45,27</Rate>' +
    '<Rate unit="100" curr="IDR">2,34</Rate><Rate unit="1" curr="ILS">101,41</Rate><Rate unit="1" curr="INR">4,29</Rate>' +
    '<Rate unit="1" curr="ISK">2,49</Rate><Rate unit="100" curr="JPY">269,17</Rate><Rate unit="100" curr="KRW">28,05</Rate>' +
    '<Rate unit="1" curr="MXN">19,14</Rate><Rate unit="1" curr="MYR">81,73</Rate><Rate unit="1" curr="NOK">35,26</Rate>' +
    '<Rate unit="1" curr="NZD">225,32</Rate><Rate unit="1" curr="PHP">6,48</Rate><Rate unit="1" curr="PLN">79,95</Rate>' +
    '<Rate unit="1" curr="RON">78,03</Rate><Rate unit="1" curr="RSD">3,26</Rate><Rate unit="1" curr="RUB">4,81</Rate>' +
    '<Rate unit="1" curr="SEK">34,48</Rate><Rate unit="1" curr="SGD">267,98</Rate><Rate unit="1" curr="THB">10,51</Rate>' +
    '<Rate unit="1" curr="TRY">18,86</Rate><Rate unit="1" curr="UAH">9,67</Rate><Rate unit="1" curr="USD">355,39</Rate>' +
    '<Rate unit="1" curr="ZAR">19,93</Rate></Day></MNBCurrentExchangeRates>';
  {$ELSE}
    GetMNBArfolyamServiceSoap.GetCurrentExchangeRates;
  {$ENDIF}

  fs := TFormatSettings.Create;
  fs.DateSeparator := '-';
  fs.ShortDateFormat := 'yyyy-mm-dd';
  fs.DecimalSeparator := ',';

  // As the returned document is fairly simple and straightforward there's no need to process it as IXMLDocument (yet).
  // Finding the necessary data as string will be more resource (and thread) friendly

  cpos := xml.IndexOf(DAYDATE);

  If cpos = -1 Then
    Exit;

  If Not TryStrToDate(xml.Substring(cpos + DAYDATE.Length, fs.ShortDateFormat.Length), _datadate, fs) Then
    Exit;

  Repeat
    cpos := xml.IndexOf(RATEUNIT, cpos);

    If cpos <> -1 Then
    Begin
      Inc(cpos, RATEUNIT.Length);

      If Not Integer.TryParse(xml.Substring(cpos, xml.IndexOf('"', cpos) - cpos), cunit) Then
        Continue;

      cpos := xml.IndexOf(CURRNAME, cpos);

      If cpos <> -1 Then
      Begin
        Inc(cpos, CURRNAME.Length);

        cname := xml.Substring(cpos, xml.IndexOf('"', cpos) - cpos);

        cpos := xml.IndexOf('>', cpos);

        If cpos <> -1 Then
        Begin
          Inc(cpos);

          If Not Double.TryParse(xml.Substring(cpos, xml.IndexOf('<', cpos) - cpos), crate, fs) Then
            Continue;

          _rates.Add(cname, crate / cunit);
        End;
      End;
    End;
  Until cpos = -1;
End;

End.
