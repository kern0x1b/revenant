# UIFeedbackGenerator

Introduced in iOS 10.0. Reconnaissance only - no implementation yet. The question
this answers is whether the iPhone 4S can vibrate at a chosen strength, and
whether what it produces can pass for the haptics the class stands for.

Sources: CoreMedia of the armv7 cache of iOS 6.0; the device tree and the
accelerometer of an iPhone4,1 running 6.1.3.

## The vibrator is reachable, and it takes a strength

CoreMedia 6.0 exports a whole vibrator interface: `FigVibratorInitialize`,
`FigVibratorIsVibratorAvailable`, `FigVibratorGetMinMaxDurations`,
`FigVibratorStartOneShot`, `FigVibratorStartRepeating`,
`FigVibratorPlayVibration`, `FigVibratorPlayVibrationWithDictionary`,
`FigVibratorStop`, `FigVibratorShutdown`, with the parameter keys
`kFigVibratorParamKey_Intensity`, `_OnDuration`, `_OffDuration`, `_Period`,
`_TotalDuration` and `_VibePattern`.

`FigVibratorStartOneShot` takes the strength as a float and refuses it outside
`[0, 1]` before doing anything else. It reaches the hardware like this:

- the strength becomes `(int32)(intensity * 65536)` - 16.16 fixed point - under
  the key `intensity` of a dictionary of its own;
- that dictionary is element 0 of a four element array, element 1 is the on
  duration in milliseconds, element 2 is `kCFBooleanFalse` (the off phase carries
  no strength) and element 3 is the off duration in milliseconds, both clamped
  to at least 1;
- the array goes under the key `hertz_millisecs`, beside `repeat` holding a
  boolean, and the pair is written with `IORegistryEntrySetCFProperties` to the
  IOService found by `IOServiceNameMatching("vibrator")`.

`FigVibratorPlayVibrationWithDictionary` reads `Intensity`, `VibePattern`,
`OnDuration`, `OffDuration`, `Period` and `TotalDuration` as CFNumbers, clamps
the intensity into `[0, 1]` the same way, and defaults to on 0.4 s, off 0.1 s,
period 0.5 s, total 0.5 s and **intensity 0.85** when a key is missing. A
`VibePattern` array replaces the durations.

None of this needs a daemon: the properties are written straight to the
IORegistry entry.

## The hardware says the strength is an amplitude

The `vibrator` node of the iPhone4,1 device tree:

| property | bytes | meaning |
|---|---|---|
| `device_type` | `pwm` | driven by a PWM codec; its parent node is `codec-pwm` |
| `intensity-config` | `ampl` | the strength is applied as an **amplitude** |
| `default-hz` | `0xaf` | 175 Hz |
| `enable-ms` | `0x64` | 100 ms |

## Measured on the phone

Writing the properties directly and reading the accelerometer at 100 Hz on the
iPhone4,1, as the RMS of the acceleration magnitude while the motor runs against
the same measure while it is still. Two runs, agreeing to within 4%:

| intensity | 16.16 value | still | running | ratio |
|---|---|---|---|---|
| 1.00 | 65536 | 0.0025 | 0.2532 | 100 |
| 0.75 | 49152 | 0.0029 | 0.2226 | 76 |
| 0.50 | 32768 | 0.0036 | 0.1396 | 39 |
| 0.25 | 16384 | 0.0032 | 0.0605 | 19 |
| 0.12 | 7864 | 0.0025 | 0.0277 | 11 |
| 0.08 | 5242 | 0.0025 | 0.0184 | 7 |
| 0.04 | 2621 | 0.0028 | 0.0093 | 3.3 |
| 0.02 | 1310 | 0.0027 | 0.0054 | 2.0 |
| 0.01 | 655 | 0.0026 | 0.0036 | 1.4 |
| 0.00 | 0 | 0.0033 | 0.0026 | 1.0 |

The strength is honoured, continuously and monotonically. It is close to linear
up to 0.5 and saturates above it - the last doubling, 0.5 to 1.0, buys 1.8 times
the amplitude, not twice. Zero is silence. Below about 0.02 the motor no longer
rises out of the noise, so the usable floor is 0.02 to 0.03.

## What it cannot do

It is an eccentric rotating mass, not a Taptic Engine, and it has to spin up.
At full strength, against the length of the pulse:

| on time | peak deviation |
|---|---|
| 20 ms | 0.0040 g - nothing, the motor never starts |
| 40 ms | 0.1461 g |
| 60 ms | 0.1878 g |
| 100 ms | 0.2684 g |
| 150 ms | 0.3380 g |
| 250 ms | 0.3586 g |
| 400 ms | 0.3856 g |

A pulse shorter than about 40 ms produces no movement at all, and full amplitude
needs upwards of 200 ms - which is what `enable-ms = 100` in the device tree is
about. So the crisp tap that `UIImpactFeedbackGenerator` and
`UISelectionFeedbackGenerator` stand for cannot be produced on this hardware.
What can be produced is a buzz of a chosen strength and length.

## The API, read off iOS 10

Public members, and nothing else: `-[UIFeedbackGenerator prepare]`,
`-[UIImpactFeedbackGenerator initWithStyle:]`, `-[UIImpactFeedbackGenerator impactOccurred]`,
`-[UINotificationFeedbackGenerator notificationOccurred:]`,
`-[UISelectionFeedbackGenerator selectionChanged]`.

What the implementation says:

- `-initWithStyle:` maps light to `+[_UIImpactFeedbackGeneratorConfiguration lightConfiguration]`,
  medium to `+defaultConfiguration` and heavy to `+strongConfiguration`. **Any other
  value is not an error**: the configuration is `nil` and the object is built with
  it, so the generator exists and plays nothing.
