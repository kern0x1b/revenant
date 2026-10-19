# The colour transformers of a cell or button configuration, iOS 14

`UIConfigurationColorTransformerGrayscale`, `UIConfigurationColorTransformerPreferredTint` and
`UIConfigurationColorTransformerMonochromeTint` (`UIKit/UIConfigurationColorTransformers14.m`).

## These are functions, not values

The release holds a **block** at each of these symbols, not a value. Reading the symbol out of a
real cache gives the address of the release's own code, and an address is not a thing this port can
export - `tools/corpus/const-values.py` reports it as it should ("raw bytes: the declared type is
not a scalar this reads", `UIColor * (^)(UIColor *)`):

| release | cache | the symbol holds |
| --- | --- | --- |
| 16.0 | `dyld_shared_cache_arm64e` | `0x1d8...` (code) |
| 18.0 | `dyld_shared_cache_arm64e` | `0x1e8...` (code) |

So these three are implemented as the three transforms the SDK's own header documents, and what is
carried is their behaviour. Each of them is a real transform over a real `UIColor`; none of them
answers a fixed value.

## Grayscale

> A color transformer that returns a grayscale version of the color.

The grayscale of a colour is what CoreGraphics computes when the colour is matched into a gray
colour space, so that is what this does: `CGColorCreateCopyByMatchingToColorSpace` into
`CGColorSpaceCreateDeviceGray()` with the default rendering intent, which keeps the colour's alpha
and discards its hue. A colour CoreGraphics cannot match that way - a pattern colour, which has no
components - is returned unchanged, because there is no grayscale *version* of it to return.

**Not measured:** the release's own gray space and rendering intent. No release that carries these
blocks can be run for the port's architecture, and the host differential that would compare them
does not build on this machine (`os/workgroup_object.h` is broken by the installed SDK's
CommandLineTools - measured by another band, FLEET.md 2026-09-27 17:45). `kCGRenderingIntentDefault`
into the device gray space is CoreGraphics' own default match, which is the plainest reading of
"a grayscale version of the color"; a release that chose a perceptual or saturation intent would
differ from it in the last bits. A caller that compares these colours exactly should compare their
grayscale-ness (equal components) rather than the exact triple.

## Preferred tint

> A color transformer that either passes the original color through, or replaces it with the system
> accent color.
> - When the system accent color is set to Multicolor: Returns the original color.
> - When the system accent color is configured to any other color: Returns that color.
> - On platforms without a system accent color: Returns the original color.

The third case is this one, and the header states it as its own case. The system accent colour is
iOS 15's, and a control's accent on iOS 6 is the tint the application gives it - there is no colour
the system picks and no "Multicolor" setting. The original colour is therefore the original colour,
which is a real answer to the contract rather than a stand-in: on such a platform the accent is
never anything but the input.

## Monochrome tint

> A color transformer that gives the color a monochrome tint. Use this to deemphasize the tinted
> item. It remains monochrome regardless of the system accent color (if the platform has one).

The two documents read together say what this is. Its difference from PreferredTint is the second
sentence: the accent colour does not reach it, so the colour the system would otherwise have
substituted is the input itself - and it is made monochrome, which is the whole point of it. On a
platform with no accent colour that is the grayscale of its input: monochrome (equal components) and
accent-independent, which are the two properties the header names.

**Not measured:** the exact blend the release performs. The header gives no more than "a monochrome
tint" and the accent-independence, and the release that performs it cannot be run here, so the blend
is the plainest one that satisfies both: the grayscale, which `Grayscale` above is also measured
against. A caller that depends on the exact triple rather than on it being monochrome is depending
on something the header does not promise.
