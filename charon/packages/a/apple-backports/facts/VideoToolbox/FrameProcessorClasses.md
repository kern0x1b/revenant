# The VideoToolbox frame processor: 17 classes and the members they carry

Ranks of `coordination/corpus/band-frameworks.tsv`: VideoToolbox, LOAD-FAIL. iOS 6.1.3 carries
`VideoToolbox.framework` at `/System/Library/Frameworks` with the whole compression and
decompression session API on the armv7 cache ladder since 3.1.3. It carries none of the
seventeen frame-processor classes, which SDK 26.2 marks `API_AVAILABLE(ios(26.0))` and which
the 6.1.3 cache ladder does not export at any release.

The measurement behind that, repeated rather than assumed: `objc-inventory.lua` and `dump-cache.lua`
over `$HOME/.charon/dyld/6.1.3/dyld_shared_cache_armv7` find no `VTFrameProcessor` class and no
`VTFrameProcessor*` symbol, and `tools/corpus/cache-index` gives the same zero on 4.3. The port's own
`VTFrameProcessor.m` says so at the head of the file, with the same commands.

## What the port does with a class the release does not have

Each class is a value object: an initialiser puts its arguments in a keyed store under the
property the SDK declares for each of them, and each accessor answers from that store. A
class property's value is kept on the class, because a class property's value belongs to the
type rather than to an instance. A `CVPixelBufferRef` is kept in an ivar and retained, because
the SDK declares `@property(nonatomic, readonly) CVPixelBufferRef buffer;` with no ownership
annotation. A `CMTime` or `CMVideoDimensions` is an `NSValue` box.

## The one class property that is an answer and not a store read

`+isSupported` on each of the seven configuration classes answers `NO`, and it is written as a
literal `return NO` rather than as a read of the class store, because nothing ever writes that key:
a store nothing writes would be `NO` by accident instead of by measurement. The measurement is in
the source at each of the seven. SDK 26.2 documents the property as "whether the SYSTEM SUPPORTS
this processor", the effects are motion estimation, frame interpolation, super resolution and
temporal noise filtering, and no armv7 device has the hardware they need.

`+supportedScaleFactors` and `+[VTLowLatencySuperResolutionScalerConfiguration
supportedScaleFactorsForFrameWidth:frameHeight:]` answer the empty array, which is what the header
asks for in so many words: "or an empty list if the processor doesn't support the dimensions".

## What the host can and cannot be the oracle for

The host is an M4 Pro, so it HAS the Neural Engine these processors need. Measured
2026-10-03 with `tests/backports/host/videotoolbox-frameprocessor`:

| question | host | this release |
| --- | --- | --- |
| `+[VTMotionBlurConfiguration isSupported]` | **1** | NO, and the release measurement above is why |
| `+[VTFrameProcessorFrame new]`, `-init` | both answer, and `frameWidth` reads 0 | the same, from NSObject |
| `VTFrameProcessorErrorDomain` | `"VTFrameProcessorErrorDomain"` | the same string, measured from the host by `dlsym` |

So the host is the oracle for the SHAPE of the family - which selectors exist, what `NS_UNAVAILABLE`
does at run time, what the domain string is - and it is NOT the oracle for the `supported` value,
which is why that one is measured on the release instead. That distinction is the reason the two
halves of the check exist separately.

## What is NOT carried, and why

`processorSupported` is declared on three of the classes and the SDK marks it
`API_DEPRECATED_WITH_REPLACEMENT("isSupported") API_UNAVAILABLE(ios)`, so it is not iOS surface
and carrying it would collide with the host's own header on the armv7 build. All three have no
registry row: a row would name an API the release does not have, and the host check asserts there is none.

`-init` and `+new` on the sixteen classes that declare `- (instancetype) init NS_UNAVAILABLE;` are
recorded `implemented`, one row each, by inheritance from NSObject, and the row is decided by a MEASUREMENT
and not by the annotation. An `absent` row would tell a caller the selector is not there, and it is there:
`respondsToSelector:` answers YES on the host and on the port alike.

## What Apple's own classes do, measured

