# The capture-device capability rows of iOS 17 and 17.2: 12 rows, two objects

`AVFoundation/AVCaptureDeviceReactions17.m` (the 17.0 half, ten rows) and
`AVFoundation/AVCaptureDeviceFormatDepthZoom17.m` (the 17.2 half, two rows). Registry:
`registry/AVFoundation/reactions17.json`. Header: `CharonAVCaptureDeviceReactions17.h`, which transcribes
26.2's own declarations because SDK 16.4 has no `AVCaptureReactions.h` at all and its `AVCaptureDevice.h`
declares none of this.

## Two oracles, and which one speaks depends on the row

**This host's own AVFoundation, and this Mac has a camera.** Measured: one video device,
`MacBook Pro Camera`, type `AVCaptureDeviceTypeBuiltInWideAngleCamera`, seven formats, 640x480 through
1920x1080. So every row here is something the host answers, and the harness
(`tests/backports/host/avf-capabilities/run.sh`) asks both sides in one process and compares **both columns**
against `expectations.tsv` - what this camera answers and what the port answers, with the reason where the
two differ. "The two columns are equal" is not the claim, because the hardware differs: this camera has
reaction effects, the devices of this port's bands (an iPhone 4S, an iPad 2) have not.

**The SDK 26.2 header's own words for the hardware that does not have the feature**, which is this port's
case. Every rule below is quoted from the header in `AVCaptureDeviceReactions17.m` beside the code that
implements it.

What the host's camera answers, all measured by the harness:

| member | host | port | why they differ |
| --- | --- | --- | --- |
| `availableReactionTypes` | 8 types: Balloons, Confetti, Fireworks, Heart, Lasers, Rain, ThumbsDown, ThumbsUp | none | "The list may differ between devices" (:2481) |
| `canPerformReactionEffects` | 1 | 0 | "returns YES when resources for reactions are available on the device instance" (:2471) |
| `reactionEffectsInProgress` | 0 running | 0 running | they agree |
| `reactionEffectsEnabled` (class) | 1 | 0 with an empty plist, 1 with voip, 1 with the opt-in key | macOS's rule is "enabled by default for all applications" (:2447); iOS's is the application's own (:2448) |
| `reactionEffectGesturesEnabled` (class) | 0 | 1 by default, 0 with `NSCameraReactionEffectGesturesEnabledDefault` false | the host reflects this Mac's Control Center Gestures setting (:2458) |
| `systemPreferredCamera` | nil | the release's own best camera: the back one | **the host's nil here is not Apple's answer for this row** - this process's camera authorization is `notDetermined` and a process that was never granted access answers nil (measured, below) |
| `userPreferredCamera` | nil until set | nil until set, then the most recent still-present choice, kept across launches | the host has one camera, so its history has nothing to fall back to; measured on the host: the value that was set reads back, and a nil after it changes nothing |
| `performEffectForReaction:` | returned | raises NSInvalidArgumentException | the host's camera has the type in `availableReactionTypes`; this one has none |
| Format `reactionEffectsSupported` | 1 for all seven formats | 0 | hardware |
| Format `videoFrameRateRangeForReactionEffectsInProgress` | a 15-30 `AVFrameRateRange` on all seven | nil | a format runs reactions only where it reports support; the NO case cannot be read off this host, so the pairing is the header's `nullable` |
| Format `supportedVideoZoomRangesForDepthDataDelivery` | 0 ranges | 0 ranges | they agree: this host's camera has no depth sensor either |
| Format `zoomFactorsOutsideOfVideoZoomRangesForDepthDeliverySupported` | 0 | 0 | they agree |

So **four of the twelve rows have the host's own answer identical to the port's** (`reactionEffectsInProgress`,
`userPreferredCamera` before a choice is made, and the two depth-delivery members), and the rest differ for a
hardware reason that is stated per row. That is a weaker differential than the controls family, and the
report says so rather than dressing it up: for a reaction effect there is nothing on this machine to measure
the *absence* of, because the only camera available to the host has the feature.

## The preferred-camera pair: what the host's nil is, measured

