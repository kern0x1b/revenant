# AVCaptureSession's controls API: 18 rows, one class, one protocol, one band

`AVFoundation/AVCaptureControls18.m`: `AVCaptureControl` and the category that adds the eleven members to
the release's own `AVCaptureSession`. Registry: `registry/AVFoundation/controls18.json`, 19 rows - the
eighteen `missing` rows of `coordination/corpus/ledger-2026-10-03/AVFoundation.tsv` introduced at 18.0, and
the protocol row, which the ledger reads `header-ok`/`lift` and which the registry needs for the four
protocol methods to be describable.

**One object, and the band rule is why.** Every name here arrived in iOS 18, so one object holds API of one
release; and `band()` keeps an object when the band's release exports none of its symbols and drops it when
the release exports all of them. This object's symbols are `_OBJC_CLASS_$_AVCaptureControl` and its
metaclass, which 18.0 and later do export and 6.1.3 does not, so the whole surface is carried in every band
from the floor up to 16.0 and left out from 18.0 on, where Apple's own class and Apple's own session answer.
That is the right answer on both sides of the line: below 18.0 there is nothing to ask, and at 18.0 and above
the hardware may have CaptureControls, which Apple's own implementation answers and this port's would not.

Splitting the class from the category was the first shape tried here and it is wrong in a way no local check
sees: the class object is dropped in the 18.0 and later bands, while a category-only object exports nothing a
release exports and is kept in **every** band - so it would replace Apple's own implementations of all eleven
session members, on hardware that has the feature, with answers measured on a Mac that does not.

## The oracle is this Mac's own AVFoundation

Measured by `tests/backports/host/avf-globals/controls.m`, which is the run: it links the port's two objects
(both renamed, see below) beside Apple's framework and prints both columns. This host has no camera, which is
why its answers are the answers of a device without CaptureControls - and that is the class of device this
port builds for.

```
host AVCaptureControl: resolves YES, superclass NSObject, 15 own instance methods, 0 own class methods
  -[AVCaptureControl isEnabled] YES   -[AVCaptureControl setEnabled:] YES   -[AVCaptureControl enabled] NO
host AVCaptureSession: all eleven controls selectors answer YES
host -supportsControls 0   -maxControlsCount 0   -controls () of class __NSArray0, the same object twice
host -controlsDelegate nil   -controlsDelegateCallbackQueue nil
host -canAddControl:nil 0, no exception
host -addControl:                NSObjectInaccessibleException *** -[AVCaptureSession addControl:] Controls are not supported
host -removeControl:             NSObjectInaccessibleException *** -[AVCaptureSession removeControl:] Controls are not supported
host -setControlsDelegate:queue: NSObjectInaccessibleException *** -[AVCaptureSession setControlsDelegate:queue:] Controls are not supported
     in all four combinations: a conforming delegate with a serial queue and with NULL, a nil delegate with a
     serial queue and with NULL
host AVCaptureSessionControlsDelegate: NSProtocolFromString answers nil
```

Three things in that output decide the shape of this family.

