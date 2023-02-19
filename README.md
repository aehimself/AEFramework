# AEFramework

AEFramework is a set of helper units / components which I use for most of my projects. Since they might be of interest of others it is now hosted on GitHub. Feel free to use, modify under [Creative Commons Attribution 4.0 International](http://creativecommons.org/licenses/by/4.0/)

## AE.Application.*.pas
These classes can be used to quickly create a service / console application.

## AE.Comp.*.pas
Fixes and enhancements for existing VCL controls. These controls fully support Delphi VCL styles.

#### AE.Comp.ComboBox.pas
Contains TAEComboBox, which allows case-insensitive item selection while typing if Style is csDropDown.

#### AE.Comp.DBGrid.pas
Contains TAEDBGrid with automatic column width detection, proper mouse wheel and scrollbar scrolling, scrollbar positioning, alternate row backgrounds and some painting improvements.

#### AE.Comp.HeaderMenuItem.pas
TAEHeaderMenuItem is always disabled, acts as a separator in Popup / main menus. Born because of a topic on [DelphiPraxis](https://en.delphipraxis.net/topic/5397-tpopupmenu-with-group-headers).

#### AE.Comp.PageControl.pas
TAEPageControl adds drag-and-drop sheet reordering and close buttons on tabs.

#### AE.Comp.ThreadedTimer.pas
TAEThreadedTimer is a modernized, drop-in replacement of Delphi's TTimer class based on a [StackExchange](https://codereview.stackexchange.com/questions/153819/ttimerthread-threaded-timer-class) StackExchange. More information is on [DelphiPraxis](https://en.delphipraxis.net/topic/6621-tthreadedtimer).

#### AE.Comp.Updater.*.pas
TAEUpdater is a free to use application autoupdater. More information on [DelphiPraxis](https://en.delphipraxis.net/topic/7711-free-low-maintenance-update-mechanism).

#### AE.DDEManager.pas
As Delphi's TDDEClientConv is severely out-of-date and is not fully functional on newer releases, TAEDDEManager can take care of DDE server discovery and command execution.

#### AE.IDE.*.pas
TAEDelphiVersions and TVSVersions detect local Delphi and Visual Studio installations and their individual running instances. Via DDE a file can be opened in the IDE of a specific instance. You can read the struggle of creation on [DelphiPraxis](https://en.delphipraxis.net/topic/7955-how-to-open-a-file-in-the-already-running-ide).

#### AE.Misc.ByteUtils.pas
Helper class to compare, fully clear and deallocate, via ZLib compress Delphi TBytes arrays.

#### AE.Misc.FileUtils.pas
Extracts specific version information from a given executable, like version number, product name, etc.

#### AE.Misc.Random.pas
TAERandom is a pure pascal pseudorandom generator which can have multiple individual instances with different seeds. Currently two useable version exists, TAEDelphiRandom and TAEXORShift.

#### AE.Misc.UnixTimestamp.pas
Before I realized Delphi now natively supports UTC converted Unix timestamps I used this unit to do those conversions. Now it only calls the Delphi methods.

#### MNB.ExchangeRate.SoapService.pas and AE.MNB.ExchangeRates.pas
The first file is the WSDL import of the webservice of [Hungarian National Bank](https://www.mnb.hu/sajtoszoba/sajtokozlemenyek/2015-evi-sajtokozlemenyek/tajekoztatas-az-arfolyam-webservice-mukodeserol), the second one is an installable component which makes it easy to convert between the [supported](https://mnb.hu/arfolyamok) currencies.
