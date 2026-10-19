# CLBeaconRegion, CLBeacon and ranging, iOS 7

Source: CoreLocation of iOS 12.0 arm64 (CoreLocation-2245.4.104), read instruction by instruction:
`-[CLBeaconRegion initWithProximityUUID:major:minor:identifier:]` at `0x187d91f80`,
`-[CLBeaconRegion peripheralDataWithMeasuredPower:]` at `0x187d9248c`, `-[CLLocationManager startRangingBeaconsInRegion:]` at
`0x187d5e034` and `-stopRangingBeaconsInRegion:` at `0x187d5e71c`, `-[CLBeacon proximity]` at `0x187d92754`; the SDK
headers of iOS 16.4 for `CLBeacon.h`, `CLBeaconRegion.h`, `CLError.h` and `CLLocationManagerDelegate.h`; and iOS 6.0 on the
emulator and iOS 6.1.3 on an iPad 2, through `tests/backports/device/corelocation.m`.

## What is read of the newest release

- A beacon region is a `CLRegion` initialised with its identifier and given the proximity UUID, the major and the minor,
  each kept in the region's own internal object; the major and the minor are `NSNumber`s that stay nil when the initializer
  did not give them.
- `-peripheralDataWithMeasuredPower:` builds the advertisement of an iBeacon: 21 bytes of the 16 bytes of the UUID, the
  major and then the minor each as two bytes with the high byte first (zero when the region has none), and the measured
  power as one signed byte, `charValue` of the number passed, or, when that is nil, the power the library holds for the
  device. It answers a mutable dictionary of that data under the key `kCBAdvDataAppleBeaconKey`, which is the string
  CoreBluetooth names `CBAdvertisementDataAppleBeaconKey`.
- The default power is a table of the hardware family: seven values from -51 to -59 for the families the library lists, and
  -59 for every family that is not in it.
- `-startRangingBeaconsInRegion:` asserts that the region is not nil (`Invalid parameter not satisfying: %@`), performs the
  courtesy prompt if one is due, adds the region to `rangedRegions` and hands it to the daemon; the beacons found, or the
  failure, come back from the daemon. `+isRangingAvailable` is the daemon's answer too.
- `-[CLBeacon proximity]` and its siblings are getters of the fields the daemon fills.
- The SDK header names `kCLErrorRangingUnavailable`, "Ranging cannot be performed", for the failure a caller meets when
  ranging is not possible, and says the delegate is told of it in
  `-locationManager:rangingBeaconsDidFailForRegion:withError:`.

## What the port does

iOS 6 cannot range beacons: its location daemon has no such request, and CoreBluetooth of iOS 6 does not export
`CBAdvertisementDataAppleBeaconKey`. So:

- `CLBeaconRegion` and `CLBeacon` are classes an application can make and read. A beacon region is made as a circular
  region of one metre at the point (0, 0), which is what gives it an identifier and the notify flags of a region, with the
  UUID, the major and the minor kept beside it; an initializer without a UUID raises `NSInvalidArgumentException`. A
  `CLBeacon` starts out with no UUID, no major and no minor, proximity unknown, accuracy -1 and signal strength 0, and
  copies and codes with secure coding; nothing in the release ever makes one that is different, since nothing ranges.
- `-startRangingBeaconsInRegion:` asserts as the release does, and tells the delegate of the manager, on the main queue,
  `-locationManager:rangingBeaconsDidFailForRegion:withError:` with `kCLErrorDomain` and `kCLErrorRangingUnavailable`,
  once. `-stopRangingBeaconsInRegion:` asserts and does nothing. `-locationManager:didRangeBeacons:inRegion:` is never sent.
  `+isRangingAvailable` is NO, `+isMonitoringAvailableForClass:` is NO for `CLBeaconRegion`, `-rangedRegions` is empty, and
  `-requestStateForRegion:` for a beacon region answers `CLRegionStateUnknown`.
- `-peripheralDataWithMeasuredPower:` builds the same 21 bytes under the same string key, with -59 when no power is given,
  because no device of iOS 6 is in the newest release's table. Whether the CoreBluetooth of iOS 6 advertises what it is given
  under that key was not measured.
- `notifyEntryStateOnDisplay` is kept and answered back, and inert: nothing tells the delegate an entry state when the
  display comes on.

What the port cannot prevent: a beacon region handed to `-startMonitoringForRegion:` is the one-metre circle at (0, 0) to
the release's manager, which will monitor it and never report it entered. An application that asks
`+isMonitoringAvailableForClass:` first, as the newest release asks it to, does not get there.

Below iOS 6.0 the two classes and the ranging calls are not carried: a region is made from an `NSUUID` and a beacon
decodes one with `-[NSCoder decodeObjectOfClass:forKey:]`, and both arrive in 6.0, with neither in the backports. The
registry holds them to 6.0; `+isMonitoringAvailableForClass:` finds no `CLBeaconRegion` there and answers NO.

## What was measured

The emulated iOS 6.0, an iPad 2 and an iPhone 4S on iOS 6.1.3, the same answers on all three: the two classes come from
`libCoreLocationBackports.dylib`; regions made from a UUID, from a UUID and a major, and from all three keep them, with the
major and the minor nil where they were not given, and a nil UUID raises `NSInvalidArgumentException`; the advertisement
of the region with major 513 and minor 258 and a measured power of -70 is the 21 bytes E2 C5 6D B5 DF FB 48 D2 B0 60 D0 F5
A7 10 96 E0, 02 01, 01 02, BA under `kCBAdvDataAppleBeaconKey`, and with no power the last byte is C5, -59; a beacon made
with `-init` is unknown, of accuracy -1 and signal 0, and copies; `-startRangingBeaconsInRegion:` tells the delegate once,
for the region asked, that ranging is unavailable, with `kCLErrorDomain` and `kCLErrorRangingUnavailable`, and a nil region
is refused with `NSInternalInconsistencyException`; `-requestStateForRegion:` for a beacon region answers unknown;
`+isMonitoringAvailableForClass:` for `CLBeaconRegion` is NO. The `notifyEntryStateOnDisplay` and `notifyOnEntry` and
`notifyOnExit` logs appear once. The 4S has the hardware for Bluetooth 4.0 and nothing here changes on it; whether the
CoreBluetooth of iOS 6.1.3 advertises what `-peripheralDataWithMeasuredPower:` builds was not tried.
