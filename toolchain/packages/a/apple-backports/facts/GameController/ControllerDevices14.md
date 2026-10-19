# The touchpad, the battery, the light, the haptics and the keyboard input of a controller (iOS 14.0)

These are the classes a `GCController` reaches for the parts of itself that are not buttons and axes: the
touchpad of a DualShock or DualSense, the battery and the light and the haptics engine, and the keyboard
input of an attached keyboard. Each one is a name an application can hold, and each one is reached from a
controller or from `[GCKeyboard coalescedKeyboard]` - which is nil, because nothing is ever attached.

## What iOS 6 and iOS 4.3 carry: nothing

```
CHARON_ROOT=$PWD xmake l tools/corpus/cache-census.lua GC 6.1.3 4.3
```

```
6.1.3     .../dyld/6.1.3/dyld_shared_cache_armv7
         images 524, of which naming GC 2
         classes 11378, of which GC* 2 (GCKEventItem GCKOOBMessage)
         protocols 1171, of which GC* 0
4.3       .../dyld/4.3/dyld_shared_cache_armv7
         images 354, of which naming GC 1
         classes 7187, of which GC* 2 (GCKEventItem GCKOOBMessage)
         protocols 564, of which GC* 0
control: 4 name(s) beginning GC found in this run, so a zero on another rung is the release's and not the reader's
```

Both band ends carry no GameController at all: the two `GC*` classes on each rung are GameCenter's keychain
helpers, not this framework, and there is no `GC*` protocol on either. The control is what makes the zero
mean something - a reader that finds four names in one run cannot be a reader that finds none.

So every row here is carried *against* a release that has nothing: the classes are what an application
refers to, and the port answers them for what names them, the way `registry/GameController/extras.json`
already records for the classes themselves.

## What the host answers, for a touchpad the application builds itself

```
sh tests/backports/host/gamecontroller/run.sh
```

The `touchpad state` group of the differential builds a `GCControllerTouchpad` on the host's own GameController
and on the port's renamed copy, and compares them line by line. What both agree on:

| what | host | port |
| --- | --- | --- |
| `touchState` before any touch | `0` (`GCTouchStateUp`) | `0` |
| after `setValueForXAxis:yAxis:touchDown:buttonValue:` with `touchDown:YES` | `1` (`Down`) | `1` |
| again with `touchDown:YES`, i.e. a move while still down | `2` (`Moving`) | `2` |
| again with `touchDown:NO` | `0` (`Up`) | `0` |
| `touchDown`/`touchMoved`/`touchUp` before anything is set | nil, nil, nil | nil, nil, nil |
| `reportsAbsoluteTouchSurfaceValues` before anything is set | **NO** | NO |

The default of `reportsAbsoluteTouchSurfaceValues` is worth stating because Apple's own header comment says the
opposite - "The default value for this property is YES". The host answers NO, and the host is the framework, so
NO is what this port carries. That is the header's comment being wrong, not the header's declaration.

## Where this port deliberately differs, and why

A touchpad the host builds itself, with no controller behind it, answers **nil** for `button` and for
`touchSurface`. Measured, and it is on both sides of the comparison above: the host's two children are nil, so
every axis read through them is zero and every handler the host runs is handed zeros and nans.

This port builds **real** elements for both instead - the surface through the same `-charon_linkXAxis:yAxis:up:down:left:right:`
a dpad spec is linked with, the button and the four surface buttons through the same `-initWithCharonSpec:` seam
every profile in this package uses - and the `touchpad elements` group of the differential reads them back
through the accessors a caller uses: the axes carry the normalized values the call put in, the button carries its
own value and its pressed state, and a value outside `[-1,1]` is clamped rather than taken whole.

