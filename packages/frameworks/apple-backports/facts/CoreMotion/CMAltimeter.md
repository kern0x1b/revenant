# CMAltimeter, CMAltitudeData and CMAbsoluteAltitudeData, iOS 8 to 15

The altimeter classes CoreMotion added in iOS 8 (absolute altitude in iOS 15). The release (6.1.3) carries CoreMotion, with
CMMotionManager and CMLogItem, and none of these classes. The device has no barometer, so the port cannot measure altitude;
it answers as the host answers on hardware without one.

Sources: the CoreMotion headers of the macOS 27.0 SDK (`CMAltimeter.h`, `CMAltitude.h`, `CMAbsoluteAltitude.h`,
`CMAuthorization.h`) for every declaration, availability and enum value; and a measurement on the host, a Mac with no
barometer, against its own CoreMotion through the Catalyst target (`arm64-apple-ios17.0-macabi`, run as a bare command-line
tool, no bundle and no usage description). The measurement is `tests/backports/host/coremotion-activity/`, cases 20 to 30.

## What is measured on the host

| question | host answer |
| --- | --- |
| `+[CMAltimeter isRelativeAltitudeAvailable]` | NO |
| `+[CMAltimeter isAbsoluteAltitudeAvailable]` | NO |
| `+[CMAltimeter authorizationStatus]` | 0, NotDetermined |
| `-startRelativeAltitudeUpdatesToQueue:withHandler:` | handler never called, no error, within 4 s |
| `-startAbsoluteAltitudeUpdatesToQueue:withHandler:` | handler never called, no error, within 4 s |
| `-stopRelativeAltitudeUpdates`, `-stopAbsoluteAltitudeUpdates` | return, nothing else |
| `+supportsSecureCoding` of `CMAltitudeData` and `CMAbsoluteAltitudeData` | YES |
| fresh `CMAbsoluteAltitudeData` | altitude, accuracy and precision each read 0.0 |
| fresh `CMAltitudeData`, `relativeAltitude` and `pressure` | host crashes (signal 11) on the read |
| copy of a fresh `CMAltitudeData` | host crashes (signal 11) |
| secure archive round trip of a fresh `CMAltitudeData` | host crashes (signal 11) |
| copy of a fresh `CMAbsoluteAltitudeData` | host crashes (signal 11) |
| secure archive round trip of a fresh `CMAbsoluteAltitudeData` | host crashes (signal 11) |

The host crashes are named by the operation and the signal only. They are not comparable: the differential leaves them out
of the agreement count, and it counts them (five cases: 25, 26, 27, 29, 30). The port's answer in each of them is the
documented value of a fresh object, which is nil for the two `NSNumber` readings and 0.0 for the three doubles, and a copy
or a coded value that keeps those values. That answer is port-only: the host gives no answer to compare it with.

## What the port answers

- Both availability class methods are NO, and `+authorizationStatus` is NotDetermined, both as the host answers.
- The updates never deliver, as the host does as a bare tool. A caller waiting for altitude waits for ever. This is the
  host's answer, not a claim about a device with an app bundle and a usage description: that case was not measured here.
- `CMAltitudeData` is a subclass of the release's `CMLogItem` with `relativeAltitude` and `pressure`, both nil for a fresh
  instance. `CMAbsoluteAltitudeData` is a subclass of the same superclass with `altitude`, `accuracy` and `precision`, all 0.0
  for a fresh instance, as the host reads them. Both keep the coding of the superclass and add their own properties.
- Both data classes declare `NSSecureCoding` through the superclass, and the port says so with `+supportsSecureCoding`.
- No populated altitude data is obtainable on the host, because no handler ever fires. A test can only see fresh instances.

## The differential

`tests/backports/host/coremotion-activity/run.sh` compiles one source (`differential.m`) per side and runs each case in its own
process. Cases 20 to 24 and 28 are EQUAL. Cases 25, 26, 27, 29 and 30 are host crashes and are not comparable. Plants on a
scratch copy of the port's sources (altimeter availability flipped, altimeter authorization flipped) each turn their case red.

## Not measured

- Whether a bundled application with `NSMotionUsageDescription` gets a handler call or an error from the host.
- The iOS 6.1.3 release's own answers: this device's CoreMotion was not run for these classes, because they are absent from it.
- The CMLogItem superclass on the release, beyond the names the release exports: its `copyWithZone:` and its coding are assumed
  to be what the subclasses depend on (the copy allocates the receiver's class, and the coding keeps the timestamp), and that
  was not measured on a device.
- The host's copy and coded values of a fresh altitude instance, where the host crashes: the port's values are the documented
  fresh values, not a measured copy.
