# Core ML, the iOS 13 update classes

What `packages/a/apple-backports/CoreML/CoreMLUpdate13.m` carries, and what was measured before it was
written.

## WHAT THE OBJECT HOLDS

| class | status | what it answers |
| --- | --- | --- |
| MLTask | implemented | taskIdentifier, state, error; -resume and -cancel move the state, exactly as MLTask.h:41-45 gives them |
| MLUpdateTask | implemented | the class; MLTask's state machine, both constructors refused as MLUpdateTask.h:53-56 marks them |
| MLUpdateContext | implemented | the five readonly properties MLUpdateContext.h:24-36 declares |
| MLUpdateProgressHandlers | inert | the class and -initForEvents:progressHandler:completionHandler:; nothing in this port fires what it holds |
| MLWritable | absent | the protocol, and this port does not declare it - see below |

## THE MEASUREMENTS, AND THE COMMANDS A READER CAN RUN

**Where each name is real.** `xmake l tools/cache-index/first-rung.lua NAME`:

```
MLTask	16.0
MLUpdateTask	16.0
MLUpdateContext	16.0
MLUpdateProgressHandlers	16.0
MLWritable	16.0
```

Five 16.0s, and the answer is NOT that these arrived in 16.0. The held ladder is dense to 12.0 and then
has a hole - no 13.0, no 14.0, no 15.0 - so a 13.0 name reads 16.0 on this tool. The placement answer is
the header's own annotation, which is `API_AVAILABLE(macos(10.15), ios(13.0), tvos(14.0))` on all four
classes (MLTask.h:29, MLUpdateTask.h:19, MLUpdateContext.h:20, MLUpdateProgressHandlers.h:18) and on the
protocol (MLWritable.h), and the registry's own source agrees:
`coordination/corpus/sdk-26.2-surface.tsv` carries one row for each at `introduced` 13.0.

**That this package declares none of the five.** The control, so a reader can tell a real zero from a
blind one:

| name | files under packages/a/apple-backports/CoreML that mention it | rows in sdk-26.2-surface.tsv |
| --- | --- | --- |
| MLTask | 0 | 1 |
| MLUpdateTask | 0 | 1 |
| MLUpdateContext | 0 | 1 |
| MLUpdateProgressHandlers | 0 | 1 |
| MLWritable | 0 | 1 |
| MLKey (control) | 1 | 1 |
| MLModel (control) | 2 | 1 |

`MLKey` and `MLModel` are the controls: the same reader finds them, so the five zeros are the package's
and not the reader's.

**Why MLWritable is `absent` and not `implemented`.** `check_registry` answers a protocol row from
whether anything carries the protocol's own metadata:

```lua
-- A protocol has no accessors, so nothing else in this loop can answer for it: the row is
-- implemented when the objects carry the protocol's own metadata and it names.
```

`CharonCoreMLProtocols.h` - the one header of this folder that declares protocols - declares
`MLFeatureProvider` and nothing else (`grep -n '@protocol'
packages/a/apple-backports/CoreML/CharonCoreMLProtocols.h` answers one line), and no `@implementation`
in the folder emits `_OBJC_PROTOCOL_$_MLWritable`. So the protocol's metadata is nowhere in the built
objects and `implemented` would be a claim no measurement supports. It stays `absent`, and the reason
now says what is actually absent instead of a sentence about iOS 6.

## WHAT WAS NOT MEASURED, STATED PLAINLY

- **No differential against Apple's code**, and none is possible: the update classes' whole behaviour is
  to drive Core ML's model-update training, which runs against a GPU and a training corpus.
- **No host case, no device run, no gate.** The only build this band ran is
  `coordination/run_light_tests.lua`.

## WHY MLUpdateProgressHandlers IS `inert` AND NOT `implemented`

`-initForEvents:progressHandler:completionHandler:` (MLUpdateProgressHandlers.h:22-24) registers a
progress block and a completion block, and both are held - strong ivars, which is what ARC copies a
block into, so what the caller registers outlives the call. What would CALL them is an
`MLUpdateProgressEvent`, and nothing in this port produces one: an event is a step of the training loop,
`MLUpdateTask`'s only two initialisers are `API_AVAILABLE(ios(14.0))` (MLUpdateTask.h:31 and :46), and
there is no training loop anywhere in this package. So the class loads, its initialiser answers, and
nothing applies what it holds - which is what `inert` means, and the status MPSImageGaussianBlur's row
already uses for exactly this shape.

`MLUpdateContext` is the other half of that, and it is `implemented` rather than inert for a reason
worth stating: its five getters answer the state the context was built with (MLUpdateContext.h:24-36
declares them and NO initialiser, so the release builds one inside its training loop and there is no
public way to make one here either). It answers; it just cannot be made from outside.

## THE OTHER FIFTEEN ROWS OF THIS SLICE, AND WHY THEY DO NOT MOVE

The eight `+[MLFeatureValue featureValueWithCGImage:...]` and `...WithImageAtURL:...` constructors, and
the six `-[MLKey init]`, `+[MLKey new]` and their `MLMetricKey` and `MLParameterKey` counterparts.

The six keys are `absent` because Apple's own header marks them `NS_UNAVAILABLE`, and each row already
says that with the effect spelled out - "an application compiled against Core ML's own header cannot send
it, and one that sends it by name gets doesNotRecognizeSelector". That is the honest end and this band
leaves it.

The eight constructors are `absent` on a measured ground, and the measurement is already in the rows: the
selector is not carried, but the CONVERSION is, inside Vision, and `tests/backports/host/vision/run-crop.sh`
compares it against Core ML's own image constructor and does not agree everywhere - 3208 of 50176 pixels
differ on 100x50 to 224x224, and the centre-crop rule differs on all 50176. A row that says a thing is
absent, says why, and prints the numbers is finished; this band has nothing to add to it.