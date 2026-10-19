# The multi-image and options decode variants: what each one can do here, and the one that cannot be written

Six rows of SDK 26.2, none of which any release this port builds exports. This page records the ladder, the
contracts, the four that are carried, and the two that are not written at all - with the mechanical reason.

## The ladder (tools/corpus/dump-cache.lua over the 4.3 armv7 cache, read-only, and v-audio's 6.1.3 armv7 dump, 2026-10-03)

```
_VTDecompressionSessionDecodeFrameWithMultiImageCapableOutputHandler   4.3=0  6.1.3=0
_VTDecompressionSessionSetMultiImageCallback                           4.3=0  6.1.3=0
_VTCompressionSessionEncodeMultiImageFrame                             4.3=0  6.1.3=0
_VTCompressionSessionEncodeMultiImageFrameWithOutputHandler            4.3=0  6.1.3=0
_VTDecompressionSessionDecodeFrameWithOptions                         4.3=0  6.1.3=0
_VTDecompressionSessionDecodeFrameWithOptionsAndOutputHandler         4.3=0  6.1.3=0
_kVTDecodeFrameOptionKey_  (any key)                                   4.3=0  6.1.3=0
_VTDecompressionSessionDecodeFrame                                     4.3=1  6.1.3=1
_VTCompressionSessionEncodeFrame                                       4.3=1  6.1.3=1
_VTCompressionSessionEncodeFrameWithOutputHandler                      4.3=0  6.1.3=0
```

The 16.4 SDK declares none of the six either; its `VTDecompressionSession.h` and `VTCompressionSession.h`
name them nowhere, so all six are declared in `CharonVideoToolbox.h`, transcribed from SDK 26.2.

## The four that are carried, and the refusal each one earns

| row | answer | why the release cannot do it |
| --- | --- | --- |
| `VTDecompressionSessionSetMultiImageCallback` | `kVTVideoDecoderNotAvailableNowErr` (-12913) | the callback is reached only "when the video decoder outputs CMTaggedBufferGroups"; the release's own decode callback ends at `CVImageBuffer imageBuffer` (16.4 SDK `VTDecompressionSession.h:85-92`), so a callback stored here could never be called |
| `VTDecompressionSessionDecodeFrameWithMultiImageCapableOutputHandler` | -12913 | the handler receives a `CMTaggedBufferGroupRef`, and the release's callback has no parameter that could receive one; the header itself says the block "will not be called" if the call returns an error |
| `VTCompressionSessionEncodeMultiImageFrame` | `kVTVideoEncoderNotAvailableNowErr` (-12915) | the multi-image encode's SOURCE is a `CMTaggedBufferGroupRef`; the release's encode entry point takes a `CVImageBuffer`, so there is no release function that reads one |
| `VTCompressionSessionEncodeMultiImageFrameWithOutputHandler` | -12915 | the same source, and a block the header says "may be called asynchronously, on a different thread from the one that calls" it - a promise that needs an encode to run it after |

**BOTH OF THOSE REASONINGS ARE ABOUT A RELEASE THAT HAS THE FUNCTION, and the host measurement below refuses
three of the four with `kVTParameterErr` (-12902) rather than the -12913 and -12915 these rows name - so the
codes in the rows are wrong, not only the reasoning.** The reasoning is kept because the shape of the argument
is what produced it and a reader comparing a row with the measurement needs to see both.

`CMTaggedBufferGroup` arrived with iOS 14 and no release the port builds has it. A variant that accepted its
argument and did nothing with it would be the silent fake the brief forbids; these refuse with the release's
own codes, before any work, and each `infoFlagsOut` is set to 0 with the file saying why - the two flags the
header names are set by a decoder or encoder as it runs, and nothing ran.

## The two options variants: WRITTEN, over the release's own decode

They were owed here for two stated reasons and **both reasons are gone**, so this section is now a record of
why they changed rather than of why they are missing.