**Apple's own class refuses all three of `-addControl:`, `-removeControl:` and `-setControlsDelegate:queue:`**
on hardware without CaptureControls, with `NSObjectInaccessibleException` and one reason string each. So the
port raises the same exception with the same reason rather than storing a list, a delegate and a queue that
nothing would ever use. That last sentence is the difference from what
`coordination/wave-2026-10-03/v-avf-report.md` scoped for this unit ("the session still keeps a real list,
delegate and queue, bounded by the release"): the measurement came after the scoping and it says the host
keeps none of the three either. A stored delegate that can never be called is the silent fake this tree
forbids, so the measured answer is the one that landed, and the four `sessionControls...` methods are
registered with that stated rather than with an unreachable dispatch path built to look like a working API.

**The header's own NULL-queue rule is unreachable here.** `AVCaptureSession.h:381` says a NULL
`controlsDelegateCallbackQueue` throws `NSInvalidArgumentException` except when the delegate is nil. Apple's
class refuses the whole call first, in every combination, so the port does not add a second error for a case
Apple never reaches.

**The host is not the oracle for the protocol.** Its header declares `AVCaptureSessionControlsDelegate` at
`AVCaptureSession.h:717` and its runtime has no such protocol object: `NSProtocolFromString` answers nil and
none of the 2141 protocols in the process carries that name. So the protocol row is answered by the port's
own declaration - `RevenantAVFoundationProtocols.h`, transcribed by `tools/transcribe-protocols.py@52253c0650` - and by the
generated `AVFoundationBackportsProtocols18.m` that emits its metadata into every band.

## What the releases carry, measured

| release | what was read | answer |
| --- | --- | --- |
| 6.1.3 armv7 cache | `tools/corpus/objc-inventory.lua` over `~/.revenant/dyld/6.1.3/dyld_shared_cache_armv7` | `AVCaptureSession` answers **none** of the eleven; its own method list is `-addInput:`, `-addOutput:`, `-commitConfiguration`, ... |
| 6.1.3 armv7 cache | same | no `AVCaptureControl`, no `AVCaptureSessionControlsDelegate` |
| 18.0 arm64e cache | same | `AVCaptureControl` is there, superclass `NSObject`, and owns `-isEnabled` and `-setEnabled:` among fourteen others; the protocol is there with exactly the four methods |
| 18.0 arm64e cache | same | **no class carries any of the ten `AVCaptureSession` controls selectors** - not `AVCaptureSession`, not any other class in 221703 class and protocol entries. The class symbol is exported by 18.0 and the controls members are not in that cache's own metadata, which is why the session's members are the port's rows and not "the release's own" |
| ladder | `tools/symbol-first-release.lua` (53 rungs, armv7) | `_OBJC_CLASS_$_AVCaptureControl` and `_OBJC_METACLASS_$_AVCaptureControl` first at **18.0**; `_OBJC_CLASS_$_AVCaptureSession` at 4.0 |

The port's floor is 6.1.3 (and 4.3), both of which predate the hardware this API needs, which is what
`AVCaptureSession.h:377` says in words: "`AVCaptureControl`s are only supported on platforms with necessary
hardware".

## The four delegate methods

They are part of a protocol object the port emits, so a caller can conform and implement them, and this port
never sends one: no delegate can be set (the setter raises, as Apple's own does here) and no control can be
added. On a platform whose hardware has CaptureControls the release's own session sends them, and the port
does not stand in the way - its object is left out of every band from 18.0 up for exactly that reason.

## The one value that is not the host's to give

`AVCaptureSession.configuresApplicationAudioSessionToMixWithOthers` is `API_UNAVAILABLE(macos)`, so on this
host the runtime answers the selector and no macOS caller may send it: its value cannot be measured against
the host. The port keeps what the caller set, defaulting to NO as the header states
(`AVCaptureSession.h:583`), and nothing on this release acts on it - the header says it "has no effect when
`usesApplicationAudioSession` is set to NO", and that property answers NO here because 6.1.3's capture
session records through an audio session of its own, measured on an iPad 2 running 6.1.3 and written up in
`CaptureZoomAudioSession.md`.

## `AVCaptureControl.enabled`

`-isEnabled`/`-setEnabled:` answer what the caller last set. Apple's own class has no `-enabled`, because the
property is declared `getter=isEnabled`, so the port does not define one either. A control this port can make
answers NO until a caller sets it; the header's "the default value is YES" is the default of a control made
through one of the concrete factories (`+[AVCaptureSlider controlWithType:]` and its siblings), and
`AVCaptureSlider`, `AVCaptureToggle` and `AVCaptureIndexPicker` are 18.0 rows this unit does not carry. Both
`-init` and `+new` are `AV_INIT_UNAVAILABLE` in the header, so no caller may make one of these at all.