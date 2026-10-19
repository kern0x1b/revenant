# The external sync and locked frame duration of iOS 26: 11 rows, one object

`AVFoundation/AVCaptureDeviceExternalSync26.m` carries all eleven - four properties on `AVCaptureDevice`, five
on `AVCaptureDeviceInput` and the two external-sync methods - in one object, over two classes every release
already carries. Registry: `registry/AVFoundation/externalsync26.json`, eleven rows, one per row the
`coordination/corpus/ledger-2026-10-03/AVFoundation.tsv` snapshot reads `missing` for them at 26.0. Header:
`CharonAVCaptureDeviceExternalSync26.h`, transcribed from the SDK 26.2 (`AVCaptureDevice.h:376-393`,
`AVCaptureInput.h:286-350`), with two names of its own that are forward declarations only: `AVExternalSyncDevice`
and its delegate protocol, whose class, six properties, `-init`, `+new`, discovery session and delegate methods
are a family of their own rows.

## The two features, in the header's words, and what this release has of them

**Locked frame duration.** "Setting this property guarantees the intra-frame duration delivered by the device
input is precisely the frame duration you request" (`AVCaptureInput.h:288`), and the header says where the
smallest duration a given device can take comes from: "Query `AVCaptureDevice/minSupportedLockedVideoFrameDuration`
to find the minimum value supported by this `AVCaptureDeviceInput`" (`:290`). So **the input's capability IS the
device's minimum being valid**, and the header says what that minimum is where the feature is absent:
"`kCMTimeInvalid` is returned when the device or its current configuration does not support locked frame rate"
(`AVCaptureDevice.h:383`).

**External sync.** An input follows an `AVExternalSyncDevice` - a genlock or a house-sync box - at a frame
duration the box drives, and again the header says what the device reports where the feature is absent: "This
property returns `kCMTimeInvalid` when the device's current configuration does not support external sync device
following" (`AVCaptureDevice.h:393`).

This release has neither: 6.1.3's `AVCaptureDevice` owns no member of either feature (measured,
tools/corpus/objc-inventory.lua over the 6.1.3 armv7 cache), its capture session has no frame-duration lock of
any kind, and no external sync hardware exists on an iPhone 4S or an iPad 2.

## Ten of the eleven rows agree with the host exactly

| row | host | port |
| --- | --- | --- |
| `videoFrameDurationLocked` | 0 | 0 |
| `minSupportedLockedVideoFrameDuration` | kCMTimeInvalid | kCMTimeInvalid |
| `followingExternalSyncDevice` | 0 | 0 |
| `minSupportedExternalSyncFrameDuration` | kCMTimeInvalid | kCMTimeInvalid |
| `lockedVideoFrameDurationSupported` | 0 | 0, **derived from the device's minimum** |
| `activeLockedVideoFrameDuration` | kCMTimeInvalid | kCMTimeInvalid |
| `externalSyncSupported` | 0 | 0, derived the same way |
| `activeExternalSyncVideoFrameDuration` | kCMTimeInvalid | kCMTimeInvalid |
| `externalSyncDevice` | nil | nil |
| `followExternalSyncDevice:videoFrameDuration:delegate:` | raises | raises, **the same string character for character** |
| `unfollowExternalSyncDevice` | returns | returns |

The refusal, measured on the host and raised unchanged:

```
*** -[AVCaptureDeviceInput followExternalSyncDevice:videoFrameDuration:delegate:] followExternalSyncDevice:videoFrameDuration:delegate: is not supported on this device. Check the device minSupportedExternalSyncFrameDuration property.
```

and the header's own rule is the same one: "Calling this method throws an `NSInvalidArgumentException` if
`AVCaptureDeviceInput/externalSyncSupported` returns `false`" (`:331`).

Two of those answers are **derived rather than written**, and the plant `syncmin` is what shows it: it gives the
device a real minimum locked frame duration (`CMTimeMake(1, 60)`), and two rows move with it - the device's own
minimum and `lockedVideoFrameDurationSupported`, which reads it through the header's sentence. `externalSyncSupported`
is derived from the other minimum the same way.

## The one divergence from the host, measured and named

**`-setActiveLockedVideoFrameDuration:` with a valid `CMTime`.** The host's own class **returns and keeps it**
(measured: `1/30` afterwards), while its device still reports `-isVideoFrameDurationLocked` NO - the host accepts
a value it then does not honour. The header says twice that this throws: "If you set this property to a valid
value while the receiver's `AVCaptureDevice/minSupportedLockedVideoFrameDuration` is `kCMTimeInvalid`, it throws
an `NSInvalidArgumentException`" (`:302`), and "If you set this property while the receiver's
`lockedVideoFrameDurationSupported` property returns `false`, it throws an `NSInvalidArgumentException`" (`:303`).

The port refuses, which is the header's rule and not a value nothing can reach: setting `kCMTimeInvalid` is
always allowed (it is how the feature is disabled, `:288`), and nothing else is kept, because a setter that
accepts only `kCMTimeInvalid` has no other value to remember. The refusal text is the port's own - the header
names the exception and no words - and the row carries both columns.

## The header's two `API_AVAILABLE` annotations this header does not repeat

`-followExternalSyncDevice:videoFrameDuration:delegate:` and `-unfollowExternalSyncDevice` carry no
`API_AVAILABLE(ios(26.0))` in the header, where 26.2 puts one on them. That is stated in the header rather
than done silently: the annotation on a void method whose signature names no 26.0 type guards nothing a caller
can reach, and the definitions in the object carry `API_AVAILABLE(ios(26.0))` instead - which is what
`AVCaptureControls18.m` does for the same reason.

## Not carried, and named

- **`AVExternalSyncDevice`** and its whole family: the class, its six properties (`clock`, `productID`,
  `signalCompensationDelay`, `status`, `uuid`, `vendorID`), its `-init` and `+new`,
  `AVExternalSyncDeviceDiscoverySession` with its four rows, and the `AVExternalSyncDeviceDelegate` protocol
  with its two methods. Forward-declared here and never instantiated, so nothing a caller can name is ever
  returned by `-externalSyncDevice`.
- The five `AVExternalSyncDeviceStatus` constants and the `AVErrorFollowExternalSyncDeviceTimedOut` error are
  `header-ok`/`lift` rows, not code.

## Checks

```
sh tests/backports/host/avf-capabilities/run.sh   exit 0
  ok  47 members are answered by both sides, or by the port alone where the table says the host has none
  ok  75 answers are the ones expectations.tsv names, the host's and the port's columns both
AVFCAPSMUTANT=syncmin  ok  the mutation was noticed: 2 of 75 table answers, 0 of 8
CONTROL=1 with each of the seven plants  ok  the control is clean
```

Seven plants, all noticed: `reactions` (1 of 75), `prefcam` (6 of the 8 preferred-camera steps),
`capabilities` (3 of 75), `multichannel` (4 of 75), `rectsupport` (1 of 75), `cinematic` (6 of 75), `syncmin`
(2 of 75).
