# AVAudioConverter - over real AudioConverterServices

`AVAudioConverter` does not exist on iOS 6.0/6.1.3 (confirmed via `objc.inventory` against the real
armv7 shared cache before any code was written, same discipline as
`facts/AVFoundation/AVAudioEngine.md`). What it sits on is real: `AudioConverterNew`,
`AudioConverterDispose`, `AudioConverterReset`, `AudioConverterConvertComplexBuffer`,
`AudioConverterFillComplexBuffer`, `AudioConverterSetProperty`/`AudioConverterGetProperty` all
resolve via `dlsym` in a running armv7 process on the 6.1.3 guest (`facts/AVFoundation/AVAudioEngine.md`,
same probe).

## What is built

`-initFromFormat:toFormat:` is a real `AudioConverterNew` call; it returns `nil` (never a crash)
when the release cannot build the requested conversion, matching the real class's own documented
behaviour. `-convertToBuffer:fromBuffer:error:` maps onto `AudioConverterConvertComplexBuffer`,
which Apple's own header restricts to "PCM-to-PCM conversions where there is no sample rate
conversion" - the same restriction this port's method carries, not a narrower one invented for it.
`-convertToBuffer:error:withInputFromBlock:` maps onto `AudioConverterFillComplexBuffer`, which does
support sample-rate conversion and packetized/compressed formats; this port's own C input proc
(`CharonConverterInputProc`, `AVAudioConverter.m`) bridges it to the caller's Objective-C block,
copying the block-returned `AVAudioBuffer`'s own buffer list into the converter's `ioData` rather
than allocating a second copy.

`AudioConverterComplexInputDataProc`'s C-level `OSStatus` return has no vocabulary for "no data
*right now*, ask again" - only "stop, this is a real error" (Apple's own header: "If the callback
returns an error ... `FillComplexBuffer` will stop producing output"). This port's bridge invents a
private four-char sentinel (`kCharonConverterNoDataNow`, `'noda'`), returned only by this file's own
proc and inspected only by the wrapper that installed it, never surfaced past `AVAudioConverter.m`,
to distinguish `AVAudioConverterInputStatus_NoDataNow` (temporarily starved, produces
`AVAudioConverterOutputStatus_InputRanDry`) from `AVAudioConverterInputStatus_EndOfStream` (a real
`noErr`/zero-packets signal, produces `AVAudioConverterOutputStatus_EndOfStream`).

## Two properties with no real C-level effect on iOS - checked, not assumed

`downmix` and `dither` are real, writable, stored `BOOL` properties with **no fabricated
AudioConverterSetProperty call behind them**, because neither has one on this platform:

- there is no `AudioConverter.h` constant for downmixing at all - checked against the real SDK
  header before writing this, not assumed from the ObjC property's name;
- `kAudioConverterPropertyDithering`/`kDitherAlgorithm_*` exist in the header but are declared
  under `#if !TARGET_OS_IPHONE` - macOS only, never available on iOS, iOS 6 or any other release.

Inventing a plausible-sounding C property for either would have been exactly the
`AVAudioUnitEQFilterParameters.active` mistake again (see `facts/AVFoundation/AVAudioEngine.md`), at
the C-symbol level instead of the Objective-C one - checked against the real header instead.

`sampleRateConverterAlgorithm` uses the real, still-functional
`kAudioConverterSampleRateConverterAlgorithm`, which Apple's header marks deprecated in favour of
`kAudioConverterSampleRateConverterComplexity` - not used here because that replacement takes a
different kind of value (a complexity level, not an algorithm name) and is not a drop-in
replacement for what this ObjC property's own documented semantics call for.

The four `Encoding` category arrays (`availableEncodeBitRates`, `applicableEncodeBitRates`,
`availableEncodeSampleRates`, `applicableEncodeSampleRates`, `availableEncodeChannelLayoutTags`) and
`maximumOutputPacketSize` answer `nil`/`0` - Apple's own header documents exactly that answer for a
converter that is not encoding, which every converter this port builds today is (PCM-to-PCM/
PCM-to-linear only, demand-driven, no compressed encoder attempted yet). `bitRate` and
`bitRateStrategy` are real, writable, stored state that no encoder this port builds yet reads.

## Verification - measured, not assumed

**`checks=8 failures=0`, `tests/backports/device/avaudioconverter.m`**, run through
`xmake emulate -d iPhone4,1 -r 6.1.3 run /usr/libexec/charon-avaudioconverter-test`
(`pass ... in 0.1 guest s / 6.2 host s`): a known 440 Hz tone, Float32 at 44.1 kHz, converted down
to Int16 at the same sample rate and back up to Float32, both hops through
`-convertToBuffer:fromBuffer:error:` (same rate, no codec, the documented restriction this call
carries). The only error a round trip like this can introduce is Int16 quantization, and that error
has a bound nameable *before* the run: `AVAudioPCMFormatInt16` maps the float range `[-1, 1]` onto
the int16 range `[-32768, 32767]`, so neither hop can move a sample by more than one int16 step -
`1/32768` per hop, `2/32768 = 0.00006103515625` for the round trip. The check asserts the measured
max error is both greater than zero (the conversion actually quantized something, not an accidental
no-op copy) and no greater than that bound.

Measured max `|round-tripped - source| = 0.0000152587890625` - about half the named bound, and
almost exactly `1/65536` (half an int16 step), which is exactly what round-to-nearest quantization
predicts for a full-scale sine tone. Comfortably inside the bound named before the run, and clearly
non-zero: the round trip really did quantize, not silently pass the buffer through unchanged.

**One real bug the first run of this probe caught, not a fabricated-API mistake this time**: both
convert methods first failed every time with `OSStatus -50` (`paramErr`) - the same shape of failure
`AVAudioEngine`'s own `AudioUnitRender`/Output-scope-format trap was
(`facts/AVFoundation/AVAudioEngine.md`). Cause: a freshly allocated `AVAudioPCMBuffer` already owns
real, calloc'd sample memory at its full `frameCapacity` (`AVAudioPCMBuffer8.m`), but its
`AudioBufferList`'s `mDataByteSize` starts at 0, mirroring the real class - it tracks `frameLength`,
not capacity. `AudioConverterConvertComplexBuffer`/`AudioConverterFillComplexBuffer` both read
`mDataByteSize` as the room they have to write into, so an output buffer nobody has written to yet
looks like zero capacity and the call fails `paramErr` on the very first write - every earlier setup
call (constructing the converter, the format) had already succeeded, exactly the "compiles, runs,
fails only at the real render/convert call" shape this cluster keeps finding. Fixed in
`AVAudioConverter.m`: both convert methods now claim the output buffer's full intended byte range
via `-setFrameLength:` *before* calling into AudioConverterServices, not after.

## Not yet closed

- The `convertToBuffer:error:withInputFromBlock:` path (sample-rate conversion, the general path)
  has no measured proof yet - only the simple `-convertToBuffer:fromBuffer:error:` round trip above
  is designed and running.
- `magicCookie` is kept as real stored state, not yet wired to a compressed-format decoder/encoder -
  no application in the corpus needs one yet.
- Encoding (`bitRate`/`bitRateStrategy` actually producing a compressed stream) is not attempted;
  every converter this port builds is PCM-to-PCM/PCM-to-linear.