`class_copyMethodList` over the host's class, then `+new` and `-init` sent through `objc_msgSend` with the
exceptions caught (a bracketed call will not compile against the annotation, so the runtime is the only
way to ask). 2026-10-03, on this machine's own VideoToolbox:

```
VTFrameProcessorFrame                          own -init: no (inherited) | +new answers | -init answers | buffer=0x0
VTFrameRateConversionConfiguration             own -init: no (inherited) | +new answers | -init answers | frameWidth=0
VTSuperResolutionScalerConfiguration           own -init: no (inherited) | +new answers | -init answers | frameWidth=0
... the same line for all sixteen, and VTFrameProcessor itself
```

Apple implements NO `-init` of its own on any of them: the method is NSObject's, inherited. Both
selectors answer, and **nothing raises** - a frame reads `buffer` NULL, a configuration reads
`frameWidth` 0. So the class's own method list does not gain an `-init` in the port either, because
adding one would make the port's class differ from Apple's in exactly the way that matters: which class
owns the method. This is CoreML's shape, not SensorKit's: `registry/CoreML/absent_CoreML.json` measures
`+new responds=1` and "answers an MLKey whose name and scope are both nil", while SensorKit's
`SRSensorReader -init` raises because Apple implements it to raise.

`VTFrameProcessor` is the seventeenth and looks like the exception, because its `VTFrameProcessor.h:51`
declares `- (instancetype) init;` with NO annotation where the other sixteen write `NS_UNAVAILABLE`. **The
annotation was never what decides these rows, and the host measurement says the same thing here:**
`class_copyMethodList` over the host's own `VTFrameProcessor` reads no own `-init` either, so it too
inherits NSObject's. So the port defines none, and `-init` is recorded `implemented` by inheritance with that measurement - the
same answer as the other sixteen, reached the same way. `-[VTFrameProcessor startSessionWithConfiguration:error:]`
on such an object answers NO with `VTFrameProcessorInitializationFailed` exactly as before.

`processorSupported` is declared on three of the classes and the SDK marks it
`API_DEPRECATED_WITH_REPLACEMENT("isSupported") API_UNAVAILABLE(ios)`, so it is not iOS surface
and carrying it would collide with the host's own header on the armv7 build. All three have no
registry row: a row would name an API the release does not have, and the host check asserts there is none.

## The nine VTFrameProcessor methods, and what each answers

All nine are carried now, each answering what SDK 26.2 documents for a device that does not have
the hardware, which is the port's contract for hardware it cannot have:

| member | answer |
| --- | --- |
| `-init` | inherited from NSObject, as on Apple's class: the port defines none, so the port's must not either; `+new` reaches NSObject's |
| `-startSessionWithConfiguration:error:` | NO with `VTFrameProcessorInitializationFailed`, or `VTFrameProcessorInvalidParameterError` for a nil configuration |
| `-processWithParameters:error:` | NO with `VTFrameProcessorSessionNotStarted`, or `VTFrameProcessorInvalidParameterError` for nil parameters |
| `-processWithParameters:completionHandler:` | the completion RUNS once, with the parameters and that same error |
| `-processWithParameters:frameOutputHandler:` | the handler runs once with `kCMTimeInvalid`, `YES` and that same error |
| `-processWithCommandBuffer:parameters:` | nothing added to the buffer, nothing reported - see below |
| `-endSession` | a no-op, because no session was ever started |
| `+supportedScaleFactorsForFrameWidth:frameHeight:` | the empty array |
| `-downloadConfigurationModelWithCompletionHandler:` | the completion runs once with `VTFrameProcessorAssetDownloadFailed`, and no request is made |

Both block-taking methods RUN their block. That is not politeness: SDK 26.2 says of the first one
that "This completion handler is called when frame processing is completed", and a completion that
never runs is a hang a caller cannot diagnose.

`-processWithCommandBuffer:parameters:` is the one member with no error channel, and that is
Apple's design rather than the port's choice: the method returns `void`, takes no `NSError`, and
SDK 26.2 says only "Performs effects in a Metal command buffer". It is written up in
`coordination/crutches.md`; the port does not invent a channel to report through.

## The members per class

### VTFrameProcessor

