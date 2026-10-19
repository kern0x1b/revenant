# The Core ML model format, read from the specification, and the interpreter over it

Apple's model format is open. coremltools (BSD-3-Clause, Apple Inc.) ships the protobuf
specification a `.mlmodel` container is written in, as one generated module per `.proto` file
under `coremltools/proto/`, and the same specification is published as protobuf. Everything
below is read from that specification rather than transcribed: `tools/coreml/gen-schema.lua`
reads every message's field number, wire type, type and oneof out of the descriptors
themselves and writes them as a C table, 354 messages and 1059 fields, so a change of
coremltools is a diff a reviewer reads rather than a silent regeneration.

The model kind, the description, the two names a classifier answers under, the class labels
and every weight are read through that table. A field the specification does not name is
stepped over by the wire type its bytes really have, so a container written by a later version
still reads.

## What is measured, and how

Two checks, both run on this host and both recorded under `.agent-work/runs/`:

- `tools/coreml/check-reader.sh` — nine containers written by coremltools' own writer are read
  and the tree printed is compared with the one protobuf's own reflection prints from the same
  file: **five of five identical, and four malformed containers refused** rather than half-read.
  This is a fidelity check on the reader only.
- `tools/coreml/check-predict.sh` — the same containers are run over fixed inputs and the
  answers compared with the host's own Core ML (predict-host, the same probe that writes the manifest): **eight models agree to 1e-5 on
  every answer**, and one has a difference written down and checked (below).

## What the arithmetic turned out to be, where the names read otherwise

Three things the obvious reading gets wrong, each measured against coremltools' own runtime
rather than assumed:

- **The scaler is `(x + shift) * scale`,** not `x * scale + shift`. Four inputs through a
  two-feature model: `(2.0 - 1.5) * 0.25 = 0.125` is what comes out, and `2.0 * 0.25 - 1.5`
  is not. The field is named `shiftValue` and reads the other way round.
- **A tree leaf's values name the class they apply to.** A leaf of a two-class tree carries
  two `evaluationInfo` entries, each with an `evaluationIndex`; they are not one vector per
  leaf. The base prediction is one value per class for the same reason, and only the leaves a
  walk down from the tree's root reaches count -- a node some other node names as a child is
  not a root.
- **An L2 normalisation divides the whole value by one length,** not each channel by its own.
  On a two-channel input the per-channel reading gives `(1, -1)`; the runtime gives
  `(0.9915, -0.1302)`, which is the single norm of the two together.

Two more, found by the check and fixed:

- **An embedding's table is laid out per output channel,** the whole row of the table for that
  channel across every index. With the index as the outer dimension the values came out of
  the wrong channel.
- **A GLM classifier in the reference-class encoding has no weight vector for the reference
  class:** it scores zero, the vectors fill the classes after it in order, and the answer is a
  softmax over the whole set. Measured over four inputs of a two-vector, three-class model,
  `softmax(0, w0.x + o0, w1.x + o1)` is that runtime's answer to the last digit. It is *not*
  the per-class logistic the post-evaluation transform names: on these inputs that would give
  `(0.5, 0.525, 0.475)`, which does not sum to one. The encoding's own first case is
  ReferenceClass and a field set to it is not written at all, so absent and ReferenceClass are
  the same value here.

## A divergence, and what it turned out to be

`nn_image`, a convolution, a ReLU and a global pool, did not match the host, and the cause is
now known: **this port put an array input through the network's own `scaler` preprocessing and
neither Core ML nor coremltools does.** The scale is a picture's. It is a per-channel scale and
a bias named for a colour — `channelScale`, `redBias`, `greenBias`, `blueBias` — and the release
puts it through for a feature the specification declares as an image and not for an array.

Measured on macOS 27.0 build 26A428, over `nn_image.mlmodel` and the input pattern
`tests/backports/host/coreml/cases.m` feeds (a five-element pattern `((element % 5) - 2) * 0.25`
repeated over the 192 elements), the release answers `0.3570, 0.3338, 0.3595, 0.3827`, which is
the global maximum of the convolution over the values **as they were fed**; this port answered
`0.4189, 0.0000, 0.0000, 0.0000`, which is the same convolution over the values after
`x / 255 - 1`. Both numbers are reproduced to the last digit by computing the convolution over
the model's own weights, read `(outputChannel, kernelChannel, kernelRow, kernelColumn)` as the
specification writes them, followed by a ReLU and a 6x6 global max — so the weights, the axes,
the kernel and the pool were never in question and the scale was the whole of it.

coremltools 9.0's own runtime agrees with the release and not with this port: for the
container's own input it answers `0.35275915265083313, 0, 0.495936781167984, 1.953547477722168`,
which is the same convolution over the raw pixels. So two independent runtimes put an array
through no scale.

What the earlier note had "ruled out" was the input with and without the scale, the weight axes
in six orders and both pool kinds — and it drew the wrong conclusion from them, because both
preprocessed readings were computed with a ReLU over a *pool*, and the one that matched the port
did match: `0.4189, 0, 0, 0`. It was read as "the port's answer is a reading of the model" rather
than "the port applies something the release does not", and the second is what the numbers say.
The check no longer records a divergence: `tools/coreml/check-predict.sh` prints `nn_image OK - 3
answers within 1e-05 of Core ML on this host`.

