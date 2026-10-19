# The six VideoToolbox queries: what the host answers, and what the release can answer at each band

Six functions SDK 26.2 declares, none of which any release this port builds exports:

| row | SDK | 4.3 | 6.1.3 | 16.0 | 18.0 |
| --- | --- | --- | --- | --- | --- |
| `VTIsHardwareDecodeSupported` | 11.0 | absent | absent | - | - |
| `VTIsStereoMVHEVCDecodeSupported` | 17.0 | absent | absent | - | - |
| `VTIsStereoMVHEVCEncodeSupported` | 17.0 | absent | absent | - | - |
| `VTCreateCGImageFromCVPixelBuffer` | 9.0 | absent | absent | - | - |
| `VTCopySupportedPropertyDictionaryForEncoder` | 11.0 | absent | absent | - | - |
| `VTRegisterSupplementalVideoDecoderIfAvailable` | 26.2 | absent | absent | - | - |

Measured with `tools/corpus/dump-cache.lua` over `~/.charon/dyld/4.3/dyld_shared_cache_armv7` (read-only)
and over v-audio's 6.1.3 armv7 dump, and over `coordination/corpus/caches/{6.0,7.0.1,10.3.4,12.0,16.0,18.0}.tsv`.

## A NEGATIVE RESULT THAT DECIDES THE FIRST ROW

`VTIsHardwareDecodeSupported` was going to be answered through the decoder's own supported-property
dictionary. **That function does not exist at any band the port builds or any band this wave holds**:

```
_VTDecompressionSessionCopySupportedPropertyDictionaryForDecoder   4.3=0  6.1.3=0  6.0=0  7.0.1=0  10.3.4=0  12.0=0  16.0=0  18.0=0
_VTCompressionSessionCopySupportedPropertyDictionaryForEncoder    4.3=0  6.1.3=0  6.0=0  7.0.1=0  10.3.4=0  12.0=0  16.0=0  18.0=0
```

so there is no dictionary to ask, at any band, and a port that answered from one would be answering from
nothing.

**The route that does exist is the release's own, and it is a specification key rather than a query:**

```
_kVTVideoDecoderSpecification_RequireHardwareAcceleratedVideoDecoder   4.3=1  6.1.3=1
_kVTDecompressionPropertyKey_UsingHardwareAcceleratedVideoDecoder      4.3=1  6.1.3=1
_kVTVideoEncoderSpecification_RequireHardwareAcceleratedVideoEncoder   4.3=1  6.1.3=1
_VTSessionCopySupportedPropertyDictionary                             4.3=1  6.1.3=1
_VTCopyVideoEncoderList                                               4.3=0  6.1.3=1
```

A decompression session created with `kVTVideoDecoderSpecification_RequireHardwareAcceleratedVideoDecoder` set
to true exists only if the release can decode that codec in hardware, so asking the release by creating that
session IS the release's answer, on every band - not a table of which codec this hardware has.

## What the host answers, measured 2026-10-03 on this Mac

```
VTIsHardwareDecodeSupported
  H264             0x61766331 -> 1        MPEG2              0x6d703276 -> 0
  HEVC             0x68766331 -> 1        JPEG               0x6a706567 -> 1
  AppleProRes422   0x6170636e -> 1        Animation          0x726c6520 -> 0
  AV1              0x61763031 -> 1        VP9                0x76703039 -> 0
VTIsStereoMVHEVCDecodeSupported   -> 1
VTIsStereoMVHEVCEncodeSupported  -> 1
VTRegisterSupplementalVideoDecoderIfAvailable (returns void)
  VP9 before 0 -> after 1
  AV1 before 1 -> after 1
VTCreateCGImageFromCVPixelBuffer, a 3x2 buffer, options NULL
  32BGRA  -> 0  3x2 bits=8 bytesPerRow=64 bitmapInfo=0x2002
  32ARGB  -> 0  3x2 bits=8 bytesPerRow=64 bitmapInfo=0x4002
  420 biplanar -> 0  3x2 bits=8 bytesPerRow=64 bitmapInfo=0x2006
  OneComponent8 -> 0  3x2 bits=8 bytesPerRow=64 bitmapInfo=0x2006
VTCopySupportedPropertyDictionaryForEncoder(320, 240, codec, NULL, &id, &properties)
  codec 0x61766331 H264       -> 0  encoderID=com.apple.videotoolbox.videoencoder.ave.avc              keys=140
  codec 0x68766331 HEVC       -> 0  encoderID=com.apple.videotoolbox.videoencoder.ave.hevc             keys=169
  codec 0x6170636e ProRes422  -> 0  encoderID=com.apple.videotoolbox.videoencoder.appleproreshw.422   keys=59
  codec 0x6a706567 JPEG       -> 0  encoderID=com.apple.videotoolbox.videoencoder.jpeg.ajpeg           keys=54
  codec 0x6d703276 MPEG2      -> -12908  encoderID=(null)  keys=0
  codec 0x61763031 AV1        -> -12908  encoderID=(null)  keys=0
```