`+systemPreferredCamera` answers nil on this host, and the previous version of this page read that as the
host's answer for the row. It is not. **Measured:** `+[AVCaptureDevice authorizationStatusForMediaType:
AVMediaTypeVideo]` is `notDetermined` (0) in this harness's process, and asking for access from a bundle
carrying `NSCameraUsageDescription` returns `granted=0` without changing the status - there is no GUI session
to answer the prompt. So the host's nil is the answer of a process with no camera access, not of a host with
a camera, and the row has no host oracle here. The harness prints it beside the authorization on every run:

```
note: PREFCAM	host	auth=0 (notDetermined)	user=[nil]	system=[nil]	default=[a camera]
```

What the same run measured on the host, and these are measurements this port's answers come from:

- `+userPreferredCamera` is **nil until an application sets one**, with a camera present (measured).
- after `+setUserPreferredCamera:` with the host's own camera, the getter answers **the very object that was
  set** (measured, `user is the object that was set? 1`).
- after `+setUserPreferredCamera: nil` the getter **still answers that camera** - which is the header's rule
  "Setting the property to nil has no effect" (`AVCaptureDevice.h:663`), not a fallback to a system default.
  (The previous version of this page called it a fallback to a system default on a release with several
  cameras; that reading is withdrawn - it is the nil rule, on a release with one camera.)
- setting the property **adds 0 keys to the bundle's own `NSUserDefaults`** and writes nothing into its
  persistent domain (measured). The release's store for the choice is the system's and is not in the
  application's domain, which is what decides where the port keeps it (below).

### Where the port keeps the choice, and what key

`CharonCaptureUserPreferredCameraHistory`, in the application's own `NSUserDefaults`, holding the
`-uniqueID` of the devices that were set, most recent first, at most three of them.

- **that store**, because the header's promise is "across app launches and reboots" (`:661`) and
  `NSUserDefaults` is the only store a program has for it; and because the release's own store is measurably
  not in the application's domain (above).
- **identifiers, not devices**, because an `AVCaptureDevice` does not outlive the process that made it.
- **a short history, depth 3**, because the header keeps a short history (`:662`) and three is enough for
  "if your user's most recent preferred camera is not currently connected, it still reports the next best
  choice" to have a next choice to report.

### The rules, and what each one is checked against

| rule (header) | the port | checked by |
| --- | --- | --- |
| the most recent still-connected choice answers (`:662`) | the first entry of the history that is in `+devicesWithMediaType:` now | the step `most-recent-gone-next-best-answers` |
| "always returns a device that is present" (`:663`) | an entry that is not in the list now is never answered | the same step, and `no-camera-at-all` |
| "If no camera is available nil is returned" (`:663`, `:674`) | nil with no camera, through `+defaultDeviceWithMediaType:`'s own nil | the step `no-camera-at-all` |
| "Setting the property to nil has no effect" (`:663`) | a nil set adds nothing to the history | the step `after-nil-is-set`, and the host measurement above |
| "persist ... across app launches and reboots" (`:661`) | the defaults key, read on every call rather than a static | two launches of one bundle, and a bundle of its own |
| "incorporates userPreferredCamera as well as other factors" (`:674`) | the user's answer, else `+defaultDeviceWithMediaType:` | every step: the `system=` column |

### Why `+defaultDeviceWithMediaType:` and not "the back camera"

The port writes the call, not a position. On the devices of this port's bands that call answers the camera on
the back: the release's own words for it are "for AVMediaTypeVideo, this method will return the built in
camera that is primarily used for capture and recording" (`AVCaptureDevice.h:120`), and this tree's own device
measurement puts the back camera first in that list (`tests/backports/device/avcapture.m:91`, with the order
recorded in `AVCaptureDeviceDiscovery.md`, "Finding devices"). Writing the call keeps the port from drifting
away from the release's own choice on hardware where the release would choose something else.

### How the harness gets two cameras to choose between

`tests/backports/host/avf-capabilities` compiles the port's two objects with the class name renamed **everywhere
the sources spell it, in a method body as well as at an `@implementation` line** (two macros in the harness's
own prologue). So the port's `[AVCaptureDevice devicesWithMediaType:]` and `[AVCaptureDevice
defaultDeviceWithMediaType:]` reach a stand-in class this build hands a list of two cameras, and "the most
recent camera is gone" is askable at all - which no host with one camera can answer. The control that this is
happening, and not the probe reading the stand-in behind the port's back, is that the steps below change with
the list: every one of them is a different list.

Two mutants, both green through `CONTROL=1`: `AVFCAPSMUTANT=1` (a camera answers it has reactions) and
`AVFCAPSMUTANT=prefcam` (the setter stops persisting, which is the promise of `:661` and which the step model
and the two launches both catch).

## The two class properties are rules, not constants

`+reactionEffectsEnabled` and `+reactionEffectGesturesEnabled` are read out of the **application's**
`Info.plist`, because that is where the header puts both rules. The harness proves that by running the probe
as a bundle four times over four `Info.plist`s it writes itself - empty, `UIBackgroundModes` = `voip`,
`NSCameraReactionEffectsEnabled` = true, `NSCameraReactionEffectGesturesEnabledDefault` = false - and
**computing the expectation out of the plist each run used**:

```
ok  the empty Info.plist: reactionEffectsEnabled=0, reactionEffectGesturesEnabled=1
ok  the voip Info.plist: reactionEffectsEnabled=1, reactionEffectGesturesEnabled=1
ok  the optin Info.plist: reactionEffectsEnabled=1, reactionEffectGesturesEnabled=1
ok  the gesturesoff Info.plist: reactionEffectsEnabled=0, reactionEffectGesturesEnabled=0
```

A constant cannot pass that, in either direction.

## `-performEffectForReaction:`

The header's rule is exact: "The reactionType requested must be one of those listed in
`availableReactionTypes` or an exception will be thrown" (:2496), and "Performing a reaction when
`canPerformReactionEffects` is NO is ignored" (same line). The list is empty here, so **every** type is one
that must not be passed and the port raises. The header names no exception for it; the port raises
`NSInvalidArgumentException`, which is the name the two unsupported-argument refusals of this host's own class
use (measured: `"*** -[AVCaptureDALDevice setAutoVideoFrameRateEnabled:] Not supported"` and
`"*** -[AVCaptureDeviceInput setMultichannelAudioMode:] Not supported"`). That choice is named here because
it is a choice.

## The bands

Both objects are categories on classes the release carries, so they export no symbol of their own and
`band()` keeps them in every band from the floor up. That is what every category in this package does, and
what the port wants here: from 17.0 up the port's answers are the ones for hardware this port's devices do
not have. (The controls family is the opposite case and says so in its own facts page: there the class object
makes the whole surface drop out of the 18.0 and later bands.)

## Checks

```
sh tests/backports/host/avf-capabilities/run.sh        exit 0
  ok  11 members are answered by both sides
  ok  11 answers are the ones expectations.tsv names, the host's and the port's columns both
      across two launches of one bundle: the first chose [front-camera], the second read [front-camera]
      a bundle of its own reads [nil], so what is kept is one application's own choice
  ok  the choice survives a launch and stays in the application that made it
  ok  8 preferred-camera steps are the ones the header's four rules give, computed here
      from the fixture each step used
  ok  over four Info.plists ... (the four lines above)
AVFCAPSMUTANT=1 sh .../run.sh       ok  the mutation was noticed: 1 of 11 table answers, 0 of 8
    preferred-camera steps, and 0 of the two checks around surviving a launch differ
AVFCAPSMUTANT=prefcam sh .../run.sh ok  the mutation was noticed: 0 of 11 table answers, 6 of 8
    preferred-camera steps, and 1 of the two checks around surviving a launch differ
CONTROL=1 AVFCAPSMUTANT=1 sh .../run.sh / CONTROL=1 AVFCAPSMUTANT=prefcam  ok  the control is clean
```

The eight steps of the preferred-camera phase, and what each one is:
`before-any-set` (nil, and the release's own best camera for the system property), `after-front-is-chosen`,
`after-back-is-chosen` (two entries of history), `after-nil-is-set` (unchanged), `most-recent-gone-next-best-answers`
(the entry before it answers), `no-camera-at-all` (nil both), `history-exhausted` (the release's own best
camera), `nothing-ever-chosen` (nil, and the best camera for the system property).
