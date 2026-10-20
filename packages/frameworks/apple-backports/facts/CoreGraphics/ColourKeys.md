# Option and key names of colour conversion and bitmap contexts, iOS 10 and 11

Source: the macOS CoreGraphics of the host, read with the probe of `tests/backports/host/cgpdf-names`, which prints
each constant's string. `Introduced` is the first held release that exports the constant, measured by
`tools/release-split.lua` over the held caches (11.0 to 18.0); where no held cache names the constant, it is the SDK
header's `API_AVAILABLE`. The release's own strings on iOS 10 and later were not read: no such device runs here.

| Constant | Introduced | Text |
| --- | --- | --- |
| `kCGColorConversionBlackPointCompensation` | 10.0.1 | `kCGColorTransformBlackPointCompensation` |
| `kCGColorConversionTRCSize` | 11.0 | `kCGColorConversionTRCSize` |
| `kCGAdaptiveMaximumBitDepth` | 11.0 (SDK, not measured) | `kCGAdaptiveMaximumBitDepth` |

`kCGAdaptiveMaximumBitDepth` is the one name the measurement does not confirm: the SDK 26.2 `CGBitmapContext.h` gives
it `API_AVAILABLE(ios(11.0))` and `CoreGraphics.tbd` exports it, but no held cache (11.0 to 18.0) contains the
name, so release-split reads it as `none`. It is in its own object, `CGBitmapContextNames11.m`, apart from the 11.0
colour key in `CGColorConversionNames11.m`, so that no object mixes releases.

The black point option is named `kCGColorTransformBlackPointCompensation` by the release's own text, and the
application writes the constant's name, so the port carries the text the release gives the constant.

As with the other names of `Names.md`, an application that names one loads on iOS 6 and gets the text. Nothing in
the port reads them: the colour conversion objects that take the black point option and the size key
(`CGColorConversionInfoCreate` and its family) and the bitmap context that takes the bit depth hint are not carried,
and their rows stay `absent`.

Test: `tests/backports/host/cgpdf-names` (the three constants are among its 1017 checks).