`-init`, `-startSessionWithConfiguration:error:`, `-processWithParameters:error:`,
`-processWithParameters:completionHandler:`, `-processWithParameters:frameOutputHandler:`,
`-processWithCommandBuffer:parameters:`, `-endSession` - the nine above. Nothing else: the class body
in `VTFrameProcessor.h` is seven methods and no properties.

### VTFrameProcessorFrame

`-initWithBuffer:presentationTimeStamp:` builds it; `-buffer` and `-presentationTimeStamp` read it
back. `-init` and `+new` are `implemented` by inheritance (NS_UNAVAILABLE).

### VTFrameProcessorOpticalFlow

`-initWithForwardFlow:backwardFlow:` builds it; `-forwardFlow` and `-backwardFlow` read it back.
`-init` and `+new` are `implemented` by inheritance (NS_UNAVAILABLE).

### VTFrameRateConversionConfiguration

`-initWithFrameWidth:frameHeight:usePrecomputedFlow:qualityPrioritization:revision:` builds it.
`+isSupported`, `+maximumDimensions`, `+minimumDimensions` and the five protocol instance
properties are the class store's; `+defaultRevision` and `+supportedRevisions` are the class's own.
`-init` and `+new` are `implemented` by inheritance, and `processorSupported` has no row: the SDK marks it `API_UNAVAILABLE(ios)`, so it is not iOS API.

### VTFrameRateConversionParameters

`-initWithSourceFrame:nextFrame:opticalFlow:interpolationPhase:submissionMode:destinationFrames:`
builds it. `-sourceFrame`, `-destinationFrame` and `-destinationFrames` come from the
`VTFrameProcessorParameters` protocol; `-nextFrame`, `-opticalFlow`, `-interpolationPhase` and
`-submissionMode` are its own. `-init` and `+new` are `implemented` by inheritance.

### VTLowLatencyFrameInterpolationConfiguration

Three initialisers in SDK 26.2 (`frameHeight:numberOfInterpolatedFrames:`,
`frameHeight:spatialScaleFactor:`, and the two-argument one at line 57 of its header). `+isSupported`
answers NO; `-numberOfInterpolatedFrames` and `-spatialScaleFactor` are its own. `-init`, `+new` and
`processorSupported` is not iOS API (`API_UNAVAILABLE(ios)`) and has no row.

### VTLowLatencyFrameInterpolationParameters

`-initWithSourceFrame:previousFrame:interpolationPhase:destinationFrames:` builds it;
`-previousFrame` and `-interpolationPhase` are its own. `-init` and `+new` are `implemented` by inheritance.

### VTLowLatencySuperResolutionScalerConfiguration

`-initWithFrameWidth:frameHeight:scaleFactor:` builds it. `+isSupported` answers NO,
`+supportedScaleFactorsForFrameWidth:frameHeight:` answers the empty array. `-init` and `+new` are
`implemented` by inheritance.

### VTLowLatencySuperResolutionScalerParameters

`-initWithSourceFrame:destinationFrame:` builds it. `-init` and `+new` are `implemented` by inheritance.

### VTMotionBlurConfiguration

Two initialisers, the five-argument one and the six-argument one that adds `revision:`.
`+isSupported` answers NO. `-init` and `+new` are `implemented` by inheritance, and `processorSupported` has no row: the SDK marks it `API_UNAVAILABLE(ios)`, so it is not iOS API.

### VTMotionBlurParameters

`-initWithSourceFrame:interpolationPhase:submissionMode:destinationFrame:` builds it. `-init` and
`+new` are `implemented` by inheritance.

### VTOpticalFlowConfiguration

`-initWithFrameWidth:frameHeight:qualityPrioritization:revision:` builds it. `+isSupported` answers
NO. `-init` and `+new` are `implemented` by inheritance, and `processorSupported` has no row: the SDK marks it `API_UNAVAILABLE(ios)`, so it is not iOS API.

### VTOpticalFlowParameters

`-initWithSourceFrame:nextFrame:opticalFlow:submissionMode:destinationOpticalFlow:` builds it.
`-init` and `+new` are `implemented` by inheritance.

### VTSuperResolutionScalerConfiguration