That check was also comparing two different inputs, which is how the stale note survived a fix:
the two array inputs it fed were a second, hand-written copy of the convolutional model's pixels,
kept from when the corpus sample was a PIL image, and they had drifted from the sample. It now
reads the values out of `make-models.lua`'s own `SAMPLES`.

Unmeasured, and unchanged by any of this: **an image feature's own scale.** No container in the
corpus declares an image input that this host's Core ML will load, so the branch that keeps the
scale for one has nothing measured behind it. It is the behaviour the specification describes and
the behaviour the crop-and-scale path in `tests/backports/host/vision/` is built around; it is
left as it was rather than removed with the array case.

## The compute device family of 17.0, and the one compute unit this release has

Measured on this host's own Core ML by `tests/backports/host/coreml/probe-devices.m` and held case by case
of both sides by `tests/backports/host/coreml/devices-cases.m`, which the Core ML differential records into
the same file as the containers' cases:

| what was asked | what this host answers |
| --- | --- |
| `MLAllComputeDevices()` | **three devices: a neural engine, a GPU and a CPU**, in that order |
| `+[MLModel availableComputeDevices]` | **the same three in the same order**, and `[a isEqual:b]` is **YES** for the two arrays |
| the function called twice | **another array** with the same contents |
| `+new` and `-init` on each of `MLCPUComputeDevice`, `MLGPUComputeDevice`, `MLNeuralEngineComputeDevice` | **an object** on all six, though each header marks both unavailable (`MLCPUComputeDevice.h:19-21` and its two siblings) |
| `conformsToProtocol:@protocol(MLComputeDeviceProtocol)` on each of them | **YES** for all three |
| the neural engine's `-totalCoreCount`, for a device of the list | **16** |
| the GPU's `-metalDevice`, for a device of the list | **a real `MTLDevice`**, and it conforms to `@protocol(MTLDevice)` |
| the same two properties, for a device made by `+new` | **0** and **nil** |

The last row is the one that decides the port: **a device that was not made over a device knows nothing
about hardware**, so the port's GPU device answers nil for `-metalDevice` and its neural engine answers 0
for `-totalCoreCount` - which is what the host answers for a device made by `+new` on any machine, and not
only where there is none.

**What this release has.** iOS 6 has no Metal driver and no neural engine at all, so the list is the one
compute unit it has, the CPU: `MLAllComputeDevices()` and `+[MLModel availableComputeDevices]` both answer a
list of that one device, and they answer the *same* device, so that a program comparing the two with
`-isEqual:` gets the framework's own answer of YES. That is the rule the API worker brief states for
hardware a device physically lacks, and the one `MLCompute`'s `MLCDevice` already follows
(`facts/MLCompute/Device.md`: the GPU and the neural engine are carried and answer as a device with
neither). The GPU and the neural engine classes are still carried, because a program asks for them by class
and by property and the corpus of SDK 26.2 names them.

**Ten keys of the family are the same question asked of two machines, and the differential names each of
them.** Six are answers that differ (the count and the first device of each of the two lists) and four exist
on one side only (the second and third devices, and the two properties read off a device of the list). Each
is in `run.sh`'s `HARDWARE` table with the hardware it is about, and **an allowance that stops being needed
fails the run**: a table nobody checks is a table that hides whatever it names.

**One thing this measurement caught that is worth naming.** The first version of the cases file reached the
function through `dlsym(RTLD_DEFAULT, "MLAllComputeDevices")`, and every one of its ten answers came out
identical on both sides - because the port's own definition is renamed in the port's build (the row is a
function row, so `rename.h` maps the name), and the plain name in a `dlsym` finds the **framework's** copy.
So the port's own list was never asked, and the comparison said so by reporting all ten allowances as stale
at once. The cases file calls the function by name, which the rename reaches on the port's side and the
framework's declaration reaches on the host's.

## Carried but not measured

Each of these is refused with a line naming the layer, not approximated:

- **`loadConstant`.** coremltools 9.0's runtime wants a constant in the five dimensions of the
  rank-five array mapping, refuses a rank-5 network input as well, and so will not run a network
  carrying a constant at all.
- **A concat, a permute, a copy, a softmax on a rank-3 value, and a two-input add on values of
  one and two dimensions** are each refused by that runtime ("Unsupported layer type"), so no
  model carrying them can be compared against it. A softmax is measured on the dense
  classifier instead, where it is the last layer.
- **The recurrent layers** (`simpleRecurrent`, `gru`, the LSTMs). A recurrent layer takes a
  *sequence*, which the specification types as a dictionary of indices to vectors, and the
  runtime refuses every multiArray shape for it. This port does not carry a sequence value
  yet, so the simple recurrent layer is carried but has never been run against anything.
