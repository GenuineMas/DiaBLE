FIXME
-----

* iOS 13.4 beta: didset is not called when a @Published Bool is toggled in SettingsView (current workaround: use logical !)
* Mac Catalyst:
   - stops receiving data from the Bubble read characteristic
   - AVAudioSession error: "Cannot activate session when app is in background" in MainDelegate init
* running the CBCentralManager delegate and log() in the main queue makes the tabs irresponsive when scanning for a device and the Mac is continuosly detected
* when the sensor is not detected the last reading time is updated anyway
*  the log ScrollView doesn't remember the position when switching tabs, nor allows scrolling to the top when reversed

TODO
----

* BLE 1805 2A2B: current time
* Watlaa iBeacon
* selection of glucose units
* notification center delegate methods
* log: limit to a number of readings; add the time when prepending "\t"; add a search field; record to a file
* save the OOP calibration parameters for offline reuse
* let the user input their BG and manage slope/offset parameters independent from the temperatures
* a single slider for setting the target glucose range and the alarms
* more modern Swift idioms: Combine, property wrappers, @dynamicCallable/MemberLookup


PLANS / WISHES
---------------

* an independent Apple Watch app connecting directly via Bluetooth
* a predictive meal log (see [WoofWoof](https://github.com/gshaviv/ninety-two))
