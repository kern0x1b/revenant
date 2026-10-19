# `CVIsCompressedPixelFormatAvailable`, and the two rules that were measured and thrown away

`CVIsCompressedPixelFormatAvailable` arrived in iOS 15 and answers a question about the **device**,
not about the format. The header says so in the block it heads:

> IMPORTANT CAVEATS: Some devices do not support these pixel formats at all. Before using one of
> these pixel formats, call CVIsCompressedPixelFormatAvailable() to check that it is available on the
> current device.

So the answer is false for a device whose hardware cannot encode and decode these formats, and that
is what the port answers: the releases this port supports are iOS 6.1.3 and iOS 4.3, and the
compressed pixel formats the header lists arrived with hardware those releases predate.

## Two rules that looked right and are not

The first version of this measured the host's whole registry and picked a rule out of the result.
Both candidates were checked against every format the host registers, and both lose:

```
registered: total=294 no_description=0 host_yes=110 host_no=184 descriptions_with_codec=0 without=294
rule by codec type: agrees=184 of 294, disagrees=110
rule by '&' FourCC:   agrees=252 of 294, disagrees=42
```

**By the description naming a codec.** The obvious rule is that a compressed format's description
carries a `kCVPixelFormatCodecType`. Over the host's 294 registered formats, **zero** descriptions
carry one, and the host still answers true for 110 of them. The rule is false in every row where the
answer is true, so it had been checked against nothing: on the hand-picked list of thirty ordinary
formats it scored 30/30, and every one of those thirty is a row the host answers false for. The
enumeration is what caught it.

**By the `&` FourCC.** The header writes the lossless forms as the uncompressed format with the high
byte changed (`kCVPixelFormatType_Lossless_32BGRA = '&BGA'`), so "the high byte is `&`" gets 252 of
294. The 42 it misses are the lossy block's own marks (`-`, `/`, `|`) and `*&Lh`, and reverse
engineering a bitmask that covers them would be a rule invented to fit a table on a machine that is
not the target.

Neither is used. What the port answers is the device, and the difference is stated rather than
papered over: over the host's 294 registered formats the host calls 110 available and this port
calls none, because every one of the 110 is a compressed FourCC for hardware this port's releases do
not have.

## The thirty ordinary formats, where the two agree

Over the thirty formats the port asks about — the ordinary uncompressed ones, the codec-compressed
FourCCs the header's own prose names (`avc1`, `hvc1`, `hev1`, the ProRes family, `bp64`, `bp16`),
`dvh `, `rle `, and two that are nothing at all — the host answers **false for all thirty** and the
port agrees on all thirty. `host_yes=0`. That is the part of the answer a caller on this port acts on.
