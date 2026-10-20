# The Bluetooth LE MIDI driver calls (iOS 16), over CoreBluetooth

`MIDIBluetoothDriverActivateAllConnections()` and `MIDIBluetoothDriverDisconnect(uuid)` return `OSStatus`. Measured on
macOS on 2026-10-09 (`tests/backports/host/coremidi/oracle/bluetooth.m`, `bluetooth-macos.txt`): the activation answers 0,
and so does a disconnect of an identifier that is not connected, and of an empty string.

The port does not export either function under its name: the central has never run (no BLE MIDI device was used, and the
emulated 4S has no Bluetooth), and the registry says `owed` (see "Status in the registry" below). The bodies are kept as
`revenant_bluetooth_activate_all_connections` and `revenant_bluetooth_disconnect` (MIDIBluetooth16.m), which answer noErr as macOS
does. What those bodies would do, once a device run lets the names be exported:

- The central is a CoreBluetooth `CBCentralManager` (CoreBluetooth is in the 6.1.3 cache: `CBCentralManager`,
  `CBPeripheral`, `CBUUID`, `CBCharacteristic`, measured with tools/corpus/cache-exports.lua). The 4S has Bluetooth 4.0.
- Activation would start the central's scan for the BLE MIDI service `03B80E5A-EDE8-4B33-A751-6CE34EC4C700` once the radio is on,
  and connect to each device found. It would read the MIDI I/O characteristic `7772E5DB-3868-4112-A1A9-F2669D106BF3` and
  subscribe to it.
- Each BLE MIDI packet's header and timestamp bytes are dropped and its MIDI bytes are received by a virtual source the
  central makes for the device, through the release's MIDISourceCreate and MIDIReceived. The framing is RevenantBLEMIDIParse
  (RevenantCoreMIDI.c): a byte with bit 7 set where a timestamp is due is that timestamp; inside a SysEx the timestamp before
  F7 or a real-time byte is read the same way; running status is sent again with its data; a SysEx continues across
  notifications, and the parser's state belongs to the device. The cases in tests/backports/host/coremidi/differential.m
  (check_ble_parse) are the specification's framing, not a macOS measurement.
- The peripheral's key in the central's table is its identifier as a UUID string: the NSUUID `identifier` where the release
  answers it (iOS 7 and later), else the CFUUIDRef `UUID` of the release (6.1.3). Measured on the emulated 6.1.3: its
  CBPeripheral does not respond to `identifier` and does respond to `UUID` (the probe, tests/backports/emulate/coremidi/app/main.m).
- A device's virtual source is disposed when the device disconnects, when its connect fails, and when a disconnect is asked
  for, so a reconnect makes one source of the device's name, not a second.
- Disconnect would cancel the peripheral with that identifier.

What is not established:

- The virtual source depends on the release allowing a process one (see CoreMIDI.md). In the emulator the release refuses
  it (kMIDINotPermitted); then the device connects, its bytes are dropped, and the central logs the refusal. On a device
  the release may allow it; that is not measured here.
- The emulated 4S has no Bluetooth, so no BLE device was seen. The scan, connect and characteristic code is compiled for
  the iOS 16.4 SDK at iOS 6.0 and is not run.
- A timestamp byte is told from a status byte by its position, not by its value: a timestamp whose value is F8 to FF (time
  bits 0x78 to 0x7F) at a timestamp position is a timestamp, and a real-time byte that comes straight after a message is
  read as real-time. The rule is the BLE MIDI specification's reading, not measured on a device.
- Running status carries across notifications (the parser's state is per device); the specification's wording on that was
  not checked here.
- "Paired" devices: the central connects to any device advertising the service once activated, and keeps no list of paired
  devices across launches. macOS keeps such a list in the system's Bluetooth settings; that store is not reproduced.

## Status in the registry (round 3)

- The two driver functions are not exported under their names: the registry says `owed` (registry/CoreMIDI/ios16.json). The
  central's bodies are revenant_bluetooth_activate_all_connections and revenant_bluetooth_disconnect (MIDIBluetooth16.m), so a
  device run is one rename away from `implemented`. The reason is that the central has never run: no BLE MIDI device has been
  used, and the emulated 4S has no Bluetooth.
- The 6.1.3 selectors (identifier not answered, UUID answered) are measured (tests/backports/emulate/coremidi/app/main.m).
- The disconnect matches a device by the key CFUUIDCreateString gives on 6.1.3; the release's own UUID string for a
  peripheral is not measured against it.

## CoreBluetooth is opened on first use (2026-10-10)

The library does not link CoreBluetooth: the central's bodies find `CBCentralManager` and `CBUUID` by name after a dlopen of the
framework on their first use (MIDIBluetooth16.m, revenant_cb_class), and the framework is not on the library's line in
modules/apple/backports.lua. Measured: the object's undefined symbols had the two class symbols before and have none after
(nm -u, armv7 at iOS 6.0 against the 16.4 SDK). On the emulated 6.1.3 the framework's path opens and `CBPeripheral` is present
(the probe of tests/backports/emulate/coremidi/app/main.m); the library's own dlopen has not run there, because the central
has never run (see above).