- **Batch normalisation, the padding layer and the rank-five array mapping.** The model that
  would measure them is written (`build_nn_layers_image` in `tools/coreml/make-models.lua`) and
  is not in the set, because the runtime refuses a rank-3 input to a convolution ("expects
  rank at least 4") and a rank-5 one as a network input.

Two more, and both are about what the build measures rather than what it carries:

- **`vision_image` carried a size the release would not accept, and did not load until 2026-10-03.**
  `tools/coreml/make-models.lua` still reports it as `no host input`, because coremltools 9.0's Python
  runtime gives no prediction for a network whose input is a picture; that is the only thing left of
  the old claim. The release refused the container itself, and the reason was in the container:
  `build_vision_image` declared both of its picture features as an `imageSizeRange` of 16 to 256,
  and asked to compile it this host's own `+[MLModel compileModelAtURL:error:]` answered
  `com.apple.CoreML`, code 0, **"compiler error: Invalid height and width for the image input."** A
  ranged image input needs a network whose blob shapes are flexible, and this one has fixed shapes.
  Measured on this host (an M4 Pro, macOS, Core ML and Vision both present, coremltools 9.0) over
  five shapes of the same network: ranged input 16..256 refused with that text, ranged input with
  32..32 refused the same way, and `ImageFeatureType.width`/`.height` = 32 on both ends compiles,
  loads and predicts. There is no `Exact` case in the enumeration the SDKs here carry (0
  unspecified, 2 enumerated, 3 range), so a fixed size is spelled as the enumerated kind holding one
  size, and that is what the release answers: `sizeConstraint` 2, `pixelsWideRange` 32+1,
  `pixelsHighRange` 32+1, `enumeratedImageSizes` 32x32.

  Fixing the container uncovered three answers this port did not have, all of them about a FIXED
  size and all of them measured against the release rather than argued. The reader left its range
  fields at `CHARON_ML_FLEXIBLE` when no range node was present, so a fixed size took the range
  branch and answered `NSRange(NSUIntegerMax, 0)` for both dimensions; it now reads a fixed size as
  no range at all (`CharonMLModel.c`). `charon_ml_image_size_constraint_of` then answers the
  enumerated kind with the one size and a length-one range per dimension
  (`CharonMLConstraints.h`). And a required feature the caller left out now says what the release
  says, `Feature image is required but not specified.` (`MLModel.m`), instead of a sentence of the
  port's own that named the feature's type.

  `tests/backports/host/vision/run.sh` measures the same container through Vision, which is the
  framework that runs an image model, and expects the compile failure -- that expectation was
  written for the ranged form and is what made the container's own fault invisible, so it is named
  there too. The image constructors this port DOES carry are measured a different way -- against Core
  ML's own image constructor, by pixels, in `tests/backports/host/vision/run-crop.sh` -- and that
  measurement is red for the crop-and-scale rules; `registry/CoreML/absent_CoreML.json` states
  which cells differ. What is unmeasured is the container, not the conversion.
- **`__OBJC_PROTOCOL_$_MLFeatureProvider` is defined by two objects.** `MLFeatureProvider.m` and
  the generated `CoreMLBackportsProtocols11.0.m` both emit it, because any translation unit that
  sees a protocol's definition and references it emits the object, and `MLFeatureProvider.m`
  must import `<CoreML/CoreML.h>` for the enums `CharonMLBridge.h` needs (`MLFeatureType`,
  `MLFeatureTypeInt64`; without it the first error is `unknown type name 'MLFeatureType'`). The
  two used to DISAGREE -- the port's own declaration gave the protocol the base `<NSObject>` and
  the SDK's header gives it none -- and ld64 kept whichever weak definition came first on the
  link line, silently; the surviving base list read 0x0 in the build's order and 0x3dd18
  reversed. The port's declaration is gone, both now come from the SDK header, and the surviving
  base list is 0x0 in both orders. What is left is the duplicate itself, which nothing in the
  build checks for a protocol with no `implemented` registry row -- the case added to
  `tests/addon/registry_test.lua` only sees the ones the generator emits.

## What the registry says about what this port carries

`registry/CoreML/absent_CoreML.json` holds the SDK's Core ML APIs this port does not carry. Every row in it was
adjudicated against the built objects - the 21 sources of `CoreML/` compiled with the package's own flags, and
`nm -gU` plus `otool -oV` over the 21 objects, which define 23 classes, 6 protocols and 262 method entries - and
the three kinds of row answer differently:

- **`MLBatchProvider` is carried.** Its row said `absent` and "the protocol is not there", which was false. It is
  `implemented`, and it is now carried twice on purpose: `CoreML/MLArrayBatchProvider12.o` conforms to it and
  therefore carries the metadata object a conforming class needs, and the generated
  `CoreMLBackportsProtocols12.0.m` emits it for the row. Measured: both definitions are
  `weak private external` (`nm -m`) and **both are the SDK's own**, from `MLBatchProvider.h`, so ld64 keeping
  whichever comes first yields the same object. That is not the case this file already recorded for
  `MLFeatureProvider`, where the two definitions DISAGREED (the port's own declaration gave the protocol the
  base `<NSObject>`, the SDK's gives it none). `CoreML/MLFeatureProvider.m` declared `MLBatchProvider` for the
  same reason it once declared `MLFeatureProvider` - and that declaration is now gone: nothing in that
  translation unit used the protocol, so clang dropped it (`nm MLFeatureProvider.o` shows no
  `__OBJC_PROTOCOL_$_MLBatchProvider`, and the object is byte-identical before and after the removal), and a
  translation unit that DID use it would have emitted a third definition that disagreed with the SDK's.
- **The nine `-init`/`+new` rows are absent, and that is the whole truth.** Apple declares all of them
  `NS_UNAVAILABLE` ("cannot construct MLKey without parameters", `MLKey.h:27-29` and its four siblings): an
  application compiled against Core ML's own header cannot send them and one that sends by name gets
  `doesNotRecognizeSelector`. The port's objects inherit NSObject's and there is no body of the port's to carry.
- **Two protocols are carried**: `MLCustomLayer` and `MLCustomModel`, both declared with a body by SDK 16.4
  (`MLCustomLayer.h:19`, `MLCustomModel.h:19`), so `CharonCoreMLProtocols.h` forward-declares them and
  `protocol_sources()` emits their metadata objects into the generated protocol source. Measured: that object
  compiles clean with the package's flags and `nm` reports `__OBJC_PROTOCOL_$_MLCustomLayer` and
  `$_MLCustomModel` in it; none of the 21 port objects defines either, so each has exactly one definition.
  `MLWritable` was carried in the first form of this change and is not: its row stays `absent` with the
  measurement in facts/CoreML/Update13.md (iOS 13.0, and the update family it belongs to), which main
  decided after this series was written.
- **Seven rows are `absent` with what is missing named, read out of a cache and not out of a header.** The 16.0
  dyld shared cache on this machine answers, through `tools/corpus/objc-inventory.lua` (168,686 classes) and
  `tools/cache-index/first-rung.lua`, exactly what six of them are: `MLModelCollection` carries
  `-initWithIdentifier:`, `-entries`, `-downloadWithProgress:`, `-registerForUpdates` and
  `-handleTrialUpdateForNamespaceName:`, which is Core ML's own model STORE - a container its daemon writes
  and syncs with Apple's servers; `MLModelCollectionEntry` is one row of that store (`-modelIdentifier`,
  `-modelURL`); `MLTask` is the state machine that daemon drives (`-initWithState:`, `-canCancel`,
  `-completeWithTaskContext:`, `-failWithError:taskContext:`); `MLUpdateTask` is
  `+updateModelAtURL:trainingData:configuration:writeToURL:error:`, a training run that writes a model back;
  `MLUpdateContext` is its per-step context; `MLUpdateProgressHandlers` is that loop's callbacks. This port
  carries no store and no daemon and cannot: its reader takes a model's bytes from a URL or from `NSData` and
  runs them, and it writes no model anywhere. `MLModelCollectionDidChangeNotification` is the seventh, and the
  cache is what keeps it out: the name is in the cache twice (`.09` and `.44.dyldlinkedit`) and five
  `com.apple.CoreML*` value strings are, but no measurement pairs the symbol with one of them, and the port
  does not write a notification name it has not measured. All seven answer `absent`, and what a caller gets is
  named: `NSClassFromString` answers nil, or the symbol does not link.

**The header-only enumeration is carried by its header, and that is what `inert` says.** `MLMultiArrayDataType`
is one `enum` row and its six cases six `constant` rows, each in the band the SDK dates it in (11.0 for
Double/Float32/Int32, 14.0 for Float64/Float, 16.0 for Float16), with the values the header writes -
`0x10000|64`, `0x10000|64`, `0x10000|32`, `0x10000|16`, `0x10000|32`, `0x20000|32`. The value is Apple's own and
the consumer inlines it at compile time, so what the port carries is the header and there is nothing to define
and nothing to export - which is why the rows are `inert` and not `implemented`: an enumeration has no
symbol, in Apple's build or in ours, and `implemented` means the port's own object answers the name. The gate
said so in the only terms that decide it:

    error: the registry does not describe what the backports carry:
      listed as implemented, but nothing of that name is built: MLMultiArrayDataType; MLMultiArrayDataTypeDouble; …

`tools/cache-index/first-rung.lua` answers NONE for `MLMultiArrayDataType` over the held caches for the same
reason, and that is the third family to meet this wall after Metal's two. A row whose api has no symbol is
`inert`, and its reason says the whole of it: an enumeration has no symbol, the cases are declared by the SDK
header, and nothing here computes or exports one. Its effect says what a caller gets - the value the SDK's own
header gives, written into the caller's code at compile time.

The wall was the status - the gate's own message above is the proof - and this family needs nothing more: the
enumeration's uses in the SDK's headers are all `implemented` members, so nothing was blocking them.

## What the host differential found, and what it changed

`tests/backports/host/coreml` records what a real Core ML answers for the same containers -- every
description, every constraint, `-isAllowedValue:` over a battery of values, the providers, the keys,
the options, the constants and a prediction per model -- and holds the port's own classes, compiled
under names of their own, to that record: **769 keys compared, none differing, none missing, five
recorded divergences**, over **eighteen mutants of the port, every one of them caught** -- on **all
ten containers `tools/coreml/make-models.lua` writes**, since 2026-10-03. It was nine of the ten: the
tenth, `vision_image`, was a container the release refused to compile, so its 48 description keys
were in the host's record and not in the port's, and the run passed on the other nine while printing
`compared 770 keys, 0 differ, 48 missing` on all ten. The container's own fault is fixed and named
under `vision_image` above; the run names the corpus it was given on its own first line. -- the run prints
`mutants: 18 run, 0 surviving`, so a harness that silently compiled none of them cannot report a
clean line, and a mutant is judged against the **port's own record** rather than the framework's,
which is what makes "a mutant changed nothing" a thing the run can see. Nine things the obvious
reading gets wrong came out of it, and each is now what the framework does:

- **A feature that fixes its shape has a shape constraint, of the *enumerated* kind.** Not none, and
  not a range: the enumerated kind with that one shape in it, and the size ranges filled in as well,
  one per dimension, each of length one. A caller therefore always gets a constraint, and a value of
  a shape that is not one of the shapes is refused rather than waved through.
- **`int64Value` of a double value is 0 and `doubleValue` of a whole number is 0.** The two are
  separate types and not two spellings of one; the accessors are how a caller tells which it has.
- **`stringValue` of a value that is not a string is nil, and so is `dictionaryValue` of one that is
  not a dictionary.** "Not an array" and "an array of no strings" are different facts.
- **An NSNumber is a whole number or a real by its own `objCType`:** `@3` is an Int64 value and
  `@3.0` is a Double value. A model that counts what it is given and one that multiplies it are told
  apart by that.
- **An NSArray handed to a feature provider becomes a sequence**, not a multi array: a sequence is
  what the specification types an input as when the model gives it no shape, and a bare array has
  none.
- **An object that cannot be a feature value at all -- an NSObject, an NSData, an NSURL -- becomes a
  value of the invalid type, and nothing is refused.** The provider is still made, and the caller can
  hand over the rest of its dictionary.
- **A dictionary handed to a feature provider may be nil, and the provider is made anyway**, with no
  names and no values.
- **`+featureValueWithDictionary:` keeps the objects it is given** rather than a copy of the numbers
  among them, and refuses nothing.
- **The metadata of a model that names none has all five keys**, the four named ones as empty strings
  and the creator-defined map as an empty dictionary. A caller can tell a model with no author from
  a model whose metadata is not there.
- **A sequence feature value is of the sequence type, not of its elements' type.** Measured: a value
  built over `+sequenceWithInt64Array:` reports 7 (Sequence) on a release with Core ML, and the
  sequence's own `type` is the kind of its elements, which is a different question.
- **`+[MLFeatureValue featureValueWithSequence:]` is the one constructor that was reporting the
  sequence's element type**, and so reported a value holding three numbers as an int64 value -- fixed,
  and the case that found it is in the differential.

Two more, from the same records:

- **The metadata, the class labels and the parameters of a model with none are empty, not nil** --
  except the two names a classifier answers under, which are nil when the model is not a classifier.
- **An answer takes the shape the model declared for it**, not the shape the layers happened to
  produce: a network whose layers leave a rank of one answers the 1x1x2 its description names, when
  the two hold the same number of elements.

And one that is a property of this host rather than of Core ML, which the check has to know about:
**this host's Core ML no longer reads an uncompiled `.mlmodel`** -- handed one it answers nil and says
to compile it. So the system run of the differential compiles each container with the framework's
own compiler and loads the bundle, and the port reads the same container uncompiled: two frameworks,
one model, in the two forms each of them reads.

## The archive round trip, and where it is better than the framework

`NSSecureCoding` is carried by MLFeatureValue, MLMultiArray and MLSequence, and the round trip is
a case in the differential: a value of every kind is archived, read back, and compared field by
field with what went in. **The review of the value types found the first version losing the value** --
the writer wrote the array and the string and the reader read the type alone -- and it is now
written and read whole, with the kind beside the type because a value of a real type that is
undefined and a value of that type that holds something are different facts.

**What the release does, measured on the caches this machine holds.** Core ML's own coder is not
there at all on the first releases that have the framework: neither `MLFeatureValue` nor
`MLMultiArray` carries `+supportsSecureCoding`, `encodeWithCoder:` or `initWithCoder:` in the
**iOS 11.0**, **12.0**, **16.0** or **18.0** dyld shared cache, read through
`tests/backports/tools/cache-methods.lua`. So on the releases an application met first, a feature
value cannot be archived at all.

Where Core ML *does* have a coder, the multi array value is the one case that does not come back:
a plain `+[NSKeyedUnarchiver unarchiveObjectWithData:]` raises
`NSInvalidUnarchiveOperationException`, `*** -[NSKeyedUnarchiver
_decodeCollectionOfClass:allowedClasses:forKey:]: This method only supports secure coding.`, because
Core ML reads the array through a private unarchiver selector that refuses a coder which does not
require secure coding. A **secure** unarchiver
(`+[NSKeyedArchiver archivedDataWithRootObject:requiringSecureCoding:error:]` and
`+[NSKeyedUnarchiver unarchivedObjectOfClass:fromData:error:]`) brings the array back on the
framework, and every other kind of value round trips on both paths.

**This port matches that.** The array is refused with the same exception name and the same reason
on the same condition, which is also the exact string the port's own Foundation raises from
`NSCoder+Collections14.m` when a collection is decoded from a coder of that kind -- the private
selector is not reachable from here and is not the sort of thing this port calls, so the refusal is
raised rather than taken. The case in `tests/backports/host/coreml` records both paths, so a change
in either is caught: 722 keys compared, none differing, five recorded divergences on the nine
containers named above, and the two builds agree on every one of them.

An **image** feature value does not round trip on either: a pixel buffer is not something a secure
archive carries, so the value comes back of the image type and undefined, and the facts say so.

## What the port does not do at all

- **A compiled `.mlmodelc` bundle.** The bundle's `coremldata.bin` is Apple's compiled storage
  container, not the specification's own protobuf message: it does not parse as a `Model` and
  the format is private. A `.mlmodel` file is read and run; a bundle whose `coremldata.bin` is
  a bare `Model` message is read and run; a bundle in the compiled storage form fails the
  load with a line saying so.
- **The kinds of model that are not the neural network, the tree ensemble, the GLM and the
  preprocessing models**: support vector machines, k-nearest neighbours, item similarity,
  nearest neighbours, the `mlProgram` (MIL text) models, and the linked-model and custom-model
  forms. Each is refused by name.

## Files

| File | Holds |
| --- | --- |
| `CharonMLSchema.h`, `CharonMLSchema.c`, `CharonMLSchema.inc` | the specification as a table, and the lookup over it |
| `CharonMLProto.h`, `CharonMLProto.c` | the wire format, and the document it builds |
| `CharonMLValue.h`, `CharonMLValue.c` | a feature's value: a number, a string, an array, a dictionary |
| `CharonMLTensor.h`, `CharonMLTensor.c` | a float tensor and the shape arithmetic the layers need |
| `CharonMLModel.h`, `CharonMLModel.c` | the model: its kind, its description, its class labels, its loading |
| `CharonMLLayers.h`, `CharonMLLayers.c`, `CharonMLLayerKinds.h`, `CharonMLLayerKinds.c` | the layers, dispatched by the field number of the specification's layer oneof |
| `CharonMLPredict.h`, `CharonMLPredict.c` | the run: pipelines, networks, trees, GLMs, preprocessing, and the answers |
| `tools/coreml/gen-schema.lua` | the generator for the table |
| `tools/coreml/make-models.lua` | the containers, and the host's own answers for them |
| `tools/coreml/ml-dump.c`, `tools/coreml/predict-main.c` | the two harnesses the checks drive |
| `tools/coreml/check-reader.sh`, `tools/coreml/check-predict.sh` | the two checks |

## The Objective-C surface this group carries

Eight classes from the previous delivery, and what an application can do with them:

- **`MLMultiArray`** — a typed, strided array of numbers. Every element type the specification
  names, its three initialisers (a shape, a shape with strides, and a caller's buffer with the
  block that gives it back), the deprecated `dataPointer`, the two addressing forms the
  specification declares (a linear index and an array of numbers), `NSSecureCoding`, and
  `+multiArrayByConcatenatingMultiArrays:alongAxis:dataType:`.
- **`MLFeatureValue`** — one value of one feature: every constructor the specification declares
  that this port can build, every accessor, `isEqualToFeatureValue:`, `NSCopying` and
  `NSSecureCoding`.
- **`MLSequence`** — an ordered list of numbers or of strings, which is what a Core ML sequence
  is, with the three constructors and the two accessors the specification declares.

`MLFeatureValue`'s array is a window on the `MLMultiArray`'s own buffer rather than a copy, so
an application that writes through the array it handed over sees the change in the model, which
is what passing an `MLMultiArray` to a model means.

### The model surface, and the two protocols it needs

The second delivery carries the surface an application hands a model through: what the model says
about itself, what it takes, what it answers, and the two ways a caller gives it values.

- **`MLFeatureDescription`** and the eight constraints Core ML declares around it --
  `MLMultiArrayConstraint`, `MLMultiArrayShapeConstraint`, `MLImageConstraint`,
  `MLImageSizeConstraint`, `MLImageSize`, `MLDictionaryConstraint`, `MLSequenceConstraint` and
  `MLNumericConstraint`. Every one is built from the specification's own fields: a feature's name,
  kind, optionality, element type, shape, size range, the set of shapes or of sizes, and a
  sequence's element kind and count range. `-isAllowedValue:` is the model's own check, written out
  rule by rule above.
- **`MLDictionaryFeatureProvider`** and **`MLArrayBatchProvider`**, with the two protocols
  `MLFeatureProvider` and `MLBatchProvider` between them.
- **`MLModel`**, **`MLModelDescription`**, **`MLModelConfiguration`**, **`MLPredictionOptions`**
  and **`MLModelAsset`**: load from a URL or from bytes, predict from one provider or from a
  batch, answer the description, the metadata, the class labels and the parameters the container
  carries, take the options of one run, and compile.
- **`MLKey`**, **`MLParameterKey`**, **`MLMetricKey`** and **`MLParameterDescription`**: the keys
  a model's parameters and metrics are named by, and what one parameter is.
- **The eight exported strings**: `MLModelErrorDomain` and the five metadata keys, the two image
  option keys. Their values were read out of a real Core ML on this host, and the domain is
  `com.apple.CoreML` -- not the framework's name.

Four things in that surface are worth writing down, because the obvious reading of each is wrong:

- **The Core ML error codes are not consecutive.** `MLModelError` skips 2, and the numbers are
  `Generic` 0, `FeatureType` 1, `IO` 3, `CustomLayer` 4, `CustomModel` 5, `Update` 6,
  `Parameters` 7, `DecryptionKeyFetch` 8, `Decryption` 9, `ModelCollection` 10. The bridge's own
  defines were wrong until they were read out of a real framework: a load that fails is `IO`, a
  value of the wrong type for a feature is `FeatureType`, a parameter the model does not have is
  `Parameters`, and a model this port cannot run is `Generic`, because none of the others
  describes it.
- **A protocol has to be a definition, not a declaration.** A class that conforms to
  `MLFeatureProvider` names a protocol object at run time, and on a release with no Core ML there
  is nothing to define it but this port. A protocol the compiler has already seen declared is a
  *reference*, so `MLFeatureProvider.m` declares both protocols before it imports Core ML's
  header, and the conforming classes are in the same file because a protocol nothing in a
  translation unit uses is dropped from it. The objects are then hidden at the link, the way
  Apple's own frameworks keep theirs, since a program reaches a protocol by name and not by
  symbol.
- **`MLMultiArrayConstraint.dataType` is zero when the model names no element type.** Core ML's
  enumeration has no case for "none": every case of it is a real width, so zero is unambiguous
  and a constraint that carries it accepts the array whatever its element type is.
- **`+[MLModel compileModelAtURL:error:]` answers a URL, not a model.** It writes the
  specification's own message into a bundle of the shape a compiled model has, under a name of its
  own in the temporary directory, and answers where it put it. A bundle written this way is read
  and run by this port; Apple's own compiled storage form is private and is not read, as above.

## What this group does not carry, and why

The rest of Core ML's Objective-C surface is **not** in this delivery:

- **The state API of iOS 18** -- `-[MLModel newState]`, the three predictions that take a state,
  `MLFeatureDescription.stateConstraint` and `MLModelDescription.stateDescriptionsByName`. A state
  is a recurrent model's own carry between calls, and the recurrent layers that would carry it are
  refused by name above, so there is no state for any of them to answer about.
- **`MLModel.availableComputeDevices`** and the compute-device family of iOS 17. The set names the
  units a model may run on, and this release has one of them: no Metal driver on iOS 6 and no
  neural engine at all.
- **`MLModelConfiguration.optimizationHints`** and **`MLModelConfiguration.functionName`**: advice
  to a compiler, and the entry point of a model of a program. This port compiles no model -- it
  reads a container and runs it -- and refuses the `mlProgram` form by name.
- **The initialisers Core ML declares `NS_UNAVAILABLE`**: a key, a model asset and an image
  constraint have none, because a model builds them and an application only reads them. Not
  implementing one is what `NS_UNAVAILABLE` means -- and it is a COMPILE-time annotation, not a
  run-time refusal, which is measured below rather than assumed.
- **The image constructors** (`+featureValueWithCGImage:`, `+featureValueWithImageAtURL:` and
  their variants). `+featureValueWithPixelBuffer:` is carried and takes a 32-bit BGRA or ARGB
  buffer; a CGImage or a URL is a decode that belongs with the image handling, and the port
  answers the undefined value of the image type rather than an image it did not decode.
- **The compute-plan, the update-task, the model-structure and the custom-model classes**, and
  the kinds of model the interpreter refuses: support vector machines, k-nearest neighbours,
  item similarity, MIL (`mlProgram`) models, linked and custom models. Each is refused by name
  in `facts/CoreML/CoreML.md`.

## `NS_UNAVAILABLE` is a compile-time annotation, not a run-time refusal

Measured 2026-10-01 on this host's own Core ML, by `tests/backports/host/coreml/probe-unavailable.m`:

```
sdk=$(xcrun --show-sdk-path)
xcrun clang -fobjc-arc -w -framework Foundation -framework CoreML \
    -F"$sdk/System/Library/Frameworks" probe-unavailable.m -o probe-unavailable && ./probe-unavailable
```

The send goes through `objc_msgSend`, because a bracketed call does not compile against a header
that declares the initialiser unavailable -- reproducing that refusal is what the annotation is,
and the probe has to get past it to measure what the framework does at run time.

```
MLKey: NSClassFromString -> a class
  superclass NSObject
  +new     responds=1  answered *nil description* (name=(null) scope=(null))
  -init    responds=1  answered *nil description* (name=(null) scope=(null))
MLMetricKey: NSClassFromString -> a class
  superclass MLKey
  +new     responds=1  answered *nil description* (name=(null) scope=(null))
  -init    responds=1  answered *nil description* (name=(null) scope=(null))
MLParameterKey: NSClassFromString -> a class
  superclass MLKey
  +new     responds=1  answered *nil description* (name=(null) scope=(null))
  -init    responds=1  answered *nil description* (name=(null) scope=(null))
```

Every one of them **answers**: `responds=1`, and the object that comes back is a real instance of
the class, built by `NSObject`'s own implementation, which the class inherits and does not override.
So a program that sends `+[MLKey new]` by name does **not** get `doesNotRecognizeSelector` -- the
claim an earlier version of these rows made, and it was wrong.

What it gets instead is the thing the annotation exists to warn about. The key answers `name` nil
and `scope` nil, and a key is *only* a name and a scope: `MLKey`'s own `-isEqual:` compares those
two, and a model's parameter dictionary is keyed by them, so a key with neither matches nothing and
is equal to no key the framework or this port ever hands out. That is why Apple marks the
initialiser unavailable -- not because the send fails, and the distinction is the whole difference
between a compile error an author never sees and a nil-valued object an application cannot tell
from a real one.

So the rows are `absent`, and their effect names what a caller actually receives.

The same run also answers for the update family and the image constructors, which is the
`responds=1` half of why those rows are the RELEASE's absence rather than the port's:

```
MLTask: NSClassFromString -> a class
  superclass NSObject
  +new     responds=1  answered <MLTask: 0x...>
  -init    responds=1  answered <MLTask: 0x...>
MLUpdateTask: NSClassFromString -> a class
  superclass MLTask
  +new     responds=1  answered updatableModelURL: (null)
trainingData: (null)  count: 0
progressHandlers: (null)
state: Task Suspended
MLUpdateContext: NSClassFromString -> a class
MLUpdateProgressHandlers: NSClassFromString -> a class
MLWritable: NSProtocolFromString -> a protocol
MLFeatureValue +featureValueWithCGImage:constraint:options:error: responds=1
MLFeatureValue +featureValueWithImageAtURL:constraint:options:error: responds=1
```

The `0x...` stands for an address, which is a run's own and differs every run; what the lines show
is that each name resolves and each initialiser answers. `MLUpdateContext` and
`MLUpdateProgressHandlers` print their superclass and initialisers between the lines quoted here
and are left out so the block stays short -- the run they come from is the one above and prints all
of them.

And the release side, from the two armv7 caches this package deploys on
(`CHARON_ROOT="$PWD" xmake l tools/corpus/cache-census.lua ML 6.1.3 4.3`, the same reader
`registry/CoreNFC/ios11.json` cites):

| release | images naming ML | classes | of which `ML*` | protocols | of which `ML*` |
| --- | --- | --- | --- | --- | --- |
| 6.1.3 armv7 | 0 of 524 | 11378 | 65 | 1171 | 3 |
| 4.3 armv7 | 0 of 354 | 7187 | 76 | 564 | 2 |

Every one of those 65 and 76 `ML*` names is MediaLibrary's (`ML3Album`, `ML3Track`,
`MLMusicLibrary`, `MLSQLiteConnection`) or Photos' (`MLPhotoLibrary`), never Core ML's: **0 of 524
and 0 of 354 images name ML at all**, so no Core ML framework is in either cache. The same reader
finds 245 `ML*` classes and 23 `ML*` protocols in 12.0's arm64 cache, among them `MLArrayBatchProvider`,
`MLFeatureValue` and `MLModel`, so a zero on the two armv7 rungs is the release's and not the
reader's. `MLTask`, `MLUpdateTask`, `MLUpdateContext`, `MLUpdateProgressHandlers`, `MLWritable`,
`MLKey`, `MLMetricKey` and `MLParameterKey` all read 16.0 from `tools/cache-index/first-rung.lua`:
the held ladder has a hole between 12.0 and 16.0, so a 13.0 name's first held rung is 16.0.