- `-impactOccurred` is `-_impactOccurredWithIntensity:` with an intensity of
  exactly `1.0f`.
- `-_impactOccurredWithIntensity:` reads the configuration's `feedback` and
  **returns without playing when it is nil**, then plays through
  `-_playFeedback:withMinimumIntervalPassed:since:prefersRegularPace:` with the
  configuration's `minimumInterval`.
- `-notificationOccurred:` tail-calls `-_playEventType:`, and so does the private
  `-_privateNotificationOccurred:`.

The three impact configurations, out of their preparation blocks:

| style | feedback type | `hapticParameters.volume` | `minimumInterval` |
|---|---|---|---|
| light | 8 | 0.7 | 0 |
| medium | 5 | 0.7 | 0 |
| heavy | 2 | 0.8 | 0 |

The type is the argument of `+[_UIDiscreteFeedback discreteFeedbackForType:]`,
and it **names a waveform; it is not a count of anything**. The class keeps it in
a `type` ivar and `-_effectiveSystemSoundID` turns it into a system sound -
`1001` into `1519`, `1002` into `1520`, anything else into a default - so each
value is one identity in a table, the way
`-[UINotificationFeedbackGenerator _categoryForType:]` also tests that space with
`(type | 2) == 1002`. Their order says nothing either: light is 8 and heavy is 2.

The fact that matters for a port: **Apple separates the three styles by waveform,
not by strength.** The volumes are within a tenth of each other; what differs is
which discrete Taptic waveform is played. `minimumInterval` is zero for all
three, so iOS 10 does not rate-limit impacts.

## What this port does, and what is ours

An eccentric rotating mass has no waveforms - only amplitude and length - so the
three styles cannot be told apart the way iOS 10 tells them apart. On top of
that, `UIFeedbackGenerator` on iOS 10 does nothing at all on hardware without a
Taptic Engine, so there is no Apple behaviour for an ERM to copy. The patterns
below are therefore **ours**, not Apple's, and they are chosen from the hardware
measured above: nothing shorter than 40 ms moves the motor, amplitude is close to
linear up to 0.5, and the usable floor is 0.02.

| call | pulses, milliseconds | intensity |
|---|---|---|
| `impactOccurred` (light) | 40 | 0.45 |
| `impactOccurred` (medium) | 65 | 0.70 |
| `impactOccurred` (heavy) | 100 | 1.00 |
| `notificationOccurred:` success | 55 on, 90 off, 55 on | 0.55 |
| `notificationOccurred:` warning | 55 on, 90 off, 110 on | 0.75 |
| `notificationOccurred:` error | 70, 70, 70, 70, 70 | 1.00 |

Kept from iOS 10 as read above: a style outside the three raises nothing and
plays nothing; `impactOccurred` is full intensity for its style; there is no
rate limiting.

The motor is reached the way the system reaches it -
`AudioServicesPlaySystemSoundWithVibration(0xFFF, nil, pattern)`. That is not a
guess at the sound identifier: `-[TLVibratorController _turnOnWithVibrationPattern:]`
of ToneLibrary, which is what the Settings vibration picker plays through, loads
`0xFFF` into r0 and nil into r1 and tail-calls exactly this function, and
`-_turnOff` stops the same identifier. The third
argument iOS 6 serialises as a binary property list and hands to mediaserverd,
which is where `FigVibratorPlayVibrationWithDictionary` reads `VibePattern` and
`Intensity`. `VibePattern` alternates a CFBoolean and a CFNumber of milliseconds,
and a true entry is the one that carries the intensity. Writing the IORegistry
node directly would skip the server's own mutex and its `VibeWillStart`
notification, so the port does not do that. Both functions are reached by
`dlsym`, so the library gains no new link.

Whether the motor exists at all is asked of
`FigVibratorIsVibratorAvailable`, which matches the IOService named `vibrator`
and is independent of `FigVibratorInitialize`. On an iPad 2, which has no motor,
it answers no and every call plays nothing - which is exactly what iOS 10 does on
a device without a Taptic Engine.

`-prepare` has nothing to warm on an ERM and does nothing. It is not a stub: its
only contract is latency, and iOS 10's own does nothing when there is no engine.

`UISelectionFeedbackGenerator` is declared and **plays nothing**, which is the implementation on this hardware. Its whole point is a tick
per detent as a picker turns, and the motor needs 40 ms before it moves at all -
slower than the detents it would have to mark. A buzz there would be an imitation
of a sensation the hardware cannot produce, so `-selectionChanged` does nothing.
That is what iOS 10 does on a device with no Taptic Engine, where the class exists
and its `-selectionChanged` reaches an engine that is not there. The class was first
left out; in a corpus of nine applications six name it, and a program that names a
class that is not there fails where one that finds it does not, so it is carried
and says plainly that it plays nothing. `-prepare` is the base class's.

## Where this departs from the release, and when that would be revisited

On hardware with no Taptic Engine iOS 10 plays nothing at all, and this port plays its own measured pattern on the
eccentric rotating mass of an iPhone 4S. That is a real departure and it is declared rather than quiet: the patterns
above are named as ours, they were read off a live iPhone4,1 rather than guessed, and on an iPad 2, which has no motor,
`FigVibratorIsVibratorAvailable` answers no and every call is silent, which is the release's own behaviour there.

The path that would have made the departure costly is already closed: `UISelectionFeedbackGenerator` plays nothing, because
a tick per detent is below the motor's 40 ms floor, and that is the call an emulator front end makes often.

This stays open, not settled. If a real application shows the impact feedback buzzing intrusively on a 4S, or draining
the battery, the answer is strict silence on every device, as the release has it.
