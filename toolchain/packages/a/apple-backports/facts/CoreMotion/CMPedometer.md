# CMPedometer, CMPedometerData and CMPedometerEvent, iOS 8 to 11

The pedometer classes CoreMotion added in iOS 8 (the events in iOS 10). The release (6.1.3) carries CoreMotion, with
CMMotionManager and CMLogItem, and none of these classes. The device has no motion coprocessor, so the port cannot count
steps; it answers as the host answers on hardware without one.

Sources: the CoreMotion headers of the macOS 27.0 SDK (`CMPedometer.h`, `CMAuthorization.h`, `CMError.h`) for every
declaration, availability and enum value; and a measurement on the host, a Mac with no motion sensor, against its own
CoreMotion through the Catalyst target (`arm64-apple-ios17.0-macabi`, run as a bare command-line tool, no bundle and no usage
description). The measurement is `tests/backports/host/coremotion-activity/`, cases 8 to 18.

## What is measured on the host

| question | host answer |
| --- | --- |
| `+isStepCountingAvailable`, `+isDistanceAvailable`, `+isFloorCountingAvailable` | NO |
| `+isPaceAvailable`, `+isCadenceAvailable`, `+isPedometerEventTrackingAvailable` | NO |
| `+[CMPedometer authorizationStatus]` | 0, NotDetermined |
| `-queryPedometerDataFromDate:toDate:withHandler:` | handler never called, no error, within 4 s |
| `-startPedometerUpdatesFromDate:withHandler:` | handler never called, no error, within 4 s |
| `-startPedometerEventUpdatesWithHandler:` | handler never called, no error, within 4 s |
| `-stopPedometerUpdates`, `-stopPedometerEventUpdates` | return, nothing else |
| `+supportsSecureCoding` of `CMPedometerData` and `CMPedometerEvent` | YES |
| fresh `CMPedometerData` | every property reads nil |
| copy of a fresh `CMPedometerData` | works, same class, every property nil |
| secure archive round trip of a fresh `CMPedometerData` | works, same class, every property nil |
| fresh `CMPedometerEvent` | date nil, type 0 (Pause) |
| copy of a fresh `CMPedometerEvent` | works, same class, date nil, type 0 |
| secure archive round trip of a fresh `CMPedometerEvent` | works, same class, date nil, type 0 |

No host crash in this family: every case in the table ran to its end.

## What the port answers

- Every availability class method is NO, and `+authorizationStatus` is NotDetermined, both as the host answers.
- The queries and the updates never deliver, as the host does as a bare tool. A caller waiting for steps waits for ever.
  This is the host's answer, not a claim about a device with an app bundle and a usage description: that case was not
  measured here.
- The three data classes are `NSObject` subclasses with the documented properties, nil by default, `NSSecureCoding` and
  `NSCopying` as the header declares them. A fresh instance behaves as on the host: nil in, nil out, and the copy and the
  coded value keep every property.
- No populated `CMPedometerData` or `CMPedometerEvent` is obtainable on the host, because no handler ever fires. A test can
  only see fresh instances.

## The differential

`tests/backports/host/coremotion-activity/run.sh` compiles one source (`differential.m`) per side and runs each case in its own
process. Cases 8 to 18 are EQUAL. Plants on a scratch copy of the port's sources (pedometer availability flipped,
pedometer authorization flipped, the event copy losing its type) each turn their case red.

## Not measured

- Whether a bundled application with `NSMotionUsageDescription` gets a handler call or an error from the host.
- The iOS 6.1.3 release's own answers: this device's CoreMotion was not run for these classes, because they are absent from it.
- The CMLogItem superclass on the release is not used by these classes, so no assumption about it is made here.