Two things in that table are the whole content of the row:

- **every value is an ATTRIBUTE DICTIONARY**, not a value and not nothing. Counted per codec:

  | codec | keys | NULL values | attribute dictionaries | of those, EMPTY | with `PropertyType` | `ReadWrite` | `ReadOnly` |
  | --- | --- | --- | --- | --- | --- | --- | --- |
  | H264 | 140 | **0** | 140 | 45 | 82 | 81 | 14 |
  | HEVC | 169 | **0** | 169 | 43 | 92 | 110 | 16 |
  | ProRes422 | 59 | **0** | 59 | 59 | 0 | 0 | 0 |
  | JPEG | 54 | **0** | 54 | 52 | 2 | 2 | 0 |

  A non-empty one is `{ PropertyType = Number; ReadWriteStatus = ReadWrite; }`, and the 14 H264 and 16 HEVC
  read-only properties are `{ PropertyType = Number; ReadWriteStatus = ReadOnly; }`. The rest are `{ }`, empty
  dictionaries - and ProRes422's fifty-nine are ALL empty, which is that encoder's own answer rather than a
  defect in the reading. So the function builds a key set AND a per-key attribute dictionary, and the port
  has to answer both.
- **a codec with no encoder answers `kVTCouldNotFindVideoEncoderErr` (-12908)**, with no encoder ID and no
  dictionary, rather than an empty dictionary. `-12908` is the release's own code (`VTErrors.h:37`). That part
  of the first measurement stands.

**The first version of this section was wrong, and the correction is the interesting part.** It said every
value in the dictionary was NULL - 140 keys and 140 NULL values - and told the reader the port must not invent
any. The cause was the probe's, not the function's: `CFDictionaryGetKeysAndValues` takes **two** buffers, one
for the keys and one for the values, and that probe passed a single buffer of `n` entries and read the values
out of its second half, which is past the end of what it had allocated. With two buffers the same call answers
0 NULL values for every codec. The coordinator's own measurement of H264 - 140 keys, 0 NULL, each value an
attribute dictionary - is what made me look at the buffer arithmetic instead of at the function.

Two readings in this family were mine before this one: the cross-format one in `PixelRotationSession.md`,
where an off-by-one on a destination pixel index made an exact channel swap look like a lossy conversion, and
the SIGSEGV below. All three were the same shape - an index computed by hand and then trusted - so the
harness for this row reads the dictionary through the documented two-buffer call and not through a hand-rolled
walk of it.

A first version of the probe asked for those six codecs in one process and died with SIGSEGV on the fifth;
each codec asked in its own process answers cleanly, so the crash was the probe's own doing - it was reading
the value of an entry through a bridge cast - and not the function's.

**The one row whose behaviour is a change rather than an answer is `VTRegisterSupplementalVideoDecoderIfAvailable`**:
it returns void, and on this host it moved `VTIsHardwareDecodeSupported(VP9)` from 0 to 1 - the decoder was
present on the system and not registered by default, which is exactly what its own documentation says it does.
That is a row with a measurement behind it rather than an empty function, and it is the one the first two rows
have to be read next to: a `VTIsHardwareDecodeSupported` that answered from a table would disagree with the
release after this call.

## The emulator run at 6.1.3: the hardware-requirement route does NOT answer the question

The route above is a SPECIFICATION rather than a query, and it was worth asking the release rather than
assuming. Asked, on the 6.1.3 armv7 release itself, through `xmake emulate -d iPhone3,1 -r 6.1.3`
(`tools/../work-2026-10-03/tools/` heavy lane, verdict `pass` in 6.2 host s), per codec, with and without
`kVTVideoDecoderSpecification_RequireHardwareAcceleratedVideoDecoder`:

