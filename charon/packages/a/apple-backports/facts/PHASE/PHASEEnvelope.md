# PHASEEnvelope and PHASEEnvelopeSegment

Carried in `libAVFAudioBackports.dylib` (the `avfaudio` config), in `PHASEEnvelope15.m` and
`PHASEEnvelopeSegment15.m`. A segmented envelope, and the one place PHASE evaluates a curve of its own.

PHASE arrived in iOS 15 and the port's releases are 6.1.3 and 4.3, so there is no PHASE.framework on
either and this is the arithmetic the header describes rather than a translation of a class that exists.

## The shape

`PHASEEnvelopeSegment` is an end point and a curve type, and the header is explicit about what it is
not: *"Envelope segments do 'not' contain a start point. We do this so we can connect envelope segments
together end to end and gaurantee continuity along the x and y axes."* The design falls out of that: a
segment's start is the previous segment's end, so nothing here can disagree with it because nothing here
knows it. `PHASEEnvelope` holds the start point the first segment does not, and `evaluateForValue:`
walks the segments.

Outside the domain the envelope answers its own end values — the start point before the first segment,
the last end point after the last — which is what "guarantee continuity" means at the ends, rather than
an extrapolation nobody asked for.

`domain` and `range` are the envelope's own extent: the first from the start point's x to the last end
point's x, the second the same in y, each a `PHASENumericPair`. An envelope with no segment is a point,
and both extents are that point.

## The eleven curves, and the two that were measured

Nine of `PHASECurveType`'s eleven cases are closed forms from their own names: the powers are `t^n` and
`1-(1-t)^n`, the trigonometry is `sin(t*pi/2)` and `1-cos(t*pi/2)`, and the two steps are the values
their names say. **The other two the header only names, and assuming them was wrong by 5% and by 100%.**

Measured against the host's own `PHASEEnvelope` at t = 0, 0.125, 0.25, 0.5, 0.75, 0.875 and 1:

| case | the host | the closed form |
| --- | --- | --- |
| `PHASECurveTypeSigmoid` | 0, 0.038060234, 0.146446609, 0.5, 0.853553391, 0.961939766, 1 | `(1 - cos(pi*t)) / 2` — a raised cosine |
| `PHASECurveTypeInverseSigmoid` | 0, 0.191341716, 0.353553391, 0.5, 0.646446609, 0.808658284, 1 | a half sine, mirrored about the midpoint |

**Neither is the logistic its name suggests**, and that is how the two were told apart: fitting a
logistic to the same seven numbers wants sharpness 1.176 at t = 0.25 and 1.845 at t = 0.125, while the
raised cosine and the half sine hit all seven exactly. An earlier version of this file used the unit
logistic and the differential failed on exactly these two cases — 0.0502 and 1.

All eleven now agree with the host to floating-point noise: worst difference **2.78e-17** over the seven
samples, and the domain and range agree exactly.

## The differential and its mutants

`tests/backports/host/phase/run.sh` asks the port's renamed classes and the host's own classes the same
question at the same seven points for each of the eleven cases, and reports the worst difference per
curve. Two mutants, both red:

| mutant | result |
| --- | --- |
| the measured sigmoid put back as a logistic | `FAIL curve 0x63725367 agrees with the host: 0.0501653238, tol 1e-06` |
| the curve evaluated past its segment instead of inside it | `FAIL curve 0x63724c6e agrees with the host: 1, tol 1e-06` |

## The unavailable initializers: `-init` and `+new`

`PHASEEnvelope` and `PHASEEnvelopeDistanceModelParameters` both mark `-init` and `+new` `NS_UNAVAILABLE`
(`PHASEEnvelope.h:107-108`), and the host does not treat that as "no such method". Measured on macOS
with the host's own PHASE, by `[[C alloc] init]` and `[C new]` in a `@try`:

| call | the host |
| --- | --- |
| `[[PHASEEnvelope alloc] init]` | raises `NSInvalidArgumentException`: `-[PHASEEnvelope init]: unrecognized selector sent to instance` |
| `[PHASEEnvelope new]` | raises `NSInvalidArgumentException`: `+[PHASEEnvelope new]: unrecognized selector sent to class` |
| the same two on `PHASEEnvelopeDistanceModelParameters` | the same shape, with its own class name |

`respondsToSelector:` still answers yes for all four: the selectors exist, and their implementation is the
raise. The port had no such implementation: it inherited `NSObject`'s `-init`, which returns an empty envelope
without a raise, so the registry's `absent` was a silent fake rather than the release's answer. The port
now implements both pairs as `[self doesNotRecognizeSelector:_cmd]`, which is the mechanism that produces the
host's message. The designated initializers are unaffected: `initWithStartPoint:segments:` and
`initWithEnvelope:` reach `NSObject`'s `-init` through `[super init]` or not at all, so they are not caught by
the override.

The differential holds the port's message to the host's, after the class name and the instance address are
taken out of both: `compareUnavailableInits()` in `tests/backports/host/phase/values.m`. A planted control
removes the envelope's two overrides in a scratch copy of the tree, and the same binary reports exactly the two
envelope checks red - `the port's -[PHASEEnvelope init] raises the same message as the host: no raise` and the
`new` line - and the distance model's four stay green, because its own overrides are still in place.

## Reuse

**searched: none.** These are eleven closed forms and a piecewise walk, all measured against the host's
own framework on this machine. Resonance Audio and Steam Audio (both Apache-2.0) carry HRTF and
attenuation DSP — the `PHASESpatialPipeline` family, not this one — and nothing here needs it. OpenAL
Soft is LGPL and was not read.

## PHASEEnvelopeDistanceModelParameters

The third class of the family, in `PHASEEnvelopeDistanceModelParameters15.m`: a distance model whose
curve is a `PHASEEnvelope`. The header states the contract twice — *"An envelope object where x values
are interpreted as distance and the y values interpreted as gain"* — and that is the whole of it, so
what is carried is the holding of an envelope and not a distance model: there is no `PHASEDistanceModel`
on any release of this port to convert.

`-init` and `+new` are `NS_UNAVAILABLE` and `-initWithEnvelope:` is the `NS_DESIGNATED_INITIALIZER`, so
the class is made one way. The designated initializer allocates the superclass directly rather than
calling `[super init]`, because `PHASEDistanceModelParameters` marks `-init` unavailable and declares no
designated initializer to chain to — and it inherits no state, its only member being its own
`fadeOutParameters`.

The differential asks both the port and the host to hold the envelope they were made with, and compares
the gain each reports at 5 m, which is the envelope's own arithmetic reached through the model:

```
stage the gain at 5 m: host 0.75, port 0.75
checks=67 failures=0
```

The unavailable initializers of both classes are checked in the same run, as described in the section above.

Two mutants, both red: the model keeping its own envelope instead of the one it was made with, and the
initializer's argument dropped. Both fail the same two checks, the second with the gain reported as 0
against the host's 0.75.
