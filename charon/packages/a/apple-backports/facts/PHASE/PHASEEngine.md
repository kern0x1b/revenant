# PHASEEngine

Carried in `libAVFAudioBackports.dylib` (the `avfaudio` config), in `PHASEEngine15.m`. The largest
cluster in the PHASE corpus, and the class the rest of the framework hangs off.

PHASE arrived in iOS 15 and the port's releases are 6.1.3 and 4.3, so there is **no PHASE.framework on
either** and none of this is a translation of an engine that exists. What there is to carry is the
engine's state, and every value in it is either a documented default or the truth about a fresh
engine.

## The values, each with the header line that states it

| property | a fresh engine holds | where |
| --- | --- | --- |
| `unitsPerSecond` | 1 | `PHASEEngine.h:123` - default 1, positive values only |
| `unitsPerMeter` | 1 | `:134` - default 1, positive values only |
| `defaultReverbPreset` | `PHASEReverbPresetNone` | `:112` |
| `defaultMedium` | `PHASEMediumPresetAir` | `:104` |
| `renderingState` | `PHASERenderingStateStopped` | the enumeration's own zero (`PHASETypes.h`) |
| `outputSpatializationMode` | `PHASESpatializationModeAutomatic` | see below |
| `rootObject` | **absent** | the host has a `PHASERootObject`; see below |
| `activeGroupPreset` | nil | the header marks it nullable |
| `soundEvents` | `@[]` | a fresh engine has none |
| `groups` | `@{}` | a fresh engine has none |
| `duckers` | `@[]` | a fresh engine has none |
| `assetRegistry` | nil | see below |
| `lastRenderTime` | nil while stopped or paused; while started, an AVAudioTime at 48 kHz from the render loop | see below |

`outputSpatializationMode` has **no documented numeric default**: the header says only that it
"overrides the default output spatializer and uses the specified one instead". The answer is the
enumeration's own zero, `PHASESpatializationModeAutomatic` - the mode whose name is "let the framework
choose", which is what a fresh engine that overrides nothing is doing. That is the enumeration's naming
rather than a number this port picked, and the facts file says so.

`unitsPerSecond` and `unitsPerMeter` are refused when set to a non-positive value, because the header
clamps to `(0, inf]` and the host's own clamp is what a caller has to live with; storing a value the
release would clamp would answer something the release does not.

## The three answers that are the empty set, and what they cost

The oracle caught one thing this delivery got wrong, and it is the reason the half exists: **a fresh
engine's `rootObject` is not nil.** The host's is a `PHASERootObject`:

```
stage a fresh engine's root object: host PHASERootObject, port nil
```

`PHASERootObject` has **no row in the PHASE corpus at all** - the corpus names 59 PHASE classes and
it is not among them - so the port has no class to put there. The row is `absent` with that
measurement as its reason, and the oracle keeps saying so rather than passing. An engine whose root
object is nil cannot take a sound event yet, which is the honest state of a framework whose root is
not carried.

`soundEvents`, `groups` and `duckers` answer empty, and `activeGroupPreset` and `assetRegistry`
answer nil. That is the truth about a fresh engine, not a stub - an engine has none of
them until objects are added. But the **classes** they would hold are separate families of the corpus
this delivery does not carry: `PHASESoundEvent`, `PHASEGroup`, `PHASEDucker`, `PHASEObject`,
`PHASEMedium`, `PHASEAssetRegistry` and `PHASEGroupPreset`. So a caller that adds a sound event to
this engine cannot yet, and the properties are not lying about the emptiness - they are honest about
the engine and incomplete about the framework around it. `defaultMedium` is held as the preset rather
than as a `PHASEMedium` object, for the same reason: the value is right and the object is not there.

## `lastRenderTime`: the port's render loop, and the host's measurements

`lastRenderTime` is an `AVAudioTime`, nil when the engine is not running. The port's engine has a render loop
(`PHASEEngine15.m`): a started engine runs a 10 ms timer on its own queue, and each tick renders one quantum of
480 frames at 48 kHz. The clock is the frames the loop has rendered since the engine was last started, and the
host time is the loop's last tick. The loop **renders no audio yet**: the engine holds no sound events, groups or
duckers, because their families are not carried, so there is nothing for a quantum to render into. When those
families land, the quantum renders into them here.

What the host does, measured with `rt.m` on the host's own engine (it was run in a scratch directory and is not
committed; `clock.m` holds the same script for the port):

| step | host `lastRenderTime` |
| --- | --- |
| fresh engine (stopped) | nil |
| `startAndReturnError:` | sample 0, 48 kHz, host time valid |
| one second later | sample 48240 |
| `pause` | nil (a paused engine is not running) |
| half a second, then resume | sample 24064: the clock **restarts** at the resume, it does not carry on |
| `stop` | nil |

Manual update mode (`PHASEUpdateModeManual`), also measured: the clock follows the wall clock on its own
(sample 48128 after one second with no `update` call, 72192 after a further half second), and `update` does not
move it (sample 48128 after 100 `update` calls). An **automatic** engine's `update` raises
`NSException` named `API Misuse` with the reason "Cannot call update while in automatic mode".

The port matches each of these: `tests/backports/host/phase/run.sh` runs `clock.m`, the same script against the host's
engine and the port's. The clock is read to within 100 ms of the elapsed time, because
the port's clock is a 10 ms timer and the host's is not a fixed quantum: host 48300 and port 48480 after one
second, host 24576 and port 24480 after the resume.

Not measured: the host's clock with a real output device (this host has the engine's own clock, not an
audio-hardware one), and the manual mode's clock when `update` is called from another thread.

## The host differential

`tests/backports/host/phase/run.sh` holds the port's own renamed classes to the host's PHASE, for the **value**
types and for the engine's clock:

- `values.m`: `checks=67 failures=0`. The host's fresh root object is a `PHASERootObject` and the port's is a
  `PHASEObject`, which is stated in the run's stage lines and is not a failure: the declared type is the same.
- `clock.m`: `checks=phase-clock failures=0`, the lifecycle and the clock above on both engines.

## Reuse

**searched: none.** Nothing here is a filter bank, a convolution or a graph: the engine's state is six
documented doubles and enums, its clock is a timer, and the rendering is a unit's work. Resonance Audio and Steam
Audio (both Apache-2.0) are the two upstreams for the HRTF *spatialization*, which is the `PHASESpatialPipeline`
and `AVAudioEnvironmentNode` family and not this one. OpenAL Soft is LGPL and was not read.
