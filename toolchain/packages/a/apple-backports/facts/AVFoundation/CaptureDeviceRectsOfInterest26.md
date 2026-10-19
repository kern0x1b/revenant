# The rectangles of interest of iOS 26: 8 rows, one object, and one answer that was wrong first

`AVFoundation/AVCaptureDeviceRectsOfInterest26.m` carries all eight - six properties on `AVCaptureDevice` and
the two `-defaultRectFor...PointOfInterest:` methods. Registry: `registry/AVFoundation/rectsofinterest26.json`,
eight rows, one per row the `coordination/corpus/ledger-2026-10-03/AVFoundation.tsv` snapshot reads `missing`
for them at 26.0. Header: `CharonAVCaptureDeviceRectsOfInterest26.h`, transcribed from the SDK 26.2
(`AVCaptureDevice.h:1159-1187` and `:1403-1429`) because SDK 16.4 declares none of it - and, unlike the two
slices below it in the same folder, **no type at all**, because CGPoint, CGSize, CGRect and BOOL are
CoreGraphics' own and Foundation's.

## The answer that was wrong, and what replaced it

The first version of this object answered `-isFocusRectOfInterestSupported` and
`-isExposureRectOfInterestSupported` with the release's own point-of-interest support, kept the rectangle a
caller set, and applied its **centre** through the release's own `-setFocusPointOfInterest:` - which is what
the header says a rectangle does (`:1171`). So it answered YES on a device that could weigh nothing but a
point, and it silently dropped the rectangle's extent.

**That is wrong, and the coordinator's ruling of 2026-10-03 says why in the terms this page now uses: a device
that honours only the rectangle's centre does not support rectangles of interest.** Apple's own devices without
the machinery answer exactly what the port answers now, and the host's own camera is one of them: measured, its
support flags are 0 for both the rectangle and the point, its minimum sizes are `{ 0, 0 }`, both its rectangles
and all four of its default-rectangle answers are `CGRectNull`, and both setters refuse. So every row of this
family now has **both columns equal**, and each pair is the header's own documented answer for a device that
does not support the rectangle.

The rows, with what decides each:

| row | both sides answer | the sentence or the measurement |
| --- | --- | --- |
| `focusRectOfInterestSupported`, `exposureRectOfInterestSupported` | NO | a rectangle is weighed as an AREA, and 6.1.3's `AVCaptureDevice` owns the point-of-interest pair and **no focus area, no metering area and no sensor size anywhere** (tools/corpus/objc-inventory.lua over the 6.1.3 armv7 cache), so there is nothing here that could weigh one |
| `minFocusRectOfInterestSize`, `minExposureRectOfInterestSize` | `{ 0, 0 }` | "If `focusRectOfInterestSupported` returns `false`, this property returns `{ 0, 0 }`" (`:1167`, `:1411`) |
| `focusRectOfInterest`, `exposureRectOfInterest` | `CGRectNull` | measured on the host; a device with no support has no rectangle to report |
| `defaultRectForFocusPointOfInterest:`, `...Exposure...` | `CGRectNull` | "This method returns `CGRectNull` if `focusRectOfInterestSupported` returns `false`" (`:1184`, `:1429`), measured on the host for four points - (0.5, 0.5), (0, 0), (0.75, 0.75), (1, 1) - `CGRectIsNull` 1 every time |
| `setFocusRectOfInterest:`, `setExposureRectOfInterest:` | two refusals, in a measured order | see below |

**Nothing is kept.** The first version kept a rectangle per device in an associated object, reconciled it
against the release's point of interest (the header's own reset rule, `:1171`) and had a size check against the
minimum. With no support there is no rectangle to keep, no reset to reconcile and no minimum to be below - a
setter that refuses every value cannot have a last accepted one - so the two static keys, the two geometry
helpers and the reset are gone. Code that stores a value nothing can reach is the silent fake this tree
forbids, and the harness's two plants for that geometry went with them.

## The order of the two refusals, which is measured

```
setFocusRectOfInterest: unlocked   NSGenericException: *** -[AVCaptureDevice_Tundra setFocusRectOfInterest:]
                                   May not be called without first successfully gaining exclusive ownership of
                                   the device using -lockForConfiguration:
setFocusRectOfInterest: locked     NSInvalidArgumentException: *** -[AVCaptureDALDevice_Tundra
                                   setFocusRectOfInterest:] Not supported - use
                                   -isFocusRectOfInterestSupported
```

An unlocked send refuses **this** way on a device whose support flag is 0, so Apple's order is the
configuration lock first and the support flag second, and the port implements that order. The lock is read
through the release's own `-isLockedForConfiguration` - a method of 6.1.3's `AVCaptureDevice` that is not in any
public header, and the seam `AVCaptureDevice+VideoZoom7.m` and `AVCaptureDevice+ActiveFrameDuration.m` already
use. The two texts differ in one place and it is stated on both rows: Apple's prefix names
`AVCaptureDALDevice`, a private class of Apple's device-access layer that this port does not have, while the
setter belongs to `AVCaptureDevice`; the port's lock message is worded the way this package words the release's
own lock refusals.

## The mutant that has to fire, and does

`AVFCAPSMUTANT=rectsupport` makes `-isFocusRectOfInterestSupported` answer YES - the answer this first version
gave and the one the ruling rejects. It is noticed by the support row, and it is the plant that would catch a
port which ever answered YES behind a centre-only implementation.

## Checks

```
sh tests/backports/host/avf-capabilities/run.sh   exit 0
  ok  38 members are answered by both sides, or by the port alone where the table says the host has none
  ok  63 answers are the ones expectations.tsv names, the host's and the port's columns both
  ok  8 preferred-camera steps are the ones the header's four rules give, computed here from the fixture each step used
AVFCAPSMUTANT=rectsupport  ok  the mutation was noticed: 1 of 63 table answers, 0 of 8
CONTROL=1 with each of the six plants  ok  the control is clean
```

Six plants now, all noticed: `reactions` (1 of 63), `prefcam` (6 of the 8 preferred-camera steps),
`capabilities` (3 of 63), `multichannel` (4 of 63), `rectsupport` (1 of 63), `cinematic` (6 of 63).

## Not measured here

**What the release's own `-isFocusPointOfInterestSupported` answers on an iPhone 4S or an iPad 2 running 6.1.3**
is still not measured, and this reworking does not depend on it: the port's answer is NO because the release
cannot weigh an area, whatever it says about a point. A device measurement would confirm the premise (that
these devices' cameras have no focus-area machinery), and `tests/backports/device/avcapture.m` is where it
would go; it needs an emulator slot and this session did not take one.
