// ************************************************************************ //
// The types declared in this file were generated from data read from the
// WSDL File described below:
// WSDL     : http://www.mnb.hu/arfolyamok.asmx?wsdl
//  >Import : http://www.mnb.hu/arfolyamok.asmx?wsdl=wsdl0
//  >Import : http://www.mnb.hu/arfolyamok.asmx?wsdl=wsdl0>0
//  >Import : http://www.mnb.hu/arfolyamok.asmx?xsd=xsd1
//  >Import : http://www.mnb.hu/arfolyamok.asmx?xsd=xsd0
// Encoding : utf-8
// Version  : 1.0
// (2023. 02. 14. 12:00:12 - - $Rev: 108085 $)
// ************************************************************************ //

unit MNB.ExchangeRate.SoapService;

interface

uses Soap.InvokeRegistry, Soap.SOAPHTTPClient, System.Types, Soap.XSBuiltIns;

const
  IS_OPTN = $0001;
  IS_NLBL = $0004;


type

  // ************************************************************************ //
  // The following types, referred to in the WSDL document are not being represented
  // in this file. They are either aliases[@] of other types represented or were referred
  // to but never[!] declared in the document. The types from the latter category
  // typically map to predefined/known XML or Embarcadero types; however, they could also 
  // indicate incorrect WSDL documents that failed to declare or import a schema type.
  // ************************************************************************ //
  // !:string          - "http://www.w3.org/2001/XMLSchema"[Gbl]

  string_              = class;                 { "http://schemas.microsoft.com/2003/10/Serialization/"[Flt][Alias] }



  // ************************************************************************ //
  // XML       : string, alias
  // Namespace : http://schemas.microsoft.com/2003/10/Serialization/
  // Serializtn: [xoSimpleTypeWrapper]
  // Info      : Fault
  // ************************************************************************ //
  string_ = class(ERemotableException)
  private
    FValue: string;
  published
    property Value: string  read FValue write FValue;
  end;


  // ************************************************************************ //
  // Namespace : http://www.mnb.hu/webservices/
  // soapAction: http://www.mnb.hu/webservices/MNBArfolyamServiceSoap/%operationName%
  // transport : http://schemas.xmlsoap.org/soap/http
  // style     : document
  // use       : literal
  // binding   : CustomBinding_MNBArfolyamServiceSoap
  // service   : MNBArfolyamServiceSoapImpl
  // port      : CustomBinding_MNBArfolyamServiceSoap
  // URL       : http://www.mnb.hu/arfolyamok.asmx
  // ************************************************************************ //
  MNBArfolyamServiceSoap = interface(IInvokable)
  ['{059D23E9-C567-5AD4-94C3-3A090B1CA894}']
    function  GetCurrencies: string; stdcall;
    function  GetCurrencyUnits(const currencyNames: string): string; stdcall;
    function  GetCurrentExchangeRates: string; stdcall;
    function  GetDateInterval: string; stdcall;
    function  GetExchangeRates(const startDate: string; const endDate: string; const currencyNames: string): string; stdcall;
    function  GetInfo: string; stdcall;
  end;

function GetMNBArfolyamServiceSoap(UseWSDL: Boolean=System.False; Addr: string=''; HTTPRIO: THTTPRIO = nil): MNBArfolyamServiceSoap;


implementation
  uses System.SysUtils;

function GetMNBArfolyamServiceSoap(UseWSDL: Boolean; Addr: string; HTTPRIO: THTTPRIO): MNBArfolyamServiceSoap;
const
  defWSDL = 'http://www.mnb.hu/arfolyamok.asmx?wsdl';
  defURL  = 'http://www.mnb.hu/arfolyamok.asmx';
  defSvc  = 'MNBArfolyamServiceSoapImpl';
  defPrt  = 'CustomBinding_MNBArfolyamServiceSoap';
var
  RIO: THTTPRIO;
begin
  Result := nil;
  if (Addr = '') then
  begin
    if UseWSDL then
      Addr := defWSDL
    else
      Addr := defURL;
  end;
  if HTTPRIO = nil then
    RIO := THTTPRIO.Create(nil)
  else
    RIO := HTTPRIO;
  try
    Result := (RIO as MNBArfolyamServiceSoap);
    if UseWSDL then
    begin
      RIO.WSDLLocation := Addr;
      RIO.Service := defSvc;
      RIO.Port := defPrt;
    end else
      RIO.URL := Addr;
  finally
    if (Result = nil) and (HTTPRIO = nil) then
      RIO.Free;
  end;
end;