The reason is a caller, not elegance. The header tells an application to poll `touchState` *in conjunction with*
`touchSurface`, so a nil `touchSurface` crashes the first caller that does what the header says, and the value the
caller reads off `setValueForXAxis:` would be silently zero. A nil child here is a crash trap, which is the same
call the mouse made when `GCMouseInput` was carried (`c240db3fe`, "Make GCMouse/GCMouseInput real, closing a live
crash trap"). This is a stated difference, not a match: the two sides of the touch-state comparison above are
equal, and the children are deliberately not.

The relative mode of `reportsAbsoluteTouchSurfaceValues` - the sliding window the header describes for a surface
with no clear middle - is **not** modelled: with the flag off this port still reports the normalized value the call
carried. That is a gap and it is named here rather than papered over; no host line can be held to for it either,
because the host's own surface is nil.

## The battery, the light and the haptics

`GCDeviceBattery`, `GCDeviceLight` and `GCDeviceHaptics` each mark `- (instancetype)init NS_UNAVAILABLE` in the
SDK 16.4 header, and a caller confirms it without a device: compiling `[[GCDeviceBattery alloc] init]` against that
header is an error, which is what the SDK says. An application never makes one of these; it asks a controller, and
`-[GCController battery]`, `-light` and `-haptics` all answer nil in this port, which is the header's own answer
for a controller that has none: each of the three is declared `nullable` and each describes hardware that iOS 6
does not carry.

`GCDeviceHaptics.supportedLocalities` is answered from the two localities the header guarantees - `GCHapticsLocalityDefault`
and `GCHapticsLocalityAll` - and `createEngineWithLocality:` cannot answer with an engine at all, because a
`CHHapticEngine` is CoreHaptics, a framework iOS 6 does not have; it answers nil, which is the return type the
header itself allows (`_Nullable`).

## The keyboard input

`GCKeyboard.keyboardInput` is the profile a keyboard carries. The port builds the keyboard itself rather than
leaving the profile nil, so a caller that reaches a keyboard - by allocating one, as the header's own
`GCKeyboard` allows - gets a real `GCKeyboardInput` and not a nil.

The profile is one real `GCControllerButtonInput` per key code, built from the same spec pipeline every other
profile in this package uses, so a key is a button a caller can poll and hook like any other. The key's name is the
key code's own name without its `GCKeyCode` prefix, with the 26 letter codes' `Key` prefix dropped
(`GCKeyCodeKeyA` is keyed `A`, `GCKeyCodeLeftArrow` is keyed `LeftArrow`); that rule was taken from the host's own
keyboard rather than from the header's comments, which are keycap legends (`a or A`, `1 or !`, `Left Arrow`) and not
names.

Measured against the host's own keyboard, the `keyboard` group of the differential holds every key both profiles
carry to the same reading, and the whole of the difference is on one line:

```
keyboard keys=134 named=133 unnamed=1 onlyHere=F13,F14,F15,F16,F17,F18,F19,F20    (host)
keyboard keys=126 named=126 unnamed=0 onlyHere=KeypadHyphen                        (port)
```

Three things in that line, all named rather than papered over:

- **eight keys the host has and the port does not**: `GCKeyCodeF13` through `GCKeyCodeF20`. Their values are
  declared by neither this package's `GCConstants14.m` nor the SDK's own `GCKeyCodes.h` for iOS, and they are
  function keys no iOS device reports, so the port carries the 126 key codes it declares a value for and answers
  nil for those eight. `buttonForKeyCode:` for one of them is nil here and a key on the host, which is the whole
  of it.
- **one key the port has and the host does not**: `KeypadHyphen`, the keypad's minus key. The host keys that
  button `Hyphen`, so a caller that reaches for the keypad spelling finds it here and not there.
- **one entry with an empty name on the host** and none here: the host's keyboard dictionary holds an element
  keyed by the empty string, and `buttonForKeyCode:` answers nil for every code including 0, so the host exposes no
  code that reaches it.

`anyKeyPressed` is NO while no key is down and YES while one is, the handler is a stored copy that runs on the
device's handler queue once per key that changed - which is what the header's own note says - and
`buttonForKeyCode:` answers the same object the profile's subscript answers for that key's name, which is what the
host does (measured: `elements[@"Eight"] == [k buttonForKeyCode:GCKeyCodeEight]` is true).

Source: the host's own GameController for every value in the two tables above, through
`tests/backports/host/gamecontroller`; the SDK 16.4 headers for the declarations, the `NS_UNAVAILABLE`
initializers and the header comment that contradicts the host's default; and the two band-end caches for the
absence.

## The touchpads, the paddles and the adaptive trigger

The three profiles' extra parts, all held against the host's own by the `gamepad extras` and
`adaptive trigger` groups of `tests/backports/host/gamecontroller`:

| what | host | port |
| --- | --- | --- |
| `GCDualShockGamepad.touchpadButton` | a `GCControllerButtonInput` | a `GCControllerButtonInput` |
| `GCDualShockGamepad.touchpadPrimary` / `Secondary` | a `GCControllerDirectionPad` each | the same |
| `GCDualSenseGamepad.touchpadButton` / `Primary` / `Secondary` | the same | the same |
| `GCDualSenseGamepad.leftTrigger` / `rightTrigger` | a `GCDualSenseAdaptiveTrigger` each | the same |
| `GCXboxGamepad.paddleButton1` through `paddleButton4` | nil, nil, nil, nil | nil, nil, nil, nil |

The touchpads are real elements, built from the same spec table and the same linking every other
profile in this package uses, so a caller can poll the surface's axes and press the surface's button
and both sides answer the same. The paddles are nil on both sides, which is what the host's own
`GCXboxGamepad` answers and what the header's `nullable` and its own example code expect: the standard
Bluetooth Xbox controller the profile describes has no paddles, and only the Elite does.

`GCXboxGamepad.buttonShare` is not answered at all here - it arrived in iOS 15 and is not this iOS 14
object's API, which is what `release-split` reads band points for.

### The adaptive trigger: mode is the controller's answer, not the caller's

The header is explicit about this and the host measures it:

> "mode ... reflects the physical state of the triggers - and requires a response from the controller.
> It does not update immediately after calling -[GCDualSenseAdaptiveTrigger setMode...]."

Measured on the host's own trigger, built by the application with no controller behind it: `mode` is 0
and `status` is 0 at rest, and each of the four `setMode` calls - off, feedback, weapon, vibration -
leaves both at 0, with `armPosition` 0 whatever the button's own value is. The port answers the same
way, and that is the point rather than a stub: a `mode` the port set from the caller's own argument
would be a mode no controller ever entered, and the header's own sentence says the value is the
controller's answer. What the port does answer is the part it can: the trigger is a real
`GCControllerButtonInput` underneath, so its value, pressed and touched states and its handlers are
this package's own button behaviour, and the four `setMode` calls record what was asked for through a
seam (`-charon_requestedMode:`) for a profile with a controller attached to send.

#### The 15.4 half of the same family

Three more members arrived at 15.4 and are carried in `GCDualSenseAdaptiveTrigger154.m`, an object of
their own release because `GCDualSenseAdaptiveTrigger.h:107`, `:123` and `:152` mark them
`API_AVAILABLE(ios(15.4))` while the class and the four calls above are the 14.5 ones:

| member | what it is that the 14.5 call is not |
| --- | --- |
| `-setModeSlopeFeedbackWithStartPosition:endPosition:startStrength:endStrength:` | a slope between two positions with a strength at each end, instead of one strength over one position |
| `-setModeFeedbackWithResistiveStrengths:` | a strength at each of the five points of the pull |
| `-setModeVibrationWithAmplitudes:frequency:` | an amplitude at each of the five points of the pull |

Measured on the host's own trigger, same trigger and same drive as the four above: all three selectors
are **present**, and each call leaves `mode` 0, `status` 0 and `armPosition` 0. That is the same answer the
four 14.5 calls give, and for the header's reason: `mode` is the controller's answer and no controller is
behind it. So the port's three do what the four do - record the mode through
`-charon_setRequestedMode:`, reach it back through `-charon_requestedMode:` - and the `adaptive trigger`
group of the differential holds both families at 11 lines a side, all identical.

What is deliberately **not** done with a curve's numbers: they are not clamped, ordered or stored. The
header declares the five fields normalized, and clamping them into a value nothing reads would be a
check that examines nothing - the only thing that could act on a curve is a controller, and there is
none, which is what the measurement above is. The four numbers of the slope call are not inspected for
the same reason.

One difference, named: `isKindOfClass:[GCControllerButtonInput class]` answers **YES** here and **NO**
on the host's own trigger, though the SDK 16.4 header declares
`@interface GCDualSenseAdaptiveTrigger : GCControllerButtonInput`. This port follows the declaration;
the host's object at runtime is a private class that does not register under the header's parent. A
caller that tests for the header's own relationship gets the header's answer here.

## What a caller gets from a controller that was never made

`GCController.controllers` is `@[]` and `+startWirelessControllerDiscoveryWithCompletionHandler:`
completes with nothing, both here and on the host with nothing attached, so `GCKeyboard`,
`GCMouse`, `GCDeviceBattery`, `GCDeviceLight` and `GCDeviceHaptics` are reached only by allocating one
- which the differential does, on both sides, and the `hardware` group asks a controller for the three
hardware descriptions the only way an application can.

Source: the host's own GameController for every value in the tables above, through
`tests/backports/host/gamecontroller`; the SDK 16.4 headers for the declarations, the `nullable` and
`NS_UNAVAILABLE` annotations, and the sentences quoted above; and the two band-end caches for the
absence.