```
vtdecodeprobe: the release answers
  kVTVideoDecoderSpecification_RequireHardwareAcceleratedVideoDecoder = RequireHardwareAcceleratedVideoDecoder
CREATE-WITH-AND-WITHOUT
  H264     format=0  noKey=-12906  withKey=-12906
  MPEG4    format=0  noKey=-12906  withKey=-12906
  JPEG     format=0  noKey=0       withKey=-12906
  HEVC     format=0  noKey=-12906  withKey=-12906
  ProRes   format=0  noKey=-12906  withKey=-12906
ENCODER-ID
  H264     compressionSession=-12902
  MPEG4    compressionSession=-12902
```

**`-12906` is `kVTVideoDecoderMalfunctionErr`** (VTErrors.h), and it is what the release answers for a
synthetic format description carrying no parameter sets - `CMVideoFormatDescriptionCreate` makes one, but a
real H264 or HEVC session needs an SPS and a PPS. So four of the five codecs never got as far as the
question. The one that did is the answer: **JPEG creates with `noErr` and FAILS with the key.** The key does
not open anything this release can do; it only removes what it could do.

**The emulator has NO decoder hardware at all**, and that is the reading which decides the row. "JPEG creates
without the key and fails with it" is ALSO exactly what a release that DOES honour the key answers on a
machine with no hardware JPEG decoder - so the run cannot tell an ignored key from an honoured one, and any
conclusion about the key's behaviour from this run would be a guess. What the run does establish is the two
things it can: that four codecs never reached the question (no parameter sets), and that on this machine the
key cannot help. So `VTIsHardwareDecodeSupported` **stays owed**, and the reason is the stronger one: **the
oracle is a device with real parameter sets**, not this machine. The row has no other reading available on any
band this port builds either - `_VTIsHardwareDecodeSupported` arrived with iOS 11 and
`_VTDecompressionSessionCopySupportedPropertyDictionaryForDecoder` does not exist at 4.3, 6.0, 6.1.3, 7.0.1,
10.3.4, 12.0, 16.0 or 18.0, so there is nothing left to ask.

Two further numbers from that run, both of which settle something else:

- **`VTSessionCopyProperty(kVTCompressionPropertyKey_EncoderID)` cannot be the route at either band**: the
  key is a NULL POINTER there. `dump-cache.lua` finds no `_kVTCompressionPropertyKey_EncoderID` in the 4.3
  or the 6.1.3 cache, and the probe's own build says the same thing in the gate's words - "weakly imports 1
  symbol the armv7 release it is checked against does not export, each of which is NULL there and must be
  called only behind a check for it" - which is why the image needed `charon.waive.weak-imports` and a
  reason. The probe prints `EncoderIDkey=NULL` and takes the other branch. So an encoder ID, which is an
  iOS 11 idea, does not exist on this port's floor at all.
- **`VTCompressionSessionCreate` answers `-12902` for a NULL encoder specification** at 6.1.3, measured for
  H264 and MPEG4. The 16.4 SDK's signature takes the specification dictionary in that position and the
  header calls it optional, but the release refuses NULL there, so a caller who passes NULL gets an error
  and not a session - which is the case `VTCopySupportedPropertyDictionaryForEncoder` has to answer.

The arity question, which the coordinator asked to settle from the 4.3 and 6.1.3 armv7 code, is settled by the
run's own output and in the coordinator's direction: `DecodeFrame(NULL sample)=-12902 infoFlags=0x5a5a5a5a`
- the word handed in as the fifth argument came back UNCHANGED, and in any case an EXTRA argument is
harmless on ARM while a MISSING one is not, so calling the 16.4 SDK's five-parameter form at 4.3 is safe and
my earlier claim that it "calls a four-argument function with five arguments at 4.3" was backwards. It is
retracted; the two options variants are no longer blocked by the arity.

## Source

- `coordination/corpus/caches/*.tsv` and the 4.3 and 6.1.3 caches, read-only, for the ladder.
- This Mac's own VideoToolbox, for the host's answers: `.agent-work/v-audio2/queries.m`, and
  `.agent-work/v-audio2/enc.m` for the one-codec-per-process table above.
- `VTErrors.h:37` for `kVTCouldNotFindVideoEncoderErr`.
- SDK 26.2 `VTUtilities.h:27-61`, `VTDecompressionSession.h:321-344`, `VTCompressionSession.h:341-346` and
  `VTVideoEncoderList.h:55-64`.