**The arity reason was backwards and is retracted.** This page said the 4.3 release's
`VTDecompressionSessionDecodeFrame` takes four arguments and that the port's five-argument forward would "call
a four-argument function with five arguments at 4.3". On ARM an EXTRA argument is harmless and a MISSING one
is not, so calling the 16.4 SDK's five-parameter form at 4.3 is safe. The `API_AVAILABLE(macosx(10.8),
ios(8.0), tvos(10.2))` annotation on `infoFlagsOut` says when the symbol became public, not how many arguments
the 4.3 code reads.

**The options reason pointed at the wrong thing.** This page said "there is no dictionary to ask, so a caller's
options cannot be passed anywhere" - and the measurement shows the opposite: the dictionary can be passed and
is dropped. `VTDecompressionSessionDecodeFrameWithOptions` is written as the release's own
`VTDecompressionSessionDecodeFrame` with the same flags, the same `sourceFrameRefCon` and the same
`infoFlagsOut` forwarded, and with `frameOptions` not even looked at. `...AndOutputHandler` answers
`kVTParameterErr` for all five dictionaries, with the block neither retained nor called and `infoFlagsOut` not
written.

The two rows' registry entries are in `registry/VideoToolbox/ios18.json`.

## What the HOST answers, measured with a real H264 sample

A NULL sample buffer makes every variant answer the same -12902 as plain `DecodeFrame` and distinguishes
nothing, so the sample is made the only way that works: one `CVPixelBuffer` encoded with an H264
`VTCompressionSession`, and the `CMSampleBuffer` the callback hands over, retained (the callback's buffer is
released when it returns). Measured on this Mac, 2026-10-03, with a 221-byte `avc1` sample at 64x48.

```
== a real H264 sample
  compression session (H264 64x48) -> 0 with a session
  EncodeFrame -> 0
  encode callback: calls=1 status=0 flags=0x1 sample=yes
  the sample: 221 bytes, format avc1, 64x48
== the multi-image family, on sessions that really exist
  decompression session -> 0 with a session
  DecodeFrameWithMultiImageCapableOutputHandler -> -12902  handler calls=0 infoFlags=0x5a5a5a5a
  DecodeFrame (the control)                  -> 0        single-image calls=1 infoFlags=0
  CMTagCollectionCreate(NULL, 0) -> 0 with a collection
  CMTaggedBufferGroupCreate(1 buffer) -> 0 with a group  [matches=1]
  EncodeMultiImageFrame(real group)            -> 0        encode callbacks=2 infoFlags=0x1
  EncodeMultiImageFrameWithOutputHandler(real)  -> -12902  encode callbacks=0 infoFlags=0x1
== the options pair, with the same real buffer
  NULL options                 DecodeFrame=0 WithOptions=0 handlerCalls=2 infoFlags=0 ...AndOutputHandler=-12902
  empty options                DecodeFrame=0 WithOptions=0 handlerCalls=2 infoFlags=0 ...AndOutputHandler=-12902
  an unknown key               DecodeFrame=0 WithOptions=0 handlerCalls=2 infoFlags=0 ...AndOutputHandler=-12902
  ContentAnalyzerRotation=90   DecodeFrame=0 WithOptions=0 handlerCalls=2 infoFlags=0 ...AndOutputHandler=-12902
  ContentAnalyzerCropRectangle DecodeFrame=0 WithOptions=0 handlerCalls=2 infoFlags=0 ...AndOutputHandler=-12902