`-initWithFrameWidth:frameHeight:scaleFactor:inputType:usePrecomputedFlow:qualityPrioritization:revision:`
builds it. `+isSupported` answers NO, `+supportedScaleFactors` and
`+supportedScaleFactorsForFrameWidth:frameHeight:`'s sibling answer empty, and
`-downloadConfigurationModelWithCompletionHandler:` completes with
`VTFrameProcessorAssetDownloadFailed`. `-usesPrecomputedFlow` is `precomputedFlow`'s getter, as the
SDK's own `getter=usesPrecomputedFlow` writes it. `-init` and `+new` are `implemented` by inheritance.

### VTSuperResolutionScalerParameters

`-initWithSourceFrame:nextFrame:opticalFlow:submissionMode:destinationFrame:` builds it. `-init` and
`+new` are `implemented` by inheritance.

### VTTemporalNoiseFilterConfiguration

`-initWithFrameWidth:frameHeight:sourcePixelFormat:` builds it. `+isSupported` answers NO.
`+supportedSourcePixelFormats` is its own. `-init` and `+new` are `implemented` by inheritance.

### VTTemporalNoiseFilterParameters

`-initWithSourceFrame:destinationFrames:` builds it. `-init` and `+new` are `implemented` by inheritance.

## The two protocols' eleven properties, and the eight renamed getters

Eleven of this family's property rows name a PROTOCOL as their owner rather than a class - the eight
`VTFrameProcessorConfiguration` properties and the three `VTFrameProcessorParameters` ones. Every
conforming class in this library carries the accessor, and the protocols themselves carry the selectors
in the built library (measured with `tools/corpus/objc-inventory.lua` over the 6.1.3 gate's
`libVideoToolboxBackports.dylib`, armv7):

```
protocol	VTFrameProcessorConfiguration
  instance	-destinationPixelBufferAttributes,-frameSupportedPixelFormats,-nextFrameCount,-previousFrameCount,-sourcePixelBufferAttributes
  class		-isSupported,-maximumDimensions,-minimumDimensions
protocol	VTFrameProcessorParameters
  instance	-destinationFrame,-destinationFrames,-sourceFrame
```

so every one of the eleven rows is carried and every one has an `implemented` registry row.

**The two protocols need rows of their own, and an earlier version of this file said they did not.** That
was wrong and it cost a 6.1.3 gate failure. `check_registry` (modules/apple/backports.lua) answers a member
row whose owner is no class **only** through the owner's protocol row, so with the eleven property rows
`implemented` and no protocol rows, the gate read all eleven as "listed as implemented, but nothing of that
name is built" (gate land-w2, 2026-10-03). Both protocols now carry an `implemented` row of `kind:
protocol`, and `CharonVideoToolboxProtocols.h` is the header the generated protocol source imports.

The lesson is the one this family has now produced twice: I read the tool's source, concluded a row was not
needed, wrote the conclusion into the facts page, and the tool disagreed. What I should have done was run the
gate's own check against the registry and watched it fail, rather than reasoning about what the check would
say. A claim about a checker's behaviour is a measurement like any other.

Eight rows are declared with the SDK's own renamed accessor - `getter=isSupported` on seven
configuration classes and `getter=usesPrecomputedFlow` on `precomputedFlow` - so the selectors a class
must carry are `+isSupported` and `-usesPrecomputedFlow`, and the built library's class set for each
carries `-isSupported` and none carries `-supported`. Every one of the eight has an `implemented`
registry row naming the selector the SDK's own attribute names, and no second accessor is added
anywhere to satisfy a spelling.

## A renamed getter, and what the ledger reads

Seven of the properties are declared `@property (class, nonatomic, readonly, getter=isSupported)
BOOL supported;` and one is `getter=usesPrecomputedFlow`, so the selectors a class must carry are
`+isSupported` and `-usesPrecomputedFlow` - not `+supported` and not `-precomputedFlow`. The port
carries exactly the accessors the SDK's own attributes name, and no second accessor is added to
satisfy a spelling: `api-ledger.py`'s `classify_property` builds its getter as `-` + the property
name and does not read `getter=`, so it reports these rows `missing` on a port that carries them. That
is a defect in the measurement, reported to the coordinator and not worked around here.