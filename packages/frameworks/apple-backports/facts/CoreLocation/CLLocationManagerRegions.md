# CLLocationManager isMonitoringAvailableForClass:, isRangingAvailable and rangedRegions, iOS 7

Source: CoreLocation of iOS 12.0 arm64 (CoreLocation-2245.4.104): `+[CLLocationManager isMonitoringAvailableForClass:]` at
`0x187d57064`, `+isRangingAvailable` at `0x187d57138`, `-rangedRegions` at `0x187d5eb8c`; and iOS 6.0 on the emulator
and iOS 6.1.3 on an iPad 2.

## What is read of the newest release

- `+isRangingAvailable` asks the location daemon whether it can range, with the kind 0, and answers whether the reply is
  not zero. The class has no rule of its own for it.
- `+isMonitoringAvailableForClass:` compares the class it is given, by identity, with `CLBeaconRegion`, `CLCircularRegion`
  and `CLRegion`, in that order. A beacon region asks the daemon with the kind 0; a circular region and the plain
  region ask with the kind 1; any other class, a subclass included, answers NO without asking.
- `-rangedRegions` answers the set of the regions the manager was asked to range.

## What the port does

iOS 6 cannot range beacons and has no beacon monitoring: its location daemon has no such request. So
`+isRangingAvailable` answers NO, `+isMonitoringAvailableForClass:` answers NO for `CLBeaconRegion`, and `-rangedRegions`
is the empty set. For `CLCircularRegion` and `CLRegion` the answer is the release's own
`+regionMonitoringAvailable`, which is the question the daemon is asked on iOS 6 about the region kind that exists there;
any other class, a subclass included, is NO, as in the newest release.

## What was measured

The emulated iOS 6.0 has no location daemon: `+regionMonitoringAvailable` is NO, so circular monitoring is unavailable
there, and `+isRangingAvailable` NO, `-rangedRegions` empty. The iPad 2 on iOS 6.1.3 has location services on, the
status not determined, `+regionMonitoringAvailable` YES and `+significantLocationChangeMonitoringAvailable` YES:
`+isMonitoringAvailableForClass:` answers YES for `CLCircularRegion` and `CLRegion`, NO for `NSString`, and
`+isRangingAvailable` NO.