```

`infoFlags` is the word handed in as `0x5a5a5a5a` and read back, so a `0` means the callee WROTE it and the
untouched value means it did not. `handlerCalls` counts the session's single-image callback, which is how a
refusal and a decode are told apart.

### Four of the six rows are answered here, and three of them are answered DIFFERENTLY from this port

| row | host | this port says | what the difference is |
| --- | --- | --- | --- |
| `VTDecompressionSessionDecodeFrameWithMultiImageCapableOutputHandler` | **-12902** with the handler NOT called and `infoFlags` untouched | -12913 | the host refuses with `kVTParameterErr`, and the control `DecodeFrame` on the SAME session answers 0 with one callback - so the refusal is about the variant, not the session or the sample |
| `VTCompressionSessionEncodeMultiImageFrame` | **0**, with `infoFlags=0x1` and the frame DROPPED (its callback reports status -12902 for that frame) | -12915 | the host ACCEPTS the call, returns noErr, and drops the frame: `kVTEncodeInfo_FrameDropped` is bit 0 of `VTEncodeInfoFlags`. A caller cannot tell from the status alone - only from `infoFlagsOut` |
| `VTCompressionSessionEncodeMultiImageFrameWithOutputHandler` | **-12902**, no callback | -12915 | again `kVTParameterErr`, not the encoder's not-available code |
| `VTDecompressionSessionDecodeFrameWithOptions` | **0 for all five cases**, and the decode HAPPENED (the single-image callback fired and `infoFlags` was written) | refuses a non-empty `frameOptions` with -12902 | see below |
| `VTDecompressionSessionDecodeFrameWithOptionsAndOutputHandler` | **-12902** for all five cases | -12913 | again `kVTParameterErr` |

**THE OPTIONS ANSWER IS THE ONE THAT SETTLES (b), and it is the opposite of what this facts page said before.**
An unknown key, `kVTDecodeFrameOptionKey_ContentAnalyzerRotation` and
`kVTDecodeFrameOptionKey_ContentAnalyzerCropRectangle` are all **IGNORED**: the host passes the decode through,
writes `infoFlags` and answers noErr, and the control decode on the same session behaves identically. The two
ContentAnalyzer keys are the ONLY `kVTDecodeFrameOptionKey_` in any SDK (both 26.0) and this host does not act
on either of them either, so the release does not implement them - which is consistent with the port's bands
having no `kVTDecodeFrameOptionKey_` of any kind, and it means the earlier reasoning on this page - "there is
no dictionary to ask, so a caller's options cannot be passed anywhere" - pointed at the wrong thing. The
options can be passed and are dropped.

That also removes the last stated obstacle to the two options rows: `VTDecompressionSessionDecodeFrameWithOptions`
is the release's own `VTDecompressionSessionDecodeFrame` plus an `infoFlagsOut` the port can forward, with the
options dictionary ignored the way the host ignores it.

### The arity claim on this page is retracted

The earlier text here said the 4.3 release's `VTDecompressionSessionDecodeFrame` takes four arguments and that
the port's five-argument forward would "call a four-argument function with five arguments at 4.3". **That was
backwards and it is gone.** On ARM an extra argument is harmless and a missing one is not, so calling the 16.4
SDK's five-parameter form at 4.3 is safe. What the iOS 8.0 annotation on `infoFlagsOut` says is when the symbol
became public, not how many arguments the 4.3 code reads.

## Why the one remaining divergence in this family cannot be closed, measured

`VTCompressionSessionEncodeMultiImageFrame` answers noErr and marks the frame dropped, as the host does, and does
NOT make the host's one output-callback call for that frame. Recorded in `coordination/crutches.md` as an open
crutch. The removal proposed there - "a per-session record of the caller's output callback taken at
VTCompressionSessionCreate with a lifetime tied to the session, an interposed create/invalidate pair" - **cannot be
built on this port's mechanism**, and the two reasons are measurements rather than opinions:

- **An interposed create cannot live in a band the port builds.** `_VTCompressionSessionCreate`,
  `_VTCompressionSessionInvalidate` and `_VTCompressionSessionCompleteFrames` are all exported by BOTH the 4.3
  and the 6.1.3 armv7 caches (`4.3=1 6.1.3=1` for each). `modules/apple/backports.lua`'s `band()` drops an
  object whose every exported symbol the band's release already exports, and raises if it exports such a symbol
  together with one the release lacks - so an object defining only `VTCompressionSessionCreate` is dropped from
  every band, and one defining it with anything else raises. `attach.c` interposes Objective-C classes and
  categories and has no C-symbol interposition. This is the same wall `VTSessionSetProperty` meets, measured, and
  it is why the rotation session's callbacks go through the registrar instead.
- **There is no public route to a session's output callback, even as a property.** Every property key the 4.3
  release exports, in full: `_kVTCompressionPropertyKey _kVTDecompressionProperty _kVTDecompressionPropertyKey
  _kVTImageRotationPropertyKey _kVTPixelTransferPropertyKey _kVTPropertyDocumentationKey
  _kVTPropertyReadWriteStatus _kVTPropertyReadWriteStatusKey _kVTPropertyShouldBeSerializedKey
  _kVTPropertySupportedValueListKey _kVTPropertySupportedValueMaximumKey _kVTPropertySupportedValueMinimumKey
  _kVTPropertyType _kVTPropertyTypeKey _kVTPropertyUserInterfaceKey`. Sixteen names, none of which carries a
  callback, and the four `kVTPropertyType`-shaped ones are the ATTRIBUTE vocabulary of a property dictionary, not
  a way to read one.

So the divergence stands, the row stays `implemented` with it named, and the crutch stays open with this reason
attached rather than with a remedy that would fail the same way twice.

## Source

- The ladder: `tools/corpus/dump-cache.lua` over `~/.charon/dyld/4.3/dyld_shared_cache_armv7` (read-only) and
  v-audio's 6.1.3 armv7 dump.
- SDK 26.2 `VTDecompressionSession.h:388-480` and `:484-566`, `VTCompressionSession.h:349-428`; `VTErrors.h:42`
  and `:45` for the two codes.
- The 16.4 SDK's `VTDecompressionSession.h:85-92` (the decode callback's shape) and `:184-190` (the decode's
  arity and its iOS 8 date).