initialization
  { MNBArfolyamServiceSoap }
  InvRegistry.RegisterInterface(TypeInfo(MNBArfolyamServiceSoap), 'http://www.mnb.hu/webservices/', 'utf-8');
  InvRegistry.RegisterDefaultSOAPAction(TypeInfo(MNBArfolyamServiceSoap), 'http://www.mnb.hu/webservices/MNBArfolyamServiceSoap/%operationName%');
  InvRegistry.RegisterInvokeOptions(TypeInfo(MNBArfolyamServiceSoap), ioDocument);
  { MNBArfolyamServiceSoap.GetCurrencies }
  InvRegistry.RegisterMethodInfo(TypeInfo(MNBArfolyamServiceSoap), 'GetCurrencies', '',
                                 '[ReturnName="GetCurrenciesResult"]', IS_OPTN or IS_NLBL);
  InvRegistry.RegisterParamInfo(TypeInfo(MNBArfolyamServiceSoap), 'GetCurrencies', 'GetCurrenciesResult', '',
                                '', IS_NLBL);
  { MNBArfolyamServiceSoap.GetCurrencyUnits }
  InvRegistry.RegisterMethodInfo(TypeInfo(MNBArfolyamServiceSoap), 'GetCurrencyUnits', '',
                                 '[ReturnName="GetCurrencyUnitsResult"]', IS_OPTN or IS_NLBL);
  InvRegistry.RegisterParamInfo(TypeInfo(MNBArfolyamServiceSoap), 'GetCurrencyUnits', 'currencyNames', '',
                                '', IS_NLBL);
  InvRegistry.RegisterParamInfo(TypeInfo(MNBArfolyamServiceSoap), 'GetCurrencyUnits', 'GetCurrencyUnitsResult', '',
                                '', IS_NLBL);
  { MNBArfolyamServiceSoap.GetCurrentExchangeRates }
  InvRegistry.RegisterMethodInfo(TypeInfo(MNBArfolyamServiceSoap), 'GetCurrentExchangeRates', '',
                                 '[ReturnName="GetCurrentExchangeRatesResult"]', IS_OPTN or IS_NLBL);
  InvRegistry.RegisterParamInfo(TypeInfo(MNBArfolyamServiceSoap), 'GetCurrentExchangeRates', 'GetCurrentExchangeRatesResult', '',
                                '', IS_NLBL);
  { MNBArfolyamServiceSoap.GetDateInterval }
  InvRegistry.RegisterMethodInfo(TypeInfo(MNBArfolyamServiceSoap), 'GetDateInterval', '',
                                 '[ReturnName="GetDateIntervalResult"]', IS_OPTN or IS_NLBL);
  InvRegistry.RegisterParamInfo(TypeInfo(MNBArfolyamServiceSoap), 'GetDateInterval', 'GetDateIntervalResult', '',
                                '', IS_NLBL);
  { MNBArfolyamServiceSoap.GetExchangeRates }
  InvRegistry.RegisterMethodInfo(TypeInfo(MNBArfolyamServiceSoap), 'GetExchangeRates', '',
                                 '[ReturnName="GetExchangeRatesResult"]', IS_OPTN or IS_NLBL);
  InvRegistry.RegisterParamInfo(TypeInfo(MNBArfolyamServiceSoap), 'GetExchangeRates', 'startDate', '',
                                '', IS_NLBL);
  InvRegistry.RegisterParamInfo(TypeInfo(MNBArfolyamServiceSoap), 'GetExchangeRates', 'endDate', '',
                                '', IS_NLBL);
  InvRegistry.RegisterParamInfo(TypeInfo(MNBArfolyamServiceSoap), 'GetExchangeRates', 'currencyNames', '',
                                '', IS_NLBL);
  InvRegistry.RegisterParamInfo(TypeInfo(MNBArfolyamServiceSoap), 'GetExchangeRates', 'GetExchangeRatesResult', '',
                                '', IS_NLBL);
  { MNBArfolyamServiceSoap.GetInfo }
  InvRegistry.RegisterMethodInfo(TypeInfo(MNBArfolyamServiceSoap), 'GetInfo', '',
                                 '[ReturnName="GetInfoResult"]', IS_OPTN or IS_NLBL);
  InvRegistry.RegisterParamInfo(TypeInfo(MNBArfolyamServiceSoap), 'GetInfo', 'GetInfoResult', '',
                                '', IS_NLBL);
  RemClassRegistry.RegisterXSClass(string_, 'http://schemas.microsoft.com/2003/10/Serialization/', 'string_', 'string');
  RemClassRegistry.RegisterSerializeOptions(string_, [xoSimpleTypeWrapper]);

end.