## Which translation units emit a protocol's metadata object, and what that means for the duplicate

The open crutch entry "Core ML's `MLFeatureProvider` protocol object is defined by two objects" names its
native fix as taking this whole folder off Apple's umbrella, because `MLFeatureProvider.m` "must see
Apple's definition, so it must import `<CoreML/CoreML.h>`". **Measured, that premise does not hold**: what
makes a translation unit emit `__OBJC_PROTOCOL_$_<name>` is not what it imports but whether it *conforms to*
the protocol or names it in `@protocol()`. Three objects compiled for armv7-apple-ios6.0 against the SDK of
iOS 16.4, each reading `#import <CoreML/MLFeatureProvider.h>` and nothing else, and each `nm -g`-ed:

| the object | `__OBJC_PROTOCOL_$_MLFeatureProvider` |
| --- | --- |
| imports the header and declares nothing that uses the protocol | **0** symbols |
| imports the header and uses `id<MLFeatureProvider>` and `@protocol(MLFeatureProvider)` | **0** symbols |
| imports the header and declares `@interface MyProvider : NSObject <MLFeatureProvider>` | **1** symbol |

So Core ML's headers being modular or not is beside the point: `MLFeatureProvider.m` emits the object
because `MLDictionaryFeatureProvider` **conforms** to `MLFeatureProvider`, and it would emit it from
`<CoreML/MLFeatureProvider.h>` exactly as it does from `<CoreML/CoreML.h>`. Taking the folder off the
umbrella therefore leaves the duplicate in place, and the seven files that use `MLFeatureType` would still
need that enum from one place or the other - which is the AppIntents entry's "two spellings of one type"
again.

The other definer is deliberate and is in the build, not in this folder. `protocol_sources()` in
`modules/apple/backports.lua` writes, for each `implemented` protocol row, a generated
`<Library>Protocols<release>.m` whose whole body is `(void)@protocol(Name);` inside a function marked
`used`, so that clang emits the object into that object - which is what makes `objc_getProtocol` and
`conformsToProtocol:` answer for a protocol no release's own dylib carries. `MLFeatureProvider` has such a
row (`registry/CoreML/ios11.json`, `implemented`, `11.0`) and `MLBatchProvider` has one too
(`registry/CoreML/absent_CoreML.json`, `implemented`, `12.0`), which is the same pair of definers the entry
describes for the second protocol.

**What would remove the duplicate, then, is in `protocol_sources()` and not in this folder**: force the
object only for a protocol no other object of the same library already defines. That is the build module's
own change and not this directory's, and it is the coordinator's to make.
