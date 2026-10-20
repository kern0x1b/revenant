# CMMotionActivityManager and CMMotionActivity, iOS 7 and 8

The activity classes CoreMotion added in iOS 7. The release (6.1.3) carries CoreMotion, with CMMotionManager and CMLogItem,
and none of these classes. The device has no motion coprocessor, so the port cannot measure activity; it answers as the
host answers on hardware without one.

Sources: the CoreMotion headers of the macOS 27.0 SDK (`CMMotionActivityManager.h`, `CMMotionActivity.h`,
`CMAuthorization.h`, `CMError.h`, `CMLogItem.h`) for every declaration, availability and enum value; and a measurement on
the host, a Mac with no motion sensor, against its own CoreMotion through the Catalyst target (`arm64-apple-ios17.0-macabi`,
run as a bare command-line tool, no bundle and no usage description). The measurement is `tests/backports/host/coremotion-activity/`.

## What is measured on the host

| question | host answer |
| --- | --- |
| `+[CMMotionActivityManager isActivityAvailable]` | NO |
| `+[CMMotionActivityManager authorizationStatus]` | 0, NotDetermined |
| `-startActivityUpdatesToQueue:withHandler:` | handler never called, no error, within 4 s |
| `-queryActivityStartingFromDate:toDate:toQueue:withHandler:` | handler never called, no error, within 4 s |
| `-stopActivityUpdates` | returns, nothing else |
| fresh `CMMotionActivity` | startDate at the reference date (0.0), confidence 0 (Low), unknown YES, the other five flags NO |
| `+supportsSecureCoding` | YES |
| `-copy` of a fresh instance | SIGSEGV in CoreMotion |
| secure archive of a fresh instance | SIGSEGV in CoreMotion |
| `-description` of a fresh instance | SIGSEGV in CoreMotion |

Each crash is recorded as the operation and its signal only; what happens inside CoreMotion is not examined (no debugger
inside Apple code). The cause of these crashes is not known. No populated instance
is obtainable on the host, because the activity handler never fires, so for a copy or a coding of this class the host gives
a crash and nothing else.

## What the port answers

- `+isActivityAvailable` is NO, and `+authorizationStatus` is NotDetermined, both as the host answers.
- The updates and the query never deliver, as the host does as a bare tool. A caller waiting for activity waits for ever.
  This is the host's answer, not a claim about a device with an app bundle and a usage description: that case was not
  measured here.
- `CMMotionActivity` is a subclass of the release's `CMLogItem`, with the defaults above, `NSSecureCoding` (the
  `+supportsSecureCoding` override is needed because the class overrides `-initWithCoder:`) and `NSCopying`. Copy and
  coding are where the port differs from the host: the port answers them, and the host crashes on them. The round trip
  is checked by the differential (case 7) against the port alone, because the host side is a crash.

## The differential

`tests/backports/host/coremotion-activity/run.sh` compiles one source (`differential.m`) per side and runs each case in its own
process: the host's CoreMotion, and the port's two `.m` files with the test-only `CMLogItem` stub, which exists because the
release's `CMLogItem` cannot share a process with the port's `CMMotionActivity`. Cases 0 to 5 are EQUAL. Cases 6 and 7 are
named as host crashes and are not counted as agreement. Two plants on a scratch copy of the manager (availability flipped,
authorization flipped) each turn case 0 red.

## Not measured

- Whether a bundled application with `NSMotionUsageDescription` gets a handler call or an error from the host.
- The iOS 6.1.3 release's own answers: this device's CoreMotion was not run for the classes, because they are absent from it.
- The CMLogItem superclass on the release, beyond the names the release exports: its `copyWithZone:` is assumed to allocate
  the receiver's class, which is what the subclass depends on in `-copyWithZone:` and was not measured on a device.
