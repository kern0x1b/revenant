# The interleaved and planar moves of vImage, iOS 7.0


The whole vImage half of this library answers **4.3**: the objects are this port's own arithmetic over headers the 4.3 SDK has, and the gate builds every one of them for 4.3 (measured - the 4.3 band's own note about what it leaves out no longer names any Accelerate object, and 134 of 134 registry rows are exported in its artifact).
Eight entry points in `Accelerate/vImagePlanar7.m`, and the twenty-four that are still to come in this group are named
at the end. Measured from the release's own armv7 caches, 7.0 is the first held release that exports the eight, so the file
holds the API of exactly one release.

Every answer is the host's own vImage, compared byte for byte by `tests/backports/host/vimageplanar`, which runs the port's
object and the host's over the same channels and compares every byte of every destination row, with the rows pre-filled so an
element only one side wrote is a difference.

## What the work is

Nothing but where each channel lands. Four of the eight move sixteen-bit values between an interleaved row and planar rows
with no arithmetic at all, and the other four apply one of the two scalings `facts/Accelerate/vImageFixedPoint.md` measured off
the host — 8 to 16Q12 is `(value * 4096 + 127) / 255` and 16Q12 to 8 is `round(value / 4096 * 255)` clamped.

| conversion | the shape |
| --- | --- |
| `vImageConvert_ARGB16UtoPlanar16U` | four interleaved 16-bit channels to four rows, alpha first |
| `vImageConvert_RGB16UtoPlanar16U` | three channels to three rows |
| `vImageConvert_Planar16UtoARGB16U` | four rows gathered into one interleaved ARGB row |
| `vImageConvert_Planar16UtoRGB16U` | three rows gathered into one interleaved RGB row |
| `vImageConvert_ARGB8888toPlanar16Q12` | four eight-bit channels to four 16Q12 rows, scaled |
| `vImageConvert_RGB888toPlanar16Q12` | three, scaled |
| `vImageConvert_Planar16Q12toARGB8888` | four 16Q12 rows to four eight-bit channels, scaled |
| `vImageConvert_Planar16Q12toRGB888` | three, scaled |

The refusals are the release's own and the ones the pixel and fixed-point groups already answer: a flag outside the set the
header lists is `kvImageUnknownFlagsBit`, `kvImageGetTempBufferSize` does no work and answers zero, a NULL buffer is
`kvImageNullPointerArgument`, and a destination larger than the source is `kvImageRoiLargerThanInputBuffer`.

## The twenty-four that are left in this group, and what each needs

They are four shapes, and the two measurements this band has already made settle most of them:

| shape | rows | what it needs |
| --- | --- | --- |
| indexed to planar 8 with a colour table, and back | 6 | `Indexed1/2/4toPlanar8` are a lookup of the index bits into the caller's `colors[]`, which is exact; the three `Planar8toIndexed*` take a `tempBuffer` **and a dither**, so they are the dithered shape below as well |
| planar 1/2/4 to planar 8 and back | 6 | the expands are `(index * 255 + half) / max` by the measured rule; the three shrinks (`Planar8toPlanar1/2/4`) take a `tempBuffer` **and a dither** |
| the thirty-two bit float rows | 8 | `ARGB8888toPlanarF`, `ARGBFFFFtoPlanar8`, `BGRXFFFFToPlanarF`, `Planar16FtoPlanar8`, `Planar8toPlanar16F`, `XRGBFFFFToPlanarF`, `BGRX8888ToPlanar8`, `XRGB8888ToPlanar8` — a float scale or a bit move each, and the two `16F` ones use the half-float code the fixed-point group already carries |
| the dithered and `int dither` forms | 4 | `PlanarFtoPlanar8_dithered` and `Planar16UtoPlanar8_dithered`, plus the shrinks above; the pattern is a fixed one and is recoverable from a constant row (facts/Accelerate/vImagePixels.md) |

## What has not been run

No device or emulator call test has been run for Accelerate in this port at all, so every answer on this page is a host
measurement and a device-unverified